@echo off
chcp 65001 >nul
title LeLab-zh 停止
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"

if not exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" (
    echo [错误] LeLab-zh 未安装。
    pause
    exit /b 1
)

echo [停止] 正在停止 LeLab-zh...
"%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" --stop
if %errorlevel% equ 0 (
    echo [完成] LeLab-zh 已停止。
) else (
    echo [警告] 停止命令返回非零退出码。
)
pause
exit /b 0
