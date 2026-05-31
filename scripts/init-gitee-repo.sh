#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${REPO_ROOT}/.." && pwd)"

PACKAGES_FILE="${PACKAGES_FILE:-${PROJECT_ROOT}/vps/apt/packages.list}"

for dep in sed awk; do
    if ! command -v "${dep}" > /dev/null 2>&1; then
        echo "ERROR: 缺少依赖命令: ${dep}" >&2
        exit 1
    fi
done

echo ">>>> 1/5 加载软件包清单 ..."
PACKAGE_NAMES=()
PACKAGE_VERSIONS=()
if [ -f "${PACKAGES_FILE}" ] && [ -s "${PACKAGES_FILE}" ]; then
    while IFS= read -r line || [ -n "${line}" ]; do
        line=$(echo "${line}" | sed 's/#.*//' | xargs)
        if [ -z "${line}" ]; then
            continue
        fi
        PKG_NAME=$(echo "${line}" | awk '{print $1}')
        PKG_VERSION=$(echo "${line}" | awk '{print $2}')
        if [ -n "${PKG_NAME}" ]; then
            PACKAGE_NAMES+=("${PKG_NAME}")
            PACKAGE_VERSIONS+=("${PKG_VERSION:-}")
        fi
    done < "${PACKAGES_FILE}"
fi

