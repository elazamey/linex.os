#!/usr/bin/env bash
# LINEX.OS TOOL + SKILL CONTRACT TESTS - P14
# Verifies contracts, JSON Schemas, and structured acceptance vectors only.
# No Tool or Skill runtime is implemented or simulated, and no executor is invoked.
# Repository-only: no package installation, no network access, no system changes.
#
# JSON Schema validation is delegated to an external, pinned validator when one is
# available (see docs/architecture/adr/0013-tool-skill-contract.md). When no validator
# is installed this suite reports explicit BLOCKED evidence for the schema group and
# never reports it as PASS.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOTAL=0
PASSED=0
FAILED=0
SCHEMA_GROUP="BLOCKED"
SCHEMA_GROUP_NOTE="no validator installed - JSON Schema meta/instance validation not performed"

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

CONTRACTS="$ROOT_DIR/docs/contracts"
TOOL_MD="$CONTRACTS/tool.md"
SKILL_MD="$CONTRACTS/skill.md"
TOOL_SCHEMA="$CONTRACTS/tool-schema.yaml"
SKILL_SCHEMA="$CONTRACTS/skill-schema.yaml"
VECTORS="$CONTRACTS/tool-skill-acceptance-tests.yaml"
EXAMPLES="$CONTRACTS/tool-skill-examples.yaml"
ADR="$ROOT_DIR/docs/architecture/adr/0013-tool-skill-contract.md"

extract_json_contract_block() {
  local file="$1" section="$2"
  awk -v section="$section" '
    $0 == section { section_found=1; next }
    section_found && /^```json$/ { in_json=1; next }
    in_json && /^```$/ { exit }
    in_json { print }
  ' "$file"
}

# ---------------------------------------------------------------- validator adapter

discover_validator() {
  if [[ -n "${LINEX_JSONSCHEMA_BIN:-}" && -x "${LINEX_JSONSCHEMA_BIN}" ]]; then
    printf '%s' "$LINEX_JSONSCHEMA_BIN"
    return 0
  fi
  local candidate
  for candidate in jsonschema check-jsonschema; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

VALIDATOR_BIN="$(discover_validator || true)"

validator_kind() {
  case "$(basename "${VALIDATOR_BIN:-unknown}")" in
    check-jsonschema) printf 'check-jsonschema' ;;
    jsonschema) printf 'jsonschema' ;;
    *) printf 'unknown' ;;
  esac
}

find_bundled_meta_schema() {
  if [[ -n "${LINEX_P14_META_SCHEMA:-}" && -s "${LINEX_P14_META_SCHEMA}" ]]; then
    printf '%s' "$LINEX_P14_META_SCHEMA"
    return 0
  fi
  [[ -n "${VALIDATOR_BIN:-}" ]] || return 1
  local base found
  base="$(cd "$(dirname "$VALIDATOR_BIN")/.." 2>/dev/null && pwd)" || return 1
  found="$(find "$base" -maxdepth 7 -type f -path '*draft202012*' -name 'metaschema.json' 2>/dev/null | head -1)"
  [[ -n "$found" ]] && printf '%s' "$found"
}

validate_instance() { # schema_file instance_file
  local schema_file="$1" instance_file="$2"
  case "$(validator_kind)" in
    check-jsonschema) "$VALIDATOR_BIN" --schemafile "$schema_file" "$instance_file" >/dev/null 2>&1 ;;
    jsonschema) "$VALIDATOR_BIN" -i "$instance_file" "$schema_file" >/dev/null 2>&1 ;;
    *) return 2 ;;
  esac
}

validate_schema_against_metaschema() { # schema_file
  local schema_file="$1" meta
  case "$(validator_kind)" in
    check-jsonschema) "$VALIDATOR_BIN" --check-metaschema "$schema_file" >/dev/null 2>&1 ;;
    jsonschema)
      meta="$(find_bundled_meta_schema || true)"
      [[ -n "$meta" ]] || return 2
      "$VALIDATOR_BIN" -i "$schema_file" "$meta" >/dev/null 2>&1 ;;
    *) return 2 ;;
  esac
}

