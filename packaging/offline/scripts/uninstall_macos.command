#!/bin/bash
# LeLab-zh 卸载 (macOS)
INSTALL_DIR="$HOME/Library/Application Support/LeLab-zh"
LOCATION_FILE="$HOME/.lelab-zh-install-dir"
if [ -f "$LOCATION_FILE" ]; then
    SAVED_INSTALL_DIR="$(cat "$LOCATION_FILE")"
    if [ -n "$SAVED_INSTALL_DIR" ]; then
        INSTALL_DIR="$SAVED_INSTALL_DIR"
    fi
fi

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

# 移除 PATH 配置
echo "[卸载] 清理 PATH 配置..."

# 检测当前 shell 类型
if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.profile"
fi

PATH_MARKER="# LeLab-zh PATH configuration"

if [ ! -f "$SHELL_RC" ]; then
    echo "[信息] 配置文件不存在，无需移除"
elif grep -q "$PATH_MARKER" "$SHELL_RC"; then
    # 使用 sed 移除标记和后续的 export 行
    sed -i.bak "/$PATH_MARKER/,/^export PATH=\".*\/venv\/bin/d" "$SHELL_RC"
    rm -f "${SHELL_RC}.bak"
    echo "[完成] PATH 配置已从 $SHELL_RC 移除"
else
    echo "[信息] PATH 配置不存在，无需移除"
fi

# 删除启动器
echo "[卸载] 删除启动器..."
rm -rf "$HOME/Applications/LeLab-zh.app"
rm -f "$HOME/Desktop/启动LeLab.app"

# 删除安装目录
echo "[卸载] 删除安装目录..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    rm -f "$LOCATION_FILE"
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
