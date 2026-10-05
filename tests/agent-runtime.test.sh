#!/usr/bin/env bash
# LINEX.OS AGENT RUNTIME CONTRACT TESTS - P13
# Verifies contracts and acceptance vectors only; no Agent runtime is implemented or simulated.
# Repository-only: no package installation, network access, or system changes.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOTAL=0
PASSED=0
FAILED=0

pass() {
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
  printf '%-68s → PASS (%s)\n' "$1" "$2"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  printf '%-68s → FAIL (%s)\n' "$1" "$2" >&2
}

check() {
  local name="$1" detail="$2" function_name="$3"
  if "$function_name"; then
    pass "$name" "$detail"
  else
    fail "$name" "check function $function_name failed"
  fi
}

has_fixed() { grep -Fq -- "$1" "$2"; }

extract_json_contract_block() {
  local section="$1"
  awk -v section="$section" '
    $0 == section { section_found=1; next }
    section_found && /^```json$/ { in_json=1; next }
    in_json && /^```$/ { exit }
    in_json { print }
  ' "$ROOT_DIR/docs/contracts/agent-runtime.md"
}

check_contract_files() {
  [[ -s "$ROOT_DIR/docs/contracts/agent-runtime.md" &&
    -s "$ROOT_DIR/docs/contracts/agent-lifecycle.md" &&
    -s "$ROOT_DIR/docs/contracts/agent-audit.md" &&
    -s "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" ]]
}

check_adr_accepted() {
  has_fixed 'Status: ACCEPTED' "$ROOT_DIR/docs/architecture/adr/0012-agent-runtime-contract.md" &&
    has_fixed 'Agent Runtime Contract (P13)' "$ROOT_DIR/docs/architecture/adr/0012-agent-runtime-contract.md"
}

check_p9_p12_boundaries() {
  local contract="$ROOT_DIR/docs/contracts/agent-runtime.md"
  for ref in 'P9' 'P10' 'P11' 'P12' 'frozen-baseline.md'; do
    has_fixed "$ref" "$contract" || return 1
  done
}

check_descriptor_fields() {
  local contract="$ROOT_DIR/docs/contracts/agent-runtime.md"
  for field in 'agent_id' 'version' 'role' 'capability_refs' 'context_ref' 'planner_ref' 'tool_refs' 'memory_refs' 'policy_ref' 'evidence_requirements' 'correlation_id'; do
    has_fixed "\"$field\"" "$contract" || return 1
  done
}

check_descriptor_schemas_parse() {
  local descriptor response
  descriptor="$(extract_json_contract_block '## Agent descriptor')"
  response="$(extract_json_contract_block '## Invocation and result boundary')"
  [[ -n "$descriptor" && -n "$response" ]] || return 1
  jq -e '
    type == "object" and
    has("agent_id") and has("version") and has("role") and has("scope") and
    has("capability_refs") and has("context_ref") and has("planner_ref") and
    has("tool_refs") and has("memory_refs") and has("policy_ref") and
    has("evidence_requirements") and has("correlation_id") and
    (.trust_level | startswith("semi_trusted"))
  ' <<< "$descriptor" >/dev/null || return 1
  jq -e '
    type == "object" and has("agent_id") and has("task_id") and has("run_id") and
    has("outcome") and has("action_id") and has("decision_ref") and
    has("reason_code") and has("correlation_id") and
    (.outcome | contains("ACTION_PROPOSED")) and
    (.outcome | contains("NEEDS_CLARIFICATION")) and
    (.outcome | contains("REJECTED")) and
    (.outcome | contains("BLOCKED"))
  ' <<< "$response" >/dev/null
}

check_planner_never_executes() {
  local contract="$ROOT_DIR/docs/contracts/agent-runtime.md"
  has_fixed 'The Planner **proposes; it never executes**.' "$contract" &&
    has_fixed 'No LLM, Planner, or Agent calls a shell, process, file, network, package, browser, computer, or MCP executor directly' "$contract" &&
    has_fixed 'Execution Authority' "$contract"
}