run_schema_group() {
  [[ -n "${VALIDATOR_BIN:-}" ]] || return 1

  # Meta-schema validation of both P14 schemas (draft 2020-12).
  local meta_state="PASS" schema_file
  for schema_file in "$TOOL_SCHEMA" "$SKILL_SCHEMA"; do
    if validate_schema_against_metaschema "$schema_file"; then
      continue
    else
      meta_state="FAIL"
    fi
  done
  if [[ "$meta_state" == "PASS" ]]; then
    pass "Schemas are valid draft 2020-12 schemas" "meta-schema validation via $(validator_kind)"
  else
    fail "Schemas are valid draft 2020-12 schemas" "meta-schema validation failed or its meta-schema source is unavailable"
    SCHEMA_GROUP="FAIL"
  fi

  # Valid examples must validate; invalid examples must be rejected.
  local tmp instance_file cid schema expect rc valid_ok=0 valid_total=0 invalid_ok=0 invalid_total=0
  tmp="$(mktemp -d)"
  while IFS=$'\t' read -r cid schema expect; do
    jq -c --arg id "$cid" '.schema_cases[] | select(.id == $id) | .instance' "$EXAMPLES" > "$tmp/instance.json"
    if [[ ! -s "$tmp/instance.json" ]]; then
      fail "Example fixture $cid" "instance could not be extracted"
      SCHEMA_GROUP="FAIL"
      continue
    fi
    if validate_instance "$CONTRACTS/$schema" "$tmp/instance.json"; then rc=0; else rc=1; fi
    if [[ "$expect" == "valid" ]]; then
      valid_total=$((valid_total + 1))
      if [[ "$rc" -eq 0 ]]; then valid_ok=$((valid_ok + 1)); fi
    else
      invalid_total=$((invalid_total + 1))
      if [[ "$rc" -ne 0 ]]; then invalid_ok=$((invalid_ok + 1)); fi
    fi
  done < <(jq -r '.schema_cases[] | [.id, .schema, .expect] | @tsv' "$EXAMPLES")

  if [[ "$valid_ok" -eq "$valid_total" && "$valid_total" -gt 0 ]]; then
    pass "Valid schema instances are accepted" "$valid_ok/$valid_total valid fixtures accepted"
  else
    fail "Valid schema instances are accepted" "$valid_ok/$valid_total valid fixtures accepted"
    SCHEMA_GROUP="FAIL"
  fi
  if [[ "$invalid_ok" -eq "$invalid_total" && "$invalid_total" -gt 0 ]]; then
    pass "Invalid schema instances are rejected" "$invalid_ok/$invalid_total invalid fixtures rejected"
  else
    fail "Invalid schema instances are rejected" "$invalid_ok/$invalid_total invalid fixtures rejected"
    SCHEMA_GROUP="FAIL"
  fi
  rm -rf "$tmp"
  return 0
}

# ---------------------------------------------------------- non-schema invariants

INVARIANTS_JQ='
def risk_ord: {"CLASS-0":0,"CLASS-1":1,"CLASS-2":2,"CLASS-3":3,"CLASS-4":4,"CLASS-5":5,"CLASS-6":6}[.];
def inv_linear_chain:
  (.steps | length) as $n
  | [range(0; $n) as $i
     | (.steps[$i].depends_on == (if $i == 0 then null else .steps[$i-1].step_id end))] | all;
def inv_step_ids_unique: (.steps | map(.step_id) | length == (unique | length));
def inv_risk_bound: ((.risk_class | risk_ord) >= ([.steps[].risk_class | risk_ord] | max));
def inv_binding_order:
  . as $s
  | [ $s.steps | to_entries[] as $e
      | $e.value.input_bindings[]?
      | select(.source == "step_output") as $b
      | (($s.steps[0:$e.key] | map(.step_id) | index($b.from_step)) != null) ] | all;
def inv_literal_type_match:
  [ .steps[].input_bindings[]? | select(.source == "literal")
    | (.value | type) as $t
    | (.type as $d
       | if $d == "integer" then ($t == "number" and ((.value | floor) == .value))
         elif $d == "number" then ($t == "number")
         else ($t == $d) end) ] | all;
def inv_step_limits_within_budget:
  . as $s
  | [ $s.steps[] | select(.resource_limits != null)
      | .resource_limits as $l
      | (($l.cpu_seconds <= $s.resource_budget.cpu_seconds)
         and ($l.memory_mb <= $s.resource_budget.memory_mb)
         and ($l.output_bytes <= $s.resource_budget.output_bytes)
         and ($l.process_count <= $s.resource_budget.process_count)
         and ($l.file_descriptors <= $s.resource_budget.file_descriptors)) ] | all;
