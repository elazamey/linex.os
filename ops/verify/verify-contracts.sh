#!/usr/bin/env bash
# LINEX.OS VERIFY CONTRACTS - P9
# Verifies Core Runtime Contracts invariants, no product code, no package install, repository-only
# No package installation, no system changes

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

EXIT_CODE=0

log() { echo -e "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2" >&2; EXIT_CODE=1; }

log "LINEX.OS VERIFY CONTRACTS - P9"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log "Mode: repository-only, no package install, no product code"
log ""

# System changes check
log "=== SYSTEM CHANGES CHECK ==="
if grep -E '^\s*apt-get install|^\s*apt install|^\s*sudo apt|^\s*systemctl' "$SCRIPT_DIR/verify-contracts.sh" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no system changes" "Found apt/sudo/systemctl in verify-contracts.sh"
else
  pass "no system changes" "No apt/sudo/systemctl in verify-contracts.sh"
fi
log ""

# Architecture docs existence (P8)
log "=== P8 ARCHITECTURE DOCS EXISTENCE (must still exist) ==="
for doc in architecture.md context.md container.md components.md execution-model.md security-boundaries.md capability-model.md event-model.md data-model.md networking.md extensibility.md threat-model.md roadmap.md frozen-baseline.md; do
  if [[ -f "$ROOT_DIR/docs/architecture/$doc" ]] || [[ -f "$ROOT_DIR/docs/$doc" ]]; then
    pass "$doc" "exists"
  else
    # architecture.md is in docs/, others in docs/architecture/
    if [[ "$doc" == "architecture.md" && -f "$ROOT_DIR/docs/architecture.md" ]]; then
      pass "$doc" "exists"
    else
      fail "$doc" "missing"
    fi
  fi
done
log ""

# Contracts docs existence (P9)
log "=== P9 CONTRACTS DOCS EXISTENCE ==="
for doc in README.md runtime.md task.md action.md event.md result.md lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# ADRs existence
log "=== ADRS EXISTENCE ==="
for adr in 0001-linex-os-scope.md 0002-execution-boundary.md 0003-capability-security-model.md 0004-policy-vs-execution.md 0005-storage-abstraction.md 0006-extensibility-model.md 0007-core-runtime-contracts.md; do
  if [[ -f "$ROOT_DIR/docs/architecture/adr/$adr" ]]; then
    pass "$adr" "exists"
  else
    fail "$adr" "missing"
  fi
done
log ""

# Contracts invariants
log "=== CONTRACTS INVARIANTS ==="

# Runtime Contract
if grep -q "CoreRuntime" "$ROOT_DIR/docs/contracts/runtime.md" && grep -q "lifecycle" "$ROOT_DIR/docs/contracts/runtime.md" && grep -q "cancellation" "$ROOT_DIR/docs/contracts/runtime.md" && grep -q "recovery" "$ROOT_DIR/docs/contracts/runtime.md"; then
  pass "runtime contract" "CoreRuntime with lifecycle, cancellation, recovery found"
else
  fail "runtime contract" "Runtime Contract missing sections"
fi

# Task/Run Contract
if grep -q "task_id" "$ROOT_DIR/docs/contracts/task.md" && grep -q "run_id" "$ROOT_DIR/docs/contracts/task.md" && grep -q "CREATED" "$ROOT_DIR/docs/contracts/task.md" && grep -q "VERIFIED" "$ROOT_DIR/docs/contracts/task.md"; then
  pass "task/run contract" "Task/Run with task_id, run_id, CREATED, VERIFIED found"
else
  fail "task/run contract" "Task/Run Contract missing"
fi

# Action Contract
if grep -q "PROPOSED" "$ROOT_DIR/docs/contracts/action.md" && grep -q "VALIDATING" "$ROOT_DIR/docs/contracts/action.md" && grep -q "AUTHORIZED" "$ROOT_DIR/docs/contracts/action.md" && grep -q "EXECUTING" "$ROOT_DIR/docs/contracts/action.md" && grep -q "VERIFIED" "$ROOT_DIR/docs/contracts/action.md"; then
  pass "action contract" "Action PROPOSED→VALIDATING→AUTHORIZED→EXECUTING→VERIFIED found"
else
  fail "action contract" "Action Contract state machine missing"
fi

# Event Contract
if grep -q "event_id" "$ROOT_DIR/docs/contracts/event.md" && grep -q "correlation_id" "$ROOT_DIR/docs/contracts/event.md" && grep -q "append-only" "$ROOT_DIR/docs/contracts/event.md" && grep -q "no secrets" "$ROOT_DIR/docs/contracts/event.md"; then
  pass "event contract" "Event with event_id, correlation_id, append-only, no secrets found"
else
  fail "event contract" "Event Contract missing"
fi

# Result/Evidence Contract
if grep -q "result_id" "$ROOT_DIR/docs/contracts/result.md" && grep -q "evidence_id" "$ROOT_DIR/docs/contracts/result.md" && grep -q "SUCCEEDED" "$ROOT_DIR/docs/contracts/result.md" && grep -q "no PASS without evidence" "$ROOT_DIR/docs/contracts/result.md"; then
  pass "result/evidence contract" "Result/Evidence with result_id, evidence_id, SUCCEEDED, no PASS without evidence found"
