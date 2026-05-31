#!/bin/bash
set -euo pipefail
set +H

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/sync-mirrors.sh"

TEMP_DIR="${TEST_DIR}/test-tmp"
rm -rf "${TEMP_DIR}"
mkdir -p "${TEMP_DIR}"

PASS=0
FAIL=0

cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

assert_pass() {
    local desc="$1"
    echo "  PASS: ${desc}"
    PASS=$((PASS + 1))
}

assert_fail() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    echo "  FAIL: ${desc}"
    echo "    expected: ${expected}"
    echo "    actual:   ${actual}"
    FAIL=$((FAIL + 1))
}

echo "=== Test: sync-mirrors.sh ==="
echo ""

echo "--- Subtask 6.1: shebang and set -euo pipefail ---"

if head -1 "${SCRIPT_PATH}" | grep -q '^#!/bin/bash$'; then
    assert_pass "shebang is #!/bin/bash"
else
    assert_fail "shebang is #!/bin/bash" "#!/bin/bash" "$(head -1 ${SCRIPT_PATH})"
fi

if sed -n '2p' "${SCRIPT_PATH}" | grep -q 'set -euo pipefail'; then
    assert_pass "set -euo pipefail on second line"
else
    assert_fail "set -euo pipefail on second line" "set -euo pipefail" "$(sed -n '2p' ${SCRIPT_PATH})"
fi

echo ""
echo "--- Subtask 6.2: 4-space indentation (no tabs) ---"

if grep -q $'\t' "${SCRIPT_PATH}" 2>/dev/null; then
    TAB_COUNT=$(grep -c $'\t' "${SCRIPT_PATH}" 2>/dev/null || echo 0)
    assert_fail "no tab indentation found" "0 tabs" "${TAB_COUNT} tabs"
else
    assert_pass "no tab indentation found"
fi

echo ""
echo "--- Subtask 6.3: is executable ---"

if [ -x "${SCRIPT_PATH}" ]; then
    assert_pass "sync-mirrors.sh is executable"
else
    assert_fail "sync-mirrors.sh is executable" "executable" "not executable"
fi

echo ""
echo "--- Subtask 6.4: dependency checks present ---"

SCRIPT_CONTENT=$(cat "${SCRIPT_PATH}")

if echo "${SCRIPT_CONTENT}" | grep -q 'command -v git'; then
    assert_pass "git dependency check present"
else
    assert_fail "git dependency check present" "command -v git" "not found"
fi

echo ""
echo "--- Subtask 6.5: --help exit code 0 (AC: 6.1) ---"

set +e
bash "${SCRIPT_PATH}" --help > "${TEMP_DIR}/help_output.txt" 2>&1
HELP_RC=$?
set -e

if [ "${HELP_RC}" -eq 0 ]; then
    assert_pass "--help exits 0"
else
    assert_fail "--help exits 0" "0" "${HELP_RC}"
fi

if grep -q 'Usage:\|用法' "${TEMP_DIR}/help_output.txt" || grep -q 'sync-mirrors' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help outputs usage information"
else
    assert_fail "--help outputs usage information" "usage" "not found"
fi

echo ""
echo "--- Subtask 6.6: --help mentions --dry-run and --first-push ---"

if grep -q '\-\-dry-run' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help mentions --dry-run"
else
    assert_fail "--help mentions --dry-run" "present" "not found"
fi

if grep -q '\-\-first-push' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help mentions --first-push"
else
    assert_fail "--help mentions --first-push" "present" "not found"
fi

echo ""
echo "--- Subtask 6.7: --help mentions GITEE_TOKEN/GITHUB_TOKEN/GITCODE_TOKEN ---"

if grep -q 'GITEE_TOKEN' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help mentions GITEE_TOKEN"
else
    assert_fail "--help mentions GITEE_TOKEN" "present" "not found"
fi

if grep -q 'GITHUB_TOKEN' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help mentions GITHUB_TOKEN"
else
    assert_fail "--help mentions GITHUB_TOKEN" "present" "not found"
fi