def invariant($name):
  if   $name == "linear_chain"              then inv_linear_chain
  elif $name == "step_ids_unique"           then inv_step_ids_unique
  elif $name == "risk_bound"                then inv_risk_bound
  elif $name == "binding_order"             then inv_binding_order
  elif $name == "literal_type_match"        then inv_literal_type_match
  elif $name == "step_limits_within_budget" then inv_step_limits_within_budget
  else error("unknown invariant \($name)") end;
'

check_invariant_case() { # case_id
  local case_id="$1"
  jq -e --arg id "$case_id" "$INVARIANTS_JQ"'
    . as $doc
    | ($doc.invariant_cases[] | select(.id == $id)) as $c
    | ($c.instance // ($doc.schema_cases[] | select(.id == ($c.instance_ref // "")) | .instance)) as $inst
    | if $c.expect == "pass" then
        ($c.invariants | all(. as $i | ($inst | invariant($i))))
      else
        (($inst | invariant($c.violates)) | not)
      end
  ' "$EXAMPLES" >/dev/null 2>&1
}

# -------------------------------------------------------------- contract checks

check_contract_files() {
  [[ -s "$TOOL_MD" && -s "$SKILL_MD" && -s "$TOOL_SCHEMA" && -s "$SKILL_SCHEMA" &&
    -s "$VECTORS" && -s "$EXAMPLES" && -s "$ADR" ]]
}

check_adr_accepted() {
  has_fixed 'Status: ACCEPTED' "$ADR" &&
    has_fixed 'Tool + Skill Contract (P14)' "$ADR" &&
    has_fixed 'contracts-only' "$ADR"
}

check_existing_authorities_referenced() {
  local file
  for file in "$TOOL_MD" "$SKILL_MD"; do
    for ref in 'P9' 'P10' 'P11' 'P12' 'P13' 'frozen-baseline.md' 'P18'; do
      has_fixed "$ref" "$file" || return 1
    done
  done
}

check_tool_descriptor_fields() {
  local block
  block="$(extract_json_contract_block "$TOOL_MD" '## Tool descriptor')"
  [[ -n "$block" ]] || return 1
  printf '%s' "$block" | jq -e '
    type == "object" and
    has("tool_id") and has("version") and has("source") and has("integrity") and
    has("capability_refs") and has("risk_class") and has("execution_authority") and
    has("action_type") and has("input_schema") and has("output_schema") and
    has("timeout_seconds") and has("resource_limits") and has("evidence_requirements")
  ' >/dev/null
}

check_skill_descriptor_fields() {
  local block
  block="$(extract_json_contract_block "$SKILL_MD" '## Skill descriptor')"
  [[ -n "$block" ]] || return 1
  printf '%s' "$block" | jq -e '
    type == "object" and
    has("skill_id") and has("version") and has("steps") and
    (.steps | type == "array" and length >= 1) and
    has("risk_class") and has("resource_budget") and has("evidence_requirements") and
    (.on_step_failure == "BLOCKED") and (.fallback == "NONE") and (.retry == "NONE")
  ' >/dev/null
}

check_tool_boundary() {
  has_fixed 'Tools declare; P10 executes.' "$TOOL_MD" &&
    has_fixed 'A Tool descriptor is never a permission.' "$TOOL_MD" &&
    has_fixed 'shell`, `process`, `file`, `network`, `package' "$TOOL_MD" &&
    has_fixed 'not valid** in a P14 Tool descriptor' "$TOOL_MD"
}

check_capability_references_not_grants() {
  has_fixed 'capability_refs` are descriptive references, not grants' "$TOOL_MD" &&
    has_fixed 'capability_refs` are descriptive references, not grants' "$SKILL_MD" &&
    has_fixed 'REFERENCE_ONLY' "$TOOL_SCHEMA" &&
    has_fixed 'REFERENCE_ONLY' "$SKILL_SCHEMA"
}

check_no_invented_capability_ids() {
  local declared_tool declared_skill expected
  declared_tool="$(jq -r '."$defs".capability_id.enum[]' "$TOOL_SCHEMA" | sort -u)"
  declared_skill="$(jq -r '."$defs".capability_id.enum[]' "$SKILL_SCHEMA" | sort -u)"
  expected="$(printf '%s\n' CAP_FS_READ CAP_FS_WRITE CAP_PROCESS_EXEC CAP_PROCESS_READ CAP_NETWORK_READ CAP_NETWORK_CONNECT CAP_PACKAGE_INSTALL CAP_SECRET_ACCESS | sort -u)"
  [[ "$declared_tool" == "$expected" ]] || return 1
  [[ "$declared_skill" == "$expected" ]] || return 1
  # Deferred/not-yet-existing identifiers are documented as refused, never selectable.
  has_fixed 'CAP_PACKAGE_REMOVE' "$TOOL_SCHEMA" &&
    has_fixed 'DEFERRED/RESTRICTED' "$TOOL_SCHEMA" &&
    ! jq -e '[."$defs".capability_id.enum[] | select(. == "CAP_PACKAGE_REMOVE" or . == "CAP_BROWSER" or . == "CAP_COMPUTER" or . == "CAP_MCP" or . == "CAP_DB_WRITE")] | length > 0' "$TOOL_SCHEMA" >/dev/null
}

check_no_latest_resolution() {
  has_fixed 'no fallback to `latest`' "$TOOL_MD" &&
    has_fixed 'There is **no fallback to `latest`**' "$SKILL_MD" &&
    has_fixed '"pattern": "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$"' "$TOOL_SCHEMA" &&
    has_fixed 'TRACK_LATEST' "$EXAMPLES"
}

check_version_immutability() {
  has_fixed 'Published versions are immutable' "$TOOL_MD" &&
    has_fixed 'Published versions are immutable' "$SKILL_MD" &&
    has_fixed 'requires a new version' "$TOOL_MD" &&
    has_fixed '"pinning": "IMMUTABLE"' "$EXAMPLES"
}

check_per_step_authorization() {
  has_fixed 'Every Tool step is a separate P9 `tool.call` Action' "$TOOL_MD" &&
    has_fixed '**Each step is authorized on its own.**' "$SKILL_MD" &&
    has_fixed '**`ALLOW` for step N never authorizes step N+1**' "$SKILL_MD" &&
    has_fixed 'no skill-level blanket approval' "$SKILL_MD"
}

check_risk_bounds() {
  has_fixed 'CLASS-0` … `CLASS-6`' "$TOOL_MD" &&
    has_fixed '`CLASS-6` is `DENY Always`' "$TOOL_MD" &&
    has_fixed 'greater than or equal to the highest step `risk_class`' "$SKILL_MD" &&
    has_fixed 'No parallel scale exists' "$TOOL_MD" &&
    has_fixed '"CLASS-6"' "$TOOL_SCHEMA"
}

check_registry_governance() {
  has_fixed 'explicit P12 delegation' "$TOOL_MD" &&
    has_fixed 'fresh P11 decision' "$TOOL_MD" &&
    has_fixed 'explicit P12 delegation' "$SKILL_MD" &&
    has_fixed 'can self-register, self-activate, or self-delegate' "$SKILL_MD" &&
    has_fixed 'must not invent `CAP_*` identifiers' "$TOOL_MD"
}

check_evidence_chain() {
  has_fixed 'The hash is an integrity check, not a signature' "$TOOL_MD" &&
    has_fixed 'a hash is an integrity check, not a signature' "$SKILL_MD" &&
    has_fixed 'Evidence storage belongs to P15; verification belongs to P16' "$TOOL_MD" &&
    has_fixed 'Evidence storage belongs to P15; verification belongs to P16' "$SKILL_MD" &&
    has_fixed '`SUCCEEDED ≠ VERIFIED`' "$TOOL_MD"
}

check_failure_semantics() {
  has_fixed 'no skip, no continue, no fallback, no automatic retry' "$SKILL_MD" &&
    has_fixed 'P14 claims no rollback or compensation' "$SKILL_MD" &&
    has_fixed '"const": "BLOCKED"' "$SKILL_SCHEMA" &&
    has_fixed '"const": "NONE"' "$SKILL_SCHEMA"
}

check_resource_limits_mandatory() {
  has_fixed 'resource_limits' "$TOOL_SCHEMA" &&
    has_fixed 'are mandatory, not optional' "$TOOL_MD" &&
    has_fixed 'A Skill without a budget is invalid' "$SKILL_MD" &&
    has_fixed '"required": ["cpu_seconds", "memory_mb", "output_bytes", "process_count", "file_descriptors"]' "$TOOL_SCHEMA" &&
    has_fixed '"required": ["cpu_seconds", "memory_mb", "output_bytes", "process_count", "file_descriptors"]' "$SKILL_SCHEMA"
}

check_no_dsl_no_runtime() {
  has_fixed 'no branching, no loops, no DSL, no expression evaluation before P18' "$SKILL_MD" &&
    has_fixed 'Linear steps only' "$SKILL_MD" &&
    has_fixed 'no expression evaluator' "$SKILL_MD" &&
    has_fixed 'no implementation-language decision' "$TOOL_MD" &&
    has_fixed 'no implementation-language decision' "$SKILL_MD"
}

check_binding_rules() {
  has_fixed '**Typed bindings only.**' "$SKILL_MD" &&
    has_fixed 'only an **earlier** step' "$SKILL_MD" &&
    has_fixed 'is `BLOCKED` before execution' "$SKILL_MD" &&
    has_fixed '"const": "step_output"' "$SKILL_SCHEMA"
}

check_vectors_parse_and_shape() {
  jq -e '
    . as $d
    | ($d.phase == "P14") and
      ($d.cases | type == "array" and length >= 5) and
      ([$d.cases[].id] as $ids | ($ids | length) == ($ids | unique | length)) and
      ([$d.cases[] | (.primary_assertion | type == "string" and length > 0)] | all) and
      ([$d.cases[] | (.acceptance_criterion | type == "string" and length > 0)] | all) and
      ([$d.cases[] | (.expected | type == "object")] | all) and
      ([$d.cases[].title] as $t | ($t | length) == ($t | unique | length))
  ' "$VECTORS" >/dev/null
}

check_required_vector_scenarios() {
  local categories
  categories="$(jq -r '[.cases[].category] | join(" ")' "$VECTORS")"
  for required in missing-step-authorization hash-mismatch resource-limit-descriptor resource-limit-result per-step-authorization version-immutability risk-bounds registry-governance evidence-chain capability-reference typed-binding unknown-tool failure-semantics no-dsl-no-runtime; do
    case " $categories " in *" $required "*) ;; *) return 1 ;; esac
  done
  return 0
}

