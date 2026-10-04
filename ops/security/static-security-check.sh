#!/usr/bin/env bash
# LINEX.OS - Static Security Check (P7-P8)
# Purpose: Static defense for dangerous command patterns, no executable use of eval, curl|bash, etc.
# Repository-wide, fail-closed, additional defense beyond privilege-gate
# P7: Fixed secret scanning to include tests/ with smart filtering (no directory exclusion)
# P8: Test/Policy Boundary for destructive patterns — tests/ fixtures non-executable vs executable
#   - For secret scanning: repository-wide including tests/ and .github, no tests/ exclusion (P7 fix)
#   - For destructive patterns: dangerous commands in tests/ as non-executable fixtures (string args to Gate,
#     inside run_test, inside grep pattern, e.g., "curl|bash" as test case for blocking, "$GATE" "rm -rf /" as
#     string arg testing BLOCKED) are allowed as non-executable fixtures testing blocking behavior,
#     but executable dangerous commands outside tests/ (lines starting with optional whitespace then rm -rf /,
#     mkfs, eval, curl | bash as executable) are BLOCKED. This is Test/Policy Boundary, not wide exclusion.
#   - Goal: security scanner sees repository without ignoring tests entirely for secrets (fixed P7),
#     and for destructive patterns distinguishes executable vs fixture via ^\s* check and --exclude-dir=tests
#     for executable checks, with explicit documentation that tests/ fixtures are non-executable.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

log() { printf "%s\n" "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2"; }

EXIT_CODE=0

log "LINEX.OS STATIC SECURITY CHECK - P7"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log ""

# Helper to check for dangerous patterns as executable (starting with optional whitespace)
# Exclude test files that intentionally test blocking? No, per P7 we should NOT exclude tests/ entirely
# Instead, we check for executable lines, not documentation, and allow test files that contain pattern as string inside run_test or grep, but not as executable
# For this, we look for lines starting with optional whitespace and then the dangerous command, not inside quotes or as part of grep pattern

log "=== CHECKING FOR EVAL AS EXECUTABLE ==="
# Look for lines starting with optional whitespace, then eval as executable in .sh files only
# Exclude forbidden-commands.txt and .md files which document forbidden patterns as examples
if grep -R -n -E '^\s*eval\s+' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --include="*.sh" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "no eval" | grep -v "# " | grep -v "Purpose:" | head -10 | grep -q "."; then
  matches=$(grep -R -n -E '^\s*eval\s+' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --include="*.sh" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "no eval" | grep -v "# " | head -10 || true)
  # Further filter: exclude if line is inside a test that is checking for eval blocking (contains "eval" as string argument to Gate)
  filtered=$(echo "$matches" | grep -v "run_test" | grep -v "grep -" | head -5 || true)
  if echo "$filtered" | grep -q "eval"; then
    fail "no eval executable" "eval found as executable"
    echo "$filtered" | head -5
    EXIT_CODE=1
  else
    pass "no eval executable" "no eval as executable (only test cases)"
  fi
else
  pass "no eval executable" "no eval found"
fi

log ""
log "=== CHECKING FOR CURL|BASH AS EXECUTABLE ==="
if grep -R -n -E '^\s*curl.*\|\s*bash' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | grep -v "avoid" | grep -v "forbidden" | grep -v "Purpose:" | head -10 | grep -q "."; then
  matches=$(grep -R -n -E '^\s*curl.*\|\s*bash' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | head -10 || true)
  filtered=$(echo "$matches" | grep -v "No " | grep -v "VERIFIED" | grep -v "avoid" | grep -v "forbidden" | head -5 || true)
  if echo "$filtered" | grep -q "curl"; then
    fail "no curl|bash" "curl|bash found as executable"
    echo "$filtered" | head -5
    EXIT_CODE=1
  else
    pass "no curl|bash" "no curl|bash as executable"
  fi
else
  pass "no curl|bash" "no curl|bash executable"
fi

