#!/bin/bash
# LeLab-zh 停止 (macOS)
INSTALL_DIR="$HOME/Library/Application Support/LeLab-zh"

if [ ! -f "$INSTALL_DIR/venv/bin/lelab-zh" ]; then
    echo "[错误] LeLab-zh 未安装。"
    read -p "按回车键退出..."
    exit 1
fi

echo "[停止] 正在停止 LeLab-zh..."
"$INSTALL_DIR/venv/bin/lelab-zh" --stop
if [ $? -eq 0 ]; then
    echo "[完成] LeLab-zh 已停止。"
else
    echo "[警告] 停止命令返回非零退出码。"
fi
echo ""
read -p "按回车键退出..."
