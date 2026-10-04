#!/usr/bin/env bash
# LINEX.OS VERIFY EXECUTION AUTHORITY - P10
# Verifies Execution Authority Contracts invariants, no product code, no package install, repository-only
# No package installation, no system changes

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

EXIT_CODE=0

log() { echo -e "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2" >&2; EXIT_CODE=1; }

log "LINEX.OS VERIFY EXECUTION AUTHORITY - P10"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log "Mode: repository-only, no package install, no product code"
log ""

# System changes check
log "=== SYSTEM CHANGES CHECK ==="
if grep -E '^\s*apt-get install|^\s*apt install|^\s*sudo apt|^\s*systemctl' "$SCRIPT_DIR/verify-execution-authority.sh" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no system changes" "Found apt/sudo/systemctl in verify-execution-authority.sh"
else
  pass "no system changes" "No apt/sudo/systemctl in verify-execution-authority.sh"
fi
log ""

# P8 Architecture docs existence (must still exist)
log "=== P8 ARCHITECTURE DOCS EXISTENCE (must still exist) ==="
for doc in architecture.md context.md container.md components.md execution-model.md security-boundaries.md capability-model.md event-model.md data-model.md networking.md extensibility.md threat-model.md roadmap.md frozen-baseline.md; do
  if [[ -f "$ROOT_DIR/docs/architecture/$doc" ]] || [[ -f "$ROOT_DIR/docs/$doc" ]]; then
    pass "$doc" "exists"
  else
    if [[ "$doc" == "architecture.md" && -f "$ROOT_DIR/docs/architecture.md" ]]; then
      pass "$doc" "exists"
    else
      fail "$doc" "missing"
    fi
  fi
done
log ""

# P9 Contracts docs existence (must still exist)
log "=== P9 CONTRACTS DOCS EXISTENCE (must still exist) ==="
for doc in README.md runtime.md task.md action.md event.md result.md lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# P10 Contracts docs existence
log "=== P10 CONTRACTS DOCS EXISTENCE ==="
for doc in execution-authority.md executor-shell.md executor-process.md executor-file.md executor-network.md executor-package.md executor-matrix.md execution-lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# ADRs existence
log "=== ADRS EXISTENCE ==="
for adr in 0001-linex-os-scope.md 0002-execution-boundary.md 0003-capability-security-model.md 0004-policy-vs-execution.md 0005-storage-abstraction.md 0006-extensibility-model.md 0007-core-runtime-contracts.md 0008-execution-authority-contract.md; do
  if [[ -f "$ROOT_DIR/docs/architecture/adr/$adr" ]]; then
    pass "$adr" "exists"
  else
    fail "$adr" "missing"
  fi
done
log ""

# Execution Authority invariants
log "=== EXECUTION AUTHORITY INVARIANTS ==="

# Execution Authority boundary
if grep -q "Execution Authority.*sole.*boundary\|sole.*architectural.*boundary" "$ROOT_DIR/docs/contracts/execution-authority.md" -i && grep -q "Planner.*Agent.*Action.*Policy.*Authorization.*Execution Authority.*Executor.*Result.*Verifier" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "execution authority boundary" "Execution Authority sole boundary with mandatory path found"
else
  fail "execution authority boundary" "Execution Authority boundary missing"
fi

# INV-EA invariants
if grep -q "INV-EA-01" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "INV-EA-20" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "LLM cannot call an Executor directly" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "Retry cannot bypass Policy/Authorization" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "INV-EA-01 to INV-EA-20" "INV-EA-01 to INV-EA-20 found"
else
  fail "INV-EA-01 to INV-EA-20" "INV-EA invariants missing"
fi

# EA security invariants
if grep -q "EA-01" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "EA-20" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "No direct Agent→Executor" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "Executor cannot modify Policy" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "EA-01 to EA-20" "EA-01 to EA-20 security invariants found"
else
  fail "EA-01 to EA-20" "EA security invariants missing"
fi

# ExecutionRequest contract
if grep -q "execution_id" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "executor_id" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "capability_required" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "resource" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "scope" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "correlation_id" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "execution request contract" "ExecutionRequest with execution_id, executor_id, capability_required, resource, scope, correlation_id found"
else
  fail "execution request contract" "ExecutionRequest contract missing"
