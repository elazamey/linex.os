#!/usr/bin/env bash
# LINEX.OS VERIFY AGENT RUNTIME - P13
# Verifies contract consistency and structured vectors only; no Agent execution.
# Repository-only: no package installation, network access, or system changes.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOTAL=0
PASSED=0
FAILED=0

pass() { TOTAL=$((TOTAL + 1)); PASSED=$((PASSED + 1)); printf '%-56s → PASS (%s)\n' "$1" "$2"; }
fail() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '%-56s → FAIL (%s)\n' "$1" "$2" >&2; }
check() {
  local name="$1" detail="$2" function_name="$3"
  if "$function_name"; then pass "$name" "$detail"; else fail "$name" "check function $function_name failed"; fi
}
has() { grep -Fq -- "$1" "$2"; }

files_present() {
  [[ -s "$ROOT_DIR/docs/contracts/agent-runtime.md" &&
    -s "$ROOT_DIR/docs/contracts/agent-lifecycle.md" &&
    -s "$ROOT_DIR/docs/contracts/agent-audit.md" &&
    -s "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" &&
    -s "$ROOT_DIR/docs/architecture/adr/0012-agent-runtime-contract.md" ]]
}

vectors_valid() {
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '
    .phase == "P13" and (.cases | type == "array" and length >= 5) and
    ([.cases[].id] as $ids | ($ids | length) == ($ids | unique | length)) and
    all(.cases[]; (.primary_assertion | type == "string" and length > 0))
  ' "$ROOT_DIR/docs/contracts/agent-acceptance-tests.yaml" >/dev/null
}

agent_boundary_valid() {
  local file="$ROOT_DIR/docs/contracts/agent-runtime.md"
  has 'The Planner **proposes; it never executes**.' "$file" &&
    has 'Natural-language intent is not permission' "$file" &&
    has 'P9 Action' "$file" &&
    has 'Execution Authority' "$file"
}

existing_authorities_referenced() {
  local file="$ROOT_DIR/docs/contracts/agent-runtime.md"
  for reference in P9 P10 P11 P12 frozen-baseline.md; do has "$reference" "$file" || return 1; done
}

capability_and_policy_fail_closed() {
  local file="$ROOT_DIR/docs/contracts/agent-runtime.md"
  has 'P12 capability' "$file" &&
    has 'Unknown or malformed input fails closed' "$file" &&
    has 'P11 `ALLOW` alone is not authorization' "$file" &&
    has 'cannot create, widen, delegate, activate, or self-grant' "$file"
}

lifecycle_valid() {
  local file="$ROOT_DIR/docs/contracts/agent-lifecycle.md"
  has 'stateDiagram-v2' "$file" && has 'sequenceDiagram' "$file" &&
    has 'P9 Run is VERIFIED and evidence exists' "$file" &&
    has 'approval recorded; obtain a fresh P11 decision' "$file"
}

audit_valid() {
  local file="$ROOT_DIR/docs/contracts/agent-audit.md"
  has 'append interface' "$file" && has 'correlation_id' "$file" &&
    has 'reason_code' "$file" && has 'decision_ref' "$file" &&
    has 'Never put credentials' "$file" &&
    has 'No claim of a digital signature' "$file"
}

adr_valid() {
  local file="$ROOT_DIR/docs/architecture/adr/0012-agent-runtime-contract.md"
  has 'Status: ACCEPTED' "$file" &&
    has 'Phase: P13' "$file" &&
    has 'Agent Runtime Contract ONLY' "$file" &&
    has 'before P18' "$file"
}

no_product_code_added() {
  ! find "$ROOT_DIR" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' | grep -q .
}

no_policy_approval_conflation() {
  has 'P11 `ALLOW` is not `AUTHORIZED`' "$ROOT_DIR/docs/contracts/agent-lifecycle.md" &&
    has '`APPROVED`' "$ROOT_DIR/docs/contracts/agent-lifecycle.md" &&
    has 'approval recorded' "$ROOT_DIR/docs/contracts/agent-lifecycle.md"
}

ci_runs_p13() {
  has './tests/agent-runtime.test.sh' "$ROOT_DIR/.github/workflows/ci.yml" &&
    has './ops/verify/verify-agent-runtime.sh' "$ROOT_DIR/.github/workflows/ci.yml"
}

printf 'LINEX.OS VERIFY AGENT RUNTIME - P13\nTimestamp: %s\nRoot: %s\nMode: read-only contract verification\n\n' "$TIMESTAMP" "$ROOT_DIR"
check 'P13 contract files' 'main contract, lifecycle, audit, acceptance vectors, ADR 0012' files_present
check 'Acceptance vector structure' 'valid YAML 1.2 JSON-compatible subset; jq parse, IDs, assertions' vectors_valid
check 'Agent/Planner authority boundary' 'typed proposals only; no direct execution or natural-language grants' agent_boundary_valid
check 'P9-P12 and P8 freeze consumption' 'existing contracts remain authoritative' existing_authorities_referenced
check 'Capability and policy fail-closed rules' 'no self-grant; ALLOW alone is not authorization' capability_and_policy_fail_closed
check 'P13 lifecycle and handoff' 'approval, authorization, Execution Authority, and evidence order is explicit' lifecycle_valid
check 'Audit and privacy requirements' 'append-only interface, reason/decision references, no secrets/signature overclaims' audit_valid
check 'ADR 0012 accepted' 'contract-only decision before P18' adr_valid
check 'No product code' 'P13 adds contracts and tests only' no_product_code_added
check 'Approval is not an Agent state' 'P11 and Authorization decisions remain distinct' no_policy_approval_conflation
check 'CI coverage' 'P13 test suite and verifier are included' ci_runs_p13

printf '\nTOTAL: %s\nPASSED: %s\nFAILED: %s\n' "$TOTAL" "$PASSED" "$FAILED"
if [[ $FAILED -eq 0 ]]; then
  printf 'STATUS → PASS\nRESULT → P13 contract verification PASS; no runtime or production claim\n'
  printf 'EVIDENCE → verify-agent-runtime.sh, jq 1.6 acceptance-vector validation\n'
  exit 0
fi
printf 'STATUS → FAIL\nRESULT → %s P13 verification check(s) failed\n' "$FAILED"
exit 1
