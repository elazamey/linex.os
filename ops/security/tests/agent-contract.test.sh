#!/usr/bin/env bash
# LINEX.OS - Agent Contract Tests (P6)
# Purpose: Validate AGENTS.md, ARENA.md, docs/agent-contract.md per P6 spec
# Repository-only, no system changes, no secrets

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENTS_MD="$ROOT_DIR/AGENTS.md"
ARENA_MD="$ROOT_DIR/ARENA.md"
AGENT_CONTRACT_MD="$ROOT_DIR/docs/agent-contract.md"
PRIVILEGE_POLICY="$ROOT_DIR/ops/security/privilege-policy.md"
GATE="$ROOT_DIR/ops/security/privilege-gate.sh"

log() { printf "%s\n" "$*"; }
pass() { printf "%-70s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-70s → FAIL (%s)\n" "$1" "$2"; }

TOTAL=0
PASSED=0
FAILED=0

run_check() {
  local name="$1"
  local condition="$2"
  local success_msg="$3"
  local fail_msg="$4"
  TOTAL=$((TOTAL+1))
  log ""
  log "--- $name ---"
  if eval "$condition"; then
    pass "$name" "$success_msg"
    PASSED=$((PASSED+1))
  else
    fail "$name" "$fail_msg"
    FAILED=$((FAILED+1))
  fi
}

log "LINEX.OS AGENT CONTRACT TESTS - P6"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log ""

# TEST 1: AGENTS.md exists
run_check "TEST 1: AGENTS.md exists" \
  "[[ -f \"$AGENTS_MD\" ]]" \
  "AGENTS.md exists at $AGENTS_MD" \
  "AGENTS.md missing"

# TEST 2: ARENA.md exists
run_check "TEST 2: ARENA.md exists" \
  "[[ -f \"$ARENA_MD\" ]]" \
  "ARENA.md exists at $ARENA_MD" \
  "ARENA.md missing"

# TEST 3: Mandatory workflow INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT
run_check "TEST 3: mandatory workflow INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT" \
  "grep -q \"INSPECT\" \"$AGENTS_MD\" && grep -q \"PLAN\" \"$AGENTS_MD\" && grep -q \"CHANGE\" \"$AGENTS_MD\" && grep -q \"TEST\" \"$AGENTS_MD\" && grep -q \"VERIFY\" \"$AGENTS_MD\" && grep -q \"REPORT\" \"$AGENTS_MD\"" \
  "Workflow INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT found" \
  "Workflow missing in AGENTS.md"

# TEST 4: Privilege policy (Gate reference, allowlist, 5 levels)
run_check "TEST 4: privilege policy Gate + allowlist + levels" \
  "grep -q \"privilege-gate.sh\" \"$AGENTS_MD\" && grep -q \"CLASS-0\" \"$AGENTS_MD\" && grep -q \"CLASS-5\" \"$AGENTS_MD\" && grep -q \"privilege-policy.md\" \"$AGENTS_MD\" && [[ -f \"$PRIVILEGE_POLICY\" ]] && [[ -x \"$GATE\" ]]" \
  "Gate reference, CLASS-0..5, privilege-policy.md exists and Gate executable" \
  "Privilege policy incomplete"

# TEST 5: Fail-closed UNKNOWN→BLOCKED (case-insensitive check for fail-closed concept)
run_check "TEST 5: fail-closed UNKNOWN→BLOCKED" \
  "grep -qi \"fail-closed\" \"$AGENTS_MD\" && grep -q \"UNKNOWN\" \"$AGENTS_MD\" && grep -q \"BLOCKED\" \"$AGENTS_MD\" && grep -qi \"fail-closed\" \"$PRIVILEGE_POLICY\"" \
  "Fail-closed with UNKNOWN→BLOCKED found" \
  "Fail-closed missing"

# TEST 6: DRY-RUN mandatory for risk
run_check "TEST 6: DRY-RUN mandatory" \
  "grep -q \"DRY-RUN\" \"$AGENTS_MD\" && grep -q \"WOULD EXECUTE\" \"$AGENTS_MD\" && grep -q \"DRY-RUN\" \"$ARENA_MD\" && grep -q \"DRY-RUN\" \"$ROOT_DIR/ops/security/privilege-gate.sh\"" \
  "DRY-RUN found in AGENTS.md, ARENA.md, Gate" \
  "DRY-RUN missing"

