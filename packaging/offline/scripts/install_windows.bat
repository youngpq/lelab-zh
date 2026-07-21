@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lelab_windows.ps1" -Action install
exit /b %ERRORLEVEL%
