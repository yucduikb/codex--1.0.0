@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall.ps1"
if errorlevel 1 (
  echo Restore incomplete. Keep the installation folder and read the error above.
  pause
  exit /b 1
)
pause
