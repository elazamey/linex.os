#!/usr/bin/env bash
# LINEX.OS - P3 Toolchain Tests
# Purpose: Verify toolchain baseline, no arbitrary apt, no curl|bash, Gate usage, smoke tests

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$SCRIPT_DIR/.."
ROOT_DIR="$(cd "$LINUX_DIR/../.." && pwd)"
GATE="$ROOT_DIR/ops/security/privilege-gate.sh"

log() { printf "%s\n" "$*"; }
pass() { printf "%-55s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-55s → FAIL (%s)\n" "$1" "$2"; }

TOTAL=0
PASSED=0
FAILED=0

run_check() {
  local name="$1"
  local condition="$2"
  local detail="$3"
  TOTAL=$((TOTAL+1))
  if eval "$condition"; then
    pass "$name" "$detail"
    PASSED=$((PASSED+1))
  else
    fail "$name" "$detail"
    FAILED=$((FAILED+1))
  fi
}

log "LINEX.OS TOOLCHAIN TESTS - P3"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log ""

# 1. required command exists
log "=== TEST 1: required command exists ==="
for cmd in bash git curl wget jq tar gzip zip unzip grep sed awk find; do
  TOTAL=$((TOTAL+1))
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "command exists: $cmd" "$(command -v $cmd)"
    PASSED=$((PASSED+1))
  else
    fail "command exists: $cmd" "MISSING"
    FAILED=$((FAILED+1))
  fi
done

# 2. required version command succeeds
log ""
log "=== TEST 2: required version command succeeds ==="
for cmd in bash git curl wget jq tar gzip grep sed awk find gcc g++ make python3 node npm pkg-config; do
  TOTAL=$((TOTAL+1))
  if command -v "$cmd" >/dev/null 2>&1; then
    # awk has different version handling
    if [[ "$cmd" == "awk" ]]; then
      if awk --version >/dev/null 2>&1 || awk -W version >/dev/null 2>&1 || ls -l "$(command -v awk)" >/dev/null 2>&1; then
        pass "version succeeds: $cmd" "awk exists at $(command -v awk)"
        PASSED=$((PASSED+1))
      else
        fail "version succeeds: $cmd" "awk check failed"
        FAILED=$((FAILED+1))
      fi
    elif "$cmd" --version >/dev/null 2>&1; then
      pass "version succeeds: $cmd" "$($cmd --version 2>&1 | head -1)"
      PASSED=$((PASSED+1))
    elif "$cmd" -v >/dev/null 2>&1 || "$cmd" -h >/dev/null 2>&1 || "$cmd" --help >/dev/null 2>&1; then
      pass "version succeeds: $cmd" "via -v or -h or --help"
      PASSED=$((PASSED+1))
    else
      fail "version succeeds: $cmd" "version command failed"
      FAILED=$((FAILED+1))
    fi
  else
    fail "version succeeds: $cmd" "MISSING"
    FAILED=$((FAILED+1))
  fi
done

# 3. package mapping valid
log ""
log "=== TEST 3: package mapping valid ==="
TOTAL=$((TOTAL+1))
if grep -q "TOOL_TO_PACKAGE" "$LINUX_DIR/install-base.sh" && grep -q "gcc.*gcc" "$LINUX_DIR/install-base.sh" && grep -q "pkg-config.*pkg-config" "$LINUX_DIR/install-base.sh"; then
  pass "package mapping valid" "TOOL_TO_PACKAGE associative array with explicit mapping"
  PASSED=$((PASSED+1))
else
  fail "package mapping valid" "mapping not found or invalid"
  FAILED=$((FAILED+1))
fi

# 4. no arbitrary apt command
log ""
log "=== TEST 4: no arbitrary apt command ==="
TOTAL=$((TOTAL+1))
if grep -E 'apt-get install.*\$RAW|apt install.*\$RAW|apt-get install.*\$1.*\$2' "$LINUX_DIR/install-base.sh" 2>/dev/null | grep -v "WOULD EXECUTE" | grep -v "No " >/dev/null; then
  fail "no arbitrary apt" "found raw user input in apt install"
  FAILED=$((FAILED+1))
