#!/bin/bash
# generate-llms-txt.sh
# 扫描 kb/ 目录下的 .md 文件，自动生成 llms.txt（llmstxt.org 标准格式）
# 由 GitHub Actions CI 调用，不手动执行

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT="$SCRIPT_DIR/llms.txt"

# llms.txt 头部（遵循 llmstxt.org 标准）
cat > "$OUTPUT" << 'HEADER'
# Noatin 软件安装知识库

> 自托管 APT 仓库 + AI/LLM 友好的软件安装知识库。
> AI CLI 工具可直接读取 llms.txt 获取安装信息，跳过网络搜索。
> 每个 .md 文件包含：描述、下载源（国内优先）、环境要求、安全检查 + 安装命令。

HEADER

# 分类定义：目录名 -> 显示名、描述
declare -A CATEGORIES=(
  ["debs"]="第三方 deb 包|直接下载 deb 文件并通过 apt install 安装"
  ["binaries"]="二进制工具|下载预编译二进制文件，install 到 /usr/local/bin"
  ["composes"]="Docker Compose 项目|docker compose up -d 一键启动"
  ["skills"]="AI Skills/规则|AI IDE/CLI 工具的 skills、rules、commands 配置"
  ["mcps"]="MCP Server|Model Context Protocol Server 安装配置"
)

for dir in "${!CATEGORIES[@]}"; do
  IFS='|' read -r title desc <<< "${CATEGORIES[$dir]}"
  
  echo "" >> "$OUTPUT"
  echo "## $title" >> "$OUTPUT"
  echo "> $desc" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  
  if [ -d "$dir" ]; then
    found=0
    for md in "$dir"/*.md; do
      [ -f "$md" ] || continue
      found=1
      # 提取第一行 # 标题作为软件名
      name=$(head -1 "$md" | sed 's/^# //')
      slug=$(basename "$md" .md)
      # 提取描述行
      desc_line=$(grep -m1 '^\-\s\*\*描述\*\*:' "$md" | sed 's/.*描述\*\*: //' || echo "")
      echo "- [$name](https://apt.cccczl.top/$dir/$slug.md): $desc_line" >> "$OUTPUT"
    done
    if [ "$found" -eq 0 ]; then
      echo "- （暂无）" >> "$OUTPUT"
    fi
  fi
done

echo "llms.txt generated: $(wc -l < "$OUTPUT") lines"