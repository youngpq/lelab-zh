# LeLab 中文版

这是 [Hugging Face LeLab](https://github.com/huggingface/leLab) 的社区汉化 fork。它为 LeRobot 提供浏览器图形界面，可完成校准、遥操作、录制、训练、推理、回放与上传等流程。

> 本项目不是 Hugging Face 官方发布渠道。上游版权与 Apache-2.0 许可证见根目录 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。

## 安装与运行

推荐使用 [uv](https://docs.astral.sh/uv/)。发布版本安装时不需要 Node.js，也不需要 Git LFS：

```bash
uv tool install --python 3.12 \
  git+https://github.com/youngpq/lelab-zh.git@v0.1.0-zh.1

lelab-zh
```

安装或覆盖同一版本时，使用：

```bash
uv tool install --force --reinstall --refresh --python 3.12 \
  git+https://github.com/youngpq/lelab-zh.git@v0.1.0-zh.1
```

首次安装需要网络连接以下载 Python、PyTorch、LeRobot 和相关依赖。若 `lelab-zh` 不在 PATH，执行一次：

```bash
uv tool update-shell
```

### 网络较慢时

下列设置将 PyPI 依赖下载切换到清华镜像，并提高连接超时；GitHub 仓库本身仍通过 GitHub 下载。

```bash
export UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
export UV_HTTP_TIMEOUT=600
export UV_HTTP_RETRIES=10
export UV_CONCURRENT_DOWNLOADS=4
```

设置后再执行上面的安装命令。若希望每次打开终端都生效，可将这四行加入 `~/.bashrc`，再执行 `source ~/.bashrc`。

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