check_mandated_vector_assertions() {
  jq -e '
    ([.cases[] | select(.id == "TC-P14-01")][0]
      | .expected.step_executed == false and .expected.p10_invoked == false and
        .expected.executor_request_emitted == false and .expected.step_status == "BLOCKED") and
    ([.cases[] | select(.id == "TC-P14-02")][0]
      | .expected.status == "BLOCKED" and .expected.fallback_to_latest == false and
        .expected.alternate_version_used == false) and
    ([.cases[] | select(.id == "TC-P14-03")][0]
      | .expected.descriptor_valid == false and .expected.execution_attempted == false) and
    ([.cases[] | select(.id == "TC-P14-04")][0]
      | .expected.result_status == "RESOURCE_EXCEEDED" and
        .expected.limit_evidence_recorded == true and .expected.promoted_to_succeeded == false) and
    ([.cases[] | select(.id == "TC-P14-05")][0]
      | .expected.step1_authorization_reused == false and .expected.step2_fresh_p11_decision_required == true) and
    ([.cases[] | select(.id == "TC-P14-08")][0]
      | .expected.p12_delegation_required == true and .expected.fresh_p11_decision_required == true and
        .expected.self_registration == false and .expected.invented_capability_ids == false) and
    ([.cases[] | select(.id == "TC-P14-09")][0]
      | .expected.hash_treated_as_signature == false and .expected.storage_owner == "P15" and
        .expected.verification_owner == "P16" and .expected.succeeded_implies_verified == false)
  ' "$VECTORS" >/dev/null
}

