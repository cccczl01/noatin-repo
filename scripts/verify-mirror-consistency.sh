#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

GITEE_RAW_BASE="https://gitee.com/cccczl01/noatin-repo/raw/main"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/cccczl01/noatin-repo/main"
GITCODE_RAW_BASE="https://gitcode.com/cccczl001/noatin-repo/raw/main"

GITEE_REPO="${GITEE_TOKEN:+https://${GITEE_TOKEN}@gitee.com/cccczl01/noatin-repo.git}"
GITEE_REPO="${GITEE_REPO:-https://gitee.com/cccczl01/noatin-repo.git}"

GITHUB_REPO="${GITHUB_TOKEN:+https://${GITHUB_TOKEN}@github.com/cccczl01/noatin-repo.git}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/cccczl01/noatin-repo.git}"

GITCODE_REPO="${GITCODE_TOKEN:+https://${GITCODE_TOKEN}@gitcode.com/cccczl001/noatin-repo.git}"
GITCODE_REPO="${GITCODE_REPO:-https://gitcode.com/cccczl001/noatin-repo.git}"

PASS=0
FAIL=0
WARN=0
SKIP=0

SLEEP_INTERVAL=0

mask_url() {
    local url="$1"
    if [[ "${url}" =~ ^https://[^@]+@ ]]; then
        echo "${url}" | sed 's|https://[^@]*@|https://***@|'
    else
        echo "${url}"
    fi
}

usage() {
    cat << 'EOF'
Usage: verify-mirror-consistency.sh [OPTIONS]

验证三平台（Gitee/GitHub/GitCode）仓库内容一致性。

Options:
  --sleep N   在批量 curl 请求之间间隔 N 秒，避免触发 rate limit（默认 0）
  --help      显示帮助信息

Environment Variables:
  GITEE_TOKEN     Gitee Personal Access Token（可选，用于私有仓库认证）
  GITHUB_TOKEN    GitHub Personal Access Token（可选）
  GITCODE_TOKEN   GitCode Personal Access Token（可选）

Exit Codes:
  0   所有验证通过
  1   存在 FAIL 项
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sleep)
            SLEEP_INTERVAL="$2"
            if ! [[ "${SLEEP_INTERVAL}" =~ ^[0-9]+$ ]]; then
                echo "ERROR: --sleep 参数必须是正整数: ${SLEEP_INTERVAL}" >&2
                exit 1
            fi
            shift 2
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

for dep in curl sha256sum awk; do
    if ! command -v "${dep}" > /dev/null 2>&1; then
        echo "ERROR: 缺少依赖命令: ${dep}" >&2
        exit 1
    fi
done

PACKAGES_FILE="${PROJECT_ROOT}/vps/apt/packages.list"
DEP11_DIR="${PROJECT_ROOT}/repo/dep11"

PACKAGE_NAMES=()
PACKAGE_VERSIONS=()

if [ -f "${PACKAGES_FILE}" ]; then
    while IFS= read -r line || [ -n "${line}" ]; do
        line=$(printf '%s' "${line}" | sed 's/#.*//' | xargs -r)
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

echo "============================================================"
echo " 三平台镜像内容一致性验证"
echo "============================================================"
echo ""
echo "平台: Gitee / GitHub / GitCode"
echo "软件包数: ${#PACKAGE_NAMES[@]}"
echo "DEP-11 目录: ${DEP11_DIR}"
echo "请求间隔: ${SLEEP_INTERVAL}s"
echo ""

###############################################################################
# Section 1: HEAD SHA 一致性验证
###############################################################################

echo "--- 1. HEAD SHA 一致性 ---"
echo ""

declare -A HEAD_SHAS

fetch_head_sha() {
    local repo_url="$1"
    local platform="$2"
    local sha=""
    set +e
    sha=$(git ls-remote "${repo_url}" HEAD 2>/dev/null | awk '{print $1}')
    set -e
    if [ -n "${sha}" ]; then
        HEAD_SHAS["${platform}"]="${sha}"
        echo "  ${platform}: ${sha}"
    else
        HEAD_SHAS["${platform}"]=""
        echo "  WARN: ${platform} HEAD SHA 获取失败"
        WARN=$((WARN + 1))
    fi
}

fetch_head_sha "${GITEE_REPO}" "Gitee"
fetch_head_sha "${GITHUB_REPO}" "GitHub"
fetch_head_sha "${GITCODE_REPO}" "GitCode"

SHA_COUNT=0
for platform in Gitee GitHub GitCode; do
    if [ -n "${HEAD_SHAS[${platform}]}" ]; then
        SHA_COUNT=$((SHA_COUNT + 1))
    fi
done

if [ "${SHA_COUNT}" -eq 3 ]; then
    SHA_VALUES=$(printf '%s\n' "${HEAD_SHAS[Gitee]}" "${HEAD_SHAS[GitHub]}" "${HEAD_SHAS[GitCode]}" | sort -u)
    UNIQUE_COUNT=$(echo "${SHA_VALUES}" | wc -l)
    if [ "${UNIQUE_COUNT}" -eq 1 ]; then
        echo "  PASS: 三平台 HEAD SHA 一致"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: 三平台 HEAD SHA 不一致"
        FAIL=$((FAIL + 1))
    fi
elif [ "${SHA_COUNT}" -ge 2 ]; then
    echo "  WARN: 仅 ${SHA_COUNT}/3 平台 HEAD SHA 可获取，跳过一致性比对"
    WARN=$((WARN + 1))
else
    echo "  WARN: 无法获取 HEAD SHA，跳过此验证项"
    WARN=$((WARN + 1))
fi

echo ""

###############################################################################
# Section 2: deb 包文件一致性验证
###############################################################################

echo "--- 2. deb 包文件一致性 ---"
echo ""

check_deb_url() {
    local raw_base="$1"
    local platform="$2"
    local pkg="$3"
    local version="$4"
    local deb="${5}"
    local url="${raw_base}/${pkg}/pool/${version}/${deb}"

    local curl_err
    curl_err=$(mktemp)
    set +e
    local status
    status=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 "${url}" 2>"${curl_err}" || echo "000")
    set -e

    if [ "${status}" = "200" ]; then
        echo "  PASS: ${platform} URL 可访问 → ${url}"
        rm -f "${curl_err}"
        return 0
    elif [ "${status}" = "404" ]; then
        echo "  SKIP: ${platform} 文件不存在 → ${url}"
        rm -f "${curl_err}"
        return 1
    elif [ "${status}" = "000" ]; then
        echo "  WARN: ${platform} 连接失败 → ${url} ($(head -n1 "${curl_err}" 2>/dev/null || echo 'timeout'))"
        rm -f "${curl_err}"
        return 2
    else
        echo "  WARN: ${platform} HTTP ${status} → ${url}"
        rm -f "${curl_err}"
        return 2
    fi
}

fetch_sha256() {
    local raw_base="$1"
    local platform="$2"
    local pkg="$3"
    local version="$4"
    local deb="$5"
    local url="${raw_base}/${pkg}/pool/${version}/${deb}"
    local sha=""

    set +e
    sha=$(curl -sL --connect-timeout 10 --max-time 300 "${url}" 2>/dev/null | sha256sum | awk '{print $1}')
    set -e

    echo "${sha}"
}

for i in "${!PACKAGE_NAMES[@]}"; do
    pkg="${PACKAGE_NAMES[$i]}"
    version="${PACKAGE_VERSIONS[$i]}"
    deb="${pkg}_${version}_amd64.deb"

    echo ">>> ${pkg} ${version} (${deb})"

    local_deb="${PROJECT_ROOT}/repo/${pkg}/pool/${version}/${deb}"
    if [ ! -f "${local_deb}" ]; then
        echo "  SKIP: 本地文件不存在 → ${local_deb}"
        SKIP=$((SKIP + 1))
        echo ""
        [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"
        continue
    fi

    local_sha=$(sha256sum "${local_deb}" | awk '{print $1}')

    # URL accessibility checks
    gitee_url_ok=0
    check_deb_url "${GITEE_RAW_BASE}" "Gitee" "${pkg}" "${version}" "${deb}"
    rc=$?
    if [ ${rc} -eq 0 ]; then
        PASS=$((PASS + 1))
        gitee_url_ok=1
    elif [ ${rc} -eq 1 ]; then
        SKIP=$((SKIP + 1))
    else
        WARN=$((WARN + 1))
    fi
    [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

    github_url_ok=0
    check_deb_url "${GITHUB_RAW_BASE}" "GitHub" "${pkg}" "${version}" "${deb}"
    rc=$?
    if [ ${rc} -eq 0 ]; then
        PASS=$((PASS + 1))
        github_url_ok=1
    elif [ ${rc} -eq 1 ]; then
        SKIP=$((SKIP + 1))
    else
        WARN=$((WARN + 1))
    fi
    [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

    gitcode_url_ok=0
    check_deb_url "${GITCODE_RAW_BASE}" "GitCode" "${pkg}" "${version}" "${deb}"
    rc=$?
    if [ ${rc} -eq 0 ]; then
        PASS=$((PASS + 1))
        gitcode_url_ok=1
    elif [ ${rc} -eq 1 ]; then
        SKIP=$((SKIP + 1))
    else
        WARN=$((WARN + 1))
    fi
    [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

    # SHA256 comparison (only for platforms where URL is accessible)
    echo "  --- SHA256 比对 ---"

    echo "  LOCAL: ${local_sha}"

    if [ "${gitee_url_ok}" -eq 1 ]; then
        gitee_sha=$(fetch_sha256 "${GITEE_RAW_BASE}" "Gitee" "${pkg}" "${version}" "${deb}")
        echo "  Gitee: ${gitee_sha}"
        if [ -n "${gitee_sha}" ] && [ "${gitee_sha}" = "${local_sha}" ]; then
            echo "  PASS: Gitee SHA256 一致"
            PASS=$((PASS + 1))
        elif [ -n "${gitee_sha}" ]; then
            echo "  FAIL: Gitee SHA256 不一致 (expected: ${local_sha})"
            FAIL=$((FAIL + 1))
        else
            echo "  WARN: Gitee SHA256 计算失败"
            WARN=$((WARN + 1))
        fi
    else
        echo "  SKIP: Gitee SHA256 (URL 不可访问)"
        SKIP=$((SKIP + 1))
    fi
    [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

    if [ "${github_url_ok}" -eq 1 ]; then
        github_sha=$(fetch_sha256 "${GITHUB_RAW_BASE}" "GitHub" "${pkg}" "${version}" "${deb}")
        echo "  GitHub: ${github_sha}"
        if [ -n "${github_sha}" ] && [ "${github_sha}" = "${local_sha}" ]; then
            echo "  PASS: GitHub SHA256 一致"
            PASS=$((PASS + 1))
        elif [ -n "${github_sha}" ]; then
            echo "  FAIL: GitHub SHA256 不一致 (expected: ${local_sha})"
            FAIL=$((FAIL + 1))
        else
            echo "  WARN: GitHub SHA256 计算失败"
            WARN=$((WARN + 1))
        fi
    else
        echo "  SKIP: GitHub SHA256 (URL 不可访问)"
        SKIP=$((SKIP + 1))
    fi
    [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

    if [ "${gitcode_url_ok}" -eq 1 ]; then
        gitcode_sha=$(fetch_sha256 "${GITCODE_RAW_BASE}" "GitCode" "${pkg}" "${version}" "${deb}")
        echo "  GitCode: ${gitcode_sha}"
        if [ -n "${gitcode_sha}" ] && [ "${gitcode_sha}" = "${local_sha}" ]; then
            echo "  PASS: GitCode SHA256 一致"
            PASS=$((PASS + 1))
        elif [ -n "${gitcode_sha}" ]; then
            echo "  FAIL: GitCode SHA256 不一致 (expected: ${local_sha})"
            FAIL=$((FAIL + 1))
        else
            echo "  WARN: GitCode SHA256 计算失败"
            WARN=$((WARN + 1))
        fi
    else
        echo "  SKIP: GitCode SHA256 (URL 不可访问)"
        SKIP=$((SKIP + 1))
    fi
    [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

    if [ "${gitee_url_ok}" -eq 1 ] && [ -n "${gitee_sha}" ] && \
       [ "${github_url_ok}" -eq 1 ] && [ -n "${github_sha}" ] && \
       [ "${gitcode_url_ok}" -eq 1 ] && [ -n "${gitcode_sha}" ]; then
        gitee_diff=$([ "${gitee_sha}" != "${local_sha}" ] && echo 1 || echo 0)
        github_diff=$([ "${github_sha}" != "${local_sha}" ] && echo 1 || echo 0)
        gitcode_diff=$([ "${gitcode_sha}" != "${local_sha}" ] && echo 1 || echo 0)
        if [ "${gitee_diff}" -eq 1 ] || [ "${github_diff}" -eq 1 ] || [ "${gitcode_diff}" -eq 1 ]; then
            gitee_github_agree=$([ "${gitee_sha}" = "${github_sha}" ] && echo 1 || echo 0)
            gitee_gitcode_agree=$([ "${gitee_sha}" = "${gitcode_sha}" ] && echo 1 || echo 0)
            github_gitcode_agree=$([ "${github_sha}" = "${gitcode_sha}" ] && echo 1 || echo 0)
            agree_count=$((gitee_github_agree + gitee_gitcode_agree + github_gitcode_agree))
            if [ "${agree_count}" -ge 2 ]; then
                echo "  WARN: 远程平台之间 SHA256 一致但本地不同，本地文件可能损坏"
            elif [ "${agree_count}" -ge 1 ]; then
                echo "  WARN: 部分远程平台之间 SHA256 不一致，可能存在部分镜像同步问题"
            fi
        fi
    fi

    echo ""
done

if [ ${#PACKAGE_NAMES[@]} -eq 0 ]; then
    echo "  （packages.list 为空，跳过 deb 包验证）"
    echo ""
fi

###############################################################################
# Section 3: DEP-11 YAML 片段文件一致性验证
###############################################################################

echo "--- 3. DEP-11 YAML 片段文件一致性 ---"
echo ""

if [ -d "${DEP11_DIR}" ]; then
    YAML_FILES=$(find "${DEP11_DIR}" -maxdepth 1 -name '*.yml' -type f 2>/dev/null || true)
    if [ -z "${YAML_FILES}" ]; then
        echo "  （dep11/ 目录中无 YAML 文件，跳过验证）"
        echo ""
    else
        while IFS= read -r yaml_file; do
            yaml_basename=$(basename "${yaml_file}")
            echo ">>> ${yaml_basename}"

            local_content=$(cat "${yaml_file}")
            local_sha=$(printf '%s' "${local_content}" | sha256sum | awk '{print $1}')
            echo "  LOCAL SHA256: ${local_sha}"

            check_yaml_url() {
                local raw_base="$1"
                local platform="$2"
                local yaml_name="$3"
                local url="${raw_base}/dep11/${yaml_name}"

                local curl_err
                curl_err=$(mktemp)
                set +e
                local status
                status=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 "${url}" 2>"${curl_err}" || echo "000")
                set -e

                if [ "${status}" = "200" ]; then
                    local remote_content
                    set +e
                    remote_content=$(curl -sL --connect-timeout 10 --max-time 30 "${url}" 2>/dev/null)
                    set -e
                    local remote_sha
                    remote_sha=$(echo "${remote_content}" | sha256sum | awk '{print $1}')
                    echo "  ${platform}: ${remote_sha}"
                    if [ "${remote_sha}" = "${local_sha}" ]; then
                        echo "  PASS: ${platform} DEP-11 YAML 一致"
                        PASS=$((PASS + 1))
                    else
                        echo "  FAIL: ${platform} DEP-11 YAML 不一致"
                        FAIL=$((FAIL + 1))
                    fi
                elif [ "${status}" = "404" ]; then
                    echo "  SKIP: ${platform} 文件不存在 → ${url}"
                    SKIP=$((SKIP + 1))
                elif [ "${status}" = "000" ]; then
                    echo "  WARN: ${platform} 连接失败 → ${url}"
                    WARN=$((WARN + 1))
                else
                    echo "  WARN: ${platform} HTTP ${status} → ${url}"
                    WARN=$((WARN + 1))
                fi
                rm -f "${curl_err}"
            }

            check_yaml_url "${GITEE_RAW_BASE}" "Gitee" "${yaml_basename}"
            [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

            check_yaml_url "${GITHUB_RAW_BASE}" "GitHub" "${yaml_basename}"
            [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

            check_yaml_url "${GITCODE_RAW_BASE}" "GitCode" "${yaml_basename}"
            [ "${SLEEP_INTERVAL}" -gt 0 ] && sleep "${SLEEP_INTERVAL}"

            echo ""
        done <<< "${YAML_FILES}"
    fi
else
    echo "  SKIP: dep11/ 目录不存在"
    SKIP=$((SKIP + 1))
    echo ""
fi

###############################################################################
# Section 4: 结果汇总
###############################################################################

echo "============================================================"
echo " 验证结果汇总"
echo "============================================================"
echo ""
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo "  WARN: ${WARN}"
echo "  SKIP: ${SKIP}"
echo ""
echo "  总计: $((PASS + FAIL + WARN + SKIP))"

if [ "${FAIL}" -gt 0 ]; then
    echo ""
    echo "FAIL: ${FAIL} 项验证未通过"
    exit 1
elif [ "${WARN}" -gt 0 ]; then
    echo ""
    echo "WARN: ${WARN} 项验证存在警告（无 FAIL）"
    exit 0
else
    echo ""
    echo "OK: 所有验证通过"
    exit 0
fi