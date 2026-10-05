#!/usr/bin/env bash
# LINEX.OS VERIFY TOOL + SKILL CONTRACT - P14
# Verifies contract consistency with the P8 freeze and the P9-P13 authorities.
# Repository-only: no package installation, no network access, no system changes.
# Delegates JSON Schema meta-schema and instance validation to tests/tool-skill.test.sh,
# which uses the approved external validator. Exit codes: 0 PASS, 2 BLOCKED, 3 FAIL.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOTAL=0
PASSED=0
FAILED=0
BLOCKED=0

CONTRACTS="$ROOT_DIR/docs/contracts"
TOOL_MD="$CONTRACTS/tool.md"
SKILL_MD="$CONTRACTS/skill.md"
TOOL_SCHEMA="$CONTRACTS/tool-schema.yaml"
SKILL_SCHEMA="$CONTRACTS/skill-schema.yaml"
VECTORS="$CONTRACTS/tool-skill-acceptance-tests.yaml"
EXAMPLES="$CONTRACTS/tool-skill-examples.yaml"
ADR="$ROOT_DIR/docs/architecture/adr/0013-tool-skill-contract.md"
SUITE="$ROOT_DIR/tests/tool-skill.test.sh"

pass() { TOTAL=$((TOTAL + 1)); PASSED=$((PASSED + 1)); printf '%-56s → PASS (%s)\n' "$1" "$2"; }
fail() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '%-56s → FAIL (%s)\n' "$1" "$2" >&2; }
blocked() { TOTAL=$((TOTAL + 1)); BLOCKED=$((BLOCKED + 1)); printf '%-56s → BLOCKED (%s)\n' "$1" "$2"; }
check() {
  local name="$1" detail="$2" function_name="$3"
  if "$function_name"; then pass "$name" "$detail"; else fail "$name" "check function $function_name failed"; fi
}
has() { grep -Fq -- "$1" "$2"; }
SCHEMA_VERDICT=""

files_present() {
  [[ -s "$TOOL_MD" && -s "$SKILL_MD" && -s "$TOOL_SCHEMA" && -s "$SKILL_SCHEMA" &&
    -s "$VECTORS" && -s "$EXAMPLES" && -s "$ADR" && -s "$SUITE" && -x "$SUITE" ]]
}

schemas_are_draft_2020_12() {
  local file
  for file in "$TOOL_SCHEMA" "$SKILL_SCHEMA"; do
    jq -e '
      .["$schema"] == "https://json-schema.org/draft/2020-12/schema" and
      (.["$id"] | type == "string") and
      (.type == "object") and
      (.additionalProperties == false)
    ' "$file" >/dev/null || return 1
  done
}

schema_strictness() {
  jq -e '
    ([.["$defs"].resource_limits.required[]] | sort) ==
      (["cpu_seconds","file_descriptors","memory_mb","output_bytes","process_count"] | sort) and
    .["$defs"].resource_limits.additionalProperties == false and
    .properties.integrity.properties.pinning.const == "IMMUTABLE" and
    (.["$defs"].semver.pattern | type == "string")
  ' "$TOOL_SCHEMA" >/dev/null &&
    jq -e '
      ([.["$defs"].resource_limits.required[]] | sort) ==
        (["cpu_seconds","file_descriptors","memory_mb","output_bytes","process_count"] | sort) and
      .properties.on_step_failure.const == "BLOCKED" and
      .properties.fallback.const == "NONE" and
      .properties.retry.const == "NONE" and
      .properties.steps.maxItems == 64
    ' "$SKILL_SCHEMA" >/dev/null
}

capability_inventory_is_existing_only() {
  local expected tool_ids skill_ids
  expected="$(printf '%s\n' CAP_FS_READ CAP_FS_WRITE CAP_PROCESS_EXEC CAP_PROCESS_READ CAP_NETWORK_READ CAP_NETWORK_CONNECT CAP_PACKAGE_INSTALL CAP_SECRET_ACCESS | sort -u)"
  tool_ids="$(jq -r '."$defs".capability_id.enum[]' "$TOOL_SCHEMA" | sort -u)"
  skill_ids="$(jq -r '."$defs".capability_id.enum[]' "$SKILL_SCHEMA" | sort -u)"
  [[ "$tool_ids" == "$expected" && "$skill_ids" == "$expected" ]]
}

