#!/bin/bash
# LeLab-zh 启动 (macOS)
INSTALL_DIR="$HOME/Library/Application Support/LeLab-zh"

if [ ! -f "$INSTALL_DIR/venv/bin/lelab-zh" ]; then
    echo "[错误] LeLab-zh 未安装或安装不完整。"
    echo "       请先运行「一键安装」。"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

echo "[启动] 正在启动 LeLab-zh..."
echo "[提示] 如果浏览器没有自动打开，请手动访问：http://127.0.0.1:8000"
echo ""

exec "$INSTALL_DIR/venv/bin/lelab-zh"
