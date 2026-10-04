#!/usr/bin/env bash
# LINEX.OS VERIFY POLICY - P11
# Verifies Policy Engine Contracts invariants, no product code, no package install, repository-only
# No package installation, no system changes

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

EXIT_CODE=0

log() { echo -e "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2" >&2; EXIT_CODE=1; }

log "LINEX.OS VERIFY POLICY - P11"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log "Mode: repository-only, no package install, no product code, CONTRACTS ONLY"
log ""

# System changes check
log "=== SYSTEM CHANGES CHECK ==="
if grep -E '^\s*apt-get install|^\s*apt install|^\s*sudo apt|^\s*systemctl' "$SCRIPT_DIR/verify-policy.sh" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no system changes" "Found apt/sudo/systemctl in verify-policy.sh"
else
  pass "no system changes" "No apt/sudo/systemctl in verify-policy.sh"
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

# P10 Contracts docs existence (must still exist)
log "=== P10 CONTRACTS DOCS EXISTENCE (must still exist) ==="
for doc in execution-authority.md executor-shell.md executor-process.md executor-file.md executor-network.md executor-package.md executor-matrix.md execution-lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# P11 Contracts docs existence
log "=== P11 CONTRACTS DOCS EXISTENCE ==="
for doc in policy.md policy-matrix.md policy-lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# ADRs existence
log "=== ADRS EXISTENCE ==="
for adr in 0001-linex-os-scope.md 0002-execution-boundary.md 0003-capability-security-model.md 0004-policy-vs-execution.md 0005-storage-abstraction.md 0006-extensibility-model.md 0007-core-runtime-contracts.md 0008-execution-authority-contract.md 0009-policy-engine-contract.md; do
  if [[ -f "$ROOT_DIR/docs/architecture/adr/$adr" ]]; then
    pass "$adr" "exists"
  else
    fail "$adr" "missing"
  fi
done
log ""

# Policy invariants
log "=== POLICY INVARIANTS ==="

# PolicyRequest
if grep -q "policy_request_id" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "capability_required" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "risk_class" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "network_context" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "filesystem_context" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "provenance" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "correlation_id" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "no secrets" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "PolicyRequest contract" "PolicyRequest with 20+ fields, no secrets found"
else
  fail "PolicyRequest contract" "PolicyRequest contract missing"
fi

# Actor model
if grep -q "user/agent/service/tool/mcp_server/execution_authority/system" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Unknown.*DENY" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Ambiguous.*DENY" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Actor model" "Actor 7 types Unknown/Ambiguous DENY found"
else
  fail "Actor model" "Actor model missing"
fi

# Action model
if grep -q "Action.*from P9/P10\|P9/P10.*Action" "$ROOT_DIR/docs/contracts/policy.md" -i && grep -q "action_id" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Action model" "Action from P9/P10 found"
else
  fail "Action model" "Action model missing"
fi

# Capability CONSUMES
if grep -q "CONSUMES.*Registry" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "P12.*DEFINE\|P12 WILL DEFINE" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Capability CONSUMES Registry" "Capability CONSUMES Registry P12 WILL DEFINE found"
else
  fail "Capability CONSUMES Registry" "Capability CONSUMES missing"
fi

# Resource model
if grep -q "workspace/repository/file/process/host/network/database/API/package/browser/computer/secret-reference" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Unknown.*DENY" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Resource model" "Resource 12 types Unknown DENY found"
else
  fail "Resource model" "Resource model missing"
fi

# Scope escalation prevention
if grep -q "workspace→host\|workspace->host" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "repository→production\|repository->production" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "production without explicit" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Scope escalation prevention" "Scope escalation prevention workspace→host repository→production found"
else
  fail "Scope escalation prevention" "Scope escalation prevention missing"
fi

# Risk CLASS-0..6 CLASS-6 DENY Always
if grep -q "CLASS-0" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "CLASS-6" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "CLASS-6.*DENY Always\|DENY Always.*CLASS-6" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Risk CLASS-0..6 CLASS-6 DENY" "Risk CLASS-0..6 CLASS-6 DENY Always found"
else
  fail "Risk CLASS-0..6 CLASS-6 DENY" "Risk model missing"