check_examples_parse_and_shape() {
  jq -e '
    . as $d
    | ($d.phase == "P14") and
      ($d.schema_cases | type == "array" and length >= 10) and
      ($d.invariant_cases | type == "array" and length >= 5) and
      ([$d.schema_cases[].id, $d.invariant_cases[].id] as $ids | ($ids | length) == ($ids | unique | length)) and
      ([$d.schema_cases[] | (.expect == "valid" or .expect == "invalid")] | all) and
      ([$d.schema_cases[] | select(.expect == "invalid") | (.reason | type == "string" and length > 0)] | all) and
      ([$d.invariant_cases[] | select(.expect == "fail") | (.violates | type == "string")] | all) and
      ($d.schemas["tool-schema.yaml"] == "docs/contracts/tool-schema.yaml") and
      ($d.schemas["skill-schema.yaml"] == "docs/contracts/skill-schema.yaml")
  ' "$EXAMPLES" >/dev/null
}

check_examples_cover_both_schemas() {
  local tool_cases skill_cases
  tool_cases="$(jq -r '[.schema_cases[] | select(.schema == "tool-schema.yaml")] | length' "$EXAMPLES")"
  skill_cases="$(jq -r '[.schema_cases[] | select(.schema == "skill-schema.yaml")] | length' "$EXAMPLES")"
  [[ "$tool_cases" -ge 6 && "$skill_cases" -ge 6 ]]
}

