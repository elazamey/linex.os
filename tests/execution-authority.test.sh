#!/usr/bin/env bash
# LINEX.OS EXECUTION AUTHORITY TESTS - P10
# Verifies Execution Authority Contracts existence, invariants, no implementation, no contradictions with P8 frozen baseline and P9 contracts
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

log "LINEX.OS EXECUTION AUTHORITY TESTS - P10"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log ""

# TEST-1: execution-authority contract exists
log "--- TEST-1: execution-authority contract exists ---"
run_check "TEST-1: execution-authority contract exists" \
  "test -f \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Execution Authority\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"ExecutionRequest\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"ExecutionResult\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "execution-authority.md exists with Execution Authority, ExecutionRequest, ExecutionResult" \
  "execution-authority contract missing"
log ""

# TEST-2: all 5 executor contracts exist
log "--- TEST-2: all 5 executor contracts exist ---"
run_check "TEST-2: all 5 executor contracts exist" \
  "test -f \"$ROOT_DIR/docs/contracts/executor-shell.md\" && test -f \"$ROOT_DIR/docs/contracts/executor-process.md\" && test -f \"$ROOT_DIR/docs/contracts/executor-file.md\" && test -f \"$ROOT_DIR/docs/contracts/executor-network.md\" && test -f \"$ROOT_DIR/docs/contracts/executor-package.md\"" \
  "All 5 executor contracts exist (shell, process, file, network, package)" \
  "Missing executor contracts"
log ""

# TEST-3: executor matrix exists
log "--- TEST-3: executor matrix exists ---"
run_check "TEST-3: executor matrix exists" \
  "test -f \"$ROOT_DIR/docs/contracts/executor-matrix.md\" && grep -q \"Executor\" \"$ROOT_DIR/docs/contracts/executor-matrix.md\" && grep -q \"Capability\" \"$ROOT_DIR/docs/contracts/executor-matrix.md\" && grep -q \"Shell\" \"$ROOT_DIR/docs/contracts/executor-matrix.md\" && grep -q \"Process\" \"$ROOT_DIR/docs/contracts/executor-matrix.md\"" \
  "executor-matrix.md exists with Executor, Capability, Shell, Process" \
  "executor matrix missing"
log ""

# TEST-4: Execution Authority boundary exists
log "--- TEST-4: Execution Authority boundary exists ---"
run_check "TEST-4: Execution Authority boundary exists" \
  "grep -q \"Execution Authority.*sole.*boundary\\|sole.*architectural.*boundary\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i && grep -q \"Planner.*Agent.*Action.*Policy.*Authorization.*Execution Authority.*Executor.*Result.*Verifier\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Responsibilities\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Execution Authority boundary exists with sole boundary and mandatory path" \
  "Execution Authority boundary missing"
log ""

# TEST-5: LLM direct executor forbidden
log "--- TEST-5: LLM direct executor forbidden ---"
run_check "TEST-5: LLM direct executor forbidden" \
  "grep -q \"INV-EA-01\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"LLM cannot call an Executor directly\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"LLM.*Executor.*forbidden\\|forbidden.*LLM.*Executor\" \"$ROOT_DIR/docs/contracts/\" -i -r" \
  "LLM direct executor forbidden found (INV-EA-01)" \
  "LLM direct executor forbidden missing"
log ""

# TEST-6: Agent direct executor forbidden
log "--- TEST-6: Agent direct executor forbidden ---"
run_check "TEST-6: Agent direct executor forbidden" \
  "grep -q \"INV-EA-03\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Agent cannot call an Executor directly\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Agent direct executor forbidden found (INV-EA-03)" \
  "Agent direct executor forbidden missing"
log ""

# TEST-7: UI direct executor forbidden
log "--- TEST-7: UI direct executor forbidden ---"
run_check "TEST-7: UI direct executor forbidden" \
  "grep -q \"INV-EA-04\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"UI cannot call an Executor directly\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"UI.*API only\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i" \
  "UI direct executor forbidden found (INV-EA-04, UI→API only)" \
  "UI direct executor forbidden missing"
log ""

# TEST-8: Policy required
log "--- TEST-8: Policy required ---"
run_check "TEST-8: Policy required" \
  "grep -q \"INV-EA-07\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Every execution requires Policy Decision\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-04\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Policy required\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Policy required found (INV-EA-07, EA-04)" \
  "Policy required missing"
log ""

# TEST-9: Authorization required for elevated actions
log "--- TEST-9: Authorization required for elevated actions ---"
run_check "TEST-9: Authorization required for elevated actions" \
  "grep -q \"INV-EA-08\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Every privileged execution requires Authorization\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-05\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Authorization required for elevated actions found (INV-EA-08, EA-05)" \
  "Authorization required missing"
