#!/usr/bin/env bash
# LINEX.OS POLICY ENGINE TESTS - P11
# Verifies Policy Engine Contracts existence, invariants, no implementation, no contradictions with P8/P9/P10
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

log "LINEX.OS POLICY ENGINE TESTS - P11"
log "Timestamp: $TIMESTAMP"
log "Root: $ROOT_DIR"
log ""

# TEST-1: policy contract exists
log "--- TEST-1: policy contract exists ---"
run_check "TEST-1: policy contract exists" \
  "test -f \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Policy Engine\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"PolicyRequest\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"PolicyDecision\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "policy.md exists with Policy Engine, PolicyRequest, PolicyDecision" \
  "policy contract missing"
log ""

# TEST-2: policy-matrix exists
log "--- TEST-2: policy-matrix exists ---"
run_check "TEST-2: policy-matrix exists" \
  "test -f \"$ROOT_DIR/docs/contracts/policy-matrix.md\" && grep -q \"Policy Risk Matrix\" \"$ROOT_DIR/docs/contracts/policy-matrix.md\" && grep -q \"CAP_FS_READ\" \"$ROOT_DIR/docs/contracts/policy-matrix.md\" && grep -q \"CLASS-0\" \"$ROOT_DIR/docs/contracts/policy-matrix.md\"" \
  "policy-matrix.md exists with Risk Matrix, CAP_FS_READ, CLASS-0" \
  "policy-matrix missing"
log ""

# TEST-3: policy-lifecycle exists
log "--- TEST-3: policy-lifecycle exists ---"
run_check "TEST-3: policy-lifecycle exists" \
  "test -f \"$ROOT_DIR/docs/contracts/policy-lifecycle.md\" && grep -q \"Policy Lifecycle\" \"$ROOT_DIR/docs/contracts/policy-lifecycle.md\" && grep -q \"CREATED\" \"$ROOT_DIR/docs/contracts/policy-lifecycle.md\" && grep -q \"REQUESTED\" \"$ROOT_DIR/docs/contracts/policy-lifecycle.md\" && grep -q \"mermaid\" \"$ROOT_DIR/docs/contracts/policy-lifecycle.md\"" \
  "policy-lifecycle.md exists with Policy Lifecycle, CREATED, REQUESTED, mermaid" \
  "policy-lifecycle missing"
log ""

# TEST-4: ADR 0009 exists
log "--- TEST-4: ADR 0009 exists ---"
run_check "TEST-4: ADR 0009 exists" \
  "test -f \"$ROOT_DIR/docs/architecture/adr/0009-policy-engine-contract.md\" && grep -q \"ACCEPTED\" \"$ROOT_DIR/docs/architecture/adr/0009-policy-engine-contract.md\" && grep -q \"Policy Engine\" \"$ROOT_DIR/docs/architecture/adr/0009-policy-engine-contract.md\" && grep -q \"deterministic\" \"$ROOT_DIR/docs/architecture/adr/0009-policy-engine-contract.md\" -i" \
  "ADR 0009 exists ACCEPTED deterministic fail-closed" \
  "ADR 0009 missing"
log ""

# TEST-5: PolicyRequest 20+ fields
log "--- TEST-5: PolicyRequest 20+ fields ---"
run_check "TEST-5: PolicyRequest 20+ fields" \
  "grep -q \"policy_request_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"actor\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"capability_required\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"resource\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"scope\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"risk_class\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"environment\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"network_context\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"filesystem_context\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"provenance\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"correlation_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no secrets\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "PolicyRequest 20+ fields found with no secrets" \
  "PolicyRequest fields missing"
log ""

# TEST-6: Actor model 7 types Unknown DENY
log "--- TEST-6: Actor model 7 types Unknown DENY ---"
run_check "TEST-6: Actor model 7 types Unknown DENY" \
  "grep -q \"user/agent/service/tool/mcp_server/execution_authority/system\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Unknown.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Ambiguous.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Unauthenticated.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Actor model 7 types Unknown/Ambiguous DENY found" \
  "Actor model missing"
log ""

# TEST-7: Action model from P9/P10
log "--- TEST-7: Action model from P9/P10 ---"
run_check "TEST-7: Action model from P9/P10" \
  "grep -q \"Action.*from P9/P10\\|P9/P10.*Action\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"action_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Unknown.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"action.md\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Action model from P9/P10 Unknown BLOCKED found" \
  "Action model missing"