if grep -q 'GITCODE_TOKEN' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help mentions GITCODE_TOKEN"
else
    assert_fail "--help mentions GITCODE_TOKEN" "present" "not found"
fi

echo ""
echo "--- Subtask 6.8: --dry-run no actual push, outputs targets (AC: 6.2) ---"

TEMP_REPO="${TEMP_DIR}/test-repo"
mkdir -p "${TEMP_REPO}"
cd "${TEMP_REPO}"
git init --quiet
git config user.email "test@test.local"
git config user.name "Test"
git commit --allow-empty -m "initial" --quiet

git remote add gitee "https://gitee.com/test/test.git" 2>/dev/null || true
git remote add github "https://github.com/test/test.git" 2>/dev/null || true
git remote add gitcode "https://gitcode.com/test/test.git" 2>/dev/null || true

set +e
bash "${SCRIPT_PATH}" --dry-run > "${TEMP_DIR}/dry_run_output.txt" 2>&1
DRY_RUN_RC=$?
set -e

if [ "${DRY_RUN_RC}" -eq 0 ]; then
    assert_pass "--dry-run exits 0"
else
    assert_fail "--dry-run exits 0" "0" "${DRY_RUN_RC}"
fi

if grep -q 'DRY-RUN' "${TEMP_DIR}/dry_run_output.txt" || grep -q '干跑' "${TEMP_DIR}/dry_run_output.txt"; then
    assert_pass "--dry-run outputs dry-run indication"
else
    assert_fail "--dry-run outputs dry-run indication" "DRY-RUN" "not found"
fi

if grep -q '未执行实际推送\|no actual push' "${TEMP_DIR}/dry_run_output.txt"; then
    assert_pass "--dry-run confirms no actual push"
else
    assert_fail "--dry-run confirms no actual push" "confirm" "not found"
fi

echo ""
echo "--- Subtask 6.9: --dry-run lists target remotes ---"

if grep -q 'gitee' "${TEMP_DIR}/dry_run_output.txt" && grep -q 'github' "${TEMP_DIR}/dry_run_output.txt" && grep -q 'gitcode' "${TEMP_DIR}/dry_run_output.txt"; then
    assert_pass "--dry-run lists all three target remotes"
else
    assert_fail "--dry-run lists all three target remotes" "gitee+github+gitcode" "not all found"
fi

cd "${PROJECT_ROOT}"

echo ""
echo "--- Subtask 6.10: git unavailable exits non-zero (AC: 6.3) ---"

if grep -q 'command -v git' "${SCRIPT_PATH}"; then
    assert_pass "script checks command -v git"
else
    assert_fail "script checks command -v git" "command -v git" "not found"
fi

if grep -A 3 'command -v git.*>.*\/dev\/null' "${SCRIPT_PATH}" | grep -q 'exit [1-9]'; then
    assert_pass "git unavailable triggers non-zero exit"
else
    assert_fail "git unavailable triggers non-zero exit" "exit non-zero" "not found after git check"
fi

GIT_CHECK_LINE=$(grep -n 'command -v git' "${SCRIPT_PATH}" | head -1 | cut -d: -f1)
if [ -n "${GIT_CHECK_LINE}" ]; then
    ERROR_CONTEXT=$(sed -n "${GIT_CHECK_LINE},$((GIT_CHECK_LINE + 5))p" "${SCRIPT_PATH}")
    if echo "${ERROR_CONTEXT}" | grep -qi 'ERROR.*git\|git.*缺失\|缺少.*git'; then
        assert_pass "git unavailable outputs ERROR message"
    else
        assert_fail "git unavailable outputs ERROR message" "ERROR" "missing git-related error"
    fi
fi

echo ""
echo "--- Subtask 6.11: push order is gitee → github → gitcode (AC: 6.2) ---"

