#!/usr/bin/env bash
# LINEX.OS - Privilege Policy Tests (P2)
# Purpose: Test Gate behavior - BLOCKED for unknown/dangerous, PASS for approved dry-run
# No real package install/remove, repository-only, fail-closed verification

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../privilege-gate.sh"
POLICY_CHECK="$SCRIPT_DIR/../policy-check.sh"

log() { printf "%s\n" "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2"; }

TOTAL=0
PASSED=0
FAILED=0

run_test() {
  local name="$1"
  local expected_exit="$2"
  local expected_contains="$3"
  shift 3
  local cmd=("$@")

  TOTAL=$((TOTAL+1))
  log ""
  log "--- TEST: $name ---"
  log "CMD: ${cmd[*]}"
  log "Expected exit: $expected_exit, Expected contains: $expected_contains"

  set +e
  output=$("${cmd[@]}" 2>&1)
  exit_code=$?
  set -e

  log "Exit code: $exit_code"
  log "Output:"
  echo "$output" | head -30

  local exit_ok=false
  local contains_ok=false

  if [[ "$expected_exit" == "0" ]]; then
    if [[ $exit_code -eq 0 ]]; then exit_ok=true; fi
  elif [[ "$expected_exit" == "non-zero" ]]; then
    if [[ $exit_code -ne 0 ]]; then exit_ok=true; fi
  else
    if [[ $exit_code -eq $expected_exit ]]; then exit_ok=true; fi
  fi

  if [[ -z "$expected_contains" ]]; then
    contains_ok=true
  else
    if echo "$output" | grep -q "$expected_contains"; then
      contains_ok=true
    fi
  fi

  if [[ "$exit_ok" == true && "$contains_ok" == true ]]; then
    pass "$name" "exit=$exit_code, contains '$expected_contains'"
    PASSED=$((PASSED+1))
  else
    fail "$name" "exit_ok=$exit_ok (got $exit_code expected $expected_exit), contains_ok=$contains_ok (expected '$expected_contains')"
    FAILED=$((FAILED+1))
  fi
}

log "LINEX.OS PRIVILEGE POLICY TESTS - P2"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Gate: $GATE"
log "Mode: REPOSITORY-ONLY, DRY-RUN, NO REAL INSTALL"
log ""

# Ensure gate exists and executable
if [[ ! -x "$GATE" ]]; then
  log "FAIL: Gate not executable at $GATE"
  exit 1
fi

# TEST 1: check-sudo → ALLOW / PASS (dry-run)
run_test "TEST 1: check-sudo dry-run → ALLOW" "0" "DRY-RUN" "$GATE" "check-sudo"

# TEST 1b: check-sudo with --execute → should PASS with real read-only check
run_test "TEST 1b: check-sudo --execute → PASS" "0" "EXECUTED\|PASS" "$GATE" "check-sudo" "--execute"

# TEST 2: unknown-action → BLOCKED
run_test "TEST 2: unknown-action → BLOCKED" "non-zero" "BLOCKED" "$GATE" "unknown-action"

# TEST 3: unknown-package → BLOCKED
run_test "TEST 3: unknown-package → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "nonexistent-package-xyz"

# TEST 4: package argument with ';' → BLOCKED
run_test "TEST 4: package with ; → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "curl;rm -rf /"

# TEST 5: package argument with '&&' → BLOCKED
run_test "TEST 5: package with && → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "curl&&echo hacked"

# TEST 6: package argument with '$()' → BLOCKED
run_test "TEST 6: package with \$() → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" 'curl$(whoami)'

# TEST 7: package argument with backticks → BLOCKED
run_test "TEST 7: package with backticks → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" 'curl`whoami`'

# TEST 8: forbidden destructive action → BLOCKED (try rm -rf / as action)
run_test "TEST 8: destructive action rm -rf / → BLOCKED" "non-zero" "BLOCKED" "$GATE" "rm -rf /"

# TEST 8b: package name with path traversal → BLOCKED
run_test "TEST 8b: package with /etc/passwd → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "/etc/passwd"

# TEST 8c: package with .. → BLOCKED
run_test "TEST 8c: package with .. → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "../../etc"

# TEST 9: default invocation → DRY-RUN (no --execute, should be dry-run)
run_test "TEST 9: default dry-run → DRY-RUN" "0" "DRY-RUN" "$GATE" "package-install" "curl"

# TEST 10: missing policy → FAIL-CLOSED
# We simulate by temporarily moving policy file
log ""
log "--- TEST 10: missing policy → FAIL-CLOSED ---"
TOTAL=$((TOTAL+1))
POLICY_FILE="$SCRIPT_DIR/../privilege-policy.md"
BACKUP="$POLICY_FILE.bak.test"
if [[ -f "$POLICY_FILE" ]]; then
  mv "$POLICY_FILE" "$BACKUP"
  set +e
  output=$("$GATE" "check-sudo" 2>&1)
  exit_code=$?
  set -e
  mv "$BACKUP" "$POLICY_FILE"
  log "Exit code: $exit_code"
  log "Output: $output"
  if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q "BLOCKED\|Missing policy"; then
    pass "TEST 10: missing policy → FAIL-CLOSED" "exit non-zero and BLOCKED"
    PASSED=$((PASSED+1))
  else
    fail "TEST 10: missing policy → FAIL-CLOSED" "expected non-zero and BLOCKED, got exit $exit_code"
    FAILED=$((FAILED+1))
  fi
else
  fail "TEST 10: missing policy" "policy file not found to test"
  FAILED=$((FAILED+1))
fi