log ""

# TEST-10: Capability required
log "--- TEST-10: Capability required ---"
run_check "TEST-10: Capability required" \
  "grep -q \"INV-EA-10\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Unknown Capability.*DENY\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-06\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Capability required\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Capability required found (INV-EA-10, EA-06, UNKNOWN→DENY)" \
  "Capability required missing"
log ""

# TEST-11: Scope required
log "--- TEST-11: Scope required ---"
run_check "TEST-11: Scope required" \
  "grep -q \"EA-07\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Scope required\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"workspace.*repository.*project.*user.*host.*network.*production\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Scope required found (EA-07, workspace/repository/project/user/host/network/production)" \
  "Scope required missing"
log ""

# TEST-12: Unknown Executor BLOCKED
log "--- TEST-12: Unknown Executor BLOCKED ---"
run_check "TEST-12: Unknown Executor BLOCKED" \
  "grep -q \"INV-EA-09\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Unknown Executor.*BLOCKED\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-08\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Unknown Executor BLOCKED found (INV-EA-09, EA-08)" \
  "Unknown Executor BLOCKED missing"
log ""

# TEST-13: Unknown Capability DENY
log "--- TEST-13: Unknown Capability DENY ---"
run_check "TEST-13: Unknown Capability DENY" \
  "grep -q \"INV-EA-10\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Unknown Capability.*DENY\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-09\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Unknown Capability DENY found (INV-EA-10, EA-09)" \
  "Unknown Capability DENY missing"
log ""

# TEST-14: No arbitrary sudo
log "--- TEST-14: No arbitrary sudo ---"
run_check "TEST-14: No arbitrary sudo" \
  "grep -q \"EA-10\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"No arbitrary sudo\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"sudo.*arbitrary\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i && grep -q \"privilege-gate.sh\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "No arbitrary sudo found (EA-10, privilege-gate.sh)" \
  "No arbitrary sudo missing"
log ""

# TEST-15: No arbitrary shell
log "--- TEST-15: No arbitrary shell ---"
run_check "TEST-15: No arbitrary shell" \
  "grep -q \"EA-11\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"No arbitrary shell\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"MUST NOT receive arbitrary user-generated command text\" \"$ROOT_DIR/docs/contracts/executor-shell.md\"" \
  "No arbitrary shell found (EA-11, MUST NOT arbitrary user-generated)" \
  "No arbitrary shell missing"
log ""

# TEST-16: Process Executor prefers argv
log "--- TEST-16: Process Executor prefers argv ---"
run_check "TEST-16: Process Executor prefers argv" \
  "grep -q \"ARGV MODE preferred\" \"$ROOT_DIR/docs/contracts/executor-process.md\" && grep -q \"executable\" \"$ROOT_DIR/docs/contracts/executor-process.md\" && grep -q \"argv\" \"$ROOT_DIR/docs/contracts/executor-process.md\" && grep -q \"no bash -c\" \"$ROOT_DIR/docs/contracts/executor-process.md\" && grep -q \"no sh -c\" \"$ROOT_DIR/docs/contracts/executor-process.md\"" \
  "Process Executor prefers argv found (ARGV MODE, no bash -c, no sh -c)" \
  "Process Executor argv preference missing"
log ""

# TEST-17: Shell Executor explicitly high risk
log "--- TEST-17: Shell Executor explicitly high risk ---"
run_check "TEST-17: Shell Executor explicitly high risk" \
  "grep -q \"Shell Executor\" \"$ROOT_DIR/docs/contracts/executor-shell.md\" && grep -q \"HIGH\" \"$ROOT_DIR/docs/contracts/executor-shell.md\" && grep -q \"CRITICAL\" \"$ROOT_DIR/docs/contracts/executor-shell.md\" && grep -q \"REQUIRE_APPROVAL\" \"$ROOT_DIR/docs/contracts/executor-shell.md\" && grep -q \"shell.command\" \"$ROOT_DIR/docs/contracts/executor-shell.md\" && grep -q \"process.argv\" \"$ROOT_DIR/docs/contracts/executor-shell.md\"" \
  "Shell Executor high risk found (HIGH/CRITICAL, REQUIRE_APPROVAL, shell.command vs process.argv)" \
  "Shell Executor high risk missing"
log ""

# TEST-18: Filesystem traversal blocked
log "--- TEST-18: Filesystem traversal blocked ---"
run_check "TEST-18: Filesystem traversal blocked" \
  "grep -q \"path traversal defense\" \"$ROOT_DIR/docs/contracts/executor-file.md\" && grep -q \"Unknown path scope.*BLOCKED\" \"$ROOT_DIR/docs/contracts/executor-file.md\" && grep -q \"no.*\\.\\./\" \"$ROOT_DIR/docs/contracts/executor-file.md\" && grep -q \"/etc/sudoers\" \"$ROOT_DIR/docs/contracts/executor-file.md\"" \
  "Filesystem traversal blocked found (path traversal defense, Unknown path scope BLOCKED, /etc/sudoers)" \
  "Filesystem traversal blocked missing"
