@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lelab_windows.ps1" -Action repair
exit /b %ERRORLEVEL%
