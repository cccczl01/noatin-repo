#!/bin/bash
set -euo pipefail
set +H

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/verify-mirror-consistency.sh"

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

echo "=== Test: verify-mirror-consistency.sh ==="
echo ""

echo "--- Subtask 7.1: shebang and set -euo pipefail ---"

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
echo "--- Subtask 7.2: 4-space indentation (no tabs) ---"

if grep -q $'\t' "${SCRIPT_PATH}" 2>/dev/null; then
    TAB_COUNT=$(grep -c $'\t' "${SCRIPT_PATH}" || true)
    assert_fail "no tab indentation found" "0 tabs" "${TAB_COUNT} tabs"
else
    assert_pass "no tab indentation found"
fi

echo ""
echo "--- Subtask 7.3: is executable ---"

if [ -x "${SCRIPT_PATH}" ]; then
    assert_pass "verify-mirror-consistency.sh is executable"
else
    assert_fail "verify-mirror-consistency.sh is executable" "executable" "not executable"
fi

echo ""
echo "--- Subtask 7.4: dependency checks present ---"

SCRIPT_CONTENT=$(cat "${SCRIPT_PATH}")

if echo "${SCRIPT_CONTENT}" | grep -q 'for dep in.*curl\|command -v.*curl\|curl' ; then
    assert_pass "curl dependency check present"
else
    assert_fail "curl dependency check present" "command -v curl" "not found"
fi

if echo "${SCRIPT_CONTENT}" | grep -q 'for dep in.*sha256sum\|command -v.*sha256sum'; then
    assert_pass "sha256sum dependency check present"
else
    assert_fail "sha256sum dependency check present" "command -v sha256sum" "not found"
fi

if echo "${SCRIPT_CONTENT}" | grep -q 'for dep in.*awk\|command -v.*awk'; then
    assert_pass "awk dependency check present"
else
    assert_fail "awk dependency check present" "command -v awk" "not found"
fi

echo ""
echo "--- Subtask 7.5: --help exit code 0 (AC: 7.1) ---"

set +e
bash "${SCRIPT_PATH}" --help > "${TEMP_DIR}/help_output.txt" 2>&1
HELP_RC=$?
set -e

if [ "${HELP_RC}" -eq 0 ]; then
    assert_pass "--help exits 0"
else
    assert_fail "--help exits 0" "0" "${HELP_RC}"
fi

if grep -q 'Usage:\|用法' "${TEMP_DIR}/help_output.txt" || grep -q 'verify-mirror' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help outputs usage information"
else
    assert_fail "--help outputs usage information" "usage" "not found"
fi

echo ""
echo "--- Subtask 7.6: --help mentions --sleep ---"

if grep -q '\-\-sleep' "${TEMP_DIR}/help_output.txt"; then
    assert_pass "--help mentions --sleep"
else
    assert_fail "--help mentions --sleep" "present" "not found"
fi

echo ""
echo "--- Subtask 7.7: packages.list parsing present ---"

if grep -q 'packages.list\|PACKAGES_FILE\|vps/apt/packages.list' "${SCRIPT_PATH}"; then
    assert_pass "packages.list path referenced"
else
    assert_fail "packages.list path referenced" "present" "not found"
fi

echo ""
echo "--- Subtask 7.8: PASS/FAIL/WARN/SKIP counters present ---"

if grep -q 'PASS=' "${SCRIPT_PATH}" && grep -q 'FAIL=' "${SCRIPT_PATH}" && grep -q 'WARN=' "${SCRIPT_PATH}" && grep -q 'SKIP=' "${SCRIPT_PATH}"; then
    assert_pass "PASS/FAIL/WARN/SKIP counters present"
else
    assert_fail "PASS/FAIL/WARN/SKIP counters present" "all four" "some missing"
fi

echo ""
echo "--- Subtask 7.9: empty packages.list exits normally (AC: 7.2) ---"

if grep -q '\${#PACKAGE_NAMES\[@\]}.*eq 0\|packages.list 为空' "${SCRIPT_PATH}"; then
    assert_pass "empty packages.list handling present"
else
    assert_fail "empty packages.list handling present" "present" "not found"
fi

echo ""
echo "--- Subtask 7.10: git ls-remote for HEAD SHA ---"

if grep -q 'git ls-remote' "${SCRIPT_PATH}"; then
    assert_pass "git ls-remote used for HEAD SHA"
else
    assert_fail "git ls-remote used for HEAD SHA" "present" "not found"
fi

echo ""
echo "--- Subtask 7.11: SHA256 comparison logic ---"

if grep -q 'sha256sum' "${SCRIPT_PATH}"; then
    assert_pass "sha256sum used for consistency check"
else
    assert_fail "sha256sum used for consistency check" "present" "not found"
fi

if grep -q 'SHA256.*不一致\|SHA256.*mismatch\|SHA256.*differ' "${SCRIPT_PATH}"; then
    assert_pass "SHA256 mismatch triggers FAIL"
else
    assert_fail "SHA256 mismatch triggers FAIL logic" "FAIL output" "not found"
fi

echo ""
echo "--- Subtask 7.12: error handling for git ls-remote failure ---"

if grep -q 'git ls-remote.*2>/dev/null' "${SCRIPT_PATH}" || grep -q 'set +e.*git ls-remote\|ls-remote.*stderr' "${SCRIPT_PATH}"; then
    assert_pass "git ls-remote error handling present"
else
    assert_fail "git ls-remote error handling present" "error handling" "not found"
fi

echo ""
echo "--- Subtask 7.13: unknown argument error handling ---"

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
echo "--- Subtask 7.14: DEP-11 YAML verification section ---"

if grep -q 'dep11\|DEP-11\|\.yml' "${SCRIPT_PATH}"; then
    assert_pass "DEP-11 YAML verification section present"
else
    assert_fail "DEP-11 YAML verification section present" "present" "not found"
fi

echo ""
echo "--- Subtask 7.15: --sleep with integer validation ---"

if grep -q '\-\-sleep' "${SCRIPT_PATH}"; then
    assert_pass "--sleep parameter accepted"
else
    assert_fail "--sleep parameter accepted" "present" "not found"
fi

if grep -q 'SLEEP_INTERVAL' "${SCRIPT_PATH}"; then
    assert_pass "SLEEP_INTERVAL variable used"
else
    assert_fail "SLEEP_INTERVAL variable used" "present" "not found"
fi

echo ""
echo "--- Subtask 7.16: exit code summary ---"

if grep -q 'FAIL.*gt 0.*exit 1\|FAIL.*-gt 0.*exit 1' "${SCRIPT_PATH}" || grep -q 'exit 1' "${SCRIPT_PATH}"; then
    assert_pass "exit 1 on any FAIL"
else
    assert_fail "exit 1 on any FAIL" "present" "not found"
fi

echo ""
echo "============================================================"
echo "Test Results: ${PASS} passed, ${FAIL} failed"
echo "============================================================"

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0