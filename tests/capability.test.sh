#!/usr/bin/env bash
# LINEX.OS CAPABILITY CONTRACT TESTS - P12
# Verifies Capability Contract + Registry existence, invariants, no implementation, no contradictions with P8/P9/P10/P11
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

log "LINEX.OS CAPABILITY CONTRACT TESTS - P12"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log ""

# TEST-1: capability contract exists
log "--- TEST-1: capability contract exists ---"
run_check "TEST-1: capability contract exists" \
  "test -f \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Capability Contract\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"capability_id\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAPABILITY.*AUTHORIZATION.*POLICY\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "capability.md exists with Capability Contract, capability_id, CAPABILITY≠AUTHORIZATION≠POLICY" \
  "capability contract missing"
log ""

# TEST-2: capability-registry exists
log "--- TEST-2: capability-registry exists ---"
run_check "TEST-2: capability-registry exists" \
  "test -f \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"Capability Registry\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"register_definition\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"check_possession\" \"$ROOT_DIR/docs/contracts/capability-registry.md\"" \
  "capability-registry.md exists with Registry, register_definition, check_possession" \
  "capability-registry missing"
log ""

# TEST-3: capability-lifecycle exists
log "--- TEST-3: capability-lifecycle exists ---"
run_check "TEST-3: capability-lifecycle exists" \
  "test -f \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"Capability Lifecycle\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"PROPOSED\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"ACTIVE\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"mermaid\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\"" \
  "capability-lifecycle.md exists with Lifecycle, PROPOSED, ACTIVE, mermaid" \
  "capability-lifecycle missing"
log ""

# TEST-4: ADR 0010 exists
log "--- TEST-4: ADR 0010 exists ---"
run_check "TEST-4: ADR 0010 exists" \
  "test -f \"$ROOT_DIR/docs/architecture/adr/0010-capability-registry-contract.md\" && grep -q \"ACCEPTED\" \"$ROOT_DIR/docs/architecture/adr/0010-capability-registry-contract.md\" && grep -q \"Capability Registry\" \"$ROOT_DIR/docs/architecture/adr/0010-capability-registry-contract.md\" && grep -q \"trusted source\" \"$ROOT_DIR/docs/architecture/adr/0010-capability-registry-contract.md\" -i" \
  "ADR 0010 exists ACCEPTED Capability Registry trusted source" \
  "ADR 0010 missing"
log ""

# TEST-5: capability object 40+ fields
log "--- TEST-5: capability object 40+ fields ---"
run_check "TEST-5: capability object 40+ fields" \
  "grep -q \"capability_id\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"capability_type\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"definition_hash\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"actor_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"resource_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"resource_type\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"resource_selector\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"allowed_operations\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"risk_class\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"executor_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"verifier_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"network_constraints\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"filesystem_constraints\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"process_constraints\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"issued_at\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"not_before\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"expires_at\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"revocation_status\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"provenance\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"parent_capability\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"delegation_policy\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"lineage\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"registry_version\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"audit_reference\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Capability object 40+ fields found" \
  "Capability object fields missing"
log ""

# TEST-6: capability IDs canonical
log "--- TEST-6: capability IDs canonical ---"
run_check "TEST-6: capability IDs canonical" \
  "grep -q \"CAP_FS_READ\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_FS_WRITE\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_PROCESS_EXEC\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_NETWORK_READ\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_NETWORK_CONNECT\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_PACKAGE_INSTALL\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_BROWSER\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_COMPUTER\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_MCP\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_SECRET_ACCESS\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Canonical capability IDs CAP_FS_READ/WRITE/PROCESS_EXEC/NETWORK_READ/CONNECT/PACKAGE_INSTALL/BROWSER/COMPUTER/MCP/SECRET_ACCESS found" \
  "Capability IDs missing"
log ""

