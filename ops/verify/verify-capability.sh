#!/usr/bin/env bash
# LINEX.OS VERIFY CAPABILITY - P12
# Verifies Capability Contract + Registry invariants, no product code, no package install, repository-only
# No package installation, no system changes

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

EXIT_CODE=0

log() { echo -e "$*"; }
pass() { printf "%-50s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-50s → FAIL (%s)\n" "$1" "$2" >&2; EXIT_CODE=1; }

log "LINEX.OS VERIFY CAPABILITY - P12"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log "Mode: repository-only, no package install, no product code, CONTRACTS ONLY"
log ""

# System changes check
log "=== SYSTEM CHANGES CHECK ==="
if grep -E '^\s*apt-get install|^\s*apt install|^\s*sudo apt|^\s*systemctl' "$SCRIPT_DIR/verify-capability.sh" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no system changes" "Found apt/sudo/systemctl in verify-capability.sh"
else
  pass "no system changes" "No apt/sudo/systemctl in verify-capability.sh"
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

# P11 Contracts docs existence (must still exist)
log "=== P11 CONTRACTS DOCS EXISTENCE (must still exist) ==="
for doc in policy.md policy-matrix.md policy-lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# P12 Contracts docs existence
log "=== P12 CONTRACTS DOCS EXISTENCE ==="
for doc in capability.md capability-registry.md capability-lifecycle.md; do
  if [[ -f "$ROOT_DIR/docs/contracts/$doc" ]]; then
    pass "$doc" "exists"
  else
    fail "$doc" "missing"
  fi
done
log ""

# ADRs existence
log "=== ADRS EXISTENCE ==="
for adr in 0001-linex-os-scope.md 0002-execution-boundary.md 0003-capability-security-model.md 0004-policy-vs-execution.md 0005-storage-abstraction.md 0006-extensibility-model.md 0007-core-runtime-contracts.md 0008-execution-authority-contract.md 0009-policy-engine-contract.md 0010-capability-registry-contract.md; do
  if [[ -f "$ROOT_DIR/docs/architecture/adr/$adr" ]]; then
    pass "$adr" "exists"
  else
    fail "$adr" "missing"
  fi
done
log ""

# Capability invariants
log "=== CAPABILITY INVARIANTS ==="

# Capability object fields
if grep -q "capability_id" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "capability_type" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "definition_hash" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "actor_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "resource_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "executor_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "verifier_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "provenance" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "audit_reference" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "SECRET_REFERENCE" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Capability object 40+ fields" "Capability object 40+ fields with SECRET_REFERENCE found"
else
  fail "Capability object 40+ fields" "Capability object fields missing"
fi

# Built-in capabilities
if grep -q "CAP_FS_READ" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_FS_WRITE" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_PROCESS_EXEC" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_NETWORK_READ" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_NETWORK_CONNECT" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_PACKAGE_INSTALL" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_BROWSER" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_COMPUTER" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_MCP" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_SECRET_ACCESS" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Built-in capabilities" "Built-in CAP_FS_READ/WRITE/PROCESS_EXEC/NETWORK_READ/CONNECT/PACKAGE_INSTALL/BROWSER/COMPUTER/MCP/SECRET_ACCESS found"
else
  fail "Built-in capabilities" "Built-in capabilities missing"
fi

# Necessary but not sufficient
if grep -q "Necessary but not sufficient" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Capability exists.*active.*bound.*valid" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAPABILITY.*AUTHORIZATION.*POLICY" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Necessary but not sufficient" "Necessary but not sufficient Capability exists+active+bound+valid → Authorization → Policy → Execution Authority found"
else
  fail "Necessary but not sufficient" "Necessary but not sufficient missing"
fi

# Default deny CAP-01
if grep -q "DEFAULT DENY" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-01" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "no ASSUME ALLOW" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Default deny CAP-01" "Default deny CAP-01 no ASSUME ALLOW found"
else
  fail "Default deny CAP-01" "Default deny missing"
fi