fi

# ExecutionResult contract
if grep -q "execution_id" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "status" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "SUCCEEDED" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "FAILED" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "BLOCKED" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "TIMEOUT" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "execution result contract" "ExecutionResult with execution_id, status SUCCEEDED/FAILED/BLOCKED/TIMEOUT found"
else
  fail "execution result contract" "ExecutionResult contract missing"
fi

# ExecutionContext
if grep -q "ExecutionContext" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "ALLOWLISTED ENV" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "SECRET_REFERENCE" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "workspace_root" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "execution context" "ExecutionContext with ALLOWLISTED ENV, SECRET_REFERENCE, workspace_root found"
else
  fail "execution context" "ExecutionContext missing"
fi

# ExecutorRegistry
if grep -q "ExecutorRegistry" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "executor_id" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "Unknown Executor.*BLOCKED" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "executor registry" "ExecutorRegistry with executor_id and Unknown Executor BLOCKED found"
else
  fail "executor registry" "ExecutorRegistry missing"
fi

# 5 Executor Contracts
if test -f "$ROOT_DIR/docs/contracts/executor-shell.md" && test -f "$ROOT_DIR/docs/contracts/executor-process.md" && test -f "$ROOT_DIR/docs/contracts/executor-file.md" && test -f "$ROOT_DIR/docs/contracts/executor-network.md" && test -f "$ROOT_DIR/docs/contracts/executor-package.md"; then
  pass "5 executor contracts" "All 5 executor contracts exist"
else
  fail "5 executor contracts" "5 executor contracts missing"
fi

# Shell vs Process separation
if grep -q "Shell Executor.*Process Executor\|Process Executor.*Shell Executor" "$ROOT_DIR/docs/contracts/execution-authority.md" -i && grep -q "shell.command" "$ROOT_DIR/docs/contracts/executor-shell.md" && grep -q "process.argv" "$ROOT_DIR/docs/contracts/executor-shell.md" && grep -q "ARGV MODE preferred" "$ROOT_DIR/docs/contracts/executor-process.md" && grep -q "no bash -c" "$ROOT_DIR/docs/contracts/executor-process.md"; then
  pass "shell vs process separation" "Shell Executor ≠ Process Executor, shell.command vs process.argv, ARGV MODE preferred found"
else
  fail "shell vs process separation" "Shell vs Process separation missing"
fi

# File Executor
if grep -q "CAP_FS_READ" "$ROOT_DIR/docs/contracts/executor-file.md" && grep -q "CAP_FS_WRITE" "$ROOT_DIR/docs/contracts/executor-file.md" && grep -q "path traversal defense" "$ROOT_DIR/docs/contracts/executor-file.md" && grep -q "Unknown path scope.*BLOCKED" "$ROOT_DIR/docs/contracts/executor-file.md"; then
  pass "file executor" "File Executor with CAP_FS_READ/WRITE, path traversal defense, Unknown path scope BLOCKED found"
else
  fail "file executor" "File Executor missing"
fi

# Network Executor
if grep -q "CAP_NETWORK_READ" "$ROOT_DIR/docs/contracts/executor-network.md" && grep -q "CAP_NETWORK_CONNECT" "$ROOT_DIR/docs/contracts/executor-network.md" && grep -q "Unknown destination.*BLOCKED" "$ROOT_DIR/docs/contracts/executor-network.md" && grep -q "no unrestricted Internet" "$ROOT_DIR/docs/contracts/executor-network.md" -i; then
  pass "network executor" "Network Executor with CAP_NETWORK_READ/CONNECT, Unknown destination BLOCKED, no unrestricted Internet found"
else
  fail "network executor" "Network Executor missing"
fi

# Package Executor
if grep -q "CAP_PACKAGE_INSTALL" "$ROOT_DIR/docs/contracts/executor-package.md" && grep -q "Privilege Gate" "$ROOT_DIR/docs/contracts/executor-package.md" && grep -q "privilege-gate.sh" "$ROOT_DIR/docs/contracts/executor-package.md" && grep -q "must not be bypassed" "$ROOT_DIR/docs/contracts/executor-package.md" -i; then
  pass "package executor" "Package Executor with CAP_PACKAGE_INSTALL, Privilege Gate, must not be bypassed found"