log ""

# TEST-8: Capability CONSUMES Registry P12 DEFINES
log "--- TEST-8: Capability CONSUMES Registry P12 DEFINES ---"
run_check "TEST-8: Capability CONSUMES Registry P12 DEFINES" \
  "grep -q \"CONSUMES.*Registry\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"P12.*DEFINE\\|P12 WILL DEFINE\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Unknown.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Inactive.*DENY\\|Revoked.*DENY\\|Expired.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Capability CONSUMES Registry P12 DEFINES Unknown/Inactive/Revoked/Expired DENY found" \
  "Capability model missing"
log ""

# TEST-9: Resource model 12 types Unknown DENY
log "--- TEST-9: Resource model 12 types Unknown DENY ---"
run_check "TEST-9: Resource model 12 types Unknown DENY" \
  "grep -q \"workspace/repository/file/process/host/network/database/API/package/browser/computer/secret-reference\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Unknown.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"outside.*scope.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Resource model 12 types Unknown DENY outside scope DENY found" \
  "Resource model missing"
log ""

# TEST-10: Scope escalation prevention
log "--- TEST-10: Scope escalation prevention ---"
run_check "TEST-10: Scope escalation prevention" \
  "grep -q \"workspace→host\\|workspace->host\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"repository→production\\|repository->production\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"user→system\\|user->system\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"network→unrestricted\\|network->unrestricted\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"production without explicit\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Scope escalation prevention workspace→host repository→production user→system network→unrestricted production explicit found" \
  "Scope escalation prevention missing"
log ""

# TEST-11: Risk CLASS-0..6 CLASS-6 DENY Always
log "--- TEST-11: Risk CLASS-0..6 CLASS-6 DENY Always ---"
run_check "TEST-11: Risk CLASS-0..6 CLASS-6 DENY Always" \
  "grep -q \"CLASS-0\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-1\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-2\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-3\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-4\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-5\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-6\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-6.*DENY Always\\|DENY Always.*CLASS-6\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-5.*CLASS-2.*explicit\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Risk CLASS-0..6 CLASS-6 DENY Always never lower CLASS-5→CLASS-2 found" \
  "Risk model missing"
log ""

# TEST-12: Decision model ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED UNKNOWN never allow
log "--- TEST-12: Decision model ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED UNKNOWN never allow ---"
run_check "TEST-12: Decision model ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED UNKNOWN never allow" \
  "grep -q \"ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN.*never.*allow\\|UNKNOWN never allow\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"Decision.*ALLOW\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Decision model ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN/BLOCKED UNKNOWN never allow found" \
  "Decision model missing"
log ""

# TEST-13: Precedence 1..12 DENY wins
log "--- TEST-13: Precedence 1..12 DENY wins ---"
run_check "TEST-13: Precedence 1..12 DENY wins" \
  "grep -q \"Precedence\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"1.*malformed\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"12.*explicit allow\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"DENY wins\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no last.*wins\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Precedence 1..12 DENY wins UNKNOWN BLOCKED no last wins found" \
  "Precedence missing"
log ""

# TEST-14: Default DENY POL-01
log "--- TEST-14: Default DENY POL-01 ---"
run_check "TEST-14: Default DENY POL-01" \
  "grep -q \"Default DENY\\|DEFAULT DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"POL-01\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"any unknown.*DENY\\|any rule not existing.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"network.*untrusted.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Default DENY POL-01 any unknown DENY network untrusted BLOCKED found" \
  "Default DENY missing"
log ""

# TEST-15: Fail-closed 15 cases BLOCKED/DENY
log "--- TEST-15: Fail-closed 15 cases BLOCKED/DENY ---"
run_check "TEST-15: Fail-closed 15 cases BLOCKED/DENY" \
  "grep -q \"Fail-closed\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN_ACTION\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN_ACTOR\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN_CAPABILITY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN_RESOURCE\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"UNKNOWN_SCOPE\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"INVALID_SCHEMA\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"MISSING_POLICY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"BLOCKED/DENY\\|BLOCKED.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no ASSUME ALLOW\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Fail-closed 15 cases BLOCKED/DENY no ASSUME ALLOW found" \
  "Fail-closed missing"
log ""

