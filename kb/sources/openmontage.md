# OpenMontage

- **类型**: source
- **描述**: 首个开源的 agentic 视频制作系统，AI 编程助手驱动的端到端视频生产流水线
- **来源**: https://github.com/cccczl/OpenMontage

## 下载源

| 优先级 | 类型 | 地址 |
|--------|------|------|
| 1 | GitHub 仓库 | `https://github.com/cccczl/OpenMontage.git` |

## 镜像通道

国内访问 GitHub 较慢时，可使用镜像加速克隆：

| 优先级 | 镜像 | 地址 |
|--------|------|------|
| 1 | jhfast.top（推荐） | `https://jhfast.top/https://github.com/cccczl/OpenMontage.git` |
| 2 | GitHub 官方 | `https://github.com/cccczl/OpenMontage.git` |

> 克隆时优先使用 jhfast.top 镜像，失败或无加速效果时回退 GitHub 官方源。

## 环境要求

- **架构**: amd64 
- **OS**: Debian 13+ 
- **Python**: >= 3.10
- **Node.js**: >= 22
- **FFmpeg**: >= 6.x（含 ffprobe）
- **Git**: 任意版本
- **磁盘**: ≈2 GB（含 node_modules + .venv）

## 安装

```bash
# 1. 克隆仓库
git clone https://jhfast.top/https://github.com/cccczl/OpenMontage.git
cd OpenMontage

# 2. 前置依赖检查
python3 --version
git --version
ffmpeg -version | head -1

# 3. 通过 nvm 安装 Node.js（nvm 已自带，仅当未装或版本低于 22 时执行）
node --version || { nvm install 22 && nvm use 22; }

# 4. Python 虚拟环境与依赖
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pip install piper-tts

# 5. Remotion 渲染引擎
cd remotion-composer && npm install && cd ..

# 6. 环境变量
cp .env.example .env
# 编辑 .env 填入 API Key(可选,不填则用免费工具)

# 7. 验证
python -c "import yaml,pydantic,jsonschema,dotenv,PIL,numpy,requests; print('Python OK')"
node -e "require('@remotion/renderer'); console.log('Remotion OK')"
ffprobe -version | head -1
```
