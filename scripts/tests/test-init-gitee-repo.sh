#!/bin/bash
set -euo pipefail
set +H

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${REPO_ROOT}/.." && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/init-gitee-repo.sh"

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

echo "=== Test: shebang and set -euo pipefail ==="

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
echo "=== Test: 4-space indentation (no tabs) ==="

if grep -q $'\t' "${SCRIPT_PATH}" 2>/dev/null; then
    TAB_COUNT=$(grep -c $'\t' "${SCRIPT_PATH}" || true)
    assert_fail "no tab indentation found" "0 tabs" "${TAB_COUNT} tabs"
else
    assert_pass "no tab indentation found"
fi

echo ""
echo "=== Test: is executable ==="

if [ -x "${SCRIPT_PATH}" ]; then
    assert_pass "init-gitee-repo.sh is executable"
else
    assert_fail "init-gitee-repo.sh is executable" "executable" "not executable"
fi

echo ""
echo "=== Test: dependency checks present ==="

SCRIPT_CONTENT=$(cat "${SCRIPT_PATH}")

if echo "${SCRIPT_CONTENT}" | grep -q 'command -v.*sed\|for dep in sed awk'; then
    assert_pass "sed dependency check present"
else
    assert_fail "sed dependency check present" "command -v" "not found"
fi

if echo "${SCRIPT_CONTENT}" | grep -q 'command -v.*awk\|for dep in sed awk'; then
    assert_pass "awk dependency check present"
else
    assert_fail "awk dependency check present" "command -v" "not found"
fi

echo ""
echo "=== Test: atomic write for README.md ==="

if echo "${SCRIPT_CONTENT}" | grep -q 'TEMP_README\|\.tmp\.\$\$' || echo "${SCRIPT_CONTENT}" | grep -q 'mv.*README'; then
    assert_pass "atomic write strategy for README.md"
else
    assert_fail "atomic write strategy for README.md" "temp + mv" "not found"
fi

echo ""
echo "=== Test: version extraction from packages.list ==="

if echo "${SCRIPT_CONTENT}" | grep -q "awk '{print \$2}'"; then
    assert_pass "version column extraction via awk present"
else
    assert_fail "version column extraction via awk present" "awk \$2" "not found"
fi

echo ""
echo "=== Test: version directory creation ==="

if echo "${SCRIPT_CONTENT}" | grep -q 'VERSION_DIR\|pool/\${pkg_version}'; then
    assert_pass "version subdirectory creation present"
else
    assert_fail "version subdirectory creation present" "VERSION_DIR" "not found"
fi

echo ""
echo "=== Test: script execution - empty packages.list ==="

TEMP_SCRIPTS="${TEMP_DIR}/scripts"
TEMP_VPS="${TEMP_DIR}/vps/apt"
mkdir -p "${TEMP_SCRIPTS}" "${TEMP_VPS}"

cp "${SCRIPT_PATH}" "${TEMP_SCRIPTS}/init-gitee-repo.sh"

cat > "${TEMP_VPS}/packages.list" << 'EOF'
# Empty packages list for testing
EOF

PACKAGES_FILE="${TEMP_VPS}/packages.list" bash "${TEMP_SCRIPTS}/init-gitee-repo.sh" > "${TEMP_DIR}/empty_output.txt" 2>&1 || true

if [ -f "${TEMP_DIR}/dep11/.gitkeep" ]; then
    assert_pass "empty packages.list: dep11/.gitkeep created"
else
    assert_fail "empty packages.list: dep11/.gitkeep created" "exists" "not found"
fi

if grep -q 'packages.list 中无软件包\|只创建基础目录结构' "${TEMP_DIR}/empty_output.txt"; then
    assert_pass "empty packages.list: correct warning message"
else
    assert_fail "empty packages.list: correct warning message" "warning" "not found"
fi

echo ""
echo "=== Test: script execution - with packages ==="

rm -rf "${TEMP_SCRIPTS}" "${TEMP_VPS}" "${TEMP_DIR}/test-pkg" "${TEMP_DIR}/another-pkg" "${TEMP_DIR}/dep11" "${TEMP_DIR}/README.md"
mkdir -p "${TEMP_SCRIPTS}" "${TEMP_VPS}"

cp "${SCRIPT_PATH}" "${TEMP_SCRIPTS}/init-gitee-repo.sh"

cat > "${TEMP_VPS}/packages.list" << 'EOF'
# Test packages
test-pkg 1.0.0
another-pkg 2.1.0
EOF

PACKAGES_FILE="${TEMP_VPS}/packages.list" bash "${TEMP_SCRIPTS}/init-gitee-repo.sh" > "${TEMP_DIR}/with_packages_output.txt" 2>&1 || true

if [ -d "${TEMP_DIR}/test-pkg/pool/1.0.0" ] && [ -f "${TEMP_DIR}/test-pkg/pool/1.0.0/.gitkeep" ]; then
    assert_pass "version subdirectory: test-pkg/pool/1.0.0/ created"
else
    assert_fail "version subdirectory: test-pkg/pool/1.0.0/ created" "dir + .gitkeep" "not found"
fi

if [ -d "${TEMP_DIR}/another-pkg/pool/2.1.0" ] && [ -f "${TEMP_DIR}/another-pkg/pool/2.1.0/.gitkeep" ]; then
    assert_pass "version subdirectory: another-pkg/pool/2.1.0/ created"
else
    assert_fail "version subdirectory: another-pkg/pool/2.1.0/ created" "dir + .gitkeep" "not found"
fi

if [ -f "${TEMP_DIR}/test-pkg/assets/.gitkeep" ]; then
    assert_pass "assets: test-pkg/assets/.gitkeep created"
else
    assert_fail "assets: test-pkg/assets/.gitkeep created" ".gitkeep" "not found"
fi

if [ -f "${TEMP_DIR}/dep11/.gitkeep" ]; then
    assert_pass "dep11/.gitkeep created"
else
    assert_fail "dep11/.gitkeep created" ".gitkeep" "not found"
fi

if [ -f "${TEMP_DIR}/README.md" ]; then
    assert_pass "README.md generated"
else
    assert_fail "README.md generated" "exists" "not found"
fi

echo ""
echo "=== Test: idempotent re-run ==="

PACKAGES_FILE="${TEMP_VPS}/packages.list" bash "${TEMP_SCRIPTS}/init-gitee-repo.sh" > "${TEMP_DIR}/rerun_output.txt" 2>&1 || true

if grep -q '跳过\|已存在' "${TEMP_DIR}/rerun_output.txt"; then
    assert_pass "idempotent re-run: existing files skipped"
else
    assert_fail "idempotent re-run: existing files skipped" "skip messages" "no skip messages found"
fi

echo ""
echo "============================================================"
echo "Test Results: ${PASS} passed, ${FAIL} failed"
echo "============================================================"

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0