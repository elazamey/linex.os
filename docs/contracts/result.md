# Result/Evidence Contract — P9

> Contract only, no implementation, no language chosen, respects P8 freeze.
> Output, error, metrics, evidence, attestation, SUCCEEDED≠VERIFIED.

## Purpose

Result is output of Action/Task/Run execution, Evidence is proof that Result is valid, attested, verified, with no secrets, with hash, provenance, STATUS/RESULT/EVIDENCE/NEXT.

```
Task created
→ Plan
→ Action proposed
→ Policy
→ Execute
→ Result (output, error, metrics, resource usage)
→ Verify (Verifier checks Result, produces Evidence)
→ Evidence (STATUS/RESULT/EVIDENCE/NEXT, ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY, hash, provenance, attestation)
→ Learn
```

Without PASS without evidence, without SUCCEEDED=VERIFIED, without LOCAL=PRODUCTION, without MOCK=PRODUCTION.

## Result Definition

Schema (contract, no implementation):

```json
{
  "result_id": "string, unique, immutable, e.g., result-uuid",
  "version": "string, semver",
  "action_id": "string | null, reference to Action if result is for action",
  "task_id": "string | null, reference to Task if result is for task",
  "run_id": "string | null, reference to Run if result is for run",
  "status": "SUCCEEDED | FAILED | BLOCKED | CANCELLED | DENIED",
  "outputs": {
    "schema": "JSON Schema, validated against Task/Action outputs schema, no secrets",
    "data": "actual outputs, no secrets, no API keys, tokens, private keys, credentials"
  },
  "error": {
    "code": "string | null, error code if FAILED/BLOCKED/DENIED/CANCELLED, e.g., 'policy_deny', 'capability_deny', 'validation_failure', 'execution_failure', 'network_failure', 'resource_exhaustion', 'cancellation', 'timeout'",
    "message": "string | null, human readable error, no secrets, no stack trace with secrets",
    "details": "object | null, error details, no secrets"
  },
  "metrics": {
    "duration": "number, seconds, actual execution time",
    "resource_usage": {
      "cpu": "number, actual",
      "memory": "number, actual",
      "disk": "number, actual",
      "process_count": "number, actual",
      "fd": "number, actual",
      "network": "boolean, used?",
      "execution_time": "number, seconds",
      "output_size": "number, bytes, actual"
    }
  },
  "evidence_id": "string | null, reference to Evidence",
  "events": ["event_id, list of events for this result"],
  "created_at": "timestamp UTC, immutable",
  "created_by": "actor id, execution authority",
  "correlation_id": "string, ties result to task, run, action, events, evidence"
}
```

### Result Status

- SUCCEEDED — execution succeeded, outputs produced, but NOT YET VERIFIED, need Verifier → Evidence → VERIFIED
- FAILED — execution failed, error code, message, details, no secrets, needs Evidence → VERIFIED failure
- BLOCKED — blocked by Policy/Authorization/Capability/Validation/Network, needs Evidence → VERIFIED blocked
- CANCELLED — cancelled cooperative/timeout/explicit, no orphaned resources, needs Evidence → VERIFIED cancellation
- DENIED — denied by Policy/Authorization, needs Evidence → VERIFIED denied

SUCCEEDED≠VERIFIED, FAILED needs verification, BLOCKED needs verification, CANCELLED needs verification, DENIED needs verification.

## Evidence Definition

Schema (contract, no implementation):

