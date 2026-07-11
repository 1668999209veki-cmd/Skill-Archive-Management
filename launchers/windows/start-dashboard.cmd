@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%..\.."
cd /d "%REPO_ROOT%"

echo.
echo Skill Archive Management
echo Generating and opening skill-archive.html...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\scripts\setup-dashboard.ps1"

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
