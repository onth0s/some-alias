<#
.SYNOPSIS
    Deploys start_menu.bat from this repo into the current user's Startup folder.

.DESCRIPTION
    Explorer's logon pass executes .bat files but not .ps1, so the job has to sit
    in the Startup folder to run at all - which means it cannot simply live in the
    repo. This copies the tracked master into place and then verifies the deployed
    copy is byte-identical, keeping the repo the source of truth and making drift
    detectable.

    Re-run after editing start_menu.bat, or on a new machine, to (re)deploy.

.EXAMPLE
    .\Install-StartupJob.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repo     = $PSScriptRoot
$master   = Join-Path $repo 'start_menu.bat'
$startup  = [Environment]::GetFolderPath('Startup')
$deployed = Join-Path $startup 'start_menu.bat'

if (-not (Test-Path -LiteralPath $master)) {
    throw "Missing required file: $master"
}

Copy-Item -LiteralPath $master -Destination $deployed -Force

$masterHash   = (Get-FileHash -LiteralPath $master   -Algorithm SHA256).Hash
$deployedHash = (Get-FileHash -LiteralPath $deployed -Algorithm SHA256).Hash
if ($masterHash -ne $deployedHash) {
    throw "Deployed copy does not match the master (SHA256 mismatch). Master=$masterHash Deployed=$deployedHash"
}

# start_menu.ps1 / start_menu.lnk were the previous mechanism. They are inert in the
# Startup folder (Explorer never ran the .ps1), so clear them out if present.
foreach ($stale in @('start_menu.ps1', 'start_menu.lnk', 'start_menu.bat.bak')) {
    $old = Join-Path $startup $stale
    if (Test-Path -LiteralPath $old) {
        Remove-Item -LiteralPath $old -Force
        Write-Host "removed stale: $stale" -ForegroundColor DarkGray
    }
}

Write-Host "deployed: $deployed"
Write-Host "sha256  : $masterHash  (matches master)" -ForegroundColor DarkGray
Write-Host "StartupApproved entry for start_menu.bat is written by Explorer at next logon." -ForegroundColor DarkGray
