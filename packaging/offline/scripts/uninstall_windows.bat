@echo off
chcp 65001 >nul
title LeLab-zh 卸载
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"

echo ============================================================
echo   LeLab-zh 卸载程序
echo ============================================================
echo.
echo [警告] 这将删除 LeLab-zh 的安装文件和桌面快捷方式。
echo        以下数据不会被删除：
echo        - 用户录制的数据集
echo        - Hugging Face 缓存
echo        - 模型文件
echo        - 用户自己保存的训练结果
echo.
choice /c YN /m "确认卸载？"
if errorlevel 2 goto :cancel

echo [卸载] 正在停止 LeLab-zh...
if exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" --stop 2>nul
echo [卸载] 删除桌面快捷方式...
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
del "%DESKTOP%\Start LeLab.lnk" 2>nul
del "%DESKTOP%\启动LeLab.lnk" 2>nul
del "%DESKTOP%\启动LeLab-zh.lnk" 2>nul
if exist "%INSTALL_DIR%" goto :remove
echo [信息] 安装目录不存在，无需删除。
goto :done

:remove
echo [卸载] 删除安装目录...
rmdir /s /q "%INSTALL_DIR%"
echo [完成] 安装目录已删除。

:done
echo.
echo ============================================================
echo   LeLab-zh 已卸载。
echo ============================================================
echo.
pause
exit /b 0

:cancel
echo 卸载已取消。
pause
exit /b 0
