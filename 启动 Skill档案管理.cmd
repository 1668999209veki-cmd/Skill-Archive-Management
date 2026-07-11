@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo.
echo Skill Archive Management
echo Generating and opening skill-archive.html...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\setup-dashboard.ps1"

if errorlevel 1 (
  echo.
  echo Failed to start. Make sure PowerShell is available and run this file from the repository root.
  echo.
  pause
  exit /b 1
)

echo.
echo Done. If the browser did not open, open skill-archive.html manually.
echo.
pause
