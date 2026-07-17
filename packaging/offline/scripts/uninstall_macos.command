#!/bin/bash
# LeLab-zh 卸载 (macOS)
INSTALL_DIR="$HOME/Library/Application Support/LeLab-zh"

echo "============================================================"
echo "  LeLab-zh 卸载程序"
echo "============================================================"
echo ""
echo "[警告] 这将删除 LeLab-zh 的安装文件和启动器。"
echo "       以下数据不会被删除："
echo "       - 用户录制的数据集"
echo "       - Hugging Face 缓存"
echo "       - 模型文件"
echo "       - 用户自己保存的训练结果"
echo ""
read -p "确认卸载？(y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "卸载已取消。"
    exit 0
fi

# 先停止
echo "[卸载] 正在停止 LeLab-zh..."
if [ -f "$INSTALL_DIR/venv/bin/lelab-zh" ]; then
    "$INSTALL_DIR/venv/bin/lelab-zh" --stop 2>/dev/null
fi

# 删除启动器
echo "[卸载] 删除启动器..."
rm -rf "$HOME/Applications/LeLab-zh.app"

# 删除安装目录
echo "[卸载] 删除安装目录..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "[完成] 安装目录已删除。"
else
    echo "[信息] 安装目录不存在，无需删除。"
fi

echo ""
echo "============================================================"
echo "  LeLab-zh 已卸载。"
echo "============================================================"
echo ""
read -p "按回车键退出..."