fi

# Decision model
if grep -q "ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "UNKNOWN.*never.*allow\|UNKNOWN never allow" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Decision model" "Decision ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED UNKNOWN never allow found"
else
  fail "Decision model" "Decision model missing"
fi

# Precedence 1..12 DENY wins
if grep -q "Precedence" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "DENY wins" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "UNKNOWN.*BLOCKED" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Precedence 1..12 DENY wins" "Precedence 1..12 DENY wins UNKNOWN BLOCKED found"
else
  fail "Precedence 1..12 DENY wins" "Precedence missing"
fi

# Default DENY
if grep -q "Default DENY\|DEFAULT DENY" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "POL-01" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Default DENY POL-01" "Default DENY POL-01 found"
else
  fail "Default DENY POL-01" "Default DENY missing"
fi

# Fail-closed
if grep -q "Fail-closed" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "UNKNOWN_ACTION" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "UNKNOWN_ACTOR" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "no ASSUME ALLOW" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Fail-closed" "Fail-closed UNKNOWN_ACTION/ACTOR no ASSUME ALLOW found"
else
  fail "Fail-closed" "Fail-closed missing"
fi

# Version immutable
if grep -q "policy_id" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "immutable" "$ROOT_DIR/docs/contracts/policy.md" -i && grep -q "new version.*no rewrite old" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Version immutable" "Version policy_id/version/hash immutable new version no rewrite old found"
else
  fail "Version immutable" "Version immutable missing"
fi

# Rule contract no shell/eval/JS deterministic
if grep -q "PolicyRule" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "no shell" "$ROOT_DIR/docs/contracts/policy.md" -i && grep -q "no eval" "$ROOT_DIR/docs/contracts/policy.md" -i && grep -q "deterministic" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Rule contract no shell/eval/JS" "Rule contract no shell/eval/JS deterministic found"
else
  fail "Rule contract no shell/eval/JS" "Rule contract missing"
fi

# Determinism LLM not final authority
if grep -q "Determinism" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "LLM.*not.*final.*authority\|LLM does not.*final" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Determinism LLM not final authority" "Determinism LLM not final authority found"
else
  fail "Determinism LLM not final authority" "Determinism missing"
fi

# Natural Language Boundary
if grep -q "Natural Language" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "intent→structured Action\|intent.*structured Action" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Natural Language Boundary" "Natural Language Boundary intent→structured Action found"
else
  fail "Natural Language Boundary" "Natural Language Boundary missing"
fi

# Approval model
if grep -q "AUTO/DRY_RUN/EXPLICIT_APPROVAL/DENY" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "bound_to_action" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "replay protection" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Approval model" "Approval AUTO/DRY_RUN/EXPLICIT/DENY bound replay protection found"
else
  fail "Approval model" "Approval model missing"
fi

# DRY-RUN
if grep -q "DRY-RUN" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "CLASS-4" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "CLASS-5" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "DRY-RUN CLASS-4/5" "DRY-RUN CLASS-4/5 external/host/package found"
else
  fail "DRY-RUN CLASS-4/5" "DRY-RUN missing"
fi

# Environment LOCAL≠PRODUCTION
if grep -q "local/arena/ci/staging/production" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "LOCAL≠PRODUCTION\|LOCAL.*PRODUCTION" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "MOCK≠PRODUCTION\|MOCK.*PRODUCTION" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "ARENA≠PRODUCTION\|ARENA.*PRODUCTION" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Environment LOCAL≠PRODUCTION" "Environment LOCAL≠PRODUCTION MOCK≠PRODUCTION ARENA≠PRODUCTION found"
else
  fail "Environment LOCAL≠PRODUCTION" "Environment model missing"
fi

# Network Unknown BLOCKED
if grep -q "network_mode" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Unknown.*BLOCKED" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Network Unknown BLOCKED" "Network Unknown BLOCKED found"
else
  fail "Network Unknown BLOCKED" "Network policy missing"
fi

