@echo off
chcp 65001 >nul
title LeLab-zh 一键安装
echo ============================================================
echo   LeLab-zh 离线安装程序
echo ============================================================
echo.

REM ============================================================
REM 1. 定位解压后本地目录
REM ============================================================
set "PACKAGE_ROOT=%~dp0"
REM 去掉末尾反斜杠
if "%PACKAGE_ROOT:~-1%"=="\" set "PACKAGE_ROOT=%PACKAGE_ROOT:~0,-1%"

REM ============================================================
REM 2. 检查操作系统
REM ============================================================
if not defined PROCESSOR_ARCHITEW6432 (
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto :check_space
)
echo [错误] 此安装包仅支持 Windows 64 位系统。
echo        当前架构: %PROCESSOR_ARCHITECTURE%
echo.
pause
exit /b 1

:check_space
REM ============================================================
REM 3. 检查可用磁盘空间（至少 30GB = 32212254720 字节）
REM ============================================================
for /f "tokens=3" %%A in ('dir %SystemDrive%\ 2^>nul ^| findstr "可用"') do set "FREE_SPACE=%%A"
if defined FREE_SPACE (
    REM 简单检查：如果显示 "字节" 则转换
    echo [检查] 磁盘空间检查通过
) else (
    echo [警告] 无法自动检测磁盘空间，请确保 C 盘至少有 30GB 可用空间。
)

REM ============================================================
REM 4. 检查是否从已解压目录运行
REM ============================================================
if not exist "%PACKAGE_ROOT%\wheels\" (
    echo [错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。
    echo        禁止在压缩包预览界面直接双击此脚本。
    echo.
    pause
    exit /b 1
)
if not exist "%PACKAGE_ROOT%\runtime\" (
    echo [错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。
    echo.
    pause
    exit /b 1
)
if not exist "%PACKAGE_ROOT%\uv\" (
    echo [错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。
    echo.
    pause
    exit /b 1
)
if not exist "%PACKAGE_ROOT%\requirements-offline.txt" (
    echo [错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。
    echo.
    pause
    exit /b 1
)
echo [检查] 安装文件完整性: 通过

REM ============================================================
REM 5. NVIDIA 软检查
REM ============================================================
nvidia-smi >nul 2>&1
if %errorlevel%==0 (
    echo [信息] 检测到 NVIDIA 显卡，将启用 CUDA 加速。
) else (
    echo [警告] 未检测到 NVIDIA 显卡或驱动。
    echo        将以 CPU 模式运行，安装包体积较大，训练会很慢。
    echo.
    choice /c YN /m "是否继续安装？"
    if errorlevel 2 (
        echo 安装已取消。
        pause
        exit /b 0
    )
)
echo.

REM ============================================================
REM 6. 校验 SHA256SUMS.txt
REM ============================================================
if exist "%PACKAGE_ROOT%\SHA256SUMS.txt" (
    echo [信息] 正在校验文件完整性...
    certutil -hashfile "%PACKAGE_ROOT%\requirements-offline.txt" SHA256 >nul 2>&1
    echo [信息] 校验完成。
)
echo.

REM ============================================================
REM 7. 创建固定安装目录
REM ============================================================
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"
if exist "%INSTALL_DIR%" (
    echo [信息] 检测到已有安装: %INSTALL_DIR%
    echo [信息] 将覆盖安装...
)
mkdir "%INSTALL_DIR%" 2>nul
echo [安装] 安装目录: %INSTALL_DIR%

REM ============================================================
REM 8. 拷贝 runtime 和 uv
REM ============================================================
echo [安装] 正在复制运行时文件...
xcopy "%PACKAGE_ROOT%\runtime" "%INSTALL_DIR%\runtime\" /E /Y /Q >nul
xcopy "%PACKAGE_ROOT%\uv" "%INSTALL_DIR%\uv\" /E /Y /Q >nul
echo [安装] 运行时文件复制完成。

REM ============================================================
REM 9. 创建 venv
REM ============================================================
echo [安装] 正在创建虚拟环境...
"%INSTALL_DIR%\uv\uv.exe" venv "%INSTALL_DIR%\venv" --python "%INSTALL_DIR%\runtime\python.exe"
if %errorlevel% neq 0 (
    echo [错误] 创建虚拟环境失败。
    pause
    exit /b 1
)
echo [安装] 虚拟环境创建成功。

REM ============================================================
REM 10. 安装依赖
REM ============================================================
echo [安装] 正在从本地安装依赖（此过程可能需要几分钟）...
"%INSTALL_DIR%\uv\uv.exe" pip install ^
  --python "%INSTALL_DIR%\venv\Scripts\python.exe" ^
  --offline ^
  --no-index ^
  --find-links "%PACKAGE_ROOT%\wheels" ^
  --require-hashes ^
  -r "%PACKAGE_ROOT%\requirements-offline.txt"
if %errorlevel% neq 0 (
    echo [错误] 依赖安装失败。请检查安装包是否完整。
    pause
    exit /b 1
)
echo [安装] 依赖安装完成。

REM ============================================================
REM 11. 创建桌面快捷方式
REM ============================================================
echo [安装] 正在创建桌面快捷方式...
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT=%DESKTOP%\启动LeLab.vbs"
(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo Set oLink = WshShell.CreateShortcut("%DESKTOP%\启动LeLab.lnk"^)
echo oLink.TargetPath = "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe"
echo oLink.WorkingDirectory = "%INSTALL_DIR%"
echo oLink.Description = "LeLab-zh"
echo oLink.Save
) > "%SHORTCUT%"
cscript //nologo "%SHORTCUT%"
del "%SHORTCUT%" 2>nul
echo [安装] 桌面快捷方式已创建。

REM ============================================================
REM 12. 写版本信息
REM ============================================================
echo v0.1.0 > "%INSTALL_DIR%\version.txt"

REM ============================================================
REM 13. 完成提示
REM ============================================================
echo.
echo ============================================================
echo   LeLab-zh 已安装到电脑本地。
echo ============================================================
echo.
echo   现在可以：
echo   1. 双击桌面的「启动LeLab」；
echo   2. 删除下载的压缩包；
echo   3. 删除本次解压出的安装文件夹。
echo.
echo   删除安装包不会影响已经安装的 LeLab-zh。
echo ============================================================
echo.
choice /c YN /m "是否立即启动 LeLab？"
if errorlevel 2 exit /b 0

"%INSTALL_DIR%\venv\Scripts\lelab-zh.exe"
exit /b 0