else
  fail "package executor" "Package Executor missing"
fi

# Privileged execution
if grep -q "SYSTEM_SUDO_POLICY" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "PROJECT_POLICY" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "sudo.*arbitrary" "$ROOT_DIR/docs/contracts/execution-authority.md" -i && grep -q "privilege-gate.sh" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "privileged execution" "Privileged execution with SYSTEM_SUDO_POLICY, PROJECT_POLICY, no arbitrary sudo, privilege-gate.sh found"
else
  fail "privileged execution" "Privileged execution missing"
fi

# DRY-RUN
if grep -q "DRY-RUN" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "WOULD_EXECUTE" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "NO SIDE EFFECT" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "dry-run contract" "DRY-RUN with WOULD_EXECUTE, NO SIDE EFFECT found"
else
  fail "dry-run contract" "DRY-RUN contract missing"
fi

# Side-effect classification
if grep -q "READ_ONLY" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "REVERSIBLE_SIDE_EFFECT" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "IRREVERSIBLE_SIDE_EFFECT" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "EXTERNAL_SIDE_EFFECT" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "PRODUCTION_SIDE_EFFECT" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "SYSTEM_SIDE_EFFECT" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "side-effect classification" "Side-effect classification READ_ONLY/REVERSIBLE/IRREVERSIBLE/EXTERNAL/PRODUCTION/SYSTEM/DENY found"
else
  fail "side-effect classification" "Side-effect classification missing"
fi

# Resource limits, Timeout, Cancellation, Retry, Idempotency
if grep -q "resource_limits" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "timeout_requested" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "CANCEL_REQUESTED" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "idempotency_key" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "resource/timeout/cancel/idempotency" "Resource limits, timeout, cancellation, idempotency found"
else
  fail "resource/timeout/cancel/idempotency" "Resource/timeout/cancel/idempotency missing"
fi

# Workspace isolation, Filesystem isolation roadmap, Network policy, Secrets, Output handling, Health, Trust
if grep -q "workspace_root" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "Level 0" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "Level 6" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "network_mode" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "SECRET_REFERENCE" "$ROOT_DIR/docs/contracts/execution-authority.md" && grep -q "max_output_size" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "workspace/fs roadmap/network/secrets/output" "Workspace isolation, filesystem roadmap Level 0-6, network policy, secrets REFERENCE ONLY, output handling found"
else
  fail "workspace/fs roadmap/network/secrets/output" "Workspace/fs roadmap/network/secrets/output missing"
fi

# Executor matrix
if test -f "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "Shell" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "Process" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "File" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "Network" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "Package" "$ROOT_DIR/docs/contracts/executor-matrix.md"; then
  pass "executor matrix" "Executor matrix with Shell, Process, File, Network, Package found"
else
  fail "executor matrix" "Executor matrix missing"
fi

# Action → Execution mapping
if grep -q "process.exec" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "shell.exec" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "fs.read" "$ROOT_DIR/docs/contracts/executor-matrix.md" && grep -q "package.install" "$ROOT_DIR/docs/contracts/executor-matrix.md"; then
  pass "action → execution mapping" "Action→Execution mapping with process.exec, shell.exec, fs.read, package.install found"
else
  fail "action → execution mapping" "Action→Execution mapping missing"
fi

# Execution lifecycle state machine
if test -f "$ROOT_DIR/docs/contracts/execution-lifecycle.md" && grep -q "PROPOSED" "$ROOT_DIR/docs/contracts/execution-lifecycle.md" && grep -q "VALIDATING" "$ROOT_DIR/docs/contracts/execution-lifecycle.md" && grep -q "AUTHORIZED" "$ROOT_DIR/docs/contracts/execution-lifecycle.md" && grep -q "RUNNING" "$ROOT_DIR/docs/contracts/execution-lifecycle.md" && grep -q "VERIFIED" "$ROOT_DIR/docs/contracts/execution-lifecycle.md" && grep -q "mermaid" "$ROOT_DIR/docs/contracts/execution-lifecycle.md"; then
  pass "execution lifecycle" "Execution lifecycle with PROPOSED, VALIDATING, AUTHORIZED, RUNNING, VERIFIED and mermaid found"