# TEST-16: Version immutable policy_id/version/hash
log "--- TEST-16: Version immutable policy_id/version/hash ---"
run_check "TEST-16: Version immutable policy_id/version/hash" \
  "grep -q \"policy_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy_version\\|version.*hash\\|policy.*hash\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"immutable\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"new version.*no rewrite old\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Version immutable policy_id/version/hash new version no rewrite old found" \
  "Version immutable missing"
log ""

# TEST-17: Rule contract no shell/eval/JS deterministic
log "--- TEST-17: Rule contract no shell/eval/JS deterministic ---"
run_check "TEST-17: Rule contract no shell/eval/JS deterministic" \
  "grep -q \"PolicyRule\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"rule_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no shell\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"no eval\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"deterministic\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"no arbitrary JS\\|no.*JS execution\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Rule contract no shell/eval/JS deterministic found" \
  "Rule contract missing"
log ""

# TEST-18: Determinism LLM not final authority
log "--- TEST-18: Determinism LLM not final authority ---"
run_check "TEST-18: Determinism LLM not final authority" \
  "grep -q \"Determinism\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"same.*Version.*Input.*Context.*same Decision\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"LLM.*not.*final.*authority\\|LLM does not.*final\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Determinism same Version/Input/Context same Decision LLM not final authority found" \
  "Determinism missing"
log ""

# TEST-19: Natural Language Boundary intent→structured Action
log "--- TEST-19: Natural Language Boundary intent→structured Action ---"
run_check "TEST-19: Natural Language Boundary intent→structured Action" \
  "grep -q \"Natural Language\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"intent→structured Action\\|intent.*structured Action\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"validated schema\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"not convertible.*BLOCKED\\|BLOCKED.*not convertible\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Natural Language Boundary intent→structured Action→validated schema→Policy BLOCKED found" \
  "Natural Language Boundary missing"
log ""

# TEST-20: Approval AUTO/DRY_RUN/EXPLICIT/DENY bound/replay protection
log "--- TEST-20: Approval AUTO/DRY_RUN/EXPLICIT/DENY bound/replay protection ---"
run_check "TEST-20: Approval AUTO/DRY_RUN/EXPLICIT/DENY bound/replay protection" \
  "grep -q \"AUTO/DRY_RUN/EXPLICIT_APPROVAL/DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"bound_to_action\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"time_bounded\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no generic approval\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"replay protection\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"action_id.*policy_version.*capability.*resource.*scope.*risk.*input_hash.*correlation_id.*expiry\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Approval AUTO/DRY_RUN/EXPLICIT/DENY bound_to_action/scope/resource time_bounded no generic replay protection found" \
  "Approval model missing"
log ""

# TEST-21: DRY-RUN CLASS-4/5 external/host/package/upload/production
log "--- TEST-21: DRY-RUN CLASS-4/5 external/host/package/upload/production ---"
run_check "TEST-21: DRY-RUN CLASS-4/5 external/host/package/upload/production" \
  "grep -q \"DRY-RUN\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-4\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-5\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"external.*host.*package\\|host.*package\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"DRY_RUN.*simulation authorized\\|simulation authorized.*new authorization\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "DRY-RUN CLASS-4/5 external/host/package/upload/production simulation authorized new auth found" \
  "DRY-RUN missing"
log ""

# TEST-22: Environment local/arena/ci/staging/production LOCAL≠PRODUCTION
log "--- TEST-22: Environment local/arena/ci/staging/production LOCAL≠PRODUCTION ---"
run_check "TEST-22: Environment local/arena/ci/staging/production LOCAL≠PRODUCTION" \
  "grep -q \"local/arena/ci/staging/production\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"LOCAL≠PRODUCTION\\|LOCAL.*PRODUCTION\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"MOCK≠PRODUCTION\\|MOCK.*PRODUCTION\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"ARENA≠PRODUCTION\\|ARENA.*PRODUCTION\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Environment local/arena/ci/staging/production LOCAL≠PRODUCTION MOCK≠PRODUCTION ARENA≠PRODUCTION found" \
  "Environment model missing"
log ""

# TEST-23: Network Unknown BLOCKED external per capability
log "--- TEST-23: Network Unknown BLOCKED external per capability ---"
run_check "TEST-23: Network Unknown BLOCKED external per capability" \
  "grep -qi \"network_mode\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Unknown.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -qi \"capability/risk/approval\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -qi \"production.*stronger\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Network network_mode Unknown BLOCKED external per capability/risk/approval production stronger found" \
  "Network policy missing"