# TEST-7: actor binding mandatory
log "--- TEST-7: actor binding mandatory ---"
run_check "TEST-7: actor binding mandatory" \
  "grep -q \"actor_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"user/agent/service/tool/mcp_server/execution_authority/system\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"actor binding mandatory\\|actor_binding mandatory\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-09\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Actor binding mandatory user/agent/service/tool/mcp_server/execution_authority/system CAP-09 found" \
  "Actor binding missing"
log ""

# TEST-8: resource binding mandatory explicit verifiable
log "--- TEST-8: resource binding mandatory explicit verifiable ---"
run_check "TEST-8: resource binding mandatory explicit verifiable" \
  "grep -q \"resource_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_FS_READ.*workspace/project/docs\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_NETWORK_CONNECT.*api.github.com:443\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_BROWSER.*approved-domain\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"resource binding mandatory\\|CAP-10\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Resource binding mandatory explicit verifiable CAP_FS_READ→workspace/project/docs CAP_NETWORK_CONNECT→api.github.com:443 CAP_BROWSER→approved-domain CAP-10 found" \
  "Resource binding missing"
log ""

# TEST-9: scope model explicit no auto expansion
log "--- TEST-9: scope model explicit no auto expansion ---"
run_check "TEST-9: scope model explicit no auto expansion" \
  "grep -q \"workspace\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"repository\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"project\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"file\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"directory\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"process\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"host\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"network destination\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"secret reference\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"must not auto-expand\\|no auto expansion\\|must NOT auto-expand\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Scope model workspace/repository/project/file/directory/process/host/network/secret explicit no auto expansion found" \
  "Scope model missing"
log ""

# TEST-10: risk model CLASS-0..6 CLASS-6 FORBIDDEN
log "--- TEST-10: risk model CLASS-0..6 CLASS-6 FORBIDDEN ---"
run_check "TEST-10: risk model CLASS-0..6 CLASS-6 FORBIDDEN" \
  "grep -q \"CLASS-0\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-1\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-2\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-3\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-4\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-5\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-6\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-6.*FORBIDDEN\\|FORBIDDEN.*CLASS-6\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CLASS-5.*CLASS-2\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Risk CLASS-0..6 CLASS-6 FORBIDDEN CLASS-5→CLASS-2 prevention found" \
  "Risk model missing"
log ""

# TEST-11: executor binding mandatory
log "--- TEST-11: executor binding mandatory ---"
run_check "TEST-11: executor binding mandatory" \
  "grep -q \"executor_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"File Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Process Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Network Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Package Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"capability contract does not execute\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Executor binding File/Process/Network/Package Executor capability contract does not execute found" \
  "Executor binding missing"
log ""

# TEST-12: verifier binding mandatory
log "--- TEST-12: verifier binding mandatory ---"
run_check "TEST-12: verifier binding mandatory" \
  "grep -q \"verifier_binding\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"filesystem evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"process result.*exit code.*execution evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"network evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"package.*execution.*privilege evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"capability does not issue PASS\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Verifier binding filesystem evidence process result+exit code network evidence package+execution+privilege evidence capability does not issue PASS found" \
  "Verifier binding missing"
log ""

# TEST-13: default deny CAP-01 no ASSUME ALLOW
log "--- TEST-13: default deny CAP-01 no ASSUME ALLOW ---"
run_check "TEST-13: default deny CAP-01 no ASSUME ALLOW" \
  "grep -q \"DEFAULT DENY\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-01\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"no ASSUME ALLOW\\|ASSUME ALLOW\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"fail-closed\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Default deny CAP-01 no ASSUME ALLOW fail-closed found" \
  "Default deny missing"
log ""

# TEST-14: unknown capability DENY CAP-02
log "--- TEST-14: unknown capability DENY CAP-02 ---"
run_check "TEST-14: unknown capability DENY CAP-02" \
  "grep -q \"unknown capability.*DENY\\|unknown capability = DENY\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-02\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Unknown capability DENY CAP-02 found" \
  "Unknown capability DENY missing"
log ""