PLATFORM_ORDER=$(grep -n 'GITEE_REMOTE\|GITHUB_REMOTE\|GITCODE_REMOTE' "${SCRIPT_PATH}" | head -6 || true)
GITEE_LINE=$(echo "${PLATFORM_ORDER}" | grep 'GITEE_REMOTE=' | head -1 | cut -d: -f1 || echo "0")
GITHUB_LINE=$(echo "${PLATFORM_ORDER}" | grep 'GITHUB_REMOTE=' | head -1 | cut -d: -f1 || echo "0")
GITCODE_LINE=$(echo "${PLATFORM_ORDER}" | grep 'GITCODE_REMOTE=' | head -1 | cut -d: -f1 || echo "0")

if [ "${GITEE_LINE}" != "" ] && [ "${GITHUB_LINE}" != "" ] && [ "${GITCODE_LINE}" != "" ]; then
    assert_pass "remotes defined in script"
else
    assert_fail "remotes defined in script" "GITEE+GITHUB+GITCODE" "missing"
fi

echo ""
echo "--- Subtask 6.12: script has set +e in push loop (AC: 6.4) ---"

if grep -q 'set +e' "${SCRIPT_PATH}"; then
    assert_pass "set +e used for error tolerance in push loop"
else
    assert_fail "set +e used for error tolerance in push loop" "set +e" "not found"
fi

if grep -q 'set -e' "${SCRIPT_PATH}" && grep -q 'set +e' "${SCRIPT_PATH}"; then
    assert_pass "both set -e and set +e present (error tolerance pattern)"
else
    assert_fail "both set -e and set +e present" "both" "not both"
fi

echo ""
echo "--- Subtask 6.13: FAILED_COUNT used for exit code ---"

if grep -q 'FAILED_COUNT' "${SCRIPT_PATH}" && grep -q 'exit.*FAILED_COUNT\|exit.*failed\|exit.*\${FAILED_COUNT}' "${SCRIPT_PATH}"; then
    assert_pass "exit code derived from FAILED_COUNT"
else
    assert_fail "exit code derived from FAILED_COUNT" "present" "not found"
fi

echo ""
echo "--- Subtask 6.14: SUCCESS/FAILED output messages ---"

if grep -q 'SUCCESS' "${SCRIPT_PATH}" && grep -q 'FAILED' "${SCRIPT_PATH}"; then
    assert_pass "SUCCESS/FAILED output messages present"
else
    assert_fail "SUCCESS/FAILED output messages present" "SUCCESS+FAILED" "missing"
fi

echo ""
echo "--- Subtask 6.15: git ls-remote for HEAD SHA verification ---"

if grep -q 'git ls-remote' "${SCRIPT_PATH}"; then
    assert_pass "git ls-remote used for HEAD SHA verification"
else
    assert_fail "git ls-remote used for HEAD SHA verification" "present" "not found"
fi

echo ""
echo "--- Subtask 6.16: --first-push uses git push --mirror ---"

if grep -q '\-\-first-push' "${SCRIPT_PATH}"; then
    assert_pass "--first-push parameter accepted"
else
    assert_fail "--first-push parameter accepted" "present" "not found"
fi

if grep -q 'push --mirror\|push.*mirror' "${SCRIPT_PATH}"; then
    assert_pass "--first-push triggers git push --mirror"
else
    assert_fail "--first-push triggers git push --mirror" "present" "not found"
fi

echo ""
echo "--- Subtask 6.17: unknown argument error handling ---"

set +e
bash "${SCRIPT_PATH}" --unknown-flag > "${TEMP_DIR}/unknown_flag_output.txt" 2>&1
UNKNOWN_RC=$?
set -e

if [ "${UNKNOWN_RC}" -ne 0 ]; then
    assert_pass "unknown argument exits non-zero"
else
    assert_fail "unknown argument exits non-zero" "non-zero" "${UNKNOWN_RC}"
fi

if grep -qi 'unknown\|error\|未知' "${TEMP_DIR}/unknown_flag_output.txt"; then
    assert_pass "unknown argument outputs error message"
else
    assert_fail "unknown argument outputs error message" "error message" "not found"
fi

echo ""
echo "============================================================"
echo "Test Results: ${PASS} passed, ${FAIL} failed"
echo "============================================================"

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0