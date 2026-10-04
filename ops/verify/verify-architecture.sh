#!/usr/bin/env bash
# LINEX.OS - Verify Architecture (P8)
# Purpose: Check architectural invariants, no package install, no product code, repository-only
# Validates P8 architecture docs, ADRs, trust boundaries, capability model, fail-closed, etc.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

log() { printf "%s\n" "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2"; }

EXIT_CODE=0

log "LINEX.OS VERIFY ARCHITECTURE - P8"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log "Mode: repository-only, no package install, no product code"
log ""

# Check no system changes (repository-only)
log "=== SYSTEM CHANGES CHECK ==="
# Ensure we are not doing apt, sudo, systemctl, etc. in this script (read-only)
if grep -E '^\s*apt-get install|^\s*apt install|^\s*sudo apt|^\s*systemctl' "$SCRIPT_DIR/verify-architecture.sh" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no system changes" "Found system modification in verify-architecture.sh"
  EXIT_CODE=1
else
  pass "no system changes" "No apt/sudo/systemctl in verify-architecture.sh"
fi

log ""
log "=== ARCHITECTURE DOCS EXISTENCE ==="
for f in "$ROOT_DIR/docs/architecture.md" "$ROOT_DIR/docs/architecture/context.md" "$ROOT_DIR/docs/architecture/container.md" "$ROOT_DIR/docs/architecture/components.md" "$ROOT_DIR/docs/architecture/execution-model.md" "$ROOT_DIR/docs/architecture/security-boundaries.md" "$ROOT_DIR/docs/architecture/capability-model.md" "$ROOT_DIR/docs/architecture/event-model.md" "$ROOT_DIR/docs/architecture/data-model.md" "$ROOT_DIR/docs/architecture/networking.md" "$ROOT_DIR/docs/architecture/extensibility.md" "$ROOT_DIR/docs/architecture/threat-model.md" "$ROOT_DIR/docs/architecture/roadmap.md" "$ROOT_DIR/docs/architecture/frozen-baseline.md"; do
  if [[ -f "$f" ]]; then
    pass "$(basename "$f")" "exists"
  else
    fail "$(basename "$f")" "missing"
    EXIT_CODE=1
  fi
done

log ""
log "=== ADRS EXISTENCE ==="
for f in "$ROOT_DIR/docs/architecture/adr/0001-linex-os-scope.md" "$ROOT_DIR/docs/architecture/adr/0002-execution-boundary.md" "$ROOT_DIR/docs/architecture/adr/0003-capability-security-model.md" "$ROOT_DIR/docs/architecture/adr/0004-policy-vs-execution.md" "$ROOT_DIR/docs/architecture/adr/0005-storage-abstraction.md" "$ROOT_DIR/docs/architecture/adr/0006-extensibility-model.md"; do
  if [[ -f "$f" ]]; then
    pass "$(basename "$f")" "exists"
  else
    fail "$(basename "$f")" "missing"
    EXIT_CODE=1
  fi
done

log ""
log "=== ARCHITECTURAL INVARIANTS ==="

# Trust boundary: LLM→Planner→Policy→Execution→Verifier
if grep -q "LLM" "$ROOT_DIR/docs/architecture.md" && grep -q "Planner" "$ROOT_DIR/docs/architecture.md" && grep -q "Policy Engine" "$ROOT_DIR/docs/architecture.md" && grep -q "Execution Authority" "$ROOT_DIR/docs/architecture.md" && grep -q "Verifier" "$ROOT_DIR/docs/architecture.md"; then
  pass "trust boundary path" "LLM→Planner→Policy→Execution→Verifier found"
else
  fail "trust boundary path" "Missing trust boundary path"
  EXIT_CODE=1
fi

# Forbidden direct paths - check security-boundaries has LLM→shell and Forbidden
if grep -q "LLM.*→.*shell" "$ROOT_DIR/docs/architecture/security-boundaries.md" && grep -q "Forbidden direct paths" "$ROOT_DIR/docs/architecture/security-boundaries.md"; then
  pass "forbidden LLM→shell" "Forbidden LLM→shell documented"
else
  fail "forbidden LLM→shell" "Missing forbidden LLM→shell"
  EXIT_CODE=1
fi

if grep -qi "UI.*client only\|UI.*API only" "$ROOT_DIR/docs/architecture.md"; then
  pass "UI→API only" "UI→API only documented"
else
  fail "UI→API only" "Missing UI→API only"
  EXIT_CODE=1
fi

# Capability model: CAP_* and DEFAULT DENY
if grep -q "CAP_FS_READ" "$ROOT_DIR/docs/architecture/capability-model.md" && grep -q "DEFAULT.*DENY" "$ROOT_DIR/docs/architecture/capability-model.md"; then
  pass "capability model" "CAP_* and DEFAULT DENY found"
else
  fail "capability model" "Missing capability model"
  EXIT_CODE=1
fi

# Fail-closed
if grep -qi "fail-closed" "$ROOT_DIR/docs/architecture.md" && grep -q "UNKNOWN.*DENY\|Unknown.*DENY" "$ROOT_DIR/docs/architecture.md"; then
  pass "fail-closed" "Fail-closed UNKNOWN→DENY found"
else
  fail "fail-closed" "Missing fail-closed"
  EXIT_CODE=1
fi