# TEST-15: revoked capability DENY CAP-03
log "--- TEST-15: revoked capability DENY CAP-03 ---"
run_check "TEST-15: revoked capability DENY CAP-03" \
  "grep -q \"revoked capability.*DENY\\|revoked.*DENY\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-03\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"revoked.*!=.*active\\|revoked != active\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Revoked capability DENY CAP-03 revoked!=active found" \
  "Revoked DENY missing"
log ""

# TEST-16: expired capability DENY CAP-04
log "--- TEST-16: expired capability DENY CAP-04 ---"
run_check "TEST-16: expired capability DENY CAP-04" \
  "grep -q \"expired capability.*DENY\\|expired.*DENY\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-04\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"expired.*!=.*active\\|expired != active\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Expired capability DENY CAP-04 expired!=active found" \
  "Expired DENY missing"
log ""

# TEST-17: suspended capability DENY/BLOCKED CAP-05
log "--- TEST-17: suspended capability DENY/BLOCKED CAP-05 ---"
run_check "TEST-17: suspended capability DENY/BLOCKED CAP-05" \
  "grep -q \"suspended.*DENY/BLOCKED\\|suspended.*DENY\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-05\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"SUSPENDED.*DENY/BLOCKED\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Suspended capability DENY/BLOCKED CAP-05 SUSPENDED→DENY/BLOCKED found" \
  "Suspended DENY missing"
log ""

# TEST-18: malformed capability BLOCKED CAP-06
log "--- TEST-18: malformed capability BLOCKED CAP-06 ---"
run_check "TEST-18: malformed capability BLOCKED CAP-06" \
  "grep -q \"malformed.*BLOCKED\\|malformed capability\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-06\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Malformed capability BLOCKED CAP-06 found" \
  "Malformed BLOCKED missing"
log ""

# TEST-19: provenance mandatory untrusted DENY/BLOCKED CAP-07 CAP-08
log "--- TEST-19: provenance mandatory untrusted DENY/BLOCKED CAP-07 CAP-08 ---"
run_check "TEST-19: provenance mandatory untrusted DENY/BLOCKED CAP-07 CAP-08" \
  "grep -q \"provenance\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"missing provenance.*DENY/BLOCKED\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"untrusted.*DENY/BLOCKED\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-07\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-08\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Provenance missing DENY/BLOCKED untrusted DENY/BLOCKED CAP-07 CAP-08 found" \
  "Provenance missing"
log ""

# TEST-20: secret reference SECRET_REFERENCE not secret_value
log "--- TEST-20: secret reference SECRET_REFERENCE not secret_value ---"
run_check "TEST-20: secret reference SECRET_REFERENCE not secret_value" \
  "grep -q \"SECRET_REFERENCE\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"not.*secret_value\\|SECRET_REFERENCE.*not.*VALUE\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"no secrets\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP_SECRET_ACCESS\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Secret REFERENCE not VALUE SECRET_REFERENCE CAP_SECRET_ACCESS no secrets found" \
  "Secret reference missing"
log ""

# TEST-21: no self-grant CAP-18
log "--- TEST-21: no self-grant CAP-18 ---"
run_check "TEST-21: no self-grant CAP-18" \
  "grep -q \"no self-grant\\|Agent cannot grant itself\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-18\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"LLM cannot grant\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"MCP.*cannot grant itself\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "No self-grant Agent cannot grant itself LLM cannot grant MCP cannot grant itself CAP-18 found" \
  "No self-grant missing"
log ""

# TEST-22: delegation bounded cannot broaden scope CAP-22
log "--- TEST-22: delegation bounded cannot broaden scope CAP-22 ---"
run_check "TEST-22: delegation bounded cannot broaden scope CAP-22" \
  "grep -q \"delegation.*explicit\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"cannot increase scope\\|cannot broaden scope\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-22\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Parent.*CAP_FS_READ workspace/project/docs\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Child.*CAP_FS_READ workspace/project/docs/file.md\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Delegation explicit bounded cannot increase scope cannot broaden scope Parent CAP_FS_READ workspace/project/docs Child CAP_FS_READ file.md CAP-22 found" \
  "Delegation bounded missing"