else
  fail "result/evidence contract" "Result/Evidence Contract missing"
fi

# Lifecycle state machines
if grep -q "Runtime State Machine" "$ROOT_DIR/docs/contracts/lifecycle.md" && grep -q "Task State Machine" "$ROOT_DIR/docs/contracts/lifecycle.md" && grep -q "Action State Machine" "$ROOT_DIR/docs/contracts/lifecycle.md" && grep -q "mermaid" "$ROOT_DIR/docs/contracts/lifecycle.md"; then
  pass "lifecycle state machines" "Runtime, Task, Action state machines with mermaid found"
else
  fail "lifecycle state machines" "Lifecycle state machines missing"
fi

# Trust boundary preserved
if grep -qr "LLM.*Planner.*Policy.*Execution.*Verifier" "$ROOT_DIR/docs/contracts/" >/dev/null && grep -qr "UI.*API only" "$ROOT_DIR/docs/contracts/" -i >/dev/null; then
  pass "trust boundary preserved" "LLM→Planner→Policy→Execution→Verifier and UI→API only preserved in P9"
else
  fail "trust boundary preserved" "Trust boundary missing in P9"
fi

# Capability model preserved
if grep -qr "CAP_" "$ROOT_DIR/docs/contracts/" >/dev/null && grep -qr "DEFAULT DENY" "$ROOT_DIR/docs/contracts/" >/dev/null && grep -qr "fail-closed" "$ROOT_DIR/docs/contracts/" -i >/dev/null; then
  pass "capability model preserved" "CAP_*, DEFAULT DENY, fail-closed preserved in P9"
else
  fail "capability model preserved" "Capability model missing in P9"
fi

# No implementation language chosen
if ! grep -qr "P9 chooses Python\|P9 chooses Node\|P9 chooses Rust" "$ROOT_DIR/docs/contracts/" >/dev/null && grep -q "No implementation language chosen" "$ROOT_DIR/docs/contracts/runtime.md" >/dev/null; then
  pass "no impl language chosen" "No implementation language chosen in P9 preserved"
else
  fail "no impl language chosen" "Implementation language chosen in P9 (should be PENDING)"
fi

# P8 frozen baseline preserved
if test -f "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "Architecture Freeze" "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "Model C" "$ROOT_DIR/docs/architecture/frozen-baseline.md"; then
  pass "P8 frozen baseline preserved" "P8 frozen baseline exists with Model C"
else
  fail "P8 frozen baseline preserved" "P8 frozen baseline missing"
fi

# No contradictions
if ! grep -qr "P8 is obsolete\|P8 replaced\|P8 no longer valid" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no contradictions" "No contradictory P8 obsolete claims"
else
  fail "no contradictions" "Found contradictory P8 obsolete claims"
fi

# Diagrams
if grep -qr "mermaid" "$ROOT_DIR/docs/contracts/" >/dev/null && grep -qr "stateDiagram" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "diagrams" "Diagrams for Runtime, Task, Run, Action found (Mermaid)"
else
  fail "diagrams" "Diagrams missing"
fi

# Contract First principle
if grep -q "Contract First" "$ROOT_DIR/docs/contracts/README.md" && grep -q "Implementation Later" "$ROOT_DIR/docs/contracts/README.md" && grep -q "P9" "$ROOT_DIR/docs/contracts/README.md"; then
  pass "contract first" "Contract First → Implementation Later found"
else
  fail "contract first" "Contract First principle missing"
fi

# 5 core contracts listed
if grep -q "Runtime Contract" "$ROOT_DIR/docs/contracts/README.md" && grep -q "Task/Run Contract" "$ROOT_DIR/docs/contracts/README.md" && grep -q "Action Contract" "$ROOT_DIR/docs/contracts/README.md" && grep -q "Event Contract" "$ROOT_DIR/docs/contracts/README.md" && grep -q "Result/Evidence Contract" "$ROOT_DIR/docs/contracts/README.md"; then
  pass "5 core contracts" "5 core contracts listed in README"
else
  fail "5 core contracts" "5 core contracts not all listed"
fi

log ""

# No product code check
log "=== NO PRODUCT CODE CHECK ==="
if find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" -not -path "*/node_modules/*" | grep -q "."; then
  fail "no product code" "Found product code (should be only docs and shell scripts in P9)"
  find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" | head -5
else
  pass "no product code" "No product code found (only docs and shell scripts)"
fi
log ""

# No package installation in P9
log "=== NO PACKAGE INSTALLATION IN P9 ==="
if grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" 2>/dev/null | head -5 | grep -q "."; then
  fail "no package install in P9" "Found apt install in contracts docs"
  grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" | head -5
else
  pass "no package install in P9" "No apt install in contracts docs (repository-only)"
fi
log ""

log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Contracts verification PASS - all invariants verified"
  log "EVIDENCE → verify-contracts.sh execution, contracts docs, ADR 0007, frozen-baseline"
  log "NEXT → Run contracts.test.sh"
else
  log "STATUS → FAIL"
  log "RESULT → Contracts verification FAIL - see failures above"
fi

exit $EXIT_CODE