tool_boundary_valid() {
  has 'Tools declare; P10 executes.' "$TOOL_MD" &&
    has 'A Tool descriptor is never a permission.' "$TOOL_MD" &&
    has 'Unknown Tool → `BLOCKED`' "$TOOL_MD" &&
    has 'The hash is an integrity check, not a signature' "$TOOL_MD"
}

skill_boundary_valid() {
  has 'Each step is authorized on its own' "$SKILL_MD" &&
    has 'ALLOW` for step N never authorizes step N+1' "$SKILL_MD" &&
    has 'on_step_failure = BLOCKED' "$SKILL_MD" &&
    has 'no skip, no continue, no fallback, no automatic retry' "$SKILL_MD"
}

existing_authorities_referenced() {
  local file
  for file in "$TOOL_MD" "$SKILL_MD"; do
    for reference in P9 P10 P11 P12 P13 frozen-baseline.md P18; do has "$reference" "$file" || return 1; done
  done
}

registry_governance_valid() {
  has 'explicit P12 delegation' "$TOOL_MD" &&
    has 'fresh P11 decision' "$TOOL_MD" &&
    has 'must not invent `CAP_*` identifiers' "$TOOL_MD" &&
    has 'explicit P12 delegation' "$SKILL_MD"
}

risk_bounds_valid() {
  has 'CLASS-0` … `CLASS-6`' "$TOOL_MD" &&
    has '`CLASS-6` is `DENY Always`' "$TOOL_MD" &&
    has 'must be greater than or equal to the highest step `risk_class`' "$SKILL_MD" &&
    has 'No parallel scale exists' "$TOOL_MD"
}

evidence_chain_valid() {
  has 'Evidence storage belongs to P15; verification belongs to P16' "$TOOL_MD" &&
    has 'a hash is an integrity check, not a signature' "$SKILL_MD" &&
    has '`SUCCEEDED ≠ VERIFIED`' "$TOOL_MD" &&
    has 'P14 claims no rollback or compensation' "$SKILL_MD"
}

vectors_valid() {
  jq -e '
    . as $d
    | ($d.phase == "P14") and
      ($d.cases | type == "array" and length >= 5) and
      ([$d.cases[].id] as $ids | ($ids | length) == ($ids | unique | length)) and
      ([$d.cases[] | (.primary_assertion | type == "string" and length > 0)] | all)
  ' "$VECTORS" >/dev/null
}

examples_valid() {
  jq -e '
    . as $d
    | ($d.phase == "P14") and
      ($d.schema_cases | length >= 10) and
      ($d.invariant_cases | length >= 5) and
      ([$d.schema_cases[] | select(.expect == "invalid") | (.reason | length > 0)] | all)
  ' "$EXAMPLES" >/dev/null
}

adr_valid() {
  has 'Status: ACCEPTED' "$ADR" &&
    has 'Tool + Skill Contract (P14)' "$ADR" &&
    has 'contracts-only' "$ADR" &&
    has 'before P18' "$ADR"
}

no_product_code_added() {
  ! find "$ROOT_DIR" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' | grep -q .
}

no_technology_selection() {
  ! grep -qE 'selected (language|runtime|database|event bus)|we (will|shall) (use|adopt) ' "$TOOL_MD" "$SKILL_MD" &&
    has 'before P18' "$TOOL_MD" &&
    has 'before P18' "$SKILL_MD"
}

ci_runs_p14() {
  has './tests/tool-skill.test.sh' "$ROOT_DIR/.github/workflows/ci.yml" &&
    has './ops/verify/verify-tool-skill.sh' "$ROOT_DIR/.github/workflows/ci.yml"
}

