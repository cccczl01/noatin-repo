#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

usage() {
    cat << 'EOF'
Usage: sync-mirrors.sh [OPTIONS]

将本地仓库的 main 分支按序推送到三平台镜像仓库。

Options:
  --dry-run       只显示将要推送的目标，不执行实际推送操作
  --first-push    首次推送模式：使用 git push --mirror 推送所有分支和标签
  --help          显示帮助信息

Environment Variables:
  GITEE_TOKEN     Gitee Personal Access Token（可选，用于 HTTPS + Token 认证）
  GITHUB_TOKEN    GitHub Personal Access Token（可选）
  GITCODE_TOKEN   GitCode Personal Access Token（可选）

  未设置 Token 时使用 SSH 协议 URL 推送。

Exit Codes:
  0   所有平台推送成功
  N   推送失败的平台数量（1-3）
EOF
}

DRY_RUN="false"
FIRST_PUSH="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --first-push)
            FIRST_PUSH="true"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: 未知参数: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if ! command -v git > /dev/null 2>&1; then
    echo "ERROR: 缺少依赖命令: git" >&2
    exit 1
fi

cd "$REPO_DIR"

mask_url() {
    local url="$1"
    if [[ "${url}" =~ ^https://[^@]+@ ]]; then
        echo "${url}" | sed 's|https://[^@]*@|https://***@|'
    else
        echo "${url}"
    fi
}

GITEE_REMOTE="gitee"
GITHUB_REMOTE="github"
GITCODE_REMOTE="gitcode"

GITEE_REPO="${GITEE_TOKEN:+https://oauth2:${GITEE_TOKEN}@gitee.com/cccczl01/noatin-repo.git}"
GITEE_REPO="${GITEE_REPO:-git@gitee.com:cccczl01/noatin-repo.git}"

GITHUB_REPO="${GITHUB_TOKEN:+https://${GITHUB_TOKEN}@github.com/cccczl01/noatin-repo.git}"
GITHUB_REPO="${GITHUB_REPO:-git@github.com:cccczl01/noatin-repo.git}"

GITCODE_REPO="${GITCODE_TOKEN:+https://${GITCODE_TOKEN}@gitcode.com/cccczl001/noatin-repo.git}"
GITCODE_REPO="${GITCODE_REPO:-git@gitcode.com:cccczl001/noatin-repo.git}"

echo "=== 三平台镜像同步 ==="
echo ""
echo "模式: $([ "${FIRST_PUSH}" = "true" ] && echo '首次推送 (--mirror)' || echo '增量推送 (main 分支)')"
echo "干跑: $([ "${DRY_RUN}" = "true" ] && echo 'YES' || echo 'NO')"
echo ""

declare -A REMOTE_URLS
REMOTE_URLS["${GITEE_REMOTE}"]="${GITEE_REPO}"
REMOTE_URLS["${GITHUB_REMOTE}"]="${GITHUB_REPO}"
REMOTE_URLS["${GITCODE_REMOTE}"]="${GITCODE_REPO}"

declare -A PUSH_RESULTS

if [ "${DRY_RUN}" = "true" ]; then
    for remote in "${GITEE_REMOTE}" "${GITHUB_REMOTE}" "${GITCODE_REMOTE}"; do
        echo "  [DRY-RUN] 将推送到: ${remote} → ${REMOTE_URLS[${remote}]}"
    done
    echo ""
    echo "DRY-RUN 完成，未执行实际推送。"
    exit 0
fi

FAILED_COUNT=0

for remote in "${GITEE_REMOTE}" "${GITHUB_REMOTE}" "${GITCODE_REMOTE}"; do
    REPO_URL="${REMOTE_URLS[${remote}]}"

    echo ">>> 推送 ${remote}: $(mask_url "${REPO_URL}")"

    if ! git remote get-url "${remote}" > /dev/null 2>&1; then
        echo "  WARN: remote '${remote}' 未配置，跳过"
        echo "  SKIP: ${remote} — remote 未配置"
        PUSH_RESULTS["${remote}"]="SKIP"
        continue
    fi

    set +e
    if [ "${FIRST_PUSH}" = "true" ]; then
        push_output=$(git push --mirror "${REPO_URL}" 2>&1)
        push_exit=$?
        echo "${push_output}" | sed "s|https://[^@]*@|https://***@|g"
    else
        push_output=$(git push "${REPO_URL}" main 2>&1)
        push_exit=$?
        echo "${push_output}" | sed "s|https://[^@]*@|https://***@|g"
    fi
    RC=$push_exit
    set -e

    if [ ${RC} -eq 0 ]; then
        echo "  SUCCESS: ${remote} 推送成功"
        PUSH_RESULTS["${remote}"]="SUCCESS"
    else
        echo "  FAILED: ${remote} 推送失败 (exit code: ${RC})"
        PUSH_RESULTS["${remote}"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    echo ""
done

echo ""
echo "--- 推送结果汇总 ---"

for remote in "${GITEE_REMOTE}" "${GITHUB_REMOTE}" "${GITCODE_REMOTE}"; do
    echo "  ${remote}: ${PUSH_RESULTS[${remote}]}"
done

echo ""
echo "--- HEAD SHA 一致性验证 ---"

declare -A HEAD_SHAS
SHA_CONSISTENT="true"

for remote in "${GITEE_REMOTE}" "${GITHUB_REMOTE}" "${GITCODE_REMOTE}"; do
    REPO_URL="${REMOTE_URLS[${remote}]}"

    set +e
    HEAD_SHA=$(git ls-remote "${REPO_URL}" HEAD 2>/dev/null | awk '{print $1}')
    RC=$?
    set -e

    if [ ${RC} -eq 0 ] && [ -n "${HEAD_SHA}" ]; then
        HEAD_SHAS["${remote}"]="${HEAD_SHA}"
        echo "  ${remote}: ${HEAD_SHA}"
    else
        HEAD_SHAS["${remote}"]="(无法获取)"
        echo "  ${remote}: (无法获取 HEAD SHA)"
        SHA_CONSISTENT="false"
    fi
done

if [ "${#HEAD_SHAS[@]}" -eq 3 ]; then
    SHA_VALUES=$(printf '%s\n' "${HEAD_SHAS[@]}" | sort -u)
    UNIQUE_COUNT=$(echo "${SHA_VALUES}" | wc -l)
    if [ "${UNIQUE_COUNT}" -eq 1 ]; then
        echo ""
        echo "  PASS: 三平台 HEAD SHA 一致"
    else
        echo ""
        echo "  FAIL: 三平台 HEAD SHA 不一致"
        SHA_CONSISTENT="false"
    fi
else
    echo ""
    echo "  WARN: 部分平台 HEAD SHA 无法获取，跳过一致性比对"
fi

echo ""
echo "============================================================"
echo "同步完成: 成功 $((3 - FAILED_COUNT))/3, 失败 ${FAILED_COUNT}/3"

exit ${FAILED_COUNT}