```json
{
  "evidence_id": "string, unique, immutable, e.g., evidence-uuid",
  "version": "string, semver",
  "result_id": "string | null, reference to Result",
  "action_id": "string | null, reference to Action",
  "task_id": "string | null, reference to Task",
  "run_id": "string | null, reference to Run",
  "status": "PASS | FAIL | BLOCKED | NOT VERIFIED | VERIFIED | UNVERIFIED",
  "result_summary": "string, summary of result, e.g., 'Task succeeded with evidence', 'Action denied by policy', 'Execution failed with evidence', no secrets",
  "evidence": {
    "logs": "string | null, relevant logs, DEBUG LOG vs AUDIT vs SECURITY vs VERIFICATION distinguished, no secrets",
    "artifacts": ["artifact_id, list of artifacts produced, with owner, scope, hash SHA256, provenance, retention, no /tmp inside repo, no *.deb inside repo"],
    "hash": "string, SHA256 hash of evidence bundle, for integrity",
    "provenance": {
      "who": "actor id who verified",
      "when": "timestamp UTC when verified",
      "how": "string, how verified, e.g., 'policy-check.sh', 'secret-scan.sh', 'architecture.test.sh', 'doctor.sh', 'verify-contracts.sh', 'manual attestation'",
      "tool": "string | null, tool used for verification, e.g., 'policy-check.sh'",
      "tool_version": "string | null, version of tool"
    },
    "attestation": {
      "verifier_id": "string, verifier actor id, not AI, Verifier is not Authorization Authority, AI is not Verifier",
      "attestation_type": "manual | automated | third_party",
      "signature": "string | null, signature of evidence bundle, roadmap Level 0 no signing → Level 1 hash → Level 2 signature, no signing system now in P9",
      "timestamp": "timestamp UTC, when attested"
    },
    "policy": {
      "decision": "ALLOW | DENY | REQUIRE_APPROVAL | DRY_RUN | BLOCKED | UNKNOWN",
      "reason": "string, why decision, which policy rule, which capability, no secrets",
      "allowlist_checked": true,
      "capability_checked": true,
      "scope_checked": true,
      "risk_checked": true,
      "network_checked": true
    },
    "execution": {
      "authority": "shell | process | file | network | package | browser | computer | mcp | tool | skill | workflow",
      "executor": "string, specific executor id",
      "exit_code": "number | null, exit code if applicable",
      "output": "string | null, output truncated if large, no secrets, max output size design only",
      "resource_usage": {
        "cpu": "number, actual",
        "memory": "number, actual",
        "disk": "number, actual",
        "process_count": "number, actual",
        "fd": "number, actual",
        "network": "boolean",
        "execution_time": "number, seconds",
        "output_size": "number, bytes"
      },
      "dry_run": "boolean, true if DRY_RUN, false if real"
    },
    "verification": {
      "checks": ["list of checks performed, e.g., 'bash -n', 'policy-check', 'secret-scan', 'architecture.test', 'contracts.test'"],
      "passed": "number, count passed",
      "failed": "number, count failed",
      "blocked": "number, count blocked",
      "total": "number, total checks"
    }
  },
  "next": "string, next steps, e.g., 'Run P10 Execution Authority Contracts', 'No further action', 'Requires manual approval', 'Retry allowed', 'Retry not allowed on Policy DENY'",
  "created_at": "timestamp UTC, immutable",
  "created_by": "verifier actor id, not AI",
  "correlation_id": "string, ties evidence to task, run, action, result, events"
}
```

### Evidence Status

- PASS — verification passed with evidence, e.g., architecture.test.sh 15/15 PASS, policy-check PASS, secret-scan PASS, doctor PASS WITH KNOWN BLOCKER
- FAIL — verification failed with evidence, e.g., architecture.test.sh 1 failed, policy-check FAIL, secret-scan FAIL
- BLOCKED — blocked with evidence, e.g., P4 PowerShell BLOCKED with evidence packages.microsoft.com BLOCKED SSL_ERROR_SYSCALL, release-assets BLOCKED, github.com PASS, Gate and logic PASS 18 tests
- NOT VERIFIED — not verified, e.g., no GitHub Actions run exists for the measured commit; do not infer remote status from a local test or a historical branch note
- VERIFIED — result verified with evidence, e.g., Task Succeeded → Verified, Action Succeeded → Verified, Runtime Ready → Verified
- UNVERIFIED — result unverified, missing evidence or verifier FAIL, e.g., Task Succeeded → Unverified if no evidence, Action Succeeded → Unverified if missing evidence

PASS requires evidence, no PASS without evidence, SUCCEEDED≠VERIFIED, EXECUTED≠SAFE, LOCAL≠PRODUCTION, MOCK≠PRODUCTION, no production claims without production evidence.