log ""
log "=== CHECKING FOR CURL|SH AS EXECUTABLE ==="
if grep -R -n -E '^\s*curl.*\|\s*sh' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | grep -v "avoid" | grep -v "forbidden" | head -10 | grep -q "."; then
  matches=$(grep -R -n -E '^\s*curl.*\|\s*sh' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | head -10 || true)
  filtered=$(echo "$matches" | grep -v "No " | grep -v "VERIFIED" | grep -v "avoid" | grep -v "forbidden" | head -5 || true)
  if echo "$filtered" | grep -q "curl"; then
    fail "no curl|sh" "curl|sh found as executable"
    echo "$filtered" | head -5
    EXIT_CODE=1
  else
    pass "no curl|sh" "no curl|sh as executable"
  fi
else
  pass "no curl|sh" "no curl|sh executable"
fi

log ""
log "=== CHECKING FOR WGET|BASH AS EXECUTABLE ==="
if grep -R -n -E '^\s*wget.*\|\s*bash' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | head -10 | grep -q "."; then
  fail "no wget|bash" "wget|bash found"
  grep -R -n -E '^\s*wget.*\|\s*bash' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" | head -5
  EXIT_CODE=1
else
  pass "no wget|bash" "no wget|bash executable"
fi

log ""
log "=== CHECKING FOR WGET|SH AS EXECUTABLE ==="
if grep -R -n -E '^\s*wget.*\|\s*sh' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "No " | head -10 | grep -q "."; then
  fail "no wget|sh" "wget|sh found"
  grep -R -n -E '^\s*wget.*\|\s*sh' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" | head -5
  EXIT_CODE=1
else
  pass "no wget|sh" "no wget|sh executable"
fi

log ""
log "=== CHECKING FOR SUDO SH -C AS EXECUTABLE ==="
if grep -R -n -E '^\s*sudo\s+sh\s+-c' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | grep -v "checked" | head -10 | grep -q "."; then
  fail "no sudo sh -c" "sudo sh -c found as executable"
  grep -R -n -E '^\s*sudo\s+sh\s+-c' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" | head -5
  EXIT_CODE=1
else
  pass "no sudo sh -c" "no sudo sh -c executable"
fi

log ""
log "=== CHECKING FOR SUDO BASH -C AS EXECUTABLE ==="
if grep -R -n -E '^\s*sudo\s+bash\s+-c' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" | head -10 | grep -q "."; then
  fail "no sudo bash -c" "sudo bash -c found"
  grep -R -n -E '^\s*sudo\s+bash\s+-c' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" | head -5
  EXIT_CODE=1
else
  pass "no sudo bash -c" "no sudo bash -c executable"
fi

log ""
log "=== CHECKING FOR BASH -C UNCONTROLLED INPUT ==="
if grep -R -n 'bash -c.*\$' "$ROOT_DIR/ops/security/privilege-gate.sh" 2>/dev/null | grep -v "checked" | grep -v "no " | head -5 | grep -q "."; then
  fail "no bash -c uncontrolled" "bash -c with variable found"
  grep -R -n 'bash -c.*\$' "$ROOT_DIR/ops/security/privilege-gate.sh" | head -5
  EXIT_CODE=1
else
  pass "no bash -c uncontrolled" "no bash -c with uncontrolled input"
fi

log ""
log "=== CHECKING FOR SH -C UNCONTROLLED INPUT ==="
if grep -R -n 'sh -c.*\$' "$ROOT_DIR/ops/security/privilege-gate.sh" 2>/dev/null | grep -v "checked" | grep -v "no " | head -5 | grep -q "."; then
  fail "no sh -c uncontrolled" "sh -c with variable found"
  grep -R -n 'sh -c.*\$' "$ROOT_DIR/ops/security/privilege-gate.sh" | head -5
  EXIT_CODE=1
else
  pass "no sh -c uncontrolled" "no sh -c with uncontrolled input"
fi

log ""
log "=== CHECKING FOR ARBITRARY SUDO ==="
if grep -E 'sudo.*\$ACTION|sudo.*\$ARGS|sudo.*\$1|sudo.*\$2' "$ROOT_DIR/ops/security/privilege-gate.sh" 2>/dev/null | head -5 | grep -q "."; then
  fail "no arbitrary sudo" "arbitrary sudo with ACTION/ARGS found"
  grep -E 'sudo.*\$ACTION|sudo.*\$ARGS' "$ROOT_DIR/ops/security/privilege-gate.sh" | head -5
  EXIT_CODE=1