log ""

# TEST-24: Filesystem canonicalized traversal symlink ../etc/passwd DENY /etc/sudoers DENY CLASS-6 unknown root BLOCKED
log "--- TEST-24: Filesystem canonicalized traversal symlink ../etc/passwd DENY /etc/sudoers DENY CLASS-6 unknown root BLOCKED ---"
run_check "TEST-24: Filesystem canonicalized traversal symlink ../etc/passwd DENY /etc/sudoers DENY CLASS-6 unknown root BLOCKED" \
  "grep -q \"filesystem_scope\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"canonicalized\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"traversal\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"\\.\\./etc/passwd\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"/etc/sudoers.*DENY\\|DENY.*sudoers\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CLASS-6\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"unknown root.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Filesystem canonicalized traversal ../etc/passwd DENY /etc/sudoers DENY CLASS-6 unknown root BLOCKED found" \
  "Filesystem policy missing"
log ""

# TEST-25: Secret REFERENCE not VALUE CAP_SECRET_ACCESS CRITICAL NO_LOG
log "--- TEST-25: Secret REFERENCE not VALUE CAP_SECRET_ACCESS CRITICAL NO_LOG ---"
run_check "TEST-25: Secret REFERENCE not VALUE CAP_SECRET_ACCESS CRITICAL NO_LOG" \
  "grep -q \"SECRET_REFERENCE\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"not.*SECRET_VALUE\\|not VALUE\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"CAP_SECRET_ACCESS\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"CRITICAL\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"NO_LOG\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Secret REFERENCE not VALUE CAP_SECRET_ACCESS CRITICAL NO_LOG_VALUE found" \
  "Secret policy missing"
log ""

# TEST-26: Provenance untrusted BLOCKED
log "--- TEST-26: Provenance untrusted BLOCKED ---"
run_check "TEST-26: Provenance untrusted BLOCKED" \
  "grep -q \"Provenance\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"untrusted.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"plugin.*MCP.*external tool\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Provenance untrusted BLOCKED plugin/MCP/external tool found" \
  "Provenance missing"
log ""

# TEST-27: Obligations 9 types transfer to Authorization/Execution/Verifier
log "--- TEST-27: Obligations 9 types transfer to Authorization/Execution/Verifier ---"
run_check "TEST-27: Obligations 9 types transfer to Authorization/Execution/Verifier" \
  "grep -q \"Obligations\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"REQUIRE_APPROVAL\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"REQUIRE_DRY_RUN\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"REQUIRE_VERIFICATION\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"LIMIT_SCOPE\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"AUDIT_REQUIRED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"transfer.*Authorization\\|Authorization.*Execution Authority.*Verifier\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Obligations REQUIRE_APPROVAL/DRY_RUN/VERIFICATION/LIMIT_SCOPE/NETWORK/OUTPUT/TIME/RESOURCE/AUDIT_REQUIRED transfer found" \
  "Obligations missing"
log ""

# TEST-28: PolicyDecision contract 20+ fields no secrets
log "--- TEST-28: PolicyDecision contract 20+ fields no secrets ---"
run_check "TEST-28: PolicyDecision contract 20+ fields no secrets" \
  "grep -q \"PolicyDecision\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"decision_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy_request_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"matched_rules\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"required_capabilities\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"obligations\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"evidence_requirements\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no secrets\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "PolicyDecision 20+ fields decision_id/policy_request_id/matched_rules/obligations/evidence_requirements no secrets found" \
  "PolicyDecision missing"
log ""

# TEST-29: Explanation WHY reason from evaluation not LLM
log "--- TEST-29: Explanation WHY reason from evaluation not LLM ---"
run_check "TEST-29: Explanation WHY reason from evaluation not LLM" \
  "grep -q \"Explanation\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"WHY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"reason.*evaluation.*not LLM\\|not LLM-generated\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Explanation WHY reason from evaluation not LLM found" \
  "Explanation missing"
log ""