if [ ${#PACKAGE_NAMES[@]} -gt 0 ]; then
    echo "    从 packages.list 加载了 ${#PACKAGE_NAMES[@]} 个软件包:"
    for i in "${!PACKAGE_NAMES[@]}"; do
        echo "      - ${PACKAGE_NAMES[$i]} ${PACKAGE_VERSIONS[$i]}"
    done
else
    echo "    packages.list 中无软件包，将只创建基础目录结构"
fi

echo ">>>> 2/5 创建仓库基础目录 ..."
mkdir -p "${REPO_ROOT}/dep11/"
if [ ! -f "${REPO_ROOT}/dep11/.gitkeep" ]; then
    touch "${REPO_ROOT}/dep11/.gitkeep"
    echo "    OK: dep11/.gitkeep 已创建"
else
    echo "    OK: dep11/.gitkeep 已存在（跳过）"
fi

echo ">>>> 3/5 按软件名创建子目录结构 ..."
CREATED_COUNT=0
for i in "${!PACKAGE_NAMES[@]}"; do
    pkg="${PACKAGE_NAMES[$i]}"
    pkg_version="${PACKAGE_VERSIONS[$i]}"
    echo "    处理: ${pkg}${pkg_version:+ (版本 ${pkg_version})}"
    POOL_DIR="${REPO_ROOT}/${pkg}/pool"
    ASSETS_DIR="${REPO_ROOT}/${pkg}/assets"
    VERSION_DIR="${REPO_ROOT}/${pkg}/pool/${pkg_version}"

    something_created=0

    if [ ! -d "${POOL_DIR}" ]; then
        mkdir -p "${POOL_DIR}"
        echo "        mkdir: ${pkg}/pool/"
        something_created=1
    fi

    if [ -n "${pkg_version}" ] && [ ! -d "${VERSION_DIR}" ]; then
        mkdir -p "${VERSION_DIR}"
        touch "${VERSION_DIR}/.gitkeep"
        echo "        mkdir: ${pkg}/pool/${pkg_version}/"
        echo "        touch: ${pkg}/pool/${pkg_version}/.gitkeep"
        something_created=1
    elif [ -n "${pkg_version}" ]; then
        if [ ! -f "${VERSION_DIR}/.gitkeep" ]; then
            touch "${VERSION_DIR}/.gitkeep"
            echo "        touch: ${pkg}/pool/${pkg_version}/.gitkeep (已存在目录)"
            something_created=1
        fi
    fi

    if [ ! -d "${ASSETS_DIR}" ]; then
        mkdir -p "${ASSETS_DIR}"
        echo "        mkdir: ${pkg}/assets/"
        something_created=1
    fi
    if [ ! -f "${ASSETS_DIR}/.gitkeep" ]; then
        touch "${ASSETS_DIR}/.gitkeep"
        echo "        touch: ${pkg}/assets/.gitkeep"
        something_created=1
    fi

    if [ "${something_created}" -eq 1 ]; then
        CREATED_COUNT=$((CREATED_COUNT + 1))
    fi
done

if [ ${#PACKAGE_NAMES[@]} -eq 0 ]; then
    echo "    （无软件包，跳过子目录创建）"
else
    echo "    子目录创建完成: ${CREATED_COUNT} 个软件（有新增）"
fi

echo ">>>> 4/5 生成 README.md ..."
# 注意: README.md 内容在此 heredoc 中定义，与 repo/README.md 内容一致。
# 修改 README 内容时需同步更新此 heredoc。
if [ ! -f "${REPO_ROOT}/README.md" ]; then
    TEMP_README="${REPO_ROOT}/README.md.tmp.$$"
    cat > "${TEMP_README}" << 'EOF'
# noatin-repo

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

本仓库通过 Gitee（主仓库）托管，同时镜像到 GitHub 和 GitCode。运行 `repo/scripts/sync-mirrors.sh` 同步三平台，或直接执行 `git push gitee main && git push github main && git push gitcode main`。
EOF
    mv "${TEMP_README}" "${REPO_ROOT}/README.md"
    echo "    OK: README.md 已生成"
else
    echo "    OK: README.md 已存在（跳过）"
fi

echo ">>>> 5/5 验证 ..."
VALIDATION_FAILED=0

check_exists() {
    local path="$1"
    local desc="$2"
    if [ -e "${path}" ]; then
        echo "    OK: ${desc}"
    else
        echo "    ERROR: ${desc} 不存在"
        VALIDATION_FAILED=1
    fi
}

check_exists "${REPO_ROOT}/dep11/.gitkeep" "dep11/.gitkeep"
check_exists "${REPO_ROOT}/README.md" "README.md"

for i in "${!PACKAGE_NAMES[@]}"; do
    pkg="${PACKAGE_NAMES[$i]}"
    pkg_version="${PACKAGE_VERSIONS[$i]}"
    check_exists "${REPO_ROOT}/${pkg}/assets/.gitkeep" "${pkg}/assets/.gitkeep"
    if [ -n "${pkg_version}" ]; then
        check_exists "${REPO_ROOT}/${pkg}/pool/${pkg_version}/.gitkeep" "${pkg}/pool/${pkg_version}/.gitkeep"
    fi
done

if [ "${VALIDATION_FAILED}" -eq 1 ]; then
    echo "FAIL: 仓库目录结构初始化验证不通过"
    exit 1
fi

echo ""
echo "OK: 仓库目录结构初始化完成"
echo "    软件包数: ${#PACKAGE_NAMES[@]}"
echo "    仓库根目录: ${REPO_ROOT}"

if [ ${#PACKAGE_NAMES[@]} -gt 0 ]; then
    echo ""
    echo "下一步:"
    echo "  git init"
    echo "  git remote add origin git@gitee.com:noatin/noatin-repo.git"
    echo "  git add -A && git commit -m '初始化仓库目录结构'"
    echo "  git push -u origin main"
else
    echo ""
    echo "注意: packages.list 中尚无软件包"
    echo "请先在 vps/apt/packages.list 中添加软件包（格式: 包名 版本号），"
    echo "然后重新运行本脚本以创建对应子目录。"
fi

echo ""
echo ">>> 镜像同步提示 <<<"
echo "仓库初始化完成。如需配置 GitHub/GitCode 镜像，请参考 repo/scripts/mirror-setup-guide.md"
echo ""
echo "添加镜像 remote 的命令示例:"
echo "  git remote add github https://github.com/noatin/noatin-repo.git"
echo "  git remote add gitcode https://gitcode.com/noatin/noatin-repo.git"
echo ""
echo "首次推送镜像:"
echo "  ./repo/scripts/sync-mirrors.sh --first-push"
echo ""
echo "后续增量同步:"
echo "  ./repo/scripts/sync-mirrors.sh"