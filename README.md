# noatin-repo

Debian 软件包托管仓库 — 为 Noatin OS 提供 AI 工具 deb 包的统一分发和存储。

## 目录结构约定

```
noatin-repo/
├── {pkg}/                    # 按软件名建子目录（如 noatin-chatgpt-client）
│   ├── pool/
│   │   └── {version}/        # 按版本号建子目录（如 1.0.0/）
│   │       └── {pkg}_{version}_amd64.deb
│   └── assets/               # 图标和截图，版本间共享
│       ├── icon.png
│       └── screenshots/
│           └── main.png
├── dep11/                    # DEP-11 YAML 片段暂存目录
│   └── {appstream_id}.yml    # 构建服务器产出的 YAML 片段
```

### 规则

- **按软件名分目录**：每个 AI 工具一个顶层子目录，格式 `{pkg}/`
- **按版本号建子目录**：`{pkg}/pool/{version}/` 下存放 deb 包，同一软件多个版本共存
- **assets 目录**：存放图标和截图，版本间共享以避免冗余，被 DEP-11 元数据引用
- **dep11 目录**：用于存放构建服务器产出的 DEP-11 YAML 片段，由 VPS 合并压缩后供 GNOME Software 使用

## 平台

本仓库托管于 GitHub。R2 作为 deb 包的灾备存储。

## 自动化构建

### 构建流程

当 `debian/packages/` 下的包源码发生变更并推送到 `main` 分支时，CI 自动执行：

1. **变更检测** — `ci-build.sh` 通过 `git diff` 检测变更的包目录
2. **包构建** — 对每个变更的包，调用 `build-package.sh` 生成 deb 包
3. **GPG 签名** — 使用项目 GPG 密钥对 deb 包签名
4. **产物提交** — 将 deb/metadata.json 和 DEP-11 元数据提交到 `repo/` 目录
5. **GitHub 推送** — 推送至 GitHub 仓库
6. **VPS 更新** — 上传 DEP-11 片段并触发索引更新回调

### 手动构建

```bash
# 单包构建
bash debian/scripts/build-package.sh --pkg-dir debian/packages/my-pkg --output-dir repo/my-pkg/pool/1.0.0-1

# CI 编排（干跑）
bash debian/scripts/ci-build.sh --dry-run

# CI 编排（指定包）
bash debian/scripts/ci-build.sh --pkg my-pkg
```

### 包配置文件

每个包目录必须包含 `build.conf` 文件，格式为 `key=value`。详见 `debian/packages/PACKAGE-CONFIG.md`。

### 所需环境变量（CI secrets）

| 变量 | 用途 |
|------|------|
| `GPG_PRIVATE_KEY` | GPG 私钥（ASCII-armored），用于 deb 包签名 |
| `GITHUB_TOKEN` | GitHub Personal Access Token |
| `VPS_API_KEY` | VPS API 密钥（DEP-11 上传和索引回调） |
| `VPS_DEP11_URL` | VPS DEP-11 上传端点 |
| `VPS_CALLBACK_URL` | VPS 索引更新回调端点 |