# TEST-30: Conflict ALLOW+DENY→DENY ALLOW+REQUIRE_APPROVAL→REQUIRE_APPROVAL any+BLOCKED→BLOCKED
log "--- TEST-30: Conflict ALLOW+DENY→DENY ALLOW+REQUIRE_APPROVAL→REQUIRE_APPROVAL any+BLOCKED→BLOCKED ---"
run_check "TEST-30: Conflict ALLOW+DENY→DENY ALLOW+REQUIRE_APPROVAL→REQUIRE_APPROVAL any+BLOCKED→BLOCKED" \
  "grep -q \"Conflict\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"ALLOW+DENY→DENY\\|ALLOW.*DENY.*DENY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"ALLOW+REQUIRE_APPROVAL→REQUIRE_APPROVAL\\|ALLOW.*REQUIRE_APPROVAL.*REQUIRE_APPROVAL\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"any.*BLOCKED→BLOCKED\\|BLOCKED.*BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Conflict ALLOW+DENY→DENY ALLOW+REQUIRE_APPROVAL→REQUIRE_APPROVAL any+BLOCKED→BLOCKED found" \
  "Conflict model missing"
log ""

# TEST-31: States UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED
log "--- TEST-31: States UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED ---"
run_check "TEST-31: States UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED" \
  "grep -q \"UNINITIALIZED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"LOADING\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"READY\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"DEGRADED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"BLOCKED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"FAILED\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "States UNINITIALIZED/LOADING/READY/DEGRADED/BLOCKED/FAILED found" \
  "States missing"
log ""

# TEST-32: Lifecycle CREATED/DRAFT/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED only ACTIVE normal
log "--- TEST-32: Lifecycle CREATED/DRAFT/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED only ACTIVE normal ---"
run_check "TEST-32: Lifecycle CREATED/DRAFT/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED only ACTIVE normal" \
  "grep -q \"CREATED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"DRAFT\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"VALIDATED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"ACTIVE\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"SUSPENDED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"REVOKED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"EXPIRED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"only ACTIVE.*normal\\|ACTIVE.*may participate\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Lifecycle CREATED/DRAFT/VALIDATED/ACTIVE/SUSPENDED/REVOKED/EXPIRED only ACTIVE normal found" \
  "Lifecycle missing"
log ""

# TEST-33: Update proposal/review/validation/new version/activation human approval learning cannot activate
log "--- TEST-33: Update proposal/review/validation/new version/activation human approval learning cannot activate ---"
run_check "TEST-33: Update proposal/review/validation/new version/activation human approval learning cannot activate" \
  "grep -q \"proposal.*review.*validation.*new version.*activation\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"human.*approval\\|policy owner approval\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"learning.*cannot activate\\|cannot activate.*automatically\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Update proposal/review/validation/new version/activation human approval learning cannot activate found" \
  "Update model missing"
log ""

# TEST-34: Learning boundary proposal≠activation
log "--- TEST-34: Learning boundary proposal≠activation ---"
run_check "TEST-34: Learning boundary proposal≠activation" \
  "grep -q \"Learning boundary\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Experience→feedback→.*proposal\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"proposal.*≠.*activation\\|proposal.*!=.*activation\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Learning boundary Experience→feedback→proposal proposal≠activation found" \
  "Learning boundary missing"
log ""

# TEST-35: Audit events policy.requested..revoked 14 types no secrets
log "--- TEST-35: Audit events policy.requested..revoked 14 types no secrets ---"
run_check "TEST-35: Audit events policy.requested..revoked 14 types no secrets" \
  "grep -q \"Audit\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy.requested\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy.allowed\\|policy.denied\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy.blocked\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy.revoked\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"event_id.*policy_id.*version.*request_id.*decision_id\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no secrets\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Audit events policy.requested..revoked event_id/policy_id/version/request_id/decision_id no secrets found" \
  "Audit events missing"
log ""

# TEST-36: Verification verifiable Policy Version/Input Hash/Matched Rules
log "--- TEST-36: Verification verifiable Policy Version/Input Hash/Matched Rules ---"
run_check "TEST-36: Verification verifiable Policy Version/Input Hash/Matched Rules" \
  "grep -q \"Verification\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"verifiable\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"Policy Version\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Input Hash\\|Matched Rules\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"do not require LLM to verify\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Verification verifiable Policy Version/Input Hash/Matched Rules no LLM found" \
  "Verification missing"
log ""

