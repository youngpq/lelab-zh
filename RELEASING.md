# 发布流程

## 首次建立 fork

1. 在 GitHub 上 fork `huggingface/leLab`，仓库名建议改为 `lelab-zh`。
2. 本地仓库中将上游仓库保留为 `upstream`，自己的 fork 设为 `origin`：

   ```bash
   git remote rename origin upstream
   git remote add origin https://github.com/<你的用户名>/lelab-zh.git
   git push -u origin main
   ```

3. 在 `pyproject.toml` 中将 `REPLACE_WITH_YOUR_GITHUB_USERNAME` 替换为实际 GitHub 用户名。

## 常规发布

1. 在 `main` 完成代码、`frontend/dist` 和文档变更。
2. 验证：

   ```bash
   cd frontend
   npm run check:i18n
   npm run build
   cd ..
   ```

3. 提交并推送：

   ```bash
   git add -A
   git commit -m "release: lelab-zh v0.1.0.post1"
   git push origin main
   ```

4. 创建并推送 Tag。Tag 与 `pyproject.toml` 的版本对应，例如 `v0.1.0-zh.1`：

   ```bash
   git tag -a v0.1.0-zh.1 -m "LeLab 中文版 v0.1.0-zh.1"
   git push origin v0.1.0-zh.1
   ```

GitHub Actions 会构建 wheel 并创建对应 Release；用户可以从 Release 下载 wheel，或直接使用 Git 安装。

## 同步上游

```bash
git fetch upstream
git switch main
git merge upstream/main
git push origin main
```

如有冲突，应优先保留本项目的中文语言包、发行名称和发布文档，再重新构建 `frontend/dist`。