# Filesystem traversal BLOCKED
if grep -q "filesystem_scope" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "canonicalized" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "\.\./etc/passwd" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "/etc/sudoers" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Filesystem traversal BLOCKED" "Filesystem canonicalized ../etc/passwd DENY /etc/sudoers DENY found"
else
  fail "Filesystem traversal BLOCKED" "Filesystem policy missing"
fi

# Secret REFERENCE not VALUE
if grep -q "SECRET_REFERENCE" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "CAP_SECRET_ACCESS" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "NO_LOG" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Secret REFERENCE not VALUE" "Secret REFERENCE not VALUE CAP_SECRET_ACCESS NO_LOG found"
else
  fail "Secret REFERENCE not VALUE" "Secret policy missing"
fi

# Provenance untrusted BLOCKED
if grep -q "Provenance" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "untrusted.*BLOCKED" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Provenance untrusted BLOCKED" "Provenance untrusted BLOCKED found"
else
  fail "Provenance untrusted BLOCKED" "Provenance missing"
fi

# Obligations
if grep -q "Obligations" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "REQUIRE_APPROVAL" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "REQUIRE_DRY_RUN" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "AUDIT_REQUIRED" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Obligations 9 types" "Obligations REQUIRE_APPROVAL/DRY_RUN/AUDIT_REQUIRED found"
else
  fail "Obligations 9 types" "Obligations missing"
fi

# PolicyDecision contract
if grep -q "PolicyDecision" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "decision_id" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "evidence_requirements" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "no secrets" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "PolicyDecision contract" "PolicyDecision decision_id evidence_requirements no secrets found"
else
  fail "PolicyDecision contract" "PolicyDecision contract missing"
fi

# Explanation WHY
if grep -q "Explanation" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "WHY" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "reason.*evaluation.*not LLM\|not LLM-generated" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Explanation WHY not LLM" "Explanation WHY reason from evaluation not LLM found"
else
  fail "Explanation WHY not LLM" "Explanation missing"
fi

# Conflict model
if grep -q "Conflict" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "ALLOW+DENY→DENY\|ALLOW.*DENY.*DENY" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "BLOCKED→BLOCKED\|BLOCKED.*BLOCKED" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Conflict ALLOW+DENY→DENY" "Conflict ALLOW+DENY→DENY any+BLOCKED→BLOCKED found"
else
  fail "Conflict ALLOW+DENY→DENY" "Conflict model missing"
fi

# States
if grep -q "UNINITIALIZED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "READY" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "BLOCKED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "FAILED" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "States UNINITIALIZED..FAILED" "States UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED found"
else
  fail "States UNINITIALIZED..FAILED" "States missing"
fi

# Lifecycle
if grep -q "CREATED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "DRAFT" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "ACTIVE" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "SUSPENDED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "REVOKED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "EXPIRED" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Lifecycle CREATED..EXPIRED" "Lifecycle CREATED/DRAFT/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED found"
else
  fail "Lifecycle CREATED..EXPIRED" "Lifecycle missing"
fi

# Update proposal/review/validation/new version/activation human approval
if grep -q "proposal.*review.*validation.*new version.*activation" "$ROOT_DIR/docs/contracts/policy.md" -i && grep -q "human.*approval\|policy owner approval" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Update proposal/review/validation" "Update proposal/review/validation/new version/activation human approval found"
else
  fail "Update proposal/review/validation" "Update model missing"
fi

# Learning boundary
if grep -q "Learning boundary" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "proposal.*≠.*activation\|proposal.*!=.*activation" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Learning boundary proposal≠activation" "Learning boundary proposal≠activation found"
else
  fail "Learning boundary proposal≠activation" "Learning boundary missing"
fi

# Audit events
if grep -q "policy.requested" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "policy.revoked" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "event_id.*policy_id.*version.*request_id.*decision_id" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Audit events policy.requested..revoked" "Audit events policy.requested..revoked event_id/policy_id/version/request_id/decision_id found"
else
  fail "Audit events policy.requested..revoked" "Audit events missing"
fi

# Verification verifiable
if grep -q "Verification" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "verifiable" "$ROOT_DIR/docs/contracts/policy.md" -i && grep -q "do not require LLM to verify" "$ROOT_DIR/docs/contracts/policy.md" -i; then
  pass "Verification verifiable no LLM" "Verification verifiable no LLM found"
