@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
if errorlevel 1 (
  echo Installation failed. Keep the error above for troubleshooting.
  pause
  exit /b 1
)
echo Installation complete. Open Codex from the Desktop or Start Menu shortcut.
pause