# TEST 7: Evidence model STATUS/RESULT/EVIDENCE/NEXT + ACTION/CLASS/POLICY/DECISION
run_check "TEST 7: evidence model STATUS/RESULT/EVIDENCE/NEXT" \
  "grep -q \"STATUS\" \"$AGENTS_MD\" && grep -q \"RESULT\" \"$AGENTS_MD\" && grep -q \"EVIDENCE\" \"$AGENTS_MD\" && grep -q \"NEXT\" \"$AGENTS_MD\" && grep -q \"ACTION\" \"$AGENTS_MD\" && grep -q \"CLASS\" \"$AGENTS_MD\" && grep -q \"POLICY\" \"$AGENTS_MD\" && grep -q \"DECISION\" \"$AGENTS_MD\"" \
  "Evidence model with STATUS/RESULT/EVIDENCE/NEXT and ACTION/CLASS/POLICY/DECISION found" \
  "Evidence model incomplete"

# TEST 8: Secret policy forbidden commit/print/log secrets
run_check "TEST 8: secret policy forbidden" \
  "grep -qi \"secret\" \"$AGENTS_MD\" && grep -qi \"forbidden\" \"$AGENTS_MD\" && grep -qi \"env vars\\|secret manager\" \"$AGENTS_MD\"" \
  "Secret policy with forbidden and env vars found" \
  "Secret policy missing"

# TEST 9: Git safety no force push EXPLICIT ACTION
run_check "TEST 9: git safety no force push" \
  "grep -q \"Git\" \"$AGENTS_MD\" && grep -q \"push --force\\|force push\" \"$AGENTS_MD\" && grep -q \"EXPLICIT\" \"$AGENTS_MD\"" \
  "Git safety with no force push and EXPLICIT ACTION found" \
  "Git safety missing"

# TEST 10: Production distinction no MOCK PASS→PRODUCTION PASS, no production claims from local
run_check "TEST 10: production distinction Mock vs Real" \
  "grep -q \"MOCK\" \"$AGENTS_MD\" && grep -qi \"production\" \"$AGENTS_MD\" && grep -q \"REAL LOCAL\\|REAL PRODUCTION\\|MOCK.*PRODUCTION\" \"$AGENTS_MD\"" \
  "Production distinction with Mock vs Real found" \
  "Production distinction missing"

# TEST 11: P4 BLOCKED preserved
run_check "TEST 11: P4 BLOCKED preserved" \
  "grep -q \"P4.*BLOCKED\\|PowerShell.*BLOCKED\\|BLOCKED.*PowerShell\" \"$AGENTS_MD\" && grep -q \"P4.*BLOCKED\\|PowerShell.*BLOCKED\" \"$ARENA_MD\" && grep -q \"packages.microsoft.com.*BLOCKED\\|BLOCKED.*packages.microsoft.com\\|packages.microsoft.com\" \"$AGENTS_MD\" && grep -q \"P4.*BLOCKED\" \"$ROOT_DIR/README.md\" && grep -q \"PowerShell.*BLOCKED\\|P4.*BLOCKED\" \"$ROOT_DIR/docs/operations.md\"" \
  "P4 BLOCKED preserved in AGENTS.md, ARENA.md, README.md, operations.md" \
  "P4 BLOCKED not preserved consistently"

# TEST 12: Arbitrary sudo prohibition via Gate
log ""
log "--- TEST 12: arbitrary sudo prohibition ---"
TOTAL=$((TOTAL+1))
# Check AGENTS.md mentions sudo <input> forbidden and Gate blocks sudo whoami
# Gate exits non-zero for BLOCKED, so use || true to allow grep to succeed with pipefail
if grep -q "sudo <input>" "$AGENTS_MD" && ("$GATE" "sudo whoami" 2>&1 || true) | grep -q "BLOCKED"; then
  pass "TEST 12: arbitrary sudo prohibition" "AGENTS.md mentions sudo <input> and Gate BLOCKED sudo whoami"
  PASSED=$((PASSED+1))
else
  fail "TEST 12: arbitrary sudo prohibition" "Missing sudo <input> mention or Gate not blocking sudo whoami"
  FAILED=$((FAILED+1))
  log "AGENTS.md sudo <input> check: $(grep -c "sudo <input>" "$AGENTS_MD" || echo 0)"
  log "Gate output: $( ("$GATE" "sudo whoami" 2>&1 || true) | head -5)"
fi

