# noatin-repo

Noatin OS APT 软件包仓库 v2 — dpkg-scanpackages + GitHub Actions + Cloudflare R2

## 目录结构

```
noatin-repo/
├── pool/                           # deb 包存放目录
│   └── {pkg}_{version}_amd64.deb   # 按文件名直接存放
├── .github/workflows/
│   └── sync-and-deploy.yml         # 自动索引生成 + R2 同步 + VPS 部署
├── LICENSE
└── README.md
```

## v2 架构

```
开发者 push deb 到 pool/  →  GitHub Actions 自动执行:
  1. dpkg-scanpackages → 生成 Packages 索引（--multiversion 多版本共存，Filename 保持相对路径）
  2. gzip + xz → 压缩生成 Packages.gz / Packages.xz
  3. apt-ftparchive → 生成 Release 文件
  4. gpg --clearsign → GPG 签名 InRelease
  5. rclone sync → deb 文件同步到 Cloudflare R2
  6. scp → 索引文件部署到 VPS (apt.cccczl.top)
  7. generate-llms-txt.sh → 生成知识库 llms.txt + index.html
  8. scp → 知识库部署到 VPS
```

用户通过 `apt.cccczl.top` 获取索引，deb 包经 nginx 301 重定向从 R2 (`r2.cccczl.top`) 下载。

## 如何加入一个 deb 包

### 1. 准备 deb 包

确保 deb 包命名符合 Debian 规范：`{pkg}_{version}_amd64.deb`

```bash
# 示例包名
noatin-chatgpt-client_1.1.0-1_amd64.deb
```

### 2. 放入 pool/ 目录

```bash
cp /path/to/your-package_1.0.0-1_amd64.deb pool/
```

### 3. 提交并推送

```bash
git add pool/
git commit -m "添加 your-package 1.0.0-1"
git push origin main
```

### 4. 自动化完成

推送后 GitHub Actions 自动执行：

1. `dpkg-scanpackages --multiversion` 扫描 `pool/` 生成 `Packages`（Filename 保持相对路径，由 VPS nginx 重定向到 R2）
2. 压缩生成 `Packages.gz` 和 `Packages.xz`
3. `apt-ftparchive` 生成 `Release`（含 Origin/Label/Suite 元数据）
4. GPG 签名生成 `InRelease`
5. `rclone` 同步 deb 文件到 Cloudflare R2
6. `scp` 将索引文件部署到 VPS
7. `generate-llms-txt.sh` 生成知识库 `llms.txt` + `index.html` 并部署到 VPS

完成后用户在客户端执行 `apt update` 即可安装新包，deb 包经 nginx 301 重定向从 R2 CDN 下载。

## 所需 GitHub Secrets

| Secret | 用途 |
|--------|------|
| `GPG_PRIVATE_KEY` | GPG 私钥（ASCII-armored），用于签名 Release |
| `R2_ACCESS_KEY` | Cloudflare R2 Access Key ID |
| `R2_SECRET_KEY` | Cloudflare R2 Secret Access Key |
| `R2_ENDPOINT` | Cloudflare R2 S3 端点地址 |
| `VPS_SSH_HOST` | VPS IP 或域名 |
| `VPS_SSH_USER` | VPS SSH 用户名 |
| `VPS_SSH_PRIVATE_KEY` | VPS SSH 私钥 |

## 注意事项

- deb 包可放在 `pool/` 根目录或子目录中（如 `pool/noatinwork/`），`dpkg-scanpackages` 会递归扫描
- v2 不再使用 `metadata.json`，所有包信息由 deb 包自身元数据提供
- v2 不再使用 DEP-11 / GNOME Software 集成
- v2 不再使用 Gitee/GitCode 多平台镜像，仅 GitHub + R2