log ""

# TEST-23: no escalation scope and risk CAP-11 CAP-12
log "--- TEST-23: no escalation scope and risk CAP-11 CAP-12 ---"
run_check "TEST-23: no escalation scope and risk CAP-11 CAP-12" \
  "grep -q \"workspace→host\\|workspace->host\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"repository→production\\|repository->production\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"user→system\\|user->system\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"github.com.*unrestricted network\\|github.com → unrestricted\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-11\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-12\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "No escalation workspace→host repository→production user→system github.com→unrestricted network CAP-11 CAP-12 found" \
  "No escalation missing"
log ""

# TEST-24: parent/child lineage ROOT→DELEGATED→CHILD
log "--- TEST-24: parent/child lineage ROOT→DELEGATED→CHILD ---"
run_check "TEST-24: parent/child lineage ROOT→DELEGATED→CHILD" \
  "grep -q \"ROOT.*DELEGATED.*CHILD\\|ROOT → DELEGATED → CHILD\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"parent_capability\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"lineage\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"one weak.*arbitrary stronger\\|one weak capability.*arbitrary stronger\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Parent/child lineage ROOT→DELEGATED→CHILD parent_capability lineage one weak→arbitrary stronger DENY found" \
  "Lineage missing"
log ""

# TEST-25: lease/expiry issued/not_before/expires_at
log "--- TEST-25: lease/expiry issued/not_before/expires_at ---"
run_check "TEST-25: lease/expiry issued/not_before/expires_at" \
  "grep -q \"issued_at\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"not_before\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"expires_at\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"expired.*!=.*active\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"no eternal.*high-risk\\|no eternal default for high-risk\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Lease/expiry issued_at/not_before/expires_at expired!=active no eternal default high-risk found" \
  "Lease/expiry missing"
log ""

# TEST-26: revocation explicit auditable immediate
log "--- TEST-26: revocation explicit auditable immediate ---"
run_check "TEST-26: revocation explicit auditable immediate" \
  "grep -q \"Revocation.*explicit\\|revocation.*auditable\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"security incident\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"owner request\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"no deleting record.*revocation nonexistent\\|audit history.*remain\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Revocation explicit auditable immediate security incident owner request audit history remains found" \
  "Revocation missing"
log ""

# TEST-27: registry states UNINITIALIZED LOADING READY DEGRADED BLOCKED FAILED
log "--- TEST-27: registry states UNINITIALIZED LOADING READY DEGRADED BLOCKED FAILED ---"
run_check "TEST-27: registry states UNINITIALIZED LOADING READY DEGRADED BLOCKED FAILED" \
  "grep -q \"UNINITIALIZED\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"LOADING\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"READY\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"DEGRADED\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"BLOCKED\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"FAILED\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" && grep -q \"UNINITIALIZED.*no grant\\|LOADING.*no authorize\" \"$ROOT_DIR/docs/contracts/capability-registry.md\" -i" \
  "Registry states UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED UNINITIALIZED→no grant LOADING→no authorize found" \
  "Registry states missing"
log ""

# TEST-28: lifecycle PROPOSED VALIDATING VALIDATED ACTIVE SUSPENDED REVOKED EXPIRED
log "--- TEST-28: lifecycle PROPOSED VALIDATING VALIDATED ACTIVE SUSPENDED REVOKED EXPIRED ---"
run_check "TEST-28: lifecycle PROPOSED VALIDATING VALIDATED ACTIVE SUSPENDED REVOKED EXPIRED" \
  "grep -q \"PROPOSED\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"VALIDATING\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"VALIDATED\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"ACTIVE\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"SUSPENDED\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"REVOKED\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"EXPIRED\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" && grep -q \"only ACTIVE.*may be used\\|only ACTIVE.*Authorization\" \"$ROOT_DIR/docs/contracts/capability-lifecycle.md\" -i" \
  "Lifecycle PROPOSED/VALIDATING/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED only ACTIVE may be used found" \
  "Lifecycle missing"