check_only_intended_malformed_hashes() {
  jq -e '
    [ .schema_cases[] | select(
        ([.instance | .. | objects | select(has("hash")) | .hash | test("^[a-f0-9]{64}$")] | all)
        | not) | .id ] == ["EX-P14-T91", "EX-P14-S92"]
  ' "$EXAMPLES" >/dev/null
}

check_vectors_are_not_runtime_simulations() {
  has_fixed 'no Tool or Skill runtime is simulated, and no executor is invoked' "$VECTORS" &&
    has_fixed 'static schema and invariant fixtures only' "$EXAMPLES" &&
    ! grep -qE 'subprocess|exec\(|spawn|popen' "$VECTORS" "$EXAMPLES"
}

check_no_product_code_added() {
  ! find "$ROOT_DIR" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' | grep -q .
}

check_no_technology_selection() {
  ! grep -qE 'we (will|shall) (use|adopt)|selected (language|runtime|database|event bus)' "$TOOL_MD" "$SKILL_MD" &&
    has_fixed 'before P18' "$SKILL_MD" &&
    has_fixed 'before P18' "$TOOL_MD"
}

check_scope_is_contract_only() {
  has_fixed '**CONTRACT ONLY.**' "$TOOL_MD" &&
    has_fixed '**CONTRACT ONLY.**' "$SKILL_MD" &&
    has_fixed 'No DSL, runtime, or implementation language is introduced before P18.' "$TOOL_MD"
}

# ------------------------------------------------------------------------ main

printf 'LINEX.OS TOOL + SKILL CONTRACT TESTS - P14\n'
printf 'Timestamp: %s\nRoot: %s\n\n' "$TIMESTAMP" "$ROOT_DIR"