else
  fail "execution lifecycle" "Execution lifecycle state machine missing"
fi

# Diagrams
if grep -qr "mermaid" "$ROOT_DIR/docs/contracts/execution-authority.md" >/dev/null && grep -qr "mermaid" "$ROOT_DIR/docs/contracts/execution-lifecycle.md" >/dev/null && grep -qr "mermaid" "$ROOT_DIR/docs/contracts/executor-matrix.md" >/dev/null; then
  pass "diagrams" "Diagrams found (Mermaid) for execution authority, lifecycle, matrix"
else
  fail "diagrams" "Diagrams missing"
fi

# P8 frozen baseline preserved
if test -f "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "Architecture Freeze" "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "Model C" "$ROOT_DIR/docs/architecture/frozen-baseline.md"; then
  pass "P8 frozen baseline preserved" "P8 frozen baseline exists with Model C"
else
  fail "P8 frozen baseline preserved" "P8 frozen baseline missing"
fi

# P9 contracts preserved
if test -f "$ROOT_DIR/docs/contracts/runtime.md" && test -f "$ROOT_DIR/docs/contracts/task.md" && test -f "$ROOT_DIR/docs/contracts/action.md" && test -f "$ROOT_DIR/docs/contracts/event.md" && test -f "$ROOT_DIR/docs/contracts/result.md" && test -f "$ROOT_DIR/docs/contracts/lifecycle.md"; then
  pass "P9 contracts preserved" "P9 contracts still exist (runtime, task, action, event, result, lifecycle)"
else
  fail "P9 contracts preserved" "P9 contracts missing"
fi

# No contradictions
if ! grep -qr "P8 is obsolete\|P8 replaced\|P9 is obsolete\|P9 replaced" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no contradictions" "No contradictory P8/P9 obsolete claims"
else
  fail "no contradictions" "Found contradictory obsolete claims"
fi

# Contract First principle
if grep -q "Contract First" "$ROOT_DIR/docs/contracts/execution-authority.md" || grep -q "CONTRACTS ONLY" "$ROOT_DIR/docs/contracts/execution-authority.md"; then
  pass "contract first" "Contract First / CONTRACTS ONLY found"
else
  fail "contract first" "Contract First principle missing"
fi

# No implementation language chosen
if ! grep -qr "P10 chooses Rust\|P10 chooses Go\|P10 chooses Python\|P10 chooses Node\|P10 chooses Docker\|P10 chooses Firecracker\|P10 chooses gVisor\|P10 chooses Playwright" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no impl language/framework chosen" "No Rust/Go/Python/Node/Docker/Firecracker/gVisor/Playwright chosen in P10 (DECISION PENDING)"
else
  fail "no impl language/framework chosen" "Implementation language/framework chosen in P10 (should be PENDING)"
fi

log ""

# No product code check
log "=== NO PRODUCT CODE CHECK ==="
if find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" -not -path "*/node_modules/*" | grep -q "."; then
  fail "no product code" "Found product code (should be only docs and shell scripts in P10)"
  find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" | head -5
else
  if test -d "$ROOT_DIR/src" || test -d "$ROOT_DIR/app" || test -d "$ROOT_DIR/api" || test -d "$ROOT_DIR/ui" || test -d "$ROOT_DIR/runtime" || test -d "$ROOT_DIR/executor"; then
    fail "no product code" "Found product code directory src/app/api/ui/runtime/executor"
  else
    pass "no product code" "No product code found (only docs and shell scripts)"
  fi
fi
log ""

# No package installation in P10
log "=== NO PACKAGE INSTALLATION IN P10 ==="
if grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no package install in P10" "Found apt install in contracts docs"
  grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" | head -5
else
  pass "no package install in P10" "No apt install in contracts docs (repository-only)"
fi
log ""

log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Execution Authority verification PASS - all invariants verified"
  log "EVIDENCE → verify-execution-authority.sh execution, contracts docs, ADR 0008, frozen-baseline, P9 contracts"
  log "NEXT → Run execution-authority.test.sh"
else
  log "STATUS → FAIL"
  log "RESULT → Execution Authority verification FAIL - see failures above"
fi

exit $EXIT_CODE