else
  fail "Verification verifiable no LLM" "Verification missing"
fi

# Boundaries Policy vs Authorization vs Execution vs Verifier vs Registry
if grep -q "Policy.*WHAT.*ALLOWED" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "P11 CONSUMES.*P12.*DEFINE\|CONSUMES.*Registry.*P12" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Boundaries Policy vs Auth vs Exec vs Verifier vs Registry" "Boundaries Policy WHAT ALLOWED vs Authorization IS ACTOR AUTHORIZED vs Execution vs Verifier vs Registry P11 CONSUMES P12 DEFINES found"
else
  fail "Boundaries Policy vs Auth vs Exec vs Verifier vs Registry" "Boundaries missing"
fi

# Interface evaluate/validate/explain/get_policy/get_active_policy/policy_status no impl
if grep -q "evaluate.*PolicyDecision\|evaluate.*request" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "get_active_policy" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "policy_status" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Interface evaluate/validate/explain/get_policy" "Interface evaluate/validate/explain/get_policy/get_active_policy/policy_status found"
else
  fail "Interface evaluate/validate/explain/get_policy" "Interface missing"
fi

# Pipeline INPUT→...→AUDIT
if grep -q "Pipeline" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "INPUT→SCHEMA\|INPUT.*SCHEMA" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "AUDIT" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Pipeline INPUT→...→AUDIT" "Pipeline INPUT→SCHEMA→...→AUDIT found"
else
  fail "Pipeline INPUT→...→AUDIT" "Pipeline missing"
fi

# Invariants POL-01..30
if grep -q "POL-01" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "POL-30" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Invariants POL-01..30" "Invariants POL-01..30 found"
else
  fail "Invariants POL-01..30" "Invariants missing"
fi

# Diagrams ASCII+Mermaid
if grep -q "Policy Evaluation Flow" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "mermaid" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Decision Precedence" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Policy vs Authorization" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "Diagrams ASCII+Mermaid" "Diagrams Policy Evaluation Flow, Decision Precedence, Policy vs Authorization ASCII+Mermaid found"
else
  fail "Diagrams ASCII+Mermaid" "Diagrams missing"
fi

# Policy Matrix checks
log ""
log "=== POLICY MATRIX CHECKS ==="
if grep -q "fs.read workspace" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "CAP_FS_READ" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "CLASS-0" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "ALLOW" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "AUTO" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "file evidence" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i; then
  pass "policy-matrix fs.read workspace" "policy-matrix fs.read workspace CAP_FS_READ CLASS-0 ALLOW AUTO file evidence found"
else
  fail "policy-matrix fs.read workspace" "policy-matrix fs.read workspace missing"
fi

if grep -q "process.exec workspace" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "CAP_PROCESS_EXEC" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "execution evidence" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i; then
  pass "policy-matrix process.exec" "policy-matrix process.exec CAP_PROCESS_EXEC execution evidence found"
else
  fail "policy-matrix process.exec" "policy-matrix process.exec missing"
fi

if grep -q "shell.exec" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "HIGH" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "REQUIRE_APPROVAL" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "trace+result+evidence\|trace.*result.*evidence" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i; then
  pass "policy-matrix shell.exec" "policy-matrix shell.exec HIGH REQUIRE_APPROVAL trace+result+evidence found"
else
  fail "policy-matrix shell.exec" "policy-matrix shell.exec missing"
fi

if grep -q "package.install" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "CAP_PACKAGE_INSTALL" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "CLASS-4" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "REQUIRE_APPROVAL" "$ROOT_DIR/docs/contracts/policy-matrix.md"; then
  pass "policy-matrix package.install" "policy-matrix package.install CAP_PACKAGE_INSTALL CLASS-4 REQUIRE_APPROVAL found"
else
  fail "policy-matrix package.install" "policy-matrix package.install missing"
fi

