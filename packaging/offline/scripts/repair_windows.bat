@echo off
chcp 65001 >nul
title LeLab-zh 修复安装
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"

if not exist "%PACKAGE_ROOT%\wheels\" (
    set /p PACKAGE_ROOT="请输入安装包解压目录路径: "
)

echo ============================================================
echo   LeLab-zh 修复安装
echo ============================================================
echo.

REM 1. 先停止正在运行的 LeLab
echo [修复] 正在停止 LeLab-zh...
if exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" (
    "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" --stop
)

REM 2. 备份旧 venv（失败时回退）
echo [修复] 备份旧环境...
set "BACKUP_DIR=%INSTALL_DIR%\venv.backup"
if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" 2>nul
if exist "%INSTALL_DIR%\venv" (
    move "%INSTALL_DIR%\venv" "%BACKUP_DIR%"
    echo [修复] 旧环境已备份到 %BACKUP_DIR%
)

REM 3. 重建 venv
echo [修复] 重建虚拟环境...
if exist "%INSTALL_DIR%\venv" rmdir /s /q "%INSTALL_DIR%\venv"
"%INSTALL_DIR%\uv\uv.exe" venv "%INSTALL_DIR%\venv" --python "%INSTALL_DIR%\runtime\python.exe"
if %errorlevel% neq 0 (
    echo [错误] 创建虚拟环境失败。正在恢复旧环境...
    if exist "%BACKUP_DIR%" move "%BACKUP_DIR%" "%INSTALL_DIR%\venv"
    echo [恢复] 已恢复旧环境。
    pause
    exit /b 1
)

REM 4. 重新安装依赖
echo [修复] 重新安装依赖...
"%INSTALL_DIR%\uv\uv.exe" pip install ^
  --python "%INSTALL_DIR%\venv\Scripts\python.exe" ^
  --offline ^
  --no-index ^
  --find-links "%PACKAGE_ROOT%\wheels" ^
  --require-hashes ^
  -r "%PACKAGE_ROOT%\requirements-offline.txt"
if %errorlevel% neq 0 (
    echo [错误] 依赖安装失败。正在恢复旧环境...
    rmdir /s /q "%INSTALL_DIR%\venv" 2>nul
    if exist "%BACKUP_DIR%" move "%BACKUP_DIR%" "%INSTALL_DIR%\venv"
    echo [恢复] 已恢复旧环境。
    pause
    exit /b 1
)

REM 5. 清理备份
if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" 2>nul

echo.
echo ============================================================
echo   修复安装完成。
echo ============================================================
echo.
pause
exit /b 0
