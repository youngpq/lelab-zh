# LeLab 中文版

这是 [Hugging Face LeLab](https://github.com/huggingface/leLab) 的社区汉化 fork。它为 LeRobot 提供浏览器图形界面，可完成校准、遥操作、录制、训练、推理、回放与上传等流程。

> 本项目不是 Hugging Face 官方发布渠道。上游版权与 Apache-2.0 许可证见根目录 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。

## 安装与运行

### 1. 安装 uv

推荐使用 [uv](https://docs.astral.sh/uv/) 安装和运行 lelab-zh。uv 会自动管理 Python 版本和依赖隔离，无需额外安装 Python。

**Linux / WSL：**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**macOS：**

打开终端（启动台 → 终端，或 `Command + 空格` 搜索「终端」），粘贴：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows（PowerShell）：**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

安装完成后，关闭终端并重新打开，验证：

```bash
uv --version
```

> 若提示 `command not found`，执行 `source ~/.bashrc`（Linux）或 `source ~/.zshrc`（macOS），或重启终端。

### 2. 安装 Git

`uv tool install` 通过 `git+https://` 拉取仓库，需要系统已安装 git。

**Linux / WSL：**

多数发行版已预装。若未安装：

```bash
# Debian / Ubuntu
sudo apt install git -y

# RHEL / Fedora
sudo yum install git -y
```

**macOS：**

```bash
xcode-select --install
```

在弹出的对话框中点击「安装」，等待完成（约 2-5 分钟）。已安装过会提示 `already installed`，可跳过。

**Windows：**

```powershell
winget install --id Git.Git -e --source winget
```

或从 [git-scm.com](https://git-scm.com/download/win) 下载安装包。

验证：

```bash
git --version
```

### 3. 换源（国内用户推荐）

将 PyPI 依赖下载切换到清华镜像，大幅提升安装速度。**建议国内用户在安装 lelab-zh 前先执行。**

**Linux / macOS：**

```bash
export UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
export UV_HTTP_TIMEOUT=600
export UV_HTTP_RETRIES=10
export UV_CONCURRENT_DOWNLOADS=4
```

持久化（每次打开终端自动生效）：
- Linux：将以上四行加入 `~/.bashrc`，再执行 `source ~/.bashrc`
- macOS：将以上四行加入 `~/.zshrc`，再执行 `source ~/.zshrc`

**Windows（PowerShell）：**

```powershell
$env:UV_DEFAULT_INDEX = "https://pypi.tuna.tsinghua.edu.cn/simple"
$env:UV_HTTP_TIMEOUT = "600"
$env:UV_HTTP_RETRIES = "10"
$env:UV_CONCURRENT_DOWNLOADS = "4"
```

持久化：打开「系统属性 → 环境变量」添加以上四个用户变量。

> **注意**：GitHub 仓库本身仍通过 GitHub 下载。如果 GitHub 完全无法访问，可先将仓库 clone 到本地再通过 `uv tool install .` 从本地安装。

### 4. 安装 lelab-zh

```bash
uv tool install --python 3.12 \
  git+https://github.com/youngpq/lelab-zh.git@v0.1.0-zh.1
```

安装或覆盖同一版本：

```bash
uv tool install --force --reinstall --refresh --python 3.12 \
  git+https://github.com/youngpq/lelab-zh.git@v0.1.0-zh.1
```

首次安装需要网络连接以下载 Python、PyTorch、LeRobot 和相关依赖。若 `lelab-zh` 不在 PATH：

```bash
uv tool update-shell
```

### 5. 运行

```bash
lelab-zh
```

浏览器会自动打开 LeLab 界面。未自动打开时手动访问 <http://127.0.0.1:8000>。

> **macOS 提示**：如果弹出「无法验证开发者」，去「系统设置 → 隐私与安全性」中点击「仍要打开」。使用机器人硬件时串口路径为 `/dev/cu.usb*` 而非 `/dev/ttyUSB*`。

### 启动、停止与访问

```bash
lelab-zh                 # 启动
lelab-zh --stop          # 释放被遗留进程占用的 8000/8080 端口
lelab-zh --no-open       # 启动但不尝试自动打开浏览器
lelab-zh --dev           # 开发模式
```

默认地址为 <http://127.0.0.1:8000>。如果 VS Code/WSL 没有允许自动打开浏览器，服务依然在运行；直接在浏览器访问该地址即可。

### 卸载与缓存

```bash
uv tool uninstall lelab-zh   # 卸载命令与隔离环境
uv cache prune               # 清理不再使用的缓存
```

如需完全清空 uv 下载缓存（下次安装会重新下载所有依赖）：

```bash
uv cache clean
```

## 环境要求

- Python 3.12 或更新版本。
- 使用机器人硬件时，推荐 Linux、macOS 或 WSL；Linux 用户需要串口权限（通常加入 `dialout` 组）。
- GPU 不是启动界面的必需条件；本地训练可使用 CPU，但速度较慢。
- 上传 Hub、云端训练等功能需要 Hugging Face Token；本地校准、遥操作和录制不需要先登录。

## 开发

前端开发或重新构建静态资源时需要 Node.js 22 和 Git LFS：

```bash
git clone https://github.com/youngpq/lelab-zh.git
cd lelab-zh
git lfs install
git lfs pull

conda create -n lelab-zh python=3.12
conda activate lelab-zh
pip install -e .

cd frontend
npm ci
npm run build
cd ..
lelab-zh --dev
```

开发服务的前端地址为 `http://localhost:8080`，后端地址为 `http://localhost:8000`。

## 发布

完整流程见 [RELEASING.md](RELEASING.md)。发布 Tag `v*` 后，GitHub Actions 会构建 wheel 并创建 GitHub Release。
