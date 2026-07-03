# Noatinwork

- **类型**: deb
- **描述**: Noatin OS 自有工作套件（含桌面集成），通过 noatin 私有 APT 源分发
- **来源**: https://github.com/cccczl01/noatin-repo

## 下载源

| 优先级 | 类型 | 地址 |
|--------|------|------|
| 1 | 自有 APT 源 | `deb https://apt.cccczl.top trixie main` |

## 环境要求

- **架构**: amd64
- **Debian 版本**: trixie
- **依赖**: hicolor-icon-theme, desktop-file-utils（安装后处理触发）
- **磁盘**: ≈1.8 GB
- **前置**: 需先配置 noatin APT 源（见 README 用户快速开始）

## 安装

```bash
# 架构检查
dpkg --print-architecture | grep -q amd64 || { echo "需要 amd64 架构，当前: $(dpkg --print-architecture)"; exit 1; }

# noatin 源检查
[ -f /etc/apt/sources.list.d/noatin.list ] || { echo "未配置 noatin 源，请先按 README 添加"; exit 1; }

# 同步索引
sudo apt-get update

# 幂等检查
if dpkg -l noatinwork &>/dev/null; then
  echo "noatinwork 已安装: $(dpkg -l noatinwork | awk '/^ii/ {print $3}')"
  exit 0
fi

# 安装
sudo apt-get install -y noatinwork

# 验证
echo "noatinwork $(dpkg -l noatinwork | awk '/^ii/ {print $3}') 安装完成"
```

## 升级

```bash
sudo apt-get remove -y noatinwork
sudo apt-get update && sudo apt-get install -y noatinwork
```

## 升级示例

2026-07-04 升级记录参考：

| 项目 | 值 |
|------|-----|
| 升级前 → 后 | 2.1.21 → 2.1.28 |
| 包大小 | 410 MB |
| 下载源 | r2.cccczl.top（经 nginx 301 重定向） |
| 耗时 / 速度 | 约 1 分 10 秒 / 1,349 kB/s |
| 安装后占用 | 约 1,825 MB |