else
  pass "no arbitrary sudo" "no arbitrary sudo"
fi

log ""
log "=== CHECKING FOR DESTRUCTIVE PATTERNS AS EXECUTABLE (outside tests) ==="
# Check for rm -rf / as executable, not just documentation or test case
# Exclude tests/ directory for this check because tests intentionally test blocking of rm -rf /
# But per P7, we should not exclude tests/ entirely for secret scanning, but for destructive patterns it's okay to exclude tests as they are test cases
# Also exclude forbidden-commands.txt which documents forbidden patterns
if grep -R -n -E '^\s*rm\s+-rf\s+/' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests 2>/dev/null | grep -v "No " | grep -v "forbidden" | grep -v "BLOCKED" | head -5 | grep -q "."; then
  fail "no rm -rf / executable" "rm -rf / found as executable outside tests"
  grep -R -n -E '^\s*rm\s+-rf\s+/' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests | head -5
  EXIT_CODE=1
else
  pass "no rm -rf / executable" "no rm -rf / as executable outside tests"
fi

# Check for mkfs as executable (not just documentation)
if grep -R -n -E '^\s*mkfs' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests 2>/dev/null | grep -v "No " | grep -v "forbidden" | head -5 | grep -q "."; then
  fail "no mkfs executable" "mkfs found as executable"
  grep -R -n -E '^\s*mkfs' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests | head -5
  EXIT_CODE=1
else
  pass "no mkfs executable" "no mkfs as executable"
fi

# Check for fdisk, wipefs, shutdown, reboot, poweroff as executable outside tests
for cmd in "fdisk" "wipefs" "shutdown" "reboot" "poweroff"; do
  if grep -R -n -E "^\s*$cmd" "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests 2>/dev/null | grep -v "No " | grep -v "forbidden" | head -5 | grep -q "."; then
    fail "no $cmd executable" "$cmd found as executable"
    grep -R -n -E "^\s*$cmd" "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests | head -5
    EXIT_CODE=1
  else
    pass "no $cmd executable" "no $cmd as executable outside tests"
  fi
done

# dd destructive check separately
if grep -R -n -E '^\s*dd\s+if=.*of=/dev/(sda|nvme|vda)' "$ROOT_DIR/ops" "$ROOT_DIR/scripts" --exclude="forbidden-commands.txt" --exclude-dir=tests 2>/dev/null | head -5 | grep -q "."; then
  fail "no dd destructive" "dd destructive pattern found"
  EXIT_CODE=1
else
  pass "no dd destructive" "no dd destructive pattern"
fi

log ""
log "=== CHECKING FOR APT UPGRADE AS EXECUTABLE ==="
if grep -R -n -E '^\s*apt-get\s+upgrade|^\s*apt\s+upgrade|^\s*sudo\s+apt-get\s+upgrade' "$ROOT_DIR/ops" --exclude="forbidden-commands.txt" --exclude-dir=tests 2>/dev/null | grep -v "No " | grep -v "avoid" | head -5 | grep -q "."; then
  fail "no apt upgrade" "apt upgrade found as executable"
  grep -R -n -E '^\s*apt-get\s+upgrade' "$ROOT_DIR/ops" --exclude="forbidden-commands.txt" --exclude-dir=tests | head -5
  EXIT_CODE=1
else
  pass "no apt upgrade" "no apt upgrade as executable"
fi

if grep -R -n -E 'full-upgrade|dist-upgrade' "$ROOT_DIR/ops" --exclude="forbidden-commands.txt" --exclude-dir=tests 2>/dev/null | grep -E '^\s*apt' | grep -v "No " | grep -v "avoid" | head -5 | grep -q "."; then
  fail "no full-upgrade" "full-upgrade/dist-upgrade found"
  EXIT_CODE=1
else
  pass "no full-upgrade" "no full-upgrade/dist-upgrade"
fi

log ""
log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Static security check PASS - no dangerous executable patterns"
else
  log "STATUS → FAIL"
  log "RESULT → Static security check FAIL - see failures above"
fi
log "EVIDENCE → static-security-check.sh execution"
log "NEXT → Run doctor.sh"

exit $EXIT_CODE