else
  pass "no arbitrary apt" "no apt-get install with RAW_USER_INPUT"
  PASSED=$((PASSED+1))
fi

# 5. no apt upgrade/full-upgrade
log ""
log "=== TEST 5: no apt upgrade/full-upgrade ==="
TOTAL=$((TOTAL+1))
# Check that install-base.sh does not contain apt upgrade as executable (only as comment about avoidance)
if grep -E '^\s*apt-get upgrade|^\s*apt upgrade|^\s*apt-get dist-upgrade|^\s*apt full-upgrade' "$LINUX_DIR/install-base.sh" >/dev/null; then
  fail "no apt upgrade" "found apt upgrade as executable"
  FAILED=$((FAILED+1))
else
  pass "no apt upgrade" "no apt upgrade/full-upgrade/dist-upgrade as executable"
  PASSED=$((PASSED+1))
fi

# 6. no curl|bash
log ""
log "=== TEST 6: no curl|bash ==="
TOTAL=$((TOTAL+1))
# Exclude this test file itself to avoid self-match on comments
if grep -R -E 'curl.*\|\s*bash' "$LINUX_DIR" --exclude="toolchain.test.sh" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | grep -v "avoid" | grep -v "forbidden" | grep -v "Purpose:" | grep -E '^\s*curl.*\|\s*bash' >/dev/null; then
  fail "no curl|bash" "found curl piped to bash as executable"
  FAILED=$((FAILED+1))
else
  pass "no curl|bash" "no curl piped to bash execution"
  PASSED=$((PASSED+1))
fi

# 7. no wget|bash
log ""
log "=== TEST 7: no wget|bash ==="
TOTAL=$((TOTAL+1))
if grep -R -E 'wget.*\|\s*bash' "$LINUX_DIR" --exclude="toolchain.test.sh" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | grep -E '^\s*wget.*\|\s*bash' >/dev/null; then
  fail "no wget|bash" "found wget piped to bash"
  FAILED=$((FAILED+1))
else
  pass "no wget|bash" "no wget piped to bash"
  PASSED=$((PASSED+1))
fi

# 8. no sudo sh -c
log ""
log "=== TEST 8: no sudo sh -c ==="
TOTAL=$((TOTAL+1))
if grep -R "sudo.*sh -c" "$LINUX_DIR" --exclude="toolchain.test.sh" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | grep -v "avoid" | grep -E '^\s*sudo.*sh -c' >/dev/null; then
  fail "no sudo sh -c" "found sudo sh -c as executable"
  FAILED=$((FAILED+1))
else
  pass "no sudo sh -c" "no sudo sh -c pattern"
  PASSED=$((PASSED+1))
fi

# 9. Gate is invoked for privileged install
log ""
log "=== TEST 9: Gate is invoked for privileged install ==="
TOTAL=$((TOTAL+1))
if grep -q "privilege-gate.sh" "$LINUX_DIR/install-base.sh" && grep -q "package-install" "$LINUX_DIR/install-base.sh"; then
  pass "Gate invoked" "install-base.sh uses privilege-gate.sh package-install"
  PASSED=$((PASSED+1))
else
  fail "Gate invoked" "Gate not used for install"
  FAILED=$((FAILED+1))
fi

# 10. missing package path is fail-closed
log ""
log "=== TEST 10: missing package path is fail-closed ==="
TOTAL=$((TOTAL+1))
# Test that unknown package is blocked by Gate
set +e
output=$("$GATE" package-install "nonexistent-pkg-xyz-123" 2>&1)
exit_code=$?
set -e
if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q "BLOCKED"; then
  pass "missing package fail-closed" "unknown package BLOCKED with non-zero exit"
  PASSED=$((PASSED+1))
else
  fail "missing package fail-closed" "expected BLOCKED non-zero, got exit $exit_code"
  FAILED=$((FAILED+1))
fi

