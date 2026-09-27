@echo off
rem Start-menu logon job: force Start_Layout=1, then restart the shell.
rem
rem This file is the tracked master. Explorer executes .bat but not .ps1 from the
rem Startup folder, so Install-StartupJob.ps1 deploys a copy there and verifies it
rem is byte-identical. Keep the copy in step after editing this file.
rem
rem Self-contained on purpose: no PowerShell, no shortcuts, nothing to resolve at
rem logon. reg.exe and taskkill.exe are both in %SystemRoot%\System32.
rem
rem Log: %TEMP%\start_menu.log  (runtime state, deliberately outside the repo)

setlocal
set "LOG=%TEMP%\start_menu.log"
set "KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

echo [%DATE% %TIME%] start_menu.bat running >> "%LOG%"

rem reg.exe rather than a PowerShell one-liner: this is the whole job, and
rem reg.exe starts in milliseconds with no execution-policy or PATH concerns.
reg add "%KEY%" /v Start_Layout /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] FAILED: reg add exit %errorlevel% >> "%LOG%"
    exit /b 1
)
echo [%DATE% %TIME%] Start_Layout=1 written >> "%LOG%"

rem Hand the restart to a detached process so this console closes immediately
rem instead of sitting visible for the whole delay. The delay itself matters:
rem Startup items are dispatched *by* explorer, so killing it before that pass
rem finishes aborts whatever has not launched yet (WinPie, test_01.ahk, pending
rem Run keys). Costs one minimised console in the taskbar for the duration.
rem
rem explorer is relaunched explicitly rather than trusting Windows to notice the
rem shell died: observed on this machine, a bare taskkill left the desktop down
rem until something started explorer again. /v:on + !DATE!/!TIME! so the log
rem timestamp is taken when the kill actually happens, not when this line parses.
start "" /min cmd /v:on /c "ping -n 9 127.0.0.1 >nul & taskkill /f /im explorer.exe & ping -n 4 127.0.0.1 >nul & start explorer.exe & echo [!DATE! !TIME!] explorer killed and relaunched >>"%LOG%""
exit