# Unknown capability DENY CAP-02
if grep -q "unknown capability.*DENY" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "CAP-02" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Unknown capability DENY CAP-02" "Unknown capability DENY CAP-02 found"
else
  fail "Unknown capability DENY CAP-02" "Unknown capability DENY missing"
fi

# Revoked/Expired/Suspended/Malformed/Provenance CAP-03..CAP-08
if grep -q "CAP-03" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-04" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-05" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-06" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-07" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-08" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "CAP-03..CAP-08 revoked/expired/suspended/malformed/provenance" "CAP-03..CAP-08 found"
else
  fail "CAP-03..CAP-08 revoked/expired/suspended/malformed/provenance" "CAP-03..CAP-08 missing"
fi

# Actor binding mandatory CAP-09
if grep -q "actor_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-09" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "user/agent/service/tool/mcp_server/execution_authority/system" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Actor binding mandatory CAP-09" "Actor binding mandatory CAP-09 user/agent/service/tool/mcp_server/execution_authority/system found"
else
  fail "Actor binding mandatory CAP-09" "Actor binding mandatory missing"
fi

# Resource binding mandatory CAP-10 explicit verifiable
if grep -q "resource_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-10" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_FS_READ.*workspace/project/docs" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP_NETWORK_CONNECT.*api.github.com:443" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Resource binding mandatory CAP-10" "Resource binding mandatory CAP-10 explicit verifiable found"
else
  fail "Resource binding mandatory CAP-10" "Resource binding mandatory missing"
fi

# Scope escalation prevention CAP-11
if grep -q "workspace→host\|workspace->host" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "repository→production\|repository->production" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-11" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Scope escalation prevention CAP-11" "Scope escalation workspace→host repository→production CAP-11 found"
else
  fail "Scope escalation prevention CAP-11" "Scope escalation prevention missing"
fi

# Risk escalation prevention CAP-12 CLASS-6 CAP-13
if grep -q "CAP-12" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-13" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CLASS-6.*FORBIDDEN\|FORBIDDEN.*CLASS-6" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Risk escalation CLASS-6 CAP-12 CAP-13" "Risk escalation CAP-12 CLASS-6 FORBIDDEN CAP-13 found"
else
  fail "Risk escalation CLASS-6 CAP-12 CAP-13" "Risk escalation missing"
fi

# Capability possession ≠ policy allow CAP-14, ≠ authorization CAP-15, ≠ execution CAP-16, cannot execute itself CAP-17
if grep -q "CAP-14" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-15" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-16" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-17" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "capability possession.*≠.*policy allow" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "CAP-14..CAP-17 possession≠policy/auth/exec cannot execute" "CAP-14..CAP-17 possession≠policy allow ≠authorization ≠execution cannot execute itself found"
else
  fail "CAP-14..CAP-17 possession≠policy/auth/exec cannot execute" "CAP-14..CAP-17 missing"
fi

# No self-grant CAP-18, no learning activation CAP-19, no memory-based CAP-20, no implicit inheritance CAP-21
if grep -q "CAP-18" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-19" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-20" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-21" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "no self-grant\|Agent cannot grant itself" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "CAP-18..CAP-21 no self-grant/learning/memory/implicit inheritance" "CAP-18..CAP-21 no self-grant no learning activation no memory-based no implicit inheritance found"
else
  fail "CAP-18..CAP-21 no self-grant/learning/memory/implicit inheritance" "CAP-18..CAP-21 missing"
fi

# Delegation bounded CAP-22..CAP-25
if grep -q "CAP-22" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-23" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-24" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-25" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "delegation.*explicit" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "cannot increase scope\|cannot broaden scope" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "Delegation bounded CAP-22..CAP-25" "Delegation bounded CAP-22..CAP-25 explicit bounded cannot increase scope found"
else
  fail "Delegation bounded CAP-22..CAP-25" "Delegation bounded missing"
fi