log ""

# TEST-29: version immutability CAP-26
log "--- TEST-29: version immutability CAP-26 ---"
run_check "TEST-29: version immutability CAP-26" \
  "grep -q \"active definition immutable\\|definition immutable\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-26\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"new version.*no rewrite old\\|change requires new version\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Version immutability active definition immutable new version no rewrite old CAP-26 found" \
  "Version immutability missing"
log ""

# TEST-30: definition hash mandatory CAP-27
log "--- TEST-30: definition hash mandatory CAP-27 ---"
run_check "TEST-30: definition hash mandatory CAP-27" \
  "grep -q \"definition_hash\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-27\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"version/hash mandatory\\|version.*hash.*mandatory\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"SHA256\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Definition hash mandatory version/hash mandatory SHA256 CAP-27 found" \
  "Definition hash missing"
log ""

# TEST-31: no implicit inheritance CAP-21
log "--- TEST-31: no implicit inheritance CAP-21 ---"
run_check "TEST-31: no implicit inheritance CAP-21" \
  "grep -q \"no implicit inheritance\\|no implicit.*inheritance\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"CAP-21\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"no implicit trust\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"system capability.*does not.*auto.*transfer.*agent\\|system capability.*auto transfer\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "No implicit inheritance no implicit trust system capability does not auto transfer to agent CAP-21 found" \
  "No implicit inheritance missing"
log ""

# TEST-32: no implicit capability activation learning boundary CAP-19 CAP-20
log "--- TEST-32: no implicit capability activation learning boundary CAP-19 CAP-20 ---"
run_check "TEST-32: no implicit capability activation learning boundary CAP-19 CAP-20" \
  "grep -q \"Learning.*Proposal.*Activation\\|Proposal.*≠.*Activation\\|Proposal != Activation\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-19\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-20\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Experience.*Feedback.*Capability Proposal\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Learning boundary Experience→Feedback→Capability Proposal Proposal≠Activation CAP-19 CAP-20 found" \
  "Learning boundary missing"
log ""

# TEST-33: MCP/plugin provenance untrusted DENY/BLOCKED
log "--- TEST-33: MCP/plugin provenance untrusted DENY/BLOCKED ---"
run_check "TEST-33: MCP/plugin provenance untrusted DENY/BLOCKED" \
  "grep -q \"plugins\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"MCP servers\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"external tools\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"downloaded.*definitions\\|generated.*definitions\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"no auto trust\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"UNTRUSTED BY DEFAULT\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "MCP/plugin provenance plugins MCP servers external tools downloaded/generated no auto trust UNTRUSTED BY DEFAULT found" \
  "MCP/plugin provenance missing"
log ""

# TEST-34: filesystem capability CAP_FS_READ/WRITE
log "--- TEST-34: filesystem capability CAP_FS_READ/WRITE ---"
run_check "TEST-34: filesystem capability CAP_FS_READ/WRITE" \
  "grep -q \"CAP_FS_READ\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_FS_WRITE\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"File Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"filesystem evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"canonicalized\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"traversal.*DENY\\|../etc/passwd.*DENY\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Filesystem capability CAP_FS_READ/WRITE File Executor filesystem evidence canonicalized traversal DENY found" \
  "Filesystem capability missing"
log ""

# TEST-35: network capability CAP_NETWORK_READ/CONNECT
log "--- TEST-35: network capability CAP_NETWORK_READ/CONNECT ---"
run_check "TEST-35: network capability CAP_NETWORK_READ/CONNECT" \
  "grep -q \"CAP_NETWORK_READ\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP_NETWORK_CONNECT\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Network Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"network evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Unknown destination.*BLOCKED\\|no unrestricted Internet\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Network capability CAP_NETWORK_READ/CONNECT Network Executor network evidence Unknown destination BLOCKED no unrestricted Internet found" \
  "Network capability missing"
log ""