log ""

# TEST-19: Network unrestricted default blocked
log "--- TEST-19: Network unrestricted default blocked ---"
run_check "TEST-19: Network unrestricted default blocked" \
  "grep -q \"Unknown destination.*BLOCKED\" \"$ROOT_DIR/docs/contracts/executor-network.md\" && grep -q \"no unrestricted Internet\" \"$ROOT_DIR/docs/contracts/executor-network.md\" -i && grep -q \"allowlist\" \"$ROOT_DIR/docs/contracts/executor-network.md\"" \
  "Network unrestricted default blocked found (Unknown destination BLOCKED, no unrestricted Internet, allowlist)" \
  "Network unrestricted blocked missing"
log ""

# TEST-20: Package Executor uses Privilege Gate
log "--- TEST-20: Package Executor uses Privilege Gate ---"
run_check "TEST-20: Package Executor uses Privilege Gate" \
  "grep -q \"Privilege Gate\" \"$ROOT_DIR/docs/contracts/executor-package.md\" && grep -q \"privilege-gate.sh\" \"$ROOT_DIR/docs/contracts/executor-package.md\" && grep -q \"must not be bypassed\" \"$ROOT_DIR/docs/contracts/executor-package.md\" -i && grep -q \"no arbitrary apt\" \"$ROOT_DIR/docs/contracts/executor-package.md\" -i" \
  "Package Executor uses Privilege Gate found (Privilege Gate, must not be bypassed, no arbitrary apt)" \
  "Package Executor Gate missing"
log ""

# TEST-21: Dry-run exists
log "--- TEST-21: Dry-run exists ---"
run_check "TEST-21: Dry-run exists" \
  "grep -q \"DRY-RUN\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"WOULD_EXECUTE\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"NO SIDE EFFECT\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-12\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Dry-run exists found (DRY-RUN, WOULD_EXECUTE, NO SIDE EFFECT, EA-12)" \
  "Dry-run missing"
log ""

# TEST-22: Timeout exists
log "--- TEST-22: Timeout exists ---"
run_check "TEST-22: Timeout exists" \
  "grep -q \"timeout_requested\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"timeout_enforced\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"TIMEOUT\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-14\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Timeout must not automatically become SUCCESS\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Timeout exists found (timeout_requested, timeout_enforced, TIMEOUT, EA-14, no auto SUCCESS)" \
  "Timeout missing"
log ""

# TEST-23: Resource limits exist
log "--- TEST-23: Resource limits exist ---"
run_check "TEST-23: Resource limits exist" \
  "grep -q \"resource_limits\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"cpu\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"memory\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-13\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Resource limits exist found (resource_limits cpu/memory, EA-13)" \
  "Resource limits missing"
log ""

# TEST-24: Cancellation exists
log "--- TEST-24: Cancellation exists ---"
run_check "TEST-24: Cancellation exists" \
  "grep -q \"CANCEL_REQUESTED\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"CANCELLING\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"CANCELLED\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"orphaned\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i && grep -q \"INV-EA-18\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Cancellation exists found (CANCEL_REQUESTED/CANCELLING/CANCELLED, no orphaned, INV-EA-18)" \
  "Cancellation missing"
log ""

# TEST-25: Bounded retry exists
log "--- TEST-25: Bounded retry exists ---"
run_check "TEST-25: Bounded retry exists" \
  "grep -q \"Retry\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"bounded\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i && grep -q \"INV-EA-20\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-15\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Bounded retry exists found (Retry bounded, INV-EA-20, EA-15)" \
  "Bounded retry missing"
log ""

# TEST-26: Idempotency exists
log "--- TEST-26: Idempotency exists ---"
run_check "TEST-26: Idempotency exists" \
  "grep -q \"idempotency_key\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Idempotency\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"replay\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i" \
  "Idempotency exists found (idempotency_key, Idempotency, replay)" \
  "Idempotency missing"
log ""

# TEST-27: No secret logging
log "--- TEST-27: No secret logging ---"
run_check "TEST-27: No secret logging" \
  "grep -q \"SECRET_REFERENCE\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"no.*SECRET_VALUE\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i && grep -q \"EA-16\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Secrets not logged\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "No secret logging found (SECRET_REFERENCE, no SECRET_VALUE, EA-16)" \
  "No secret logging missing"
log ""