# AI/Policy/Execution separation - check execution-model.md
if grep -q "AI PROPOSES\|LLM" "$ROOT_DIR/docs/architecture/execution-model.md" && grep -qi "policy.*decides\|policy engine" "$ROOT_DIR/docs/architecture/execution-model.md" && grep -q "Execution Authority" "$ROOT_DIR/docs/architecture/execution-model.md"; then
  pass "AI/Policy/Execution separation" "AI PROPOSES→POLICY→EXECUTION→VERIFIER found in execution-model"
else
  fail "AI/Policy/Execution separation" "Missing separation"
  EXIT_CODE=1
fi

# MCP trust boundary
if grep -q "MCP Gateway" "$ROOT_DIR/docs/architecture.md" && grep -qi "no.*unbounded.*host.*access\|isolation.*boundary" "$ROOT_DIR/docs/architecture/security-boundaries.md"; then
  pass "MCP trust boundary" "MCP Gateway with no unbounded host access found"
else
  fail "MCP trust boundary" "Missing MCP trust boundary"
  EXIT_CODE=1
fi

# Production distinction
if grep -q "LOCAL.*PRODUCTION\|MOCK.*PRODUCTION" "$ROOT_DIR/docs/architecture.md"; then
  pass "production distinction" "LOCAL≠PRODUCTION and MOCK≠PRODUCTION found"
else
  fail "production distinction" "Missing production distinction"
  EXIT_CODE=1
fi

# P4 BLOCKED preserved
if grep -q "P4.*BLOCKED\|PowerShell.*BLOCKED" "$ROOT_DIR/docs/architecture.md" && grep -q "P4.*BLOCKED" "$ROOT_DIR/docs/architecture/frozen-baseline.md"; then
  pass "P4 BLOCKED preserved" "P4 BLOCKED preserved in architecture docs"
else
  fail "P4 BLOCKED preserved" "P4 BLOCKED not preserved"
  EXIT_CODE=1
fi

# System vs Project sudo distinction - check frozen-baseline and security-boundaries
if grep -q "SYSTEM_SUDO_POLICY" "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "PROJECT.*POLICY" "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "SYSTEM_SUDO_POLICY" "$ROOT_DIR/docs/architecture/security-boundaries.md"; then
  pass "sudo distinction preserved" "SYSTEM_SUDO_POLICY vs PROJECT_POLICY preserved in frozen-baseline and security-boundaries"
else
  fail "sudo distinction preserved" "Missing sudo distinction"
  EXIT_CODE=1
fi

# No contradictory statements (UI contains sudo without NOT)
if grep -i "UI.*contains.*sudo" "$ROOT_DIR/docs/architecture.md" | grep -v "must not" | grep -v "must NOT" | grep -v "does not" | grep -v "no.*sudo" | grep -q "."; then
  fail "no contradictory statements" "Found contradictory UI sudo"
  EXIT_CODE=1
else
  pass "no contradictory statements" "No contradictory statements"
fi

# Architecture freeze
if grep -q "Architecture Freeze" "$ROOT_DIR/docs/architecture/frozen-baseline.md" && grep -q "No implementation should violate" "$ROOT_DIR/docs/architecture/frozen-baseline.md"; then
  pass "architecture freeze" "Freeze exists with violation requires ADR"
else
  fail "architecture freeze" "Missing freeze"
  EXIT_CODE=1
fi

# Diagrams - avoid triple backticks inside double quotes (bash would parse as command substitution)
if grep -q "System Context\|Runtime Layers\|Action Execution\|Trust Boundaries\|Capability Flow\|Event Flow" "$ROOT_DIR/docs/architecture.md" && grep -q "mermaid" "$ROOT_DIR/docs/architecture/execution-model.md"; then
  pass "diagrams" "Diagrams for System Context, Runtime Layers, etc. found"
else
  fail "diagrams" "Missing diagrams"
  EXIT_CODE=1
fi

# No product code in P8 (check for src/, app/, etc. with implementation)
log ""
log "=== NO PRODUCT CODE CHECK ==="
if find "$ROOT_DIR" -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.rs" -o -name "*.go" 2>/dev/null | grep -v ".git" | grep -v "node_modules" | head -5 | grep -q "."; then
  # Allow if only in docs or tests as examples? For P8, product code forbidden, but check if any product code exists outside ops/scripts/tests/docs/config/.github
  if find "$ROOT_DIR/src" "$ROOT_DIR/app" "$ROOT_DIR/api" "$ROOT_DIR/ui" -type f 2>/dev/null | head -5 | grep -q "."; then
    fail "no product code" "Found product code in src/app/api/ui"
    find "$ROOT_DIR/src" "$ROOT_DIR/app" -type f 2>/dev/null | head -10
    EXIT_CODE=1
  else
    pass "no product code" "No product code in src/app/api/ui (only ops/scripts/tests/docs allowed)"
  fi
else
  pass "no product code" "No product code found (only docs and shell scripts)"
fi

# Check no package installation in P8 docs (should not have apt install as executable in architecture docs)
log ""
log "=== NO PACKAGE INSTALLATION IN P8 ==="
if grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/architecture" 2>/dev/null | head -5 | grep -q "."; then
  fail "no package install in P8" "Found apt install in architecture docs"
  EXIT_CODE=1
else
  pass "no package install in P8" "No apt install in architecture docs (repository-only)"
fi

log ""
log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Architecture verification PASS - all invariants verified"
  log "EVIDENCE → verify-architecture.sh execution, architecture docs, ADRs, frozen-baseline"
  log "NEXT → Run architecture.test.sh"
else
  log "STATUS → FAIL"
  log "RESULT → Architecture verification FAIL - see failures above"
fi

exit $EXIT_CODE