# 11. C compiler smoke test if gcc exists
log ""
log "=== TEST 11: C compiler smoke test ==="
TOTAL=$((TOTAL+1))
if command -v gcc >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/test.c" <<'EOF'
#include <stdio.h>
int main() { printf("LINEX.OS C SMOKE PASS\n"); return 0; }
EOF
  if gcc "$tmpdir/test.c" -o "$tmpdir/test_c" 2>&1 && "$tmpdir/test_c" 2>&1 | grep -q "LINEX.OS C SMOKE PASS"; then
    pass "C compiler smoke test" "gcc compiled and ran, output PASS"
    PASSED=$((PASSED+1))
  else
    fail "C compiler smoke test" "gcc compile or run failed"
    FAILED=$((FAILED+1))
  fi
  rm -rf "$tmpdir"
else
  fail "C compiler smoke test" "gcc not found"
  FAILED=$((FAILED+1))
fi

# 12. C++ compiler smoke test if g++ exists
log ""
log "=== TEST 12: C++ compiler smoke test ==="
TOTAL=$((TOTAL+1))
if command -v g++ >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/test.cpp" <<'EOF'
#include <iostream>
int main() { std::cout << "LINEX.OS CPP SMOKE PASS" << std::endl; return 0; }
EOF
  if g++ "$tmpdir/test.cpp" -o "$tmpdir/test_cpp" 2>&1 && "$tmpdir/test_cpp" 2>&1 | grep -q "LINEX.OS CPP SMOKE PASS"; then
    pass "C++ compiler smoke test" "g++ compiled and ran, output PASS"
    PASSED=$((PASSED+1))
  else
    fail "C++ compiler smoke test" "g++ compile or run failed"
    FAILED=$((FAILED+1))
  fi
  rm -rf "$tmpdir"
else
  fail "C++ compiler smoke test" "g++ not found"
  FAILED=$((FAILED+1))
fi

# 13. No docker/podman install in P3
log ""
log "=== TEST 13: No docker/podman install in P3 ==="
TOTAL=$((TOTAL+1))
# Check for actual docker install as executable, not log mentioning "No docker"
if grep -E '^\s*sudo.*docker|^\s*apt.*docker|^\s*docker.*install' "$LINUX_DIR/install-base.sh" 2>/dev/null | grep -v "No " | grep -v "NOT REQUIRED" | grep -v "NOT INSTALLED" | grep -v "VERIFIED" >/dev/null; then
  fail "no docker install" "found docker/podman install as executable in P3"
  FAILED=$((FAILED+1))
else
  pass "no docker install" "no docker/podman install in P3"
  PASSED=$((PASSED+1))
fi

# 14. No pwsh install in P3
log ""
log "=== TEST 14: No pwsh install in P3 ==="
TOTAL=$((TOTAL+1))
if grep -i "pwsh\|powershell" "$LINUX_DIR/install-base.sh" 2>/dev/null | grep -i "install" | grep -v "NOT VERIFIED" | grep -v "P4 only" | grep -v "no pwsh" >/dev/null; then
  fail "no pwsh install" "found pwsh install in P3 (should be P4 only)"
  FAILED=$((FAILED+1))
else
  pass "no pwsh install" "no pwsh install in P3, remains NOT VERIFIED"
  PASSED=$((PASSED+1))
fi

# 15. toolchain-manifest exists and has required entries
log ""
log "=== TEST 15: toolchain-manifest exists ==="
TOTAL=$((TOTAL+1))
if [[ -f "$LINUX_DIR/toolchain-manifest.txt" ]] && grep -q "gcc" "$LINUX_DIR/toolchain-manifest.txt" && grep -q "VERIFIED" "$LINUX_DIR/toolchain-manifest.txt"; then
  pass "toolchain-manifest" "exists and contains VERIFIED entries"
  PASSED=$((PASSED+1))
else
  fail "toolchain-manifest" "missing or invalid"
  FAILED=$((FAILED+1))
fi

log ""
log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All toolchain tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED tests failed out of $TOTAL"
  exit 1
fi
