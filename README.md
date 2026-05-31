# noatin-repo
<!-- 注意：本 README 与 repo/scripts/init-gitee-repo.sh 中 heredoc 生成内容需保持同步，修改任一处请同步更新另一处 -->

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
└── scripts/                  # 仓库运维脚本
    └── init-gitee-repo.sh    # 仓库初始化脚本
```

### 规则

- **按软件名分目录**：每个 AI 工具一个顶层子目录，格式 `{pkg}/`
- **按版本号建子目录**：`{pkg}/pool/{version}/` 下存放 deb 包，同一软件多个版本共存
- **assets 目录**：存放图标和截图，版本间共享以避免冗余，被 DEP-11 元数据引用
- **dep11 目录**：用于存放构建服务器产出的 DEP-11 YAML 片段，由 VPS 合并压缩后供 GNOME Software 使用

## 平台

本仓库通过 Gitee（主仓库）托管，同时镜像到 GitHub 和 GitCode。构建 CI 通过 `git push gitee main && git push github main && git push gitcode main` 同步三平台。

## 自动化构建

### 构建流程

当 `debian/packages/` 下的包源码发生变更并推送到 `main` 分支时，CI 自动执行：

1. **变更检测** — `ci-build.sh` 通过 `git diff` 检测变更的包目录
2. **包构建** — 对每个变更的包，调用 `build-package.sh` 生成 deb 包
3. **GPG 签名** — 使用项目 GPG 密钥对 deb 包签名
4. **产物提交** — 将 deb 包和 DEP-11 元数据提交到 `repo/` 目录
5. **多平台推送** — 推送到 Gitee 并通过 `sync-mirrors.sh` 同步 GitHub/GitCode
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
| `GITEE_TOKEN` | Gitee Personal Access Token |
| `GITHUB_TOKEN` | GitHub Personal Access Token |
| `GITCODE_TOKEN` | GitCode Personal Access Token |
| `VPS_API_KEY` | VPS API 密钥（DEP-11 上传和索引回调） |
| `VPS_DEP11_URL` | VPS DEP-11 上传端点 |
| `VPS_CALLBACK_URL` | VPS 索引更新回调端点 |