@echo off
setlocal
chcp 65001 >nul
if /i "%~1"=="/?" goto :help
set SCRIPT_DIR=%~dp0
set PS1=%SCRIPT_DIR%main_en.ps1
if not exist "%PS1%" (
  echo PowerShell script not found: %PS1%
  pause
  exit /b 1
)
rem English-only launcher (/silent removed)
start "DEMConvertEN" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -STA -File "%PS1%"
exit /b 0

:help
echo Usage: convert_and_merge.cmd
echo   /?   Show this help
exit /b 0