check 'P14 contract deliverables exist' 'tool, skill, both schemas, vectors, examples, ADR 0013' check_contract_files
check 'ADR 0013 is accepted' 'contracts-only decision before P18' check_adr_accepted
check 'P9-P13 and P8 freeze are consumed' 'P14 references existing authorities without redefining them' check_existing_authorities_referenced
check 'Tool descriptor declares the required contract' 'id, version, source, integrity, capability, risk, authority, limits, evidence' check_tool_descriptor_fields
check 'Skill descriptor declares the required contract' 'linear steps, budget, failure semantics, no fallback' check_skill_descriptor_fields
check 'Tools declare and P10 executes' 'no Tool performs a side effect and only P10 executors are valid' check_tool_boundary
check 'Capability references are not grants' 'capability_refs are descriptive; P12 decides possession' check_capability_references_not_grants
check 'No invented capability identifiers' 'the schema enum is exactly the existing P12 inventory' check_no_invented_capability_ids
check 'No latest resolution' 'versions are semver-pinned with no floating fallback' check_no_latest_resolution
check 'Version immutability' 'published versions and hashes cannot change in place' check_version_immutability
check 'Per-step authorization' 'every step needs its own Action, P11 decision, and P12 check' check_per_step_authorization
check 'Risk bounds reuse the P11 scale' 'CLASS-0..CLASS-6, CLASS-6 DENY Always, no downgrade' check_risk_bounds
check 'Registry governance' 'P12 delegation plus a fresh P11 decision are mandatory' check_registry_governance
check 'Evidence chain' 'per-step evidence; hash is not a signature; P15/P16 own storage/verification' check_evidence_chain
check 'Failure semantics' 'on_step_failure BLOCKED; no skip, continue, fallback, retry, or rollback claim' check_failure_semantics
check 'Resource limits are mandatory' 'all five limits are required in both schemas' check_resource_limits_mandatory
check 'No DSL or runtime before P18' 'linear steps only; no expression evaluation or language choice' check_no_dsl_no_runtime
check 'Typed binding rules' 'explicit, backward-only, schema-checked, fail-closed' check_binding_rules
check 'Acceptance vectors parse and are well formed' 'jq validates the YAML 1.2 JSON-compatible subset' check_vectors_parse_and_shape
check 'All required acceptance scenarios are present' '14 categories including the three mandated scenarios' check_required_vector_scenarios
check 'Mandated vector assertions are explicit' 'missing authorization, hash mismatch, limits, governance, evidence' check_mandated_vector_assertions
check 'Schema examples parse and are well formed' 'unique ids, reasons on every invalid fixture, schema map' check_examples_parse_and_shape
check 'Examples cover both schemas' 'tool and skill fixtures are both present' check_examples_cover_both_schemas
check 'Only intended malformed hashes exist' 'exactly the two truncation fixtures carry a bad hash' check_only_intended_malformed_hashes
check 'Vectors do not simulate a runtime' 'contract definitions only, no executor invocation' check_vectors_are_not_runtime_simulations
check 'P14 adds no product code' 'no .py/.js/.ts/.go/.rs/.java anywhere in the repository' check_no_product_code_added
check 'No technology selection' 'the P18 gate is preserved' check_no_technology_selection
check 'Scope is contract-only' 'no DSL, runtime, or implementation language' check_scope_is_contract_only

if [[ -n "${VALIDATOR_BIN:-}" ]]; then
  SCHEMA_GROUP="PASS"
  run_schema_group || true
else
  printf '\n%-68s → BLOCKED (%s)\n' 'JSON Schema meta-schema and instance validation' "$SCHEMA_GROUP_NOTE"
fi

# Non-schema invariants (JSON Schema cannot express uniqueness, ordering, or cross-field bounds).
inv_case_failures=0
inv_case_total=0
while read -r cid; do
  inv_case_total=$((inv_case_total + 1))
  if check_invariant_case "$cid"; then
    pass "Invariant fixture $cid" 'declared expectation matches the invariant checker'
  else
    inv_case_failures=$((inv_case_failures + 1))
    fail "Invariant fixture $cid" 'declared expectation does not match the invariant checker'
  fi
done < <(jq -r '.invariant_cases[].id' "$EXAMPLES")

printf '\nTOTAL: %s\nPASSED: %s\nFAILED: %s\n' "$TOTAL" "$PASSED" "$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  printf 'STATUS → FAIL\nRESULT → %s P14 contract test(s) failed\n' "$FAILED"
  exit 1
fi
if [[ "$SCHEMA_GROUP" == "PASS" ]]; then
  printf 'STATUS → PASS\n'
  printf 'RESULT → All P14 contract tests PASS including JSON Schema meta-schema and instance validation\n'
  printf 'EVIDENCE → %s; validator %s (%s); %s invariant fixtures\n' \
    "$ROOT_DIR/tests/tool-skill.test.sh" "$VALIDATOR_BIN" "$(validator_kind)" "$inv_case_total"
  exit 0
fi
if [[ "$SCHEMA_GROUP" == "FAIL" ]]; then
  printf 'STATUS → FAIL\nRESULT → P14 schema validation FAILED (external validator)\n'
  exit 1
fi
printf 'STATUS → PASS WITH SCHEMA VALIDATION BLOCKED\n'
printf 'RESULT → %s contract checks PASS; JSON Schema meta-schema and instance validation NOT performed\n' "$PASSED"
printf 'BLOCKER → %s\n' "$SCHEMA_GROUP_NOTE"
printf 'EVIDENCE → %s; jq structural checks; %s invariant fixtures\n' "$ROOT_DIR/tests/tool-skill.test.sh" "$inv_case_total"
printf 'NEXT → adopt a pinned JSON Schema validator (ADR 0013) and rerun; this suite must not report it as PASS before then\n'
exit 0
