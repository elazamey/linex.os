#!/usr/bin/env bash
# LINEX.OS CONTRACTS TESTS - P9
# Verifies Core Runtime Contracts existence, invariants, no implementation, no contradictions with P8 frozen baseline
# No package installation, no system changes, repository-only

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

TOTAL=0
PASSED=0
FAILED=0

log() { echo -e "$*"; }

pass() {
  local name="$1"
  local detail="$2"
  TOTAL=$((TOTAL+1))
  PASSED=$((PASSED+1))
  printf "%-70s → PASS (%s)\n" "$name" "$detail"
}

fail() {
  local name="$1"
  local detail="$2"
  TOTAL=$((TOTAL+1))
  FAILED=$((FAILED+1))
  printf "%-70s → FAIL (%s)\n" "$name" "$detail" >&2
}

run_check() {
  local name="$1"
  local cmd="$2"
  local pass_msg="$3"
  local fail_msg="$4"
  if eval "$cmd" >/dev/null 2>&1; then
    pass "$name" "$pass_msg"
  else
    fail "$name" "$fail_msg"
  fi
}

log "LINEX.OS CONTRACTS TESTS - P9"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log ""

# TEST 1: contracts docs exist
log "--- TEST 1: contracts docs exist ---"
run_check "TEST 1: contracts docs exist" \
  "test -f \"$ROOT_DIR/docs/contracts/README.md\" && test -f \"$ROOT_DIR/docs/contracts/runtime.md\" && test -f \"$ROOT_DIR/docs/contracts/task.md\" && test -f \"$ROOT_DIR/docs/contracts/action.md\" && test -f \"$ROOT_DIR/docs/contracts/event.md\" && test -f \"$ROOT_DIR/docs/contracts/result.md\" && test -f \"$ROOT_DIR/docs/contracts/lifecycle.md\"" \
  "All contracts docs exist (README, runtime, task, action, event, result, lifecycle)" \
  "Missing contracts docs"
log ""

# TEST 2: ADR 0007 exists
log "--- TEST 2: ADR 0007 exists ---"
run_check "TEST 2: ADR 0007 exists" \
  "test -f \"$ROOT_DIR/docs/architecture/adr/0007-core-runtime-contracts.md\" && grep -q \"ACCEPTED\" \"$ROOT_DIR/docs/architecture/adr/0007-core-runtime-contracts.md\" && grep -q \"Contract First\" \"$ROOT_DIR/docs/architecture/adr/0007-core-runtime-contracts.md\"" \
  "ADR 0007 exists with ACCEPTED and Contract First" \
  "ADR 0007 missing or not ACCEPTED"
log ""

# TEST 3: Runtime Contract exists with lifecycle
log "--- TEST 3: Runtime Contract exists ---"
run_check "TEST 3: Runtime Contract exists" \
  "grep -q \"CoreRuntime\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"lifecycle\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"task execution\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"cancellation\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"recovery\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"configuration\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"health\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"events\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"verification hooks\" \"$ROOT_DIR/docs/contracts/runtime.md\"" \
  "Runtime Contract with lifecycle, task execution, cancellation, recovery, config, health, events, verification hooks found" \
  "Runtime Contract missing sections"
log ""

# TEST 4: Task/Run Contract exists
log "--- TEST 4: Task/Run Contract exists ---"
run_check "TEST 4: Task/Run Contract exists" \
  "grep -q \"Task\" \"$ROOT_DIR/docs/contracts/task.md\" && grep -q \"Run\" \"$ROOT_DIR/docs/contracts/task.md\" && grep -q \"task_id\" \"$ROOT_DIR/docs/contracts/task.md\" && grep -q \"run_id\" \"$ROOT_DIR/docs/contracts/task.md\" && grep -q \"CREATED\" \"$ROOT_DIR/docs/contracts/task.md\" && grep -q \"VERIFIED\" \"$ROOT_DIR/docs/contracts/task.md\"" \
  "Task/Run Contract with task_id, run_id, CREATED, VERIFIED found" \
  "Task/Run Contract missing"
log ""