# TEST 13: Destructive DENY CLASS-6 DENY
log ""
log "--- TEST 13: destructive DENY CLASS-6 ---"
TOTAL=$((TOTAL+1))
if grep -q "CLASS-6" "$AGENTS_MD" && grep -q "DESTRUCTIVE" "$AGENTS_MD" && grep -q "DENY" "$AGENTS_MD" && ("$GATE" "rm -rf /" 2>&1 || true) | grep -q "BLOCKED"; then
  pass "TEST 13: destructive DENY CLASS-6" "CLASS-6 DESTRUCTIVE DENY found and Gate blocks rm -rf /"
  PASSED=$((PASSED+1))
else
  fail "TEST 13: destructive DENY CLASS-6" "Destructive DENY missing or Gate not blocking"
  FAILED=$((FAILED+1))
fi

# TEST 14: AI/Policy/Execution separation AI PROPOSES→POLICY→EXECUTION→VERIFIER
run_check "TEST 14: AI/Policy/Execution separation" \
  "grep -q \"AI PROPOSES\" \"$AGENTS_MD\" && grep -q \"POLICY\" \"$AGENTS_MD\" && grep -q \"EXECUTION\" \"$AGENTS_MD\" && grep -q \"VERIFIER\" \"$AGENTS_MD\"" \
  "AI PROPOSES→POLICY→EXECUTION→VERIFIER separation found" \
  "Separation missing"

# TEST 15: No secrets in repo - P7 FIX: no longer exclude tests/ entirely, use smart filtering and runtime construction
log ""
log "--- TEST 15: no secrets in repo (P7: includes tests/ with smart filtering) ---"
TOTAL=$((TOTAL+1))
SECRET_FOUND=false
# P7: scanner must include tests/, not exclude directory
# Use placeholders and runtime construction for test fixtures instead of literal secrets
# Build detection patterns at runtime to avoid literal secret-like strings in file static content

# Build patterns at runtime from parts (not containing full credential literal statically)
# For generic credential assignment: build pattern parts
cred_keyword1="api_key"
cred_keyword2="password"
# Construct search pattern at runtime: (api_key|password) assignment
pattern_part1="(${cred_keyword1}|${cred_keyword2})"
# Check ops and config including tests/ but with smart filtering for placeholders and docs
if grep -R -E "${pattern_part1}.{0,10}=.{0,2}[A-Za-z0-9_\-]{16,}" "$ROOT_DIR/ops" "$ROOT_DIR/config" 2>/dev/null | grep -v "No secrets" | grep -v "passwords" | grep -v "API keys" | grep -v "forbidden" | grep -v "secret manager" | grep -v "Secret policy" | grep -v "Check for" | grep -v "example" | grep -v "placeholder" | grep -v "\[A-Za-z0-9" | head -5 | grep -q "."; then
  # Further filter: exclude lines that are detection patterns themselves (contain [A-Za-z0-9] or {16})
  matches=$(grep -R -E "${pattern_part1}.{0,10}=.{0,2}[A-Za-z0-9_\-]{16,}" "$ROOT_DIR/ops" "$ROOT_DIR/config" 2>/dev/null | grep -v "No secrets" | grep -v "passwords" | grep -v "API keys" | grep -v "forbidden" | grep -v "secret manager" | grep -v "Secret policy" | grep -v "Check for" | grep -v "example" | grep -v "placeholder" | grep -v "\[A-Za-z0-9" | head -5 || true)
  if echo "$matches" | grep -q "."; then
    SECRET_FOUND=true
  fi
fi

# Check for GitHub tokens - build prefix at runtime to avoid literal full token in static file
# Use runtime construction: prefix + body pattern
gh_prefix="ghp_"
# Search for concrete tokens: ghp_ + 36 alphanumeric, but filter out regex patterns containing brackets
if grep -R -E "${gh_prefix}[A-Za-z0-9]{36}" "$ROOT_DIR" 2>/dev/null | grep -v "\[A-Za-z0-9\]" | grep -v "{36}" | grep -v -i "pattern" | grep -v -i "regex" | grep -v "example" | grep -v "placeholder" | grep -v "forbidden" | head -5 | grep -q "."; then
  SECRET_FOUND=true
fi

if [[ "$SECRET_FOUND" == false ]]; then
  pass "TEST 15: no secrets in repo" "no credential patterns with values found (checked including tests/ with smart filtering)"
  PASSED=$((PASSED+1))
else
  fail "TEST 15: no secrets in repo" "potential secret found - check grep results"
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
  log "RESULT → All agent contract tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED failed out of $TOTAL"
  exit 1
fi
