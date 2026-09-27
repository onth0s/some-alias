# Force the Start-menu layout at logon, then restart the shell.
#
# Launched by start_menu.lnk in the Startup folder, which Install-StartupShortcut.ps1
# deploys from the copy tracked in this repo. Explorer's logon pass executes .lnk
# files but not .ps1, which is the whole reason the shortcut exists.
#
# The shortcut passes -NoProfile: this is a login task, and it must not depend on
# the Documents\PowerShell shim chain-dot-sourcing the 58KB profile. A throwing
# profile would otherwise kill the task silently, with no console at logon to show it.
#
# Log: %TEMP%\start_menu.log  (runtime state, deliberately outside the repo)

$log = Join-Path $env:TEMP 'start_menu.log'

function Write-Log {
    param([Parameter(Mandatory)][string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.ff'), $Message
    Add-Content -LiteralPath $log -Value $line
}

Write-Log 'start_menu.ps1 running'

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
try {
    Set-ItemProperty -Path $key -Name Start_Layout -Value 1 -Type DWord -ErrorAction Stop
    Write-Log 'Start_Layout=1 written'
} catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}

# Startup items are dispatched *by* explorer, so killing it before that pass
# finishes aborts whatever has not launched yet (WinPie, test_01.ahk, pending Run
# keys). Wait them out first.
Start-Sleep -Seconds 8
Stop-Process -Name explorer -Force
Write-Log 'explorer killed'