# TEST 5: Action Contract exists with state machine
log "--- TEST 5: Action Contract exists ---"
run_check "TEST 5: Action Contract exists" \
  "grep -q \"Action\" \"$ROOT_DIR/docs/contracts/action.md\" && grep -q \"PROPOSED\" \"$ROOT_DIR/docs/contracts/action.md\" && grep -q \"VALIDATING\" \"$ROOT_DIR/docs/contracts/action.md\" && grep -q \"AUTHORIZED\" \"$ROOT_DIR/docs/contracts/action.md\" && grep -q \"EXECUTING\" \"$ROOT_DIR/docs/contracts/action.md\" && grep -q \"VERIFIED\" \"$ROOT_DIR/docs/contracts/action.md\" && grep -q \"capability_required\" \"$ROOT_DIR/docs/contracts/action.md\"" \
  "Action Contract with PROPOSED→VALIDATING→AUTHORIZED→EXECUTING→VERIFIED and capability_required found" \
  "Action Contract missing"
log ""

# TEST 6: Event Contract exists
log "--- TEST 6: Event Contract exists ---"
run_check "TEST 6: Event Contract exists" \
  "grep -q \"event_id\" \"$ROOT_DIR/docs/contracts/event.md\" && grep -q \"timestamp\" \"$ROOT_DIR/docs/contracts/event.md\" && grep -q \"actor\" \"$ROOT_DIR/docs/contracts/event.md\" && grep -q \"correlation_id\" \"$ROOT_DIR/docs/contracts/event.md\" && grep -q \"append-only\" \"$ROOT_DIR/docs/contracts/event.md\" && grep -q \"no secrets\" \"$ROOT_DIR/docs/contracts/event.md\"" \
  "Event Contract with event_id, timestamp, actor, correlation_id, append-only, no secrets found" \
  "Event Contract missing"
log ""

# TEST 7: Result/Evidence Contract exists
log "--- TEST 7: Result/Evidence Contract exists ---"
run_check "TEST 7: Result/Evidence Contract exists" \
  "grep -q \"result_id\" \"$ROOT_DIR/docs/contracts/result.md\" && grep -q \"evidence_id\" \"$ROOT_DIR/docs/contracts/result.md\" && grep -q \"SUCCEEDED\" \"$ROOT_DIR/docs/contracts/result.md\" && grep -q \"VERIFIED\" \"$ROOT_DIR/docs/contracts/result.md\" && grep -q \"STATUS.*RESULT.*EVIDENCE.*NEXT\" \"$ROOT_DIR/docs/contracts/result.md\" && grep -q \"no PASS without evidence\" \"$ROOT_DIR/docs/contracts/result.md\"" \
  "Result/Evidence Contract with result_id, evidence_id, SUCCEEDED, VERIFIED, STATUS/RESULT/EVIDENCE/NEXT, no PASS without evidence found" \
  "Result/Evidence Contract missing"
log ""

# TEST 8: Lifecycle state machines exist with diagrams
log "--- TEST 8: Lifecycle state machines exist ---"
run_check "TEST 8: lifecycle state machines exist" \
  "grep -q \"Runtime State Machine\" \"$ROOT_DIR/docs/contracts/lifecycle.md\" && grep -q \"Task State Machine\" \"$ROOT_DIR/docs/contracts/lifecycle.md\" && grep -q \"Action State Machine\" \"$ROOT_DIR/docs/contracts/lifecycle.md\" && grep -q \"mermaid\" \"$ROOT_DIR/docs/contracts/lifecycle.md\" && grep -q \"SUCCEEDED.*VERIFIED\" \"$ROOT_DIR/docs/contracts/lifecycle.md\"" \
  "Lifecycle state machines for Runtime, Task, Action with mermaid and SUCCEEDED≠VERIFIED found" \
  "Lifecycle state machines missing"
log ""

# TEST 9: No implementation language chosen in P9
log "--- TEST 9: No implementation language chosen ---"
run_check "TEST 9: No implementation language chosen" \
  "! grep -qr \"P9 chooses Python\\|P9 chooses Node\\|P9 chooses Rust\\|P9 implementation language is\" \"$ROOT_DIR/docs/contracts/\" && grep -q \"No implementation language chosen\" \"$ROOT_DIR/docs/contracts/runtime.md\" && grep -q \"DECISION PENDING\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\"" \
  "No implementation language chosen in P9, open decisions PENDING preserved" \
  "Implementation language chosen in P9 (should be PENDING until P18)"