# TEST-36: process capability CAP_PROCESS_EXEC
log "--- TEST-36: process capability CAP_PROCESS_EXEC ---"
run_check "TEST-36: process capability CAP_PROCESS_EXEC" \
  "grep -q \"CAP_PROCESS_EXEC\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Process Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"ARGV MODE preferred\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"no bash -c\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"process result.*exit code\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Process capability CAP_PROCESS_EXEC Process Executor ARGV MODE preferred no bash -c process result+exit code found" \
  "Process capability missing"
log ""

# TEST-37: package capability CAP_PACKAGE_INSTALL P2/P10 compatibility
log "--- TEST-37: package capability CAP_PACKAGE_INSTALL P2/P10 compatibility ---"
run_check "TEST-37: package capability CAP_PACKAGE_INSTALL P2/P10 compatibility" \
  "grep -q \"CAP_PACKAGE_INSTALL\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Package Executor\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Privilege Gate\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"privilege-gate.sh\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"must not be bypassed\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"Action→Policy→Authorization→Package Executor→Privilege Gate\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Package capability CAP_PACKAGE_INSTALL Package Executor Privilege Gate must not be bypassed Action→Policy→Authorization→Package Executor→Privilege Gate found" \
  "Package capability missing"
log ""

# TEST-38: secret capability CAP_SECRET_ACCESS CRITICAL
log "--- TEST-38: secret capability CAP_SECRET_ACCESS CRITICAL ---"
run_check "TEST-38: secret capability CAP_SECRET_ACCESS CRITICAL" \
  "grep -q \"CAP_SECRET_ACCESS\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"SECRET_REFERENCE\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CRITICAL\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"EXPLICIT_APPROVAL\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"AUDIT_REQUIRED\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"NO_LOG\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Secret capability CAP_SECRET_ACCESS SECRET_REFERENCE CRITICAL EXPLICIT_APPROVAL AUDIT_REQUIRED NO_LOG found" \
  "Secret capability missing"
log ""

# TEST-39: policy separation CAP-14 capability possession ≠ policy allow
log "--- TEST-39: policy separation CAP-14 capability possession ≠ policy allow ---"
run_check "TEST-39: policy separation CAP-14 capability possession ≠ policy allow" \
  "grep -q \"CAP-14\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"capability possession.*≠.*policy allow\\|possession.*policy allow\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"Policy.*WHAT.*ALLOWED\\|WHAT IS ALLOWED\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"P11 consumes.*Registry\\|Policy consumes Registry\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Policy separation CAP-14 capability possession≠policy allow WHAT IS ALLOWED P11 consumes Registry found" \
  "Policy separation missing"
log ""

# TEST-40: authorization separation CAP-15 capability possession ≠ authorization
log "--- TEST-40: authorization separation CAP-15 capability possession ≠ authorization ---"
run_check "TEST-40: authorization separation CAP-15 capability possession ≠ authorization" \
  "grep -q \"CAP-15\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"capability possession.*≠.*authorization\\|possession.*authorization\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"Is this specific actor currently authorized\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"check_possession\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Authorization separation CAP-15 capability possession≠authorization Is this specific actor currently authorized check_possession found" \
  "Authorization separation missing"
log ""

# TEST-41: execution/verifier separation CAP-16 CAP-17
log "--- TEST-41: execution/verifier separation CAP-16 CAP-17 ---"
run_check "TEST-41: execution/verifier separation CAP-16 CAP-17" \
  "grep -q \"CAP-16\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-17\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"capability.*≠.*execution permission\\|capability.*execution permission\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"capability cannot execute itself\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && grep -q \"SUCCEEDED.*!=.*VERIFIED\\|SUCCEEDED.*not.*VERIFIED\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "Execution/verifier separation CAP-16 capability≠execution permission CAP-17 capability cannot execute itself SUCCEEDED≠VERIFIED found" \
  "Execution/verifier separation missing"
log ""

