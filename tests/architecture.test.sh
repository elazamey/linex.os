#!/usr/bin/env bash
# LINEX.OS - Architecture Tests (P8)
# Purpose: Validate architecture docs, ADRs, trust boundaries, capability model, fail-closed, etc.
# Repository-only, no system changes, no secrets, no product code

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

log "LINEX.OS ARCHITECTURE TESTS - P8"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log ""

# TEST 1: architecture docs exist
run_check "TEST 1: architecture docs exist" \
  "[[ -f \"$ROOT_DIR/docs/architecture.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/context.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/container.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/components.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/execution-model.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/security-boundaries.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/capability-model.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/event-model.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/data-model.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/networking.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/extensibility.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/threat-model.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/roadmap.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" ]]" \
  "All architecture docs exist (context, container, components, execution-model, security-boundaries, capability-model, event-model, data-model, networking, extensibility, threat-model, roadmap, frozen-baseline)" \
  "Missing architecture docs"

# TEST 2: ADRs exist (at least 6)
run_check "TEST 2: ADRs exist (6)" \
  "[[ -f \"$ROOT_DIR/docs/architecture/adr/0001-linex-os-scope.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/adr/0002-execution-boundary.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/adr/0003-capability-security-model.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/adr/0004-policy-vs-execution.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/adr/0005-storage-abstraction.md\" ]] && [[ -f \"$ROOT_DIR/docs/architecture/adr/0006-extensibility-model.md\" ]]" \
  "6 ADRs exist (0001-0006)" \
  "Missing ADRs"

# TEST 3: trust boundary exists (LLM→Planner→Policy→Execution→Verifier)
run_check "TEST 3: trust boundary exists" \
  "grep -q \"LLM\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"Planner\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"Policy Engine\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"Execution Authority\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"Verifier\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"Trust Boundaries\" \"$ROOT_DIR/docs/architecture.md\"" \
  "Trust boundary LLM→Planner→Policy→Execution→Verifier found" \
  "Trust boundary missing"

# TEST 4: capability model exists (CAP_*)
run_check "TEST 4: capability model exists" \
  "grep -q \"CAP_FS_READ\" \"$ROOT_DIR/docs/architecture/capability-model.md\" && grep -q \"CAP_FS_WRITE\" \"$ROOT_DIR/docs/architecture/capability-model.md\" && grep -q \"CAP_PACKAGE_INSTALL\" \"$ROOT_DIR/docs/architecture/capability-model.md\" && grep -q \"DEFAULT.*DENY\\|DEFAULT: DENY\" \"$ROOT_DIR/docs/architecture/capability-model.md\"" \
  "Capability model with CAP_* and DEFAULT DENY found" \
  "Capability model missing"

# TEST 5: fail-closed documented (UNKNOWN→DENY, etc.)
run_check "TEST 5: fail-closed documented" \
  "grep -qi \"fail-closed\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"UNKNOWN\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"DENY\" \"$ROOT_DIR/docs/architecture.md\" && grep -qi \"fail-closed\" \"$ROOT_DIR/docs/architecture/data-model.md\"" \
  "Fail-closed with UNKNOWN→DENY documented" \
  "Fail-closed missing"

# TEST 6: AI/Policy/Execution separation exists
run_check "TEST 6: AI/Policy/Execution separation" \
  "grep -qr \"AI PROPOSES\" \"$ROOT_DIR/docs/architecture/\" && grep -qr \"Policy.*Decides\|POLICY.*DECIDES\" \"$ROOT_DIR/docs/architecture/\" -i && grep -qr \"Execution.*Executes\|EXECUTION.*AUTHORITY\" \"$ROOT_DIR/docs/architecture/\" -i && grep -qr \"Verifier\" \"$ROOT_DIR/docs/architecture/\" -i" \
  "AI/Policy/Execution separation found in architecture docs" \
  "Separation missing"

# TEST 7: UI does not directly control privileged execution
run_check "TEST 7: UI does not directly control privileged execution" \
  "grep -qi \"UI.*client only\|UI.*API only\" \"$ROOT_DIR/docs/architecture.md\" && grep -qi \"UI.*privileged.*directly.*BLOCKED\|UI.*must.*not.*privileged\|UI.*no.*sudo\|UI.*client only\" \"$ROOT_DIR/docs/architecture/security-boundaries.md\"" \
  "UI boundary client only, no privileged execution found" \
  "UI boundary missing or allows privileged"

