@echo off
rem Start-menu logon job: force expanded/large Start menu, then restart the host.
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
set "SKEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Start"
set "AKEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

echo [%DATE% %TIME%] start_menu.bat running >> "%LOG%"

rem New menu (24H2 build 26120.4250+, all 25H2): the old Start_Layout value is
rem ignored, so force its replacements instead.
reg add "%SKEY%" /v ShowAllPinsList /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] FAILED: ShowAllPinsList exit %errorlevel% >> "%LOG%"
    exit /b 1
)
reg add "%SKEY%" /v StartMenuSize /t REG_DWORD /d 2 /f >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] FAILED: StartMenuSize exit %errorlevel% >> "%LOG%"
    exit /b 1
)
echo [%DATE% %TIME%] ShowAllPinsList=1 StartMenuSize=2 written >> "%LOG%"

rem Legacy pre-redesign menu: ignored on the new menu, kept so the job is a
rem no-op-safe on old builds rather than doing nothing there.
reg add "%AKEY%" /v Start_Layout /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1

rem Restart only the Start host, not explorer. The host auto-relaunches on kill
rem (verified), so no explicit start and no delay are needed. That also avoids
rem the old job's 8s deferred explorer kill, which aborted pending Startup items
rem (WinPie, test_01.ahk, Run keys) when it fired too early.
taskkill /f /im StartMenuExperienceHost.exe >> "%LOG%" 2>&1
echo [%DATE% %TIME%] StartMenuExperienceHost restarted >> "%LOG%"
exit
