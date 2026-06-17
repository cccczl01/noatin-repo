# Pixelle-Video

- **类型**: compose
- **描述**: 开源 AI 视频生成平台，支持文本到视频、图像到视频等生成能力
- **来源**: https://github.com/AIDC-AI/Pixelle-Video

## 下载源

| 优先级 | 类型 | 地址 |
|--------|------|------|
| 1 | 官方源 (ghcr.io) | `ghcr.io/aidc-ai/pixelle-video:latest` |

## 环境要求

- **架构**: x86_64
- **依赖**: Docker + Docker Compose
- **端口**: 7860（Web UI）

## 安装

```bash
# 检查 Docker
docker compose version &>/dev/null || { echo "需要 Docker Compose"; exit 1; }

# 检查端口冲突
if ss -tlnp | grep -q ':7860 '; then
  echo "端口 7860 已被占用:"
  ss -tlnp | grep ':7860 '
  exit 1
fi

# 检查是否已有同名容器在运行
if docker ps --format '{{.Names}}' | grep -q '^pixelle-video$'; then
  echo "pixelle-video 容器已在运行"
  exit 0
fi

# 创建 compose 文件和启动
mkdir -p pixelle-video && cd pixelle-video
cat > docker-compose.yml << 'YAML'
services:
  pixelle-video:
    image: ghcr.io/aidc-ai/pixelle-video:latest
    container_name: pixelle-video
    ports:
      - "7860:7860"
    restart: unless-stopped
YAML

docker compose up -d
echo "Pixelle-Video 已启动，访问 http://localhost:7860"
```