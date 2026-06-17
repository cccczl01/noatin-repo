# Opencode

- **类型**: binary
- **描述**: 开源 AI 代码生成 CLI 工具，支持多种 LLM 后端
- **来源**: https://github.com/anomalyco/opencode

## 下载源

| 优先级 | 类型 | 地址 |
|--------|------|------|
| 1 | 官方源 (GitHub Releases) | `https://github.com/anomalyco/opencode/releases` |

## 环境要求

- **架构**: x86_64
- **依赖**: 无（静态编译的 Go 二进制文件）

## 安装

```bash
# 检查架构
uname -m | grep -q x86_64 || { echo "需要 x86_64 架构，当前: $(uname -m)"; exit 1; }

# 检查是否已安装
if command -v opencode &>/dev/null; then
  echo "opencode 已安装: $(opencode --version 2>/dev/null || echo "版本未知")"
  exit 0
fi

# 获取最新版本号
VERSION=$(curl -s "https://api.github.com/repos/anomalyco/opencode/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
if [ -z "$VERSION" ]; then
  echo "无法获取最新版本号"
  exit 1
fi
echo "最新版本: $VERSION"

# 下载
DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/download/${VERSION}/opencode_${VERSION#v}_linux_amd64.tar.gz"
curl -fsSL "$DOWNLOAD_URL" -o /tmp/opencode.tar.gz || { echo "下载失败: $DOWNLOAD_URL"; exit 1; }

# 解压并安装
tar xf /tmp/opencode.tar.gz -C /tmp/ opencode
sudo install -m 755 /tmp/opencode /usr/local/bin/opencode
rm /tmp/opencode.tar.gz /tmp/opencode

echo "opencode ${VERSION} 安装完成"
```