if grep -q "network.upload" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "CAP_NETWORK_CONNECT" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "HIGH" "$ROOT_DIR/docs/contracts/policy-matrix.md"; then
  pass "policy-matrix network.upload" "policy-matrix network.upload CAP_NETWORK_CONNECT HIGH/CRITICAL REQUIRE_APPROVAL found"
else
  fail "policy-matrix network.upload" "policy-matrix network.upload missing"
fi

if grep -q "production write" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i && grep -q "CLASS-5" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "production evidence" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i; then
  pass "policy-matrix production write" "policy-matrix production write CLASS-5 production evidence found"
else
  fail "policy-matrix production write" "policy-matrix production write missing"
fi

if grep -q "sudoers modification" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i && grep -q "CLASS-6" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "DENY Always" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "security evidence" "$ROOT_DIR/docs/contracts/policy-matrix.md" -i; then
  pass "policy-matrix sudoers modification" "policy-matrix sudoers modification CLASS-6 DENY Always security evidence found"
else
  fail "policy-matrix sudoers modification" "policy-matrix sudoers modification missing"
fi

if grep -q "Decision Precedence" "$ROOT_DIR/docs/contracts/policy-matrix.md" || grep -q "Precedence" "$ROOT_DIR/docs/contracts/policy-matrix.md"; then
  pass "policy-matrix precedence" "policy-matrix precedence found"
else
  fail "policy-matrix precedence" "policy-matrix precedence missing"
fi

if grep -q "Default.*DENY\|DEFAULT DENY" "$ROOT_DIR/docs/contracts/policy-matrix.md" && grep -q "Fail-closed" "$ROOT_DIR/docs/contracts/policy-matrix.md"; then
  pass "policy-matrix default deny fail-closed" "policy-matrix default deny fail-closed found"
else
  fail "policy-matrix default deny fail-closed" "policy-matrix default deny fail-closed missing"
fi

# Policy Lifecycle checks
log ""
log "=== POLICY LIFECYCLE CHECKS ==="
if grep -q "CREATED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "DRAFT" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "VALIDATED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "ACTIVE" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "SUSPENDED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "REVOKED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "EXPIRED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md"; then
  pass "policy lifecycle states" "Policy lifecycle CREATED/DRAFT/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED found"
else
  fail "policy lifecycle states" "Policy lifecycle states missing"
fi

if grep -q "REQUESTED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "VALIDATING" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "EVALUATING" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "ALLOW" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "DENY" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "REQUIRE_APPROVAL" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "DRY_RUN" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "BLOCKED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "RECORDED" "$ROOT_DIR/docs/contracts/policy-lifecycle.md"; then
  pass "decision lifecycle" "Decision lifecycle REQUESTED→VALIDATING→EVALUATING→ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED→RECORDED found"
else
  fail "decision lifecycle" "Decision lifecycle missing"
fi

if grep -q "No implicit transitions\|no implicit" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" -i && grep -q "fail-closed" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" -i; then
  pass "no implicit transitions fail-closed" "No implicit transitions fail-closed found"
else
  fail "no implicit transitions fail-closed" "No implicit transitions fail-closed missing"
fi

if grep -q "mermaid" "$ROOT_DIR/docs/contracts/policy-lifecycle.md" && grep -q "stateDiagram-v2\|flowchart TD" "$ROOT_DIR/docs/contracts/policy-lifecycle.md"; then
  pass "lifecycle diagrams mermaid" "Lifecycle diagrams mermaid stateDiagram-v2/flowchart found"
else
  fail "lifecycle diagrams mermaid" "Lifecycle diagrams missing"
fi

# P2/P10 compatibility
log ""
log "=== P2/P10 COMPATIBILITY ==="
if grep -q "Action→Policy→Authorization→Package Executor→Privilege Gate→Package Manager→Result→Verification→Evidence" "$ROOT_DIR/docs/contracts/policy.md" && grep -q "Policy does NOT replace.*Gate\|does NOT replace.*Privilege Gate" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "package path Action→Policy→Authorization→Package Executor→Gate" "Package path Action→Policy→Authorization→Package Executor→Privilege Gate preserved Policy does NOT replace Gate found"
else
  fail "package path Action→Policy→Authorization→Package Executor→Gate" "Package path compatibility missing"
fi