### Evidence Model (from AGENTS.md, P6)

```
STATUS  → PASS / FAIL / BLOCKED / NOT VERIFIED / VERIFIED / UNVERIFIED
RESULT  → summary, e.g., 'Architecture verification PASS - all invariants verified'
EVIDENCE → logs, artifacts, hash SHA256, provenance who/when/how, attestation verifier_id, policy decision, execution authority/executor/exit_code/resource_usage/dry_run, verification checks passed/failed/blocked/total
NEXT    → next steps, e.g., 'Run architecture.test.sh', 'Run P10', 'Requires manual approval'

ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY — for privilege-gate evidence
```

## Evidence Store Contract

Evidence Store is append-only immutable store of evidence, no secrets, with hash, provenance, attestation, local/optional remote/replaceable, no vendor, free-first, vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB.

Interface (contract, no implementation):

```
EvidenceStore
  ├── create(evidence) → evidence_id, creates evidence, immutable, no secrets, validates schema, hash SHA256, provenance who/when/how, attestation verifier_id, fails closed on invalid schema → DENY
  ├── get(evidence_id) → evidence | null
  ├── list(filter) → evidences, filter by task_id, run_id, action_id, result_id, correlation_id, status, actor, timestamp range, no secrets
  ├── verify(evidence_id) → PASS/FAIL/BLOCKED/NOT VERIFIED/VERIFIED/UNVERIFIED, verifies evidence integrity hash, provenance, attestation, no secrets
  └── retention policy: how long evidence kept, when deleted, ownership, access policy, encryption, deletion — design only, no implementation P9

Invariants:
- Append-only: evidence never modified, only created, retention policy with audit for deletion
- Immutable: evidence_id, timestamp, actor, correlation_id, hash, provenance, attestation immutable after creation
- No secrets: no API keys, tokens, private keys, credentials, no commit/print/log secrets, validated via secret-scan
- Hash: SHA256 hash of evidence bundle for integrity, provenance who/when/how, attestation verifier_id
- Fail-closed: invalid schema→DENY, missing evidence_id/timestamp/actor/correlation_id/hash/provenance/attestation→DENY/UNVERIFIED, evidence with secrets→DENY + SECURITY EVENT
- No PASS without evidence, SUCCEEDED≠VERIFIED, EXECUTED≠SAFE, LOCAL≠PRODUCTION, MOCK≠PRODUCTION, no production claims without production evidence
- Local must work offline, optional remote sync, replaceable, no vendor chosen in P9
- Resource limits design only: max evidence, max payload size, max retention, no enforcement P9
- Low-resource modes CORE/STANDARD/HEAVY respected, no GPU/K8s assumed
```

## Verification Hooks

- Runtime, Task, Run, Action provide hooks for Verifier: before_transition, after_transition, before_task, after_task, before_run, after_run, before_action, after_action, on_cancel, on_recover, on_health, on_config
- Verifier uses hooks to produce evidence, checks Result, produces Evidence with STATUS/RESULT/EVIDENCE/NEXT
- Verifier is not Authorization Authority, AI is not Verifier, no PASS without evidence
- Verification hooks must not allow bypass: no hook can skip Policy, no hook can allow LLM→shell direct, no hook can produce PASS without evidence

## Invariants