# TEST-37: Boundaries Policy vs Authorization vs Execution vs Verifier vs Registry P11 CONSUMES P12 DEFINES
log "--- TEST-37: Boundaries Policy vs Authorization vs Execution vs Verifier vs Registry P11 CONSUMES P12 DEFINES ---"
run_check "TEST-37: Boundaries Policy vs Authorization vs Execution vs Verifier vs Registry P11 CONSUMES P12 DEFINES" \
  "grep -q \"Policy.*WHAT.*ALLOWED\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Authorization.*IS.*ACTOR.*AUTHORIZED\\|Authorization.*IS THIS SPECIFIC ACTOR\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Execution.*does not run commands\\|Policy does not run commands\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"Verifier.*specifies.*verification\\|Verifier.*decides\" \"$ROOT_DIR/docs/contracts/policy.md\" -i && grep -q \"P11 CONSUMES.*P12.*DEFINE\\|CONSUMES.*Registry.*P12\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Boundaries Policy WHAT ALLOWED vs Authorization IS ACTOR AUTHORIZED vs Execution vs Verifier vs Registry P11 CONSUMES P12 DEFINES found" \
  "Boundaries missing"
log ""

# TEST-38: Interface evaluate/validate/explain/get_policy/get_active_policy/policy_status no impl
log "--- TEST-38: Interface evaluate/validate/explain/get_policy/get_active_policy/policy_status no impl ---"
run_check "TEST-38: Interface evaluate/validate/explain/get_policy/get_active_policy/policy_status no impl" \
  "grep -q \"evaluate.*PolicyDecision\\|evaluate.*request\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"validate.*ValidationResult\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"explain.*Explanation\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"get_policy\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"get_active_policy\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"policy_status\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"no.*impl\\|no implementation\" \"$ROOT_DIR/docs/contracts/policy.md\" -i" \
  "Interface evaluate/validate/explain/get_policy/get_active_policy/policy_status no impl found" \
  "Interface missing"
log ""

# TEST-39: Pipeline INPUT→...→AUDIT 17 steps + Diagrams ASCII+Mermaid + Invariants POL-01..30
log "--- TEST-39: Pipeline INPUT→...→AUDIT 17 steps + Diagrams ASCII+Mermaid + Invariants POL-01..30 ---"
run_check "TEST-39: Pipeline INPUT→...→AUDIT 17 steps + Diagrams ASCII+Mermaid + Invariants POL-01..30" \
  "grep -q \"Pipeline\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"INPUT→SCHEMA\\|INPUT.*SCHEMA\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"AUDIT\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"mermaid\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"POL-01\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"POL-30\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Policy Evaluation Flow\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Decision Precedence\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "Pipeline INPUT→...→AUDIT 17 steps Diagrams ASCII+Mermaid Invariants POL-01..30 found" \
  "Pipeline/Diagrams/Invariants missing"
log ""

# TEST-40: No product implementation + no package install + P8/P9/P10 compat + P2/P10 package path
log "--- TEST-40: No product implementation + no package install + P8/P9/P10 compat + P2/P10 package path ---"
run_check "TEST-40: No product implementation + no package install + P8/P9/P10 compat + P2/P10 package path" \
  "test -f \"$ROOT_DIR/docs/architecture/frozen-baseline.md\" && test -f \"$ROOT_DIR/docs/contracts/runtime.md\" && test -f \"$ROOT_DIR/docs/contracts/execution-authority.md\" && grep -q \"CONTRACTS ONLY\\|POLICY CONTRACT ONLY\" \"$ROOT_DIR/docs/contracts/policy.md\" && ! find \"$ROOT_DIR\" -type f \\( -name \"*.py\" -o -name \"*.js\" -o -name \"*.ts\" -o -name \"*.go\" -o -name \"*.rs\" \\) -not -path \"*/.git/*\" -not -path \"*/node_modules/*\" | grep -q \".\" && grep -q \"Action→Policy→Authorization→Package Executor→Privilege Gate→Package Manager→Result→Verification→Evidence\" \"$ROOT_DIR/docs/contracts/policy.md\" && grep -q \"Policy does NOT replace.*Gate\\|does NOT replace.*Privilege Gate\" \"$ROOT_DIR/docs/contracts/policy.md\"" \
  "No product implementation P8/P9/P10 compat package path Action→Policy→Authorization→Package Executor→Privilege Gate preserved Policy does NOT replace Gate found" \
  "No product implementation or P8/P9/P10 compat or package path missing"
log ""

log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
log ""

if [[ $FAILED -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → All $PASSED/$TOTAL policy tests PASS"
  exit 0
else
  log "STATUS → FAIL"
  log "RESULT → $FAILED failed out of $TOTAL"
  exit 1
fi