check_natural_language_not_authority() {
  has_fixed 'Natural-language intent is not permission' "$ROOT_DIR/docs/contracts/agent-runtime.md" &&
    has_fixed 'schema-valid P9 Action' "$ROOT_DIR/docs/contracts/agent-runtime.md"
}

check_no_self_grant_or_automatic_escalation() {
  local contract="$ROOT_DIR/docs/contracts/agent-runtime.md"
  has_fixed 'cannot create, widen, delegate, activate, or self-grant a P12 capability' "$contract" &&
    has_fixed 'No automatic routing to a more privileged agent is allowed' "$contract"
}

check_existing_policy_decisions() {
  local lifecycle="$ROOT_DIR/docs/contracts/agent-lifecycle.md"
  for decision in 'ALLOW' 'DENY' 'REQUIRE_APPROVAL' 'DRY_RUN' 'BLOCKED'; do
    has_fixed "$decision" "$lifecycle" || return 1
  done
  has_fixed 'P11 `ALLOW` is not `AUTHORIZED`' "$lifecycle" &&
    has_fixed '`APPROVED`' "$lifecycle"
}

check_full_lifecycle_and_mermaid() {
  local lifecycle="$ROOT_DIR/docs/contracts/agent-lifecycle.md"
  has_fixed 'stateDiagram-v2' "$lifecycle" &&
    has_fixed 'sequenceDiagram' "$lifecycle" &&
    has_fixed 'RECEIVED --> VALIDATING' "$lifecycle" &&
    has_fixed 'VALIDATING --> PLANNING' "$lifecycle" &&
    has_fixed 'PLANNING --> ACTION_PROPOSED' "$lifecycle" &&
    has_fixed 'ACTION_PROPOSED --> WAITING_POLICY' "$lifecycle" &&
    has_fixed 'WAITING_POLICY --> WAITING_AUTHORIZATION' "$lifecycle" &&
    has_fixed 'WAITING_AUTHORIZATION --> EXECUTING' "$lifecycle" &&
    has_fixed 'EXECUTING --> VERIFYING' "$lifecycle" &&
    has_fixed 'VERIFYING --> COMPLETED' "$lifecycle" &&
    has_fixed 'P9 Run is VERIFIED and evidence exists' "$lifecycle"
}

check_approval_is_rechecked() {
  has_fixed 'approval recorded; obtain a fresh P11 decision' "$ROOT_DIR/docs/contracts/agent-lifecycle.md" &&
    has_fixed 'No execution is authorized until approval is recorded and P11 re-evaluates the Action.' "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml"
}

check_audit_requirements() {
  local audit="$ROOT_DIR/docs/contracts/agent-audit.md"
  for required in 'append interface' 'event_id' 'timestamp' 'actor' 'correlation_id' 'reason_code' 'decision_ref' 'Never put credentials' 'P9 Evidence'; do
    has_fixed "$required" "$audit" || return 1
  done
}

check_no_false_tamper_proof_claim() {
  has_fixed 'not a claim that a deployed log is physically undeletable' "$ROOT_DIR/docs/contracts/agent-audit.md" &&
    has_fixed 'No claim of a digital signature, hash chain, write-once medium, or tamper-proof storage' "$ROOT_DIR/docs/contracts/agent-audit.md"
}

check_vectors_parse_and_shape() {
  local vectors="$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml"
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '
    .phase == "P13" and
    .schema_version == "1.0.0" and
    (.cases | type == "array" and length >= 5) and
    ([.cases[].id] as $ids | ($ids | length) == ($ids | unique | length)) and
    all(.cases[];
      (.id | test("^TC-P13-[0-9]{2}$")) and
      (.acceptance_criterion | type == "string" and length > 0) and
      (.given | type == "string" and length > 0) and
      (.when | type == "string" and length > 0) and
      (.expected | type == "object") and
      (.primary_assertion | type == "string" and length > 0)
    )
  ' "$vectors" >/dev/null
}