- Result is output of Action/Task/Run execution with result_id unique immutable, action_id/task_id/run_id reference, status SUCCEEDED/FAILED/BLOCKED/CANCELLED/DENIED, outputs schema validated no secrets, error code/message/details no secrets, metrics duration/resource_usage, evidence_id reference, events, created_at, created_by, correlation_id
- Evidence is proof that Result is valid with evidence_id unique immutable, result_id/action_id/task_id/run_id reference, status PASS/FAIL/BLOCKED/NOT VERIFIED/VERIFIED/UNVERIFIED, result_summary no secrets, evidence logs/artifacts/hash/provenance/attestation/policy/execution/verification, next steps, created_at, created_by verifier not AI, correlation_id
- SUCCEEDED≠VERIFIED, EXECUTED≠SAFE, LOCAL≠PRODUCTION, MOCK≠PRODUCTION, no PASS without evidence, no production claims without production evidence
- Evidence Store append-only immutable no secrets with hash SHA256 provenance who/when/how attestation verifier_id, local/optional remote/replaceable no vendor free-first vendor-neutral self-hostable local-capable no mandatory paid API/cloud DB
- Fail-closed: invalid schema→DENY, missing evidence_id/timestamp/actor/correlation_id/hash/provenance/attestation→DENY/UNVERIFIED, evidence with secrets→DENY + SECURITY EVENT, unknown status→DENY/BLOCKED/UNVERIFIED
- No auto-success, no implicit verification, verification hooks explicit, Verifier not Authorization Authority, AI not Verifier
- Events append-only immutable no secrets with event_id timestamp actor correlation_id evidence hash
- Observability distinction DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE no mixing no secrets
- No implementation language chosen, no product code, no package installation, no system changes, no /tmp inside repo, no *.deb inside repo
- UI client only UI→API only, LLM→shell forbidden, capability explicit DEFAULT DENY UNKNOWN→DENY, MCP via Gateway no unbounded host access, storage abstraction interfaces local/optional remote/replaceable no vendor
- Resource limits design only no enforcement P9, low-resource modes CORE/STANDARD/HEAVY respected no GPU/K8s assumed
- Respects P8 frozen baseline no violation without ADR

## May Do

- Define Result as output of Action/Task/Run with declarative schema no secrets
- Define Evidence as proof with STATUS/RESULT/EVIDENCE/NEXT, ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY, hash, provenance, attestation, no secrets
- Create evidence via Evidence Store create interface, immutable, no secrets, validated, hash, provenance, attestation
- Get evidence by id, list by filter, verify integrity
- Emit verification.started/passed/failed, evidence.created events with event_id timestamp actor correlation_id evidence hash no secrets
- Provide hooks for Verifier before/after task/run/action, on_cancel, on_recover, on_health, on_config
- Verify Result via Verifier, produce Evidence, no PASS without evidence, SUCCEEDED≠VERIFIED
- Support retention policy design only, signature verification roadmap Level 0 no signing → Level 1 hash → Level 2 signature no signing system now P9
- Support low-resource modes CORE/STANDARD/HEAVY

## Must Never Do

- Choose implementation language
- Implement Result/Evidence production (no product code)
- Install packages
- Modify system
- Commit/print/log secrets, include secrets in outputs/error/logs/artifacts
- Create /tmp inside repo, *.deb inside repo
- Allow LLM→shell direct, UI→privileged direct, Agent→prod DB direct, MCP→unrestricted host
- Bypass Policy, allow unknown result status as PASS, allow missing evidence as PASS, allow PASS without evidence, allow SUCCEEDED=VERIFIED, LOCAL=PRODUCTION, MOCK=PRODUCTION, production claims without production evidence
- Mutable evidence, delete evidence without audit, no evidence_id/timestamp/actor/correlation_id/hash/provenance/attestation
- Events with secrets, mutable events, no event_id/timestamp/actor/correlation_id
- Evidence without STATUS/RESULT/EVIDENCE/NEXT, without ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY for gate evidence, without hash/provenance/attestation
- Verifier as Authorization Authority, AI as Verifier, auto-success, implicit verification
- Mix DEBUG LOG with AUDIT or SECURITY or VERIFICATION, include secrets in any log/event/evidence
- Choose vendor for storage, require paid API/cloud DB, require GPU/K8s
- Violate P8 frozen baseline without ADR

## References

- docs/architecture/frozen-baseline.md
- docs/architecture/data-model.md (artifact, evidence, storage abstraction)
- docs/architecture/security-boundaries.md (no secrets, observability distinction)
- docs/agent-contract.md (evidence model STATUS/RESULT/EVIDENCE/NEXT, AI PROPOSES→POLICY→EXECUTION→VERIFIER)
- docs/contracts/README.md
- docs/contracts/runtime.md, task.md, action.md, event.md, lifecycle.md
- docs/architecture/adr/0004-policy-vs-execution.md