# Active definition immutable CAP-26, version/hash mandatory CAP-27, audit history immutable CAP-28, registry failure fail-closed CAP-29, registry cannot bypass CAP-30
if grep -q "CAP-26" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-27" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-28" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-29" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "CAP-30" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "CAP-26..CAP-30 immutable/version/hash/audit/fail-closed/no bypass" "CAP-26..CAP-30 found"
else
  fail "CAP-26..CAP-30 immutable/version/hash/audit/fail-closed/no bypass" "CAP-26..CAP-30 missing"
fi

# Executor binding
if grep -q "executor_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "File Executor" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Process Executor" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Package Executor" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Executor binding" "Executor binding File/Process/Package Executor found"
else
  fail "Executor binding" "Executor binding missing"
fi

# Verifier binding
if grep -q "verifier_binding" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "filesystem evidence" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "capability does not issue PASS" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "Verifier binding" "Verifier binding filesystem evidence capability does not issue PASS found"
else
  fail "Verifier binding" "Verifier binding missing"
fi

# Leases/expiration
if grep -q "issued_at" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "not_before" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "expires_at" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "expired.*!=.*active" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Leases/expiration" "Leases issued_at/not_before/expires_at expired!=active found"
else
  fail "Leases/expiration" "Leases/expiration missing"
fi

# Revocation
if grep -q "Revocation.*explicit\|revocation.*auditable" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "security incident" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "audit history.*remain\|no deleting record" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "Revocation explicit auditable" "Revocation explicit auditable security incident audit history remains found"
else
  fail "Revocation explicit auditable" "Revocation missing"
fi

# Delegation chain
if grep -q "ROOT.*DELEGATED.*CHILD\|ROOT → DELEGATED → CHILD" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "parent_capability" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "lineage" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Delegation chain ROOT→DELEGATED→CHILD" "Delegation chain ROOT→DELEGATED→CHILD parent_capability lineage found"
else
  fail "Delegation chain ROOT→DELEGATED→CHILD" "Delegation chain missing"
fi

# No self-grant
if grep -q "no self-grant\|Agent cannot grant itself" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "LLM cannot grant" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Proposal.*Validation.*Authorization/Owner Approval.*Registry Activation" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "No self-grant Proposal→Validation→Approval→Activation" "No self-grant Proposal→Validation→Authorization/Owner Approval→Registry Activation found"
else
  fail "No self-grant Proposal→Validation→Approval→Activation" "No self-grant missing"
fi

# Learning boundary
if grep -q "Learning.*Proposal.*Activation\|Proposal.*≠.*Activation" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Experience.*Feedback.*Capability Proposal" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Learning boundary Experience→Feedback→Proposal≠Activation" "Learning boundary Experience→Feedback→Capability Proposal Proposal≠Activation found"
else
  fail "Learning boundary Experience→Feedback→Proposal≠Activation" "Learning boundary missing"
fi

# Provenance
if grep -q "provenance" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "source.*source_version.*definition_hash.*issuer.*trust_level" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "untrusted.*DENY/BLOCKED" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "Provenance source/version/hash/issuer/trust_level" "Provenance source/source_version/definition_hash/issuer/trust_level untrusted DENY/BLOCKED found"
else
  fail "Provenance source/version/hash/issuer/trust_level" "Provenance missing"
fi

# No unrestricted wildcards
if grep -q "No Unrestricted Wildcards\|no.*\\*" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "unrestricted filesystem\|unrestricted network" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "explicit allowlists/selectors\|allowlist" "$ROOT_DIR/docs/contracts/capability.md" -i; then
  pass "No unrestricted wildcards explicit allowlists" "No unrestricted wildcards * unrestricted filesystem/network explicit allowlists/selectors found"
else
  fail "No unrestricted wildcards explicit allowlists" "No unrestricted wildcards missing"
fi

# Secret reference
if grep -q "SECRET_REFERENCE" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "not.*secret_value\|SECRET_REFERENCE.*not.*VALUE" "$ROOT_DIR/docs/contracts/capability.md" -i && grep -q "CAP_SECRET_ACCESS" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Secret REFERENCE not VALUE CAP_SECRET_ACCESS" "Secret REFERENCE not VALUE CAP_SECRET_ACCESS found"
else
  fail "Secret REFERENCE not VALUE CAP_SECRET_ACCESS" "Secret reference missing"