check_required_scenarios() {
  jq -e '
    [.cases[].category] as $categories |
    ["valid-proposal", "clarification", "capability-boundary", "approval-boundary",
     "verified-lifecycle", "rejection-audit", "fail-closed", "untrusted-context"] as $required |
    all($required[]; . as $category | $categories | index($category) != null)
  ' "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_single_primary_assertion() {
  jq -e 'all(.cases[]; (.primary_assertion | type == "string") and ((.assertions? // []) | length == 0))' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_01() {
  jq -e '.cases[] | select(.id == "TC-P13-01") |
    .expected.agent_outcome == "ACTION_PROPOSED" and .expected.p9_action_state == "PROPOSED"' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_02() {
  jq -e '.cases[] | select(.id == "TC-P13-02") |
    .expected.agent_outcome == "NEEDS_CLARIFICATION" and .expected.action_proposed == false' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_03() {
  jq -e '.cases[] | select(.id == "TC-P13-03") |
    .expected.authoritative_decision == "DENY" and .expected.execution_authorized == false' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_04() {
  jq -e '.cases[] | select(.id == "TC-P13-04") |
    .expected.invocation_state == "WAITING_APPROVAL" and
    .expected.p11_decision == "REQUIRE_APPROVAL" and .expected.execution_authorized == false' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_05() {
  jq -e '.cases[] | select(.id == "TC-P13-05") |
    .expected.invocation_state == "COMPLETED" and .expected.p9_run_state == "VERIFIED" and
    .expected.evidence_reference == "required"' "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_06() {
  jq -e '.cases[] | select(.id == "TC-P13-06") |
    .expected.event_type == "agent.rejected" and .expected.raw_secret_payload == false and
    (["event_id", "timestamp", "actor.id", "task.id", "payload.reason_code", "payload.decision_ref", "correlation_id"] - .expected.required_references | length == 0)' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_07() {
  jq -e '.cases[] | select(.id == "TC-P13-07") |
    .expected.agent_outcome == "BLOCKED" and .expected.execution_authorized == false' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_case_08() {
  jq -e '.cases[] | select(.id == "TC-P13-08") |
    .expected.context_trust == "UNTRUSTED_DATA" and .expected.direct_executor_call == false' \
    "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

check_agent_trust_class() {
  has_fixed '"trust_level": "semi_trusted"' "$ROOT_DIR/docs/contracts/agent-runtime.md" &&
    has_fixed 'the Agent Runtime is `semi_trusted`' "$ROOT_DIR/docs/contracts/agent-runtime.md"
}

check_acceptance_vectors_are_not_runtime_simulations() {
  has_fixed 'no Agent Runtime implementation is simulated' "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" &&
    has_fixed 'contract checks, not simulations of an unimplemented runtime' "$ROOT_DIR/docs/contracts/agent-runtime.md"
}

check_no_implementation_choice() {
  local adr="$ROOT_DIR/docs/architecture/adr/0012-agent-runtime-contract.md"
  has_fixed 'before P18' "$adr" &&
    has_fixed 'No Agent code, LLM integration' "$adr"
}

check_ci_wiring() {
  has_fixed './tests/agent-runtime.test.sh' "$ROOT_DIR/.github/workflows/ci.yml" &&
    has_fixed './ops/verify/verify-agent-runtime.sh' "$ROOT_DIR/.github/workflows/ci.yml"
}

printf 'LINEX.OS AGENT RUNTIME CONTRACT TESTS - P13\n'
printf 'Timestamp: %s\nRoot: %s\n\n' "$TIMESTAMP" "$ROOT_DIR"

check 'P13 contract deliverables exist' 'runtime, lifecycle, audit, and structured acceptance vectors are present' check_contract_files
check 'ADR 0012 is accepted' 'P13 decision record exists and is ACCEPTED' check_adr_accepted
check 'P9-P12 and P8 freeze are referenced' 'P13 consumes existing contracts without redefining them' check_p9_p12_boundaries
check 'Agent descriptor contains required references' 'identity, role, scope, capabilities, context, planner, tools, memory, policy, evidence' check_descriptor_fields
check 'Agent descriptor and response examples are valid JSON' 'jq parses both contract schema fragments and checks required fields' check_descriptor_schemas_parse
check 'Agent Runtime remains semi-trusted' 'Agent trust cannot be self-promoted to trusted' check_agent_trust_class
check 'Planner and Agent never execute directly' 'all side effects stay behind P10 Execution Authority' check_planner_never_executes
check 'Natural-language intent is not authority' 'intent must become a schema-valid P9 Action' check_natural_language_not_authority
check 'No self-grant or automatic privilege escalation' 'P12 owns capability grants and delegation' check_no_self_grant_or_automatic_escalation
check 'P11 decision vocabulary is preserved' 'ALLOW is not AUTHORIZED; approval is not an Agent state' check_existing_policy_decisions
check 'Invocation lifecycle and interaction diagram exist' 'Mermaid flow covers proposal through verified completion' check_full_lifecycle_and_mermaid
check 'Approval is re-evaluated' 'REQUIRE_APPROVAL cannot flow directly to execution' check_approval_is_rechecked
check 'Audit envelope and rejection evidence are specified' 'P9 event fields, reason, decision reference, correlation, no secrets' check_audit_requirements
check 'Audit claims match contract-only evidence' 'append-only interface is not represented as deployed tamper-proof storage' check_no_false_tamper_proof_claim
check 'Structured acceptance vectors parse and are well formed' 'jq validates YAML 1.2 JSON-compatible subset and unique single assertions' check_vectors_parse_and_shape
check 'All required acceptance scenarios are present' 'eight independent vectors cover positive, ambiguity, authority, approval, lifecycle, audit, fail-closed, untrusted context' check_required_scenarios
check 'Each vector has one primary assertion' 'no compound assertion list is declared' check_single_primary_assertion
check 'TC-P13-01 accepts only a typed proposal' 'P9 Action remains PROPOSED' check_case_01
check 'TC-P13-02 clarifies ambiguous requests' 'no Action is proposed for unresolved ambiguity' check_case_02
check 'TC-P13-03 rejects capability scope expansion' 'DENY cannot authorize execution' check_case_03
check 'TC-P13-04 waits for bound approval' 'REQUIRE_APPROVAL is not execution authorization' check_case_04
check 'TC-P13-05 requires verified evidence' 'completion follows P9 Run VERIFIED' check_case_05
check 'TC-P13-06 audits rejection safely' 'reason, correlation, decision refs; no secret payload' check_case_06
check 'TC-P13-07 blocks unknown authority inputs' 'unknown policy/capability never reaches an Executor' check_case_07
check 'TC-P13-08 treats prompt injection as untrusted data' 'no direct executor call or policy override' check_case_08
check 'Acceptance vectors do not imply runtime execution' 'tests verify contract definitions only' check_acceptance_vectors_are_not_runtime_simulations
check 'P13 does not select technology or implement an Agent' 'P18 decision gate and no-code boundary are preserved' check_no_implementation_choice
check 'P13 verification is wired into CI' 'CI runs the contract tests and verifier' check_ci_wiring

printf '\nTOTAL: %s\nPASSED: %s\nFAILED: %s\n' "$TOTAL" "$PASSED" "$FAILED"
if [[ $FAILED -eq 0 ]]; then
  printf 'STATUS → PASS\nRESULT → All P13 contract tests PASS (contract-only evidence)\n'
  exit 0
fi
printf 'STATUS → FAIL\nRESULT → %s P13 contract test(s) failed\n' "$FAILED"
exit 1
