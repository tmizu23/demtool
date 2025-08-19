@echo off
setlocal
chcp 65001 >nul
set SCRIPT_DIR=%~dp0
set PS1=%SCRIPT_DIR%main_jp.ps1
if not exist "%PS1%" (
  echo PowerShell script not found: %PS1%
  pause
  exit /b 1
)
rem 日本語専用ランチャー (/silent オプション削除)
start "DEMConvertJP" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -STA -File "%PS1%"
exit /b 0
