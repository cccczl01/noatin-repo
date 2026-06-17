# Trae CN

- **类型**: deb
- **描述**: 字节跳动推出的 AI 编程 IDE，基于 VS Code 深度定制，内置 AI 助手
- **来源**: https://www.trae.com.cn/

## 下载源

| 优先级 | 类型 | 地址 |
|--------|------|------|
| 1 | 国内 CDN | `https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/2.3.42911/linux/Trae_CN-linux-x64.deb` |

## 环境要求

- **架构**: x86_64 (amd64)
- **依赖**: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libsecret-1-0

## 安装

```bash
# 检查架构
dpkg --print-architecture | grep -q amd64 || { echo "需要 amd64 架构，当前: $(dpkg --print-architecture)"; exit 1; }

# 检查是否已安装
if dpkg -l trae-cn &>/dev/null; then
  echo "Trae CN 已安装"
  exit 0
fi

# 下载并安装
wget "https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/2.3.42911/linux/Trae_CN-linux-x64.deb" -O /tmp/trae-cn.deb
sudo apt install -y /tmp/trae-cn.deb
rm /tmp/trae-cn.deb
```