# Delegates the JSON Schema meta-schema and instance validation to the P14 suite and
# records one of three verdicts: PASS (validated), BLOCKED (validator unavailable),
# FAIL (validation failed). Never upgraded to PASS without evidence.
schema_validation_delegated() {
  local out rc=0
  out="$("$SUITE" 2>&1)" || rc=$?
  printf '%s\n' "$out" | grep -E '^(TOTAL|PASSED|FAILED|STATUS|RESULT|BLOCKER)' | sed 's/^/    /' || true
  if printf '%s' "$out" | grep -q '^STATUS → PASS$'; then
    SCHEMA_VERDICT="PASS"
    return 0
  fi
  if printf '%s' "$out" | grep -q '^STATUS → PASS WITH SCHEMA VALIDATION BLOCKED$'; then
    SCHEMA_VERDICT="BLOCKED"
    return 1
  fi
  SCHEMA_VERDICT="FAIL"
  [[ "$rc" -ne 0 ]] || true
  return 1
}

printf 'LINEX.OS VERIFY TOOL + SKILL CONTRACT - P14\nTimestamp: %s\nRoot: %s\nMode: read-only contract verification\n\n' "$TIMESTAMP" "$ROOT_DIR"

check 'P14 contract deliverables' 'tool, skill, schemas, vectors, examples, ADR, suite' files_present
check 'Schemas are strict draft 2020-12 documents' 'declared draft, object root, additionalProperties false' schemas_are_draft_2020_12
check 'Schema strictness reflects the contract' 'mandatory limits, IMMUTABLE pinning, semver, no skip/fallback/retry' schema_strictness
check 'Capability inventory is existing-only' 'the P12 inventory is reused; nothing is invented in P14' capability_inventory_is_existing_only
check 'Tool boundary' 'declares only; P10 executes; unknown Tool BLOCKED; hash is not a signature' tool_boundary_valid
check 'Skill boundary' 'per-step authorization; BLOCKED failure semantics; no inheritance' skill_boundary_valid
check 'P9-P13 and P8 freeze consumption' 'existing contracts remain authoritative' existing_authorities_referenced
check 'Registry governance' 'explicit P12 delegation plus a fresh P11 decision; no invented CAP_*' registry_governance_valid
check 'Risk bounds' 'CLASS-0..CLASS-6 reused; CLASS-6 DENY Always; no downgrade' risk_bounds_valid
check 'Evidence chain' 'per-step evidence; no signature claim; P15/P16 ownership' evidence_chain_valid
check 'Acceptance vectors' 'structured, unique, single-assertion P14 vectors' vectors_valid
check 'Schema and invariant fixtures' 'invalid fixtures carry reasons; both schemas covered' examples_valid
check 'ADR 0013 accepted' 'contract-only decision before P18' adr_valid
check 'No product code' 'P14 adds contracts, schemas, and tests only' no_product_code_added
check 'No technology selection' 'the P18 implementation gate is preserved' no_technology_selection
check 'CI coverage' 'CI runs the P14 suite and this verifier' ci_runs_p14

if schema_validation_delegated; then
  pass 'JSON Schema meta-schema and instance validation' 'performed by tests/tool-skill.test.sh with the approved validator'
else
  if [[ "$SCHEMA_VERDICT" == "BLOCKED" ]]; then
    blocked 'JSON Schema meta-schema and instance validation' 'no approved validator installed; schema evidence is NOT verified'
  else
    fail 'JSON Schema meta-schema and instance validation' 'the P14 suite reported a schema or contract failure'
  fi
fi

printf '\nTOTAL: %s\nPASSED: %s\nFAILED: %s\nBLOCKED: %s\n' "$TOTAL" "$PASSED" "$FAILED" "$BLOCKED"
if [[ "$FAILED" -eq 0 && "$BLOCKED" -eq 0 ]]; then
  printf 'STATUS → PASS\nRESULT → P14 Tool + Skill contract verification PASS; contracts only, no runtime and no production claim\n'
  printf 'EVIDENCE → verify-tool-skill.sh, jq structural checks, tests/tool-skill.test.sh schema validation verdict %s\n' "$SCHEMA_VERDICT"
  exit 0
fi
if [[ "$FAILED" -eq 0 && "$BLOCKED" -gt 0 ]]; then
  printf 'STATUS → BLOCKED\nRESULT → %s P14 verification check(s) blocked; P14 is NOT verified complete\n' "$BLOCKED"
  printf 'EVIDENCE → verify-tool-skill.sh; JSON Schema validation requires the approved pinned validator (ADR 0013)\n'
  exit 2
fi
printf 'STATUS → FAIL\nRESULT → %s P14 verification check(s) failed\n' "$FAILED"
exit 3