# TEST-42: P2/P10 compatibility package path preserved
log "--- TEST-42: P2/P10 compatibility package path preserved ---"
run_check "TEST-42: P2/P10 compatibility package path preserved" \
  "grep -q \"Action→Policy→Authorization→Package Executor→Privilege Gate→Package Manager→Result→Verification→Evidence\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Capability Registry does NOT replace.*Gate\\|does NOT replace.*Privilege Gate\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"does NOT mean.*sudo allowed\" \"$ROOT_DIR/docs/contracts/capability.md\" -i && test -f \"$ROOT_DIR/ops/security/privilege-policy.md\" && test -f \"$ROOT_DIR/ops/security/privilege-gate.sh\"" \
  "P2/P10 compatibility package path Action→Policy→Authorization→Package Executor→Privilege Gate preserved Capability Registry does NOT replace Gate does NOT mean sudo allowed found" \
  "P2/P10 compatibility missing"
log ""

# TEST-43: invariants CAP-01..CAP-30 + diagrams ASCII+Mermaid
log "--- TEST-43: invariants CAP-01..CAP-30 + diagrams ASCII+Mermaid ---"
run_check "TEST-43: invariants CAP-01..CAP-30 + diagrams ASCII+Mermaid" \
  "grep -q \"CAP-01\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"CAP-30\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"mermaid\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Capability Evaluation Flow\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Delegation Chain\" \"$ROOT_DIR/docs/contracts/capability.md\" && grep -q \"Scope Escalation Prevention\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "Invariants CAP-01..CAP-30 Diagrams ASCII+Mermaid Capability Evaluation Flow Delegation Chain Scope Escalation Prevention found" \
  "Invariants/Diagrams missing"
log ""

# TEST-44: no product implementation + no package install + no technology choice
log "--- TEST-44: no product implementation + no package install + no technology choice ---"
run_check "TEST-44: no product implementation + no package install + no technology choice" \
  "grep -q \"CONTRACTS ONLY\\|CAPABILITY CONTRACT ONLY\" \"$ROOT_DIR/docs/contracts/capability.md\" && ! find \"$ROOT_DIR\" -type f \\( -name \"*.py\" -o -name \"*.js\" -o -name \"*.ts\" -o -name \"*.go\" -o -name \"*.rs\" \\) -not -path \"*/.git/*\" -not -path \"*/node_modules/*\" | grep -q \".\" && ! grep -qr \"P12 chooses Rust\\|P12 chooses Go\\|P12 chooses Python\\|P12 chooses Node\\|P12 chooses OPA\\|P12 chooses Cedar\\|P12 chooses Casbin\\|P12 chooses OpenFGA\" \"$ROOT_DIR/docs/contracts/\" && grep -q \"DECISION PENDING.*P18\\|PENDING.*Technology Selection P18\" \"$ROOT_DIR/docs/contracts/capability.md\"" \
  "No product implementation CONTRACTS ONLY no technology choice DECISION PENDING P18 found" \
  "No product implementation or technology choice violation"
log ""

# TEST-45: P8/P9/P10/P11 preserved no contradictions
log "--- TEST-45: P8/P9/P10/P11 preserved no contradictions ---"
run_check "TEST-45: P8/P9/P10/P11 preserved no contradictions" \
  "test -f \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && test -f \"$ROOT_DIR/docs/contracts/runtime.md\" && test -f \"$ROOT_DIR/docs/contracts/execution-authority.md\" && test -f \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Model C\" \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && ! grep -qr \"P8 is obsolete\\|P9 is obsolete\\|P10 is obsolete\\|P11 is obsolete\" \"$ROOT_DIR/docs/contracts/\" && grep -q \"P11 consumes.*Registry\\|Policy consumes Registry\" \"$ROOT_DIR/docs/contracts/capability.md\" -i" \
  "P8/P9/P10/P11 preserved Model C no obsolete claims P11 consumes Registry found" \
  "P8/P9/P10/P11 preservation missing"
log ""

log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All $PASSED/$TOTAL capability tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED failed out of $TOTAL"
  exit 1
fi
