# GitHub / GitCode 镜像仓库创建指南

本文档说明如何在 GitHub 和 GitCode 上为 Gitee 仓库 `noatin-repo` 创建镜像副本，配置本地三平台 remote 并完成首次同步。

## 前提条件

- Gitee 仓库 `noatin-repo` 已创建（via `init-gitee-repo.sh`）并推送到主仓库
- 已拥有 GitHub 账号和 GitCode 账号
- 本地已 clone Gitee 仓库：`git clone git@gitee.com:noatin/noatin-repo.git`

## 第一步：在 GitHub 上创建镜像仓库

1. 登录 [GitHub](https://github.com/)。
2. 点击右上角 `+` → **New repository**。
3. 填写仓库信息：

   | 字段 | 值 |
   |------|-----|
   | Owner | `noatin`（组织名或用户名） |
   | Repository name | `noatin-repo` |
   | Description | `Debian package repository for Noatin OS — mirror of Gitee noatin-repo` |
   | Visibility | **Public** |

4. **关键**：**不勾选** 以下选项（确保创建**完全空的仓库**）：
   - ❌ "Add a README file"
   - ❌ "Add .gitignore"
   - ❌ "Choose a license"

   如果勾选了任一选项，仓库将包含初始提交，首次 `git push` 会被拒绝（non-fast-forward 错误）。

5. 点击 **Create repository**。
6. 创建后的页面会显示 "Quick setup" 提示——记下仓库 URL：
   ```
   https://github.com/noatin/noatin-repo.git
   ```

## 第二步：在 GitCode 上创建镜像仓库

1. 登录 [GitCode](https://gitcode.com/)（CSDN 开发者社区）。
2. 点击右上角 `+` → **新建项目** / **New Project**。
3. 填写仓库信息：

   | 字段 | 值 |
   |------|-----|
   | 项目路径 / Group | `noatin` |
   | 项目名称 / Project name | `noatin-repo` |
   | 项目描述 / Description | `Debian package repository for Noatin OS — mirror of Gitee noatin-repo` |
   | 可见性 / Visibility | **Public** |

4. **关键**：**不勾选** 以下选项（确保创建**完全空的仓库**）：
   - ❌ "Initialize repository with a README"
   - ❌ 任何初始化选项

5. 点击 **Create project**。
6. 记下仓库 URL：
   ```
   https://gitcode.com/noatin/noatin-repo.git
   ```

## 第三步：在本地仓库添加 GitHub/GitCode remote

在本地 clone 的 Gitee 仓库目录中执行：

```bash
# 确认当前在 noatin-repo 本地仓库目录
cd noatin-repo

# 查看当前 remote（应已有 gitee/origin）
git remote -v

# 添加 GitHub remote
git remote add github https://github.com/noatin/noatin-repo.git

# 添加 GitCode remote
git remote add gitcode https://gitcode.com/noatin/noatin-repo.git

# 验证 remote 配置
git remote -v
# 预期输出:
# gitee   https://gitee.com/noatin/noatin-repo.git (fetch)
# gitee   https://gitee.com/noatin/noatin-repo.git (push)
# github  https://github.com/noatin/noatin-repo.git (fetch)
# github  https://github.com/noatin/noatin-repo.git (push)
# gitcode https://gitcode.com/noatin/noatin-repo.git (fetch)
# gitcode https://gitcode.com/noatin/noatin-repo.git (push)
```

## 第四步：首次推送（镜像同步）

```bash
# 首次推送：将仓库所有分支和标签同步到镜像仓库
# 注意：GitHub/GitCode 仓库必须是完全空的，否则会报 non-fast-forward 错误
git push github main
git push github --tags
git push gitcode main
git push gitcode --tags

# 或使用 sync-mirrors.sh 脚本：
# ./repo/scripts/sync-mirrors.sh --first-push
```

## Raw URL 格式参考

| 平台 | Raw URL 前缀 | 示例 |
|------|-------------|------|
| Gitee | `https://gitee.com/noatin/noatin-repo/raw/main` | `https://gitee.com/noatin/noatin-repo/raw/main/noatin-chatgpt-client/pool/1.0.0/noatin-chatgpt-client_1.0.0_amd64.deb` |
| GitHub | `https://raw.githubusercontent.com/noatin/noatin-repo/main` | `https://raw.githubusercontent.com/noatin/noatin-repo/main/noatin-chatgpt-client/pool/1.0.0/noatin-chatgpt-client_1.0.0_amd64.deb` |
| GitCode | `https://gitcode.com/noatin/noatin-repo/raw/main` | `https://gitcode.com/noatin/noatin-repo/raw/main/noatin-chatgpt-client/pool/1.0.0/noatin-chatgpt-client_1.0.0_amd64.deb` |

## 使用 Token 认证（CI/自动化场景）

在 CI 环境中，使用 Personal Access Token 进行认证推送：

```bash
# 通过环境变量注入 Token
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export GITCODE_TOKEN="xxxxxxxxxxxx"

# 使用 Token URL 格式推送
git push "https://${GITHUB_TOKEN}@github.com/noatin/noatin-repo.git" main
git push "https://${GITCODE_TOKEN}@gitcode.com/noatin/noatin-repo.git" main

# 或使用 sync-mirrors.sh（自动读取环境变量）:
# ./repo/scripts/sync-mirrors.sh
```

## 验证同步成功

推送完成后，通过以下方式验证：

```bash
# 1. 比较三平台 HEAD SHA
git ls-remote gitee HEAD
git ls-remote github HEAD
git ls-remote gitcode HEAD

# 或使用 verify-mirror-consistency.sh:
# ./repo/scripts/verify-mirror-consistency.sh

# 2. 验证 raw URL 可访问
curl -I "https://raw.githubusercontent.com/noatin/noatin-repo/main/noatin-chatgpt-client/pool/1.0.0/noatin-chatgpt-client_1.0.0_amd64.deb"
# 预期: HTTP/2 200

curl -I "https://gitcode.com/noatin/noatin-repo/raw/main/noatin-chatgpt-client/pool/1.0.0/noatin-chatgpt-client_1.0.0_amd64.deb"
# 预期: HTTP/1.1 200
```

## 常见问题

### Q: 首次推送报 `! [remote rejected] main -> main (non-fast-forward)`

**原因**：GitHub/GitCode 仓库在创建时勾选了 "Initialize with README" 等选项，导致仓库非空。

**解决**：
1. 删除 GitHub/GitCode 上的仓库。
2. 重新创建，**不勾选任何初始化选项**。
3. 重新执行推送。

### Q: 推送需要密码/认证

**原因**：未配置 SSH 或 Token 认证。

**解决**：
- **SSH 方式**：将 remote URL 改为 SSH 格式（如 `git@github.com:noatin/noatin-repo.git`）并上传公钥。
- **HTTPS + Token**：使用 `https://TOKEN@github.com/noatin/noatin-repo.git` 格式，Token 通过环境变量注入。

### Q: GitCode 推送超时

**原因**：GitCode 位于国内网络，海外网络可能延迟较高。

**解决**：重试推送；或配置 Git HTTP buffer 大小：
```bash
git config http.postBuffer 524288000
```