# TEST-28: Execution success != verification
log "--- TEST-28: Execution success != verification ---"
run_check "TEST-28: Execution success != verification" \
  "grep -q \"INV-EA-17\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Execution success.*!=.*Verification\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-17\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"SUCCEEDED.*!=.*VERIFIED\\|SUCCEEDED.*not.*VERIFIED\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i" \
  "Execution success != verification found (INV-EA-17, EA-17, SUCCEEDED≠VERIFIED)" \
  "Execution success != verification missing"
log ""

# TEST-29: Evidence required
log "--- TEST-29: Evidence required ---"
run_check "TEST-29: Evidence required" \
  "grep -q \"INV-EA-12\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Missing Evidence Requirement\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-18\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Evidence required\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Evidence required found (INV-EA-12, EA-18)" \
  "Evidence required missing"
log ""

# TEST-30: Production side effects require stronger auth
log "--- TEST-30: Production side effects require stronger auth ---"
run_check "TEST-30: Production side effects require stronger auth" \
  "grep -q \"EA-19\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Production side effects require stronger authorization\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"PRODUCTION_SIDE_EFFECT\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Production side effects require stronger auth found (EA-19, PRODUCTION_SIDE_EFFECT)" \
  "Production side effects auth missing"
log ""

# TEST-31: Executor cannot authorize itself
log "--- TEST-31: Executor cannot authorize itself ---"
run_check "TEST-31: Executor cannot authorize itself" \
  "grep -q \"Verifier cannot authorize execution\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"INV-EA-16\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"hook cannot authorize\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" -i" \
  "Executor cannot authorize itself found (INV-EA-16, hook cannot authorize)" \
  "Executor cannot authorize missing"
log ""

# TEST-32: Executor cannot modify policy
log "--- TEST-32: Executor cannot modify policy ---"
run_check "TEST-32: Executor cannot modify policy" \
  "grep -q \"INV-EA-14\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"Executor cannot modify Policy\" \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"EA-20\" \"$ROOT_DIR/docs/contracts/execution-authority.md\"" \
  "Executor cannot modify policy found (INV-EA-14, EA-20)" \
  "Executor cannot modify policy missing"
log ""

# TEST-33: ADR 0008 exists
log "--- TEST-33: ADR 0008 exists ---"
run_check "TEST-33: ADR 0008 exists" \
  "test -f \"$ROOT_DIR/docs/architecture/adr/0008-execution-authority-contract.md\" && grep -q \"ACCEPTED\" \"$ROOT_DIR/docs/architecture/adr/0008-execution-authority-contract.md\" && grep -q \"Execution Authority\" \"$ROOT_DIR/docs/architecture/adr/0008-execution-authority-contract.md\"" \
  "ADR 0008 exists with ACCEPTED and Execution Authority" \
  "ADR 0008 missing"
log ""

# TEST-34: Architecture Freeze preserved
log "--- TEST-34: Architecture Freeze preserved ---"
run_check "TEST-34: Architecture Freeze preserved" \
  "test -f \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"Architecture Freeze\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && grep -q \"Model C\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && ! grep -qr \"P8 is obsolete\\|P8 replaced\" \"$ROOT_DIR/docs/contracts/\"" \
  "Architecture Freeze preserved, Model C, no obsolete claims" \
  "Architecture Freeze missing or contradicted"
log ""

# TEST-35: No product implementation
log "--- TEST-35: No product implementation ---"
run_check "TEST-35: No product implementation" \
  "! find \"$ROOT_DIR\" -type f \\( -name \"*.py\" -o -name \"*.js\" -o -name \"*.ts\" -o -name \"*.go\" -o -name \"*.rs\" \\) -not -path \"*/.git/*\" -not -path \"*/node_modules/*\" | grep -q \".\" && ! test -d \"$ROOT_DIR/src\" && ! test -d \"$ROOT_DIR/app\" && ! test -d \"$ROOT_DIR/api\" && ! test -d \"$ROOT_DIR/ui\" && ! test -d \"$ROOT_DIR/runtime\" && ! test -d \"$ROOT_DIR/executor\"" \
  "No product implementation found (only docs and shell scripts)" \
  "Product implementation found (should be contracts only)"
log ""

# TEST-36: No package installation
log "--- TEST-36: No package installation ---"
run_check "TEST-36: No package installation" \
  "! grep -R -n -E '^\\s*apt-get install|^\\s*apt install' \"$ROOT_DIR/docs/contracts\" 2>/dev/null | grep -v \"No \" | grep -q \".\"" \
  "No apt install in contracts docs (repository-only)" \
  "Found apt install in contracts docs (should be repository-only)"
log ""

log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All $PASSED/$TOTAL execution authority tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED failed out of $TOTAL"
  exit 1
fi
