# OpenMontage

- **类型**: source
- **描述**: 首个开源的 agentic 视频制作系统，AI 编程助手驱动的端到端视频生产流水线
- **来源**: https://github.com/cccczl/OpenMontage

## 下载源

| 优先级 | 类型 | 地址 |
|--------|------|------|
| 1 | GitHub 仓库 | `https://github.com/cccczl/OpenMontage.git` |

## 环境要求

- **架构**: amd64 / arm64
- **OS**: Debian 12+ / Ubuntu 22.04+
- **Python**: >= 3.10
- **Node.js**: >= 18（推荐 20 LTS）
- **FFmpeg**: >= 6.x（含 ffprobe）
- **Git**: 任意版本
- **磁盘**: ≈2 GB（含 node_modules + .venv）

## 安装

```bash
# === 1. 系统依赖 ===
sudo apt-get install -y python3 python3-venv python3-pip
python3 --version  # 需 >= 3.10

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version    # 需 >= 18

sudo apt-get install -y ffmpeg
ffmpeg -version   # 需 >= 6.x

sudo apt-get install -y git

# === 2. 克隆仓库 ===
git clone https://github.com/cccczl/OpenMontage.git
cd OpenMontage

# === 3. Python 虚拟环境与依赖 ===
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pip install piper-tts  # 离线 TTS

# === 4. Remotion 渲染引擎 ===
cd remotion-composer && npm install && cd ..

# === 5. 环境变量 ===
cp .env.example .env
# 编辑 .env 填入 API Key（可选，不填则用免费工具）

# === 6. 验证 ===
source .venv/bin/activate
python -c "import yaml,pydantic,jsonschema,dotenv,PIL,numpy,requests; print('Python OK')"
node -e "require('@remotion/renderer'); console.log('Remotion OK')"
ffprobe -version | head -1
```