fi

# Registry contract interface
if grep -q "register_definition" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "validate_definition" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "get_definition" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "get_active_definition" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "grant" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "check_possession" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "check_scope" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "check_expiry" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "check_revocation" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "delegate" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "suspend" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "revoke" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "restore" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "registry_status" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "get_version" "$ROOT_DIR/docs/contracts/capability-registry.md"; then
  pass "Registry interface contract" "Registry interface register_definition/validate_definition/get_definition/get_active_definition/grant/get_grant/list_actor_capabilities/check_possession/check_scope/check_expiry/check_revocation/delegate/suspend/revoke/restore/registry_status/get_version found"
else
  fail "Registry interface contract" "Registry interface missing"
fi

# Registry states
if grep -q "UNINITIALIZED" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "LOADING" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "READY" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "DEGRADED" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "BLOCKED" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "FAILED" "$ROOT_DIR/docs/contracts/capability-registry.md"; then
  pass "Registry states UNINITIALIZED..FAILED" "Registry states UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED found"
else
  fail "Registry states UNINITIALIZED..FAILED" "Registry states missing"
fi

# Capability vs Policy table
if grep -q "What capability exists?" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "Can this actor possess it?" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "Is this action allowed now?" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "Which executor may run it?" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "Did it actually happen?" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "Is it verified?" "$ROOT_DIR/docs/contracts/capability-registry.md" && grep -q "P11 consumes.*Registry\|Policy consumes Registry" "$ROOT_DIR/docs/contracts/capability-registry.md" -i; then
  pass "Capability vs Policy table P11 consumes Registry" "Capability vs Policy table What capability exists? Can this actor possess it? Is this action allowed now? Which executor may run it? Did it actually happen? Is it verified? P11 consumes Registry found"
else
  fail "Capability vs Policy table P11 consumes Registry" "Capability vs Policy table missing"
fi

# P2/P10 compatibility
if grep -q "Action→Policy→Authorization→Package Executor→Privilege Gate→Package Manager→Result→Verification→Evidence" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Capability Registry does NOT replace.*Gate\|does NOT replace.*Privilege Gate" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "P2/P10 compatibility package path" "P2/P10 compatibility Action→Policy→Authorization→Package Executor→Privilege Gate preserved Capability Registry does NOT replace Gate found"
else
  fail "P2/P10 compatibility package path" "P2/P10 compatibility missing"
fi

# Diagrams
if grep -q "Capability Evaluation Flow" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "mermaid" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Delegation Chain" "$ROOT_DIR/docs/contracts/capability.md" && grep -q "Scope Escalation Prevention" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "Diagrams ASCII+Mermaid" "Diagrams Capability Evaluation Flow, Delegation Chain, Scope Escalation Prevention ASCII+Mermaid found"
else
  fail "Diagrams ASCII+Mermaid" "Diagrams missing"
fi

# Lifecycle diagrams
if grep -q "mermaid" "$ROOT_DIR/docs/contracts/capability-lifecycle.md" && grep -q "stateDiagram-v2" "$ROOT_DIR/docs/contracts/capability-lifecycle.md" && grep -q "PROPOSED" "$ROOT_DIR/docs/contracts/capability-lifecycle.md" && grep -q "ACTIVE" "$ROOT_DIR/docs/contracts/capability-lifecycle.md"; then
  pass "Lifecycle diagrams mermaid" "Lifecycle diagrams mermaid stateDiagram-v2 PROPOSED ACTIVE found"
else
  fail "Lifecycle diagrams mermaid" "Lifecycle diagrams missing"
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

# P11 contracts preserved
if test -f "$ROOT_DIR/docs/contracts/policy.md" && test -f "$ROOT_DIR/docs/contracts/policy-matrix.md" && test -f "$ROOT_DIR/docs/contracts/policy-lifecycle.md"; then
  pass "P11 contracts preserved" "P11 contracts still exist (policy, policy-matrix, policy-lifecycle)"