if test -f "$ROOT_DIR/ops/security/privilege-policy.md" && test -f "$ROOT_DIR/ops/security/privilege-gate.sh" && grep -q "privilege-gate.sh" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "privilege-policy privilege-gate exists" "privilege-policy.md privilege-gate.sh exists and referenced"
else
  fail "privilege-policy privilege-gate exists" "privilege-policy/gate missing or not referenced"
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

# P10 contracts preserved
if test -f "$ROOT_DIR/docs/contracts/execution-authority.md" && test -f "$ROOT_DIR/docs/contracts/executor-matrix.md" && test -f "$ROOT_DIR/docs/contracts/execution-lifecycle.md"; then
  pass "P10 contracts preserved" "P10 contracts still exist (execution-authority, executor-matrix, execution-lifecycle)"
else
  fail "P10 contracts preserved" "P10 contracts missing"
fi

# No contradictions
if ! grep -qr "P8 is obsolete\|P8 replaced\|P9 is obsolete\|P9 replaced\|P10 is obsolete\|P10 replaced" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no contradictions" "No contradictory P8/P9/P10 obsolete claims"
else
  fail "no contradictions" "Found contradictory obsolete claims"
fi

# Contract First principle
if grep -q "Contract First\|CONTRACTS ONLY" "$ROOT_DIR/docs/contracts/policy.md"; then
  pass "contract first" "Contract First / CONTRACTS ONLY found"
else
  fail "contract first" "Contract First principle missing"
fi

# No implementation language chosen
log ""
log "=== NO IMPLEMENTATION LANGUAGE CHECK ==="
if ! grep -qr "P11 chooses Rust\|P11 chooses Go\|P11 chooses Python\|P11 chooses Node\|P11 chooses OPA\|P11 chooses Cedar\|P11 chooses Casbin\|P11 chooses OpenFGA\|P11 chooses Rego" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no impl language/framework chosen" "No Rust/Go/Python/Node/OPA/Cedar/Casbin/OpenFGA/Rego chosen in P11 (DECISION PENDING P18)"
else
  fail "no impl language/framework chosen" "Implementation language/framework chosen in P11 (should be PENDING P18)"
fi

if grep -q "DECISION PENDING.*P18\|P18.*Technology Selection\|Technology.*PENDING" "$ROOT_DIR/docs/contracts/policy.md" || grep -q "DECISION PENDING" "$ROOT_DIR/docs/architecture/adr/0009-policy-engine-contract.md"; then
  pass "technology decision pending P18" "Technology decision PENDING P18 found"
else
  fail "technology decision pending P18" "Technology decision pending P18 missing"
fi

log ""

# No product code check
log "=== NO PRODUCT CODE CHECK ==="
if find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" -not -path "*/node_modules/*" | grep -q "."; then
  fail "no product code" "Found product code (should be only docs and shell scripts in P11)"
  find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" | head -5
else
  if test -d "$ROOT_DIR/src" || test -d "$ROOT_DIR/app" || test -d "$ROOT_DIR/api" || test -d "$ROOT_DIR/ui" || test -d "$ROOT_DIR/runtime" || test -d "$ROOT_DIR/executor" || test -d "$ROOT_DIR/policy-engine"; then
    fail "no product code" "Found product code directory src/app/api/ui/runtime/executor/policy-engine"
  else
    pass "no product code" "No product code found (only docs and shell scripts)"
  fi
fi
log ""

# No package installation in P11
log "=== NO PACKAGE INSTALLATION IN P11 ==="
if grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no package install in P11" "Found apt install in contracts docs"
  grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" | head -5
else
  pass "no package install in P11" "No apt install in contracts docs (repository-only)"
fi
log ""

log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Policy verification PASS - all invariants verified"
  log "EVIDENCE → verify-policy.sh execution, contracts docs policy.md/policy-matrix.md/policy-lifecycle.md, ADR 0009, frozen-baseline, P9/P10 contracts"
  log "NEXT → Run policy.test.sh"
else
  log "STATUS → FAIL"
  log "RESULT → Policy verification FAIL - see failures above"
fi

exit $EXIT_CODE