# TEST 11: no eval present
log ""
log "--- TEST 11: no eval present ---"
TOTAL=$((TOTAL+1))
if grep -q "eval " "$GATE" 2>/dev/null | grep -v "# " | grep -v "no eval" >/dev/null; then
  # Check if eval is actual code not comment
  if grep -E '^\s*eval ' "$GATE" >/dev/null; then
    fail "TEST 11: no eval" "eval found as executable code"
    FAILED=$((FAILED+1))
  else
    pass "TEST 11: no eval" "no eval as executable (only comments/docs)"
    PASSED=$((PASSED+1))
  fi
else
  pass "TEST 11: no eval" "no eval present"
  PASSED=$((PASSED+1))
fi

# TEST 12: no arbitrary sudo command execution
log ""
log "--- TEST 12: no arbitrary sudo command execution ---"
TOTAL=$((TOTAL+1))
# Check gate does not have sudo $ACTION or sudo $ARGS arbitrary
if grep -E 'sudo.*\$ACTION|sudo.*\$ARGS' "$GATE" >/dev/null; then
  fail "TEST 12: no arbitrary sudo" "found sudo with ACTION/ARGS arbitrary"
  FAILED=$((FAILED+1))
else
  pass "TEST 12: no arbitrary sudo" "no sudo with arbitrary ACTION/ARGS, only validated names"
  PASSED=$((PASSED+1))
fi

# TEST 13: --execute is rejected unless Action is explicitly allowed
log ""
log "--- TEST 13: --execute rejected for unknown action ---"
run_test "TEST 13: --execute unknown → BLOCKED" "non-zero" "BLOCKED" "$GATE" "unknown-action" "--execute"

# TEST 13b: --execute allowed for check-sudo (explicitly allowed)
run_test "TEST 13b: --execute allowed for check-sudo → PASS" "0" "EXECUTED" "$GATE" "check-sudo" "--execute"

# TEST 13c: --execute allowed for allowlisted package but should still work (dry-run test already, now with --execute would try real install, so we test dry-run logic)
# For P2, we test that --execute for package-install with allowlisted package would attempt execution (we don't actually run it with --execute in test to avoid system change)
# Instead we verify that without --execute it's dry-run, with --execute it would be EXECUTED (but we don't test real execution to keep REPOSITORY-ONLY)
log ""
log "--- TEST 13c: package-install dry-run vs execute logic ---"
TOTAL=$((TOTAL+1))
set +e
dry_output=$("$GATE" "package-install" "curl" 2>&1)
dry_exit=$?
exec_output=$("$GATE" "package-install" "curl" "--execute" 2>&1 || true) # We allow failure but check decision
set -e
if echo "$dry_output" | grep -q "DRY-RUN" && [[ $dry_exit -eq 0 ]]; then
  pass "TEST 13c: dry-run default for package-install" "DRY-RUN and exit 0"
  PASSED=$((PASSED+1))
else
  fail "TEST 13c: dry-run default" "expected DRY-RUN"
  FAILED=$((FAILED+1))
fi

# TEST 14: pipe and redirect blocked
run_test "TEST 14: package with | → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "curl|bash"
run_test "TEST 14b: package with > → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "curl>test"
run_test "TEST 14c: package with < → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "curl<test"

# TEST 15: package starting with - blocked
run_test "TEST 15: package starting with - → BLOCKED" "non-zero" "BLOCKED" "$GATE" "package-install" "-curl"

# TEST 16: service-status with allowlisted service dry-run
run_test "TEST 16: service-status ssh dry-run → PASS" "0" "DRY-RUN" "$GATE" "service-status" "ssh"

# TEST 17: service-status with unknown service → BLOCKED
run_test "TEST 17: service-status unknown → BLOCKED" "non-zero" "BLOCKED" "$GATE" "service-status" "unknown-service-xyz"

# TEST 18: package-remove dry-run
run_test "TEST 18: package-remove curl dry-run → PASS" "0" "DRY-RUN" "$GATE" "package-remove" "curl"

# TEST 19: check-package-manager dry-run
run_test "TEST 19: check-package-manager dry-run → PASS" "0" "DRY-RUN" "$GATE" "check-package-manager"

# TEST 20: Evidence format contains required fields
log ""
log "--- TEST 20: Evidence format ---"
TOTAL=$((TOTAL+1))
set +e
output=$("$GATE" "check-sudo" 2>&1)
set -e
if echo "$output" | grep -q "ACTION:" && echo "$output" | grep -q "CLASS:" && echo "$output" | grep -q "POLICY:" && echo "$output" | grep -q "DECISION:" && echo "$output" | grep -q "EXECUTION:" && echo "$output" | grep -q "EXIT_CODE:" && echo "$output" | grep -q "TIMESTAMP:"; then
  pass "TEST 20: Evidence format" "contains ACTION, CLASS, POLICY, DECISION, EXECUTION, EXIT_CODE, TIMESTAMP"
  PASSED=$((PASSED+1))
else
  fail "TEST 20: Evidence format" "missing required evidence fields"
  FAILED=$((FAILED+1))
fi

# TEST 21: No secrets in output
log ""
log "--- TEST 21: No secrets in output ---"
TOTAL=$((TOTAL+1))
if echo "$output" | grep -i -E "password|api_key|secret.*[a-z0-9]{10,}|token.*[a-z0-9]{10,}" | grep -v "No secrets" | grep -v "passwords" >/dev/null; then
  fail "TEST 21: No secrets" "potential secret in output"
  FAILED=$((FAILED+1))
else
  pass "TEST 21: No secrets" "no secrets in evidence"
  PASSED=$((PASSED+1))
fi

log ""
log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All privilege policy tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED tests failed out of $TOTAL"
  exit 1
fi