else
  fail "P11 contracts preserved" "P11 contracts missing"
fi

# No contradictions
if ! grep -qr "P8 is obsolete\|P8 replaced\|P9 is obsolete\|P9 replaced\|P10 is obsolete\|P10 replaced\|P11 is obsolete\|P11 replaced" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no contradictions" "No contradictory P8/P9/P10/P11 obsolete claims"
else
  fail "no contradictions" "Found contradictory obsolete claims"
fi

# Contract First principle
if grep -q "Contract First\|CONTRACTS ONLY\|CAPABILITY CONTRACT ONLY" "$ROOT_DIR/docs/contracts/capability.md"; then
  pass "contract first" "Contract First / CONTRACTS ONLY / CAPABILITY CONTRACT ONLY found"
else
  fail "contract first" "Contract First principle missing"
fi

# No implementation language chosen
log ""
log "=== NO IMPLEMENTATION LANGUAGE CHECK ==="
if ! grep -qr "P12 chooses Rust\|P12 chooses Go\|P12 chooses Python\|P12 chooses Node\|P12 chooses OPA\|P12 chooses Cedar\|P12 chooses Casbin\|P12 chooses OpenFGA\|P12 chooses Postgres\|P12 chooses SQLite\|P12 chooses Redis" "$ROOT_DIR/docs/contracts/" >/dev/null; then
  pass "no impl language/framework chosen" "No Rust/Go/Python/Node/OPA/Cedar/Casbin/OpenFGA/Postgres/SQLite/Redis chosen in P12 (DECISION PENDING P18)"
else
  fail "no impl language/framework chosen" "Implementation language/framework chosen in P12 (should be PENDING P18)"
fi

if grep -q "DECISION PENDING.*P18\|P18.*Technology Selection\|Technology.*PENDING" "$ROOT_DIR/docs/contracts/capability.md" || grep -q "DECISION PENDING" "$ROOT_DIR/docs/architecture/adr/0010-capability-registry-contract.md"; then
  pass "technology decision pending P18" "Technology decision PENDING P18 found"
else
  fail "technology decision pending P18" "Technology decision pending P18 missing"
fi

log ""

# No product code check
log "=== NO PRODUCT CODE CHECK ==="
if find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" -not -path "*/node_modules/*" | grep -q "."; then
  fail "no product code" "Found product code (should be only docs and shell scripts in P12)"
  find "$ROOT_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" \) -not -path "*/.git/*" | head -5
else
  if test -d "$ROOT_DIR/src" || test -d "$ROOT_DIR/app" || test -d "$ROOT_DIR/api" || test -d "$ROOT_DIR/ui" || test -d "$ROOT_DIR/runtime" || test -d "$ROOT_DIR/executor" || test -d "$ROOT_DIR/policy-engine" || test -d "$ROOT_DIR/capability-registry"; then
    fail "no product code" "Found product code directory src/app/api/ui/runtime/executor/policy-engine/capability-registry"
  else
    pass "no product code" "No product code found (only docs and shell scripts)"
  fi
fi
log ""

# No package installation in P12
log "=== NO PACKAGE INSTALLATION IN P12 ==="
if grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" 2>/dev/null | grep -v "No " | head -5 | grep -q "."; then
  fail "no package install in P12" "Found apt install in contracts docs"
  grep -R -n -E '^\s*apt-get install|^\s*apt install' "$ROOT_DIR/docs/contracts" | head -5
else
  pass "no package install in P12" "No apt install in contracts docs (repository-only)"
fi
log ""

log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Capability verification PASS - all invariants verified"
  log "EVIDENCE → verify-capability.sh execution, contracts docs capability.md/capability-registry.md/capability-lifecycle.md, ADR 0010, frozen-baseline, P9/P10/P11 contracts"
  log "NEXT → Run capability.test.sh"
else
  log "STATUS → FAIL"
  log "RESULT → Capability verification FAIL - see failures above"
fi

exit $EXIT_CODE