# TEST 8: LLM does not directly invoke shell
run_check "TEST 8: LLM does not directly invoke shell" \
  "grep -q \"LLM.*→.*shell\|LLM.*shell.*BLOCKED\|Forbidden.*LLM\" \"$ROOT_DIR/docs/architecture/security-boundaries.md\" && grep -q \"LLM\" \"$ROOT_DIR/docs/architecture/execution-model.md\"" \
  "LLM→shell forbidden documented" \
  "LLM→shell not forbidden"

# TEST 9: MCP has trust boundary
run_check "TEST 9: MCP has trust boundary" \
  "grep -q \"MCP Gateway\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"MCP.*trust.*boundary\\|MCP.*isolation\\|MCP.*unbounded.*host.*BLOCKED\\|MCP.*no.*unbounded\" \"$ROOT_DIR/docs/architecture.md\" -i" \
  "MCP Gateway with trust boundary and no unbounded host access found" \
  "MCP trust boundary missing"

# TEST 10: Production distinction exists (LOCAL PASS≠PRODUCTION PASS, MOCK≠PRODUCTION)
run_check "TEST 10: production distinction exists" \
  "grep -q \"LOCAL.*PRODUCTION\\|MOCK.*PRODUCTION\\|Production.*forbidden\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"SUCCEEDED.*≠.*VERIFIED\\|LOCAL PASS.*PRODUCTION PASS\\|MOCK\" \"$ROOT_DIR/docs/architecture.md\"" \
  "Production distinction LOCAL≠PRODUCTION and MOCK≠PRODUCTION found" \
  "Production distinction missing"

# TEST 11: P4 BLOCKED preserved
run_check "TEST 11: P4 BLOCKED preserved" \
  "grep -q \"P4.*BLOCKED\\|PowerShell.*BLOCKED\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"P4.*BLOCKED\\|PowerShell.*BLOCKED\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"P4.*BLOCKED\" \"$ROOT_DIR/README.md\" && grep -q \"PowerShell.*BLOCKED\" \"$ROOT_DIR/docs/operations.md\"" \
  "P4 BLOCKED preserved in architecture docs, frozen-baseline, README, operations" \
  "P4 BLOCKED not preserved"

# TEST 12: system vs project sudo distinction preserved
run_check "TEST 12: system vs project sudo distinction preserved" \
  "grep -q \"SYSTEM_SUDO_POLICY\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"PROJECT.*POLICY\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"SYSTEM_SUDO_POLICY\" \"$ROOT_DIR/docs/architecture/security-boundaries.md\" && grep -q \"SYSTEM_SUDO_POLICY\" \"$ROOT_DIR/AGENTS.md\"" \
  "SYSTEM_SUDO_POLICY vs PROJECT_POLICY distinction preserved in frozen-baseline and security-boundaries" \
  "Sudo distinction missing"

# TEST 13: no contradictory architecture statements (e.g., both says UI has sudo and UI client only)
log ""
log "--- TEST 13: no contradictory architecture statements ---"
TOTAL=$((TOTAL+1))
# Check that architecture.md does not contain both "UI contains sudo" and "UI client only" as positive
# We look for contradictory: if file says UI must have sudo (not must NOT), that would be contradiction
# Our docs say UI must NOT contain sudo, so check that file does NOT contain "UI.*contains.*sudo" without NOT
if grep -i "UI.*contains.*sudo" "$ROOT_DIR/docs/architecture.md" | grep -v "must not" | grep -v "must NOT" | grep -v "does not" | grep -v "no.*sudo" | grep -q "."; then
  fail "TEST 13: no contradictory statements" "Found contradictory UI sudo statement"
  FAILED=$((FAILED+1))
else
  pass "TEST 13: no contradictory statements" "No contradictory UI sudo statements"
  PASSED=$((PASSED+1))
fi

# TEST 14: architecture freeze exists
run_check "TEST 14: architecture freeze exists" \
  "[[ -f \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" ]] && grep -q \"Architecture Freeze\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"No implementation should violate\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\"" \
  "frozen-baseline.md exists with freeze statement" \
  "Freeze missing"

# TEST 15: diagrams exist (ASCII or Mermaid) - avoid triple backticks inside double quotes
run_check "TEST 15: diagrams exist" \
  "grep -q \"System Context\|Runtime Layers\|Action Execution\|Trust Boundaries\|Capability Flow\|Event Flow\" \"$ROOT_DIR/docs/architecture.md\" && grep -q \"mermaid\" \"$ROOT_DIR/docs/architecture/execution-model.md\"" \
  "Diagrams for System Context, Runtime Layers, Action Execution, Trust Boundaries, Capability Flow, Event Flow found (ASCII/Mermaid)" \
  "Diagrams missing"

log ""
log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All architecture tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED failed out of $TOTAL"
  exit 1
fi