log ""

# TEST 10: No product code in P9
log "--- TEST 10: No product code in P9 ---"
run_check "TEST 10: No product code in P9" \
  "! find \"$ROOT_DIR\" -type f \\( -name \"*.py\" -o -name \"*.js\" -o -name \"*.ts\" -o -name \"*.go\" -o -name \"*.rs\" \\) -not -path \"*/.git/*\" -not -path \"*/node_modules/*\" | grep -q \".\" && ! test -d \"$ROOT_DIR/src\" && ! test -d \"$ROOT_DIR/app\" && ! test -d \"$ROOT_DIR/api\" && ! test -d \"$ROOT_DIR/ui\"" \
  "No product code found (only docs and shell scripts, repository-only)" \
  "Product code found (should be docs only in P9)"
log ""

# TEST 11: P8 frozen baseline preserved, no contradictions
log "--- TEST 11: P8 frozen baseline preserved ---"
run_check "TEST 11: P8 frozen baseline preserved" \
  "test -f \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"Architecture Freeze\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"Model C\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"LLM.*Planner.*Policy\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && ! grep -qr \"P8 is obsolete\\|P8 replaced\\|P8 no longer valid\" \"$ROOT_DIR/docs/contracts/\"" \
  "P8 frozen baseline preserved, Model C, trust boundary, no obsolete claims" \
  "P8 frozen baseline missing or contradicted"
log ""

# TEST 12: Trust boundary preserved in P9
log "--- TEST 12: Trust boundary preserved ---"
run_check "TEST 12: trust boundary preserved" \
  "grep -qr \"LLM.*Planner.*Policy.*Execution.*Verifier\" \"$ROOT_DIR/docs/contracts/\" && grep -qr \"LLM.*shell.*forbidden\\|forbidden.*LLM.*shell\" \"$ROOT_DIR/docs/contracts/\" -i && grep -qr \"UI.*API only\" \"$ROOT_DIR/docs/contracts/\" -i" \
  "Trust boundary LLM→Planner→Policy→Execution→Verifier preserved, LLM→shell forbidden, UI→API only" \
  "Trust boundary missing in P9"
log ""

# TEST 13: Capability model preserved
log "--- TEST 13: Capability model preserved ---"
run_check "TEST 13: capability model preserved" \
  "grep -qr \"CAP_\" \"$ROOT_DIR/docs/contracts/\" && grep -qr \"DEFAULT DENY\" \"$ROOT_DIR/docs/contracts/\" && grep -qr \"UNKNOWN.*DENY\\|UNKNOWN→DENY\" \"$ROOT_DIR/docs/contracts/\" && grep -qr \"fail-closed\\|Fail-closed\" \"$ROOT_DIR/docs/contracts/\" -i" \
  "Capability model CAP_*, DEFAULT DENY, UNKNOWN→DENY, fail-closed preserved" \
  "Capability model missing in P9"
log ""

# TEST 14: No package install in P9 docs
log "--- TEST 14: No package install in P9 ---"
run_check "TEST 14: no package install in P9" \
  "! grep -R -n -E '^\\s*apt-get install|^\\s*apt install' \"$ROOT_DIR/docs/contracts\" 2>/dev/null | grep -v \"No \" | grep -q \".\"" \
  "No apt install in contracts docs (repository-only)" \
  "Found apt install in contracts docs (should be repository-only)"
log ""

# TEST 15: Diagrams exist
log "--- TEST 15: diagrams exist ---"
run_check "TEST 15: diagrams exist" \
  "grep -qr \"mermaid\" \"$ROOT_DIR/docs/contracts/\" && grep -qr \"stateDiagram\" \"$ROOT_DIR/docs/contracts/\"" \
  "Diagrams found (Mermaid stateDiagram for Runtime, Task, Run, Action)" \
  "Diagrams missing"
log ""

log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All $PASSED/$TOTAL contracts tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED failed out of $TOTAL"
  exit 1
fi
