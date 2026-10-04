# Event Contract — P9

> Contract only, no implementation, no language chosen, respects P8 freeze.
> Append-only immutable events, no secrets, with correlation, observability distinction.

## Purpose

Event is immutable fact that something happened in LINEX.OS: task created, action proposed, policy validated, execution started, result produced, verification passed, evidence created, runtime health, etc.

Events are source of truth for audit, observability, recovery, learning — without being tied to Linux or LLM provider.

```
Task created
→ Plan
→ Action proposed
→ Policy
→ Execute
→ Result
→ Verify
→ Evidence
→ Learn
      ↑
   Events (append-only, no secrets, correlation_id ties all)
```

## Event Definition

Schema (contract, no implementation):

```json
{
  "event_id": "string, unique, immutable, e.g., event-uuid, ULID, sortable",
  "version": "string, semver, e.g., '1.0.0'",
  "type": "string, e.g., 'task.created', 'task.queued', 'task.scheduled', 'task.started', 'task.completed', 'task.failed', 'task.cancelled', 'task.verified', 'task.unverified', 'action.proposed', 'action.validated', 'action.authorized', 'action.denied', 'action.started', 'action.completed', 'action.failed', 'action.blocked', 'action.cancelled', 'runtime.created', 'runtime.initializing', 'runtime.ready', 'runtime.running', 'runtime.pausing', 'runtime.paused', 'runtime.resuming', 'runtime.stopping', 'runtime.stopped', 'runtime.failed', 'runtime.terminated', 'runtime.health', 'verification.started', 'verification.passed', 'verification.failed', 'evidence.created', 'run.created', 'run.running', 'run.succeeded', 'run.failed', 'run.cancelled', 'run.blocked', 'run.verified', 'run.unverified'",
  "timestamp": "string, ISO8601 UTC, e.g., '2026-10-04T18:12:00Z', immutable",
  "actor": {
    "id": "string, user | agent | service | tool | mcp server | execution authority | system",
    "type": "user | agent | service | tool | mcp_server | execution_authority | system",
    "role": "string, role"
  },
  "action": {
    "id": "string | null, action_id if event is about action",
    "type": "string | null, action type if applicable",
    "capability": "string | null, CAP_* if applicable",
    "resource": "string | null, resource if applicable, no secrets, validated no path traversal",
    "scope": "workspace | repository | project | user | host | network | production | system | null, explicit"
  },
  "task": {
    "id": "string | null, task_id if event is about task",
    "run_id": "string | null, run_id if event is about run"
  },
  "result": "string, e.g., 'success', 'failure', 'denied', 'blocked', 'cancelled', 'verified', 'unverified', 'proposed', 'validating', 'authorized', 'executing'",
  "correlation_id": "string, ties event to workflow, task, run, action, evidence, e.g., correlation-uuid, must be present for all events in same workflow",
  "evidence": {
    "id": "string | null, evidence_id if event is about evidence",
    "hash": "string | null, SHA256 hash of evidence if applicable, no secrets"
  },
  "metadata": {
    "env": "local | arena | ci | production, LOCAL≠PRODUCTION",
    "runtime_id": "string | null, runtime_id if applicable",
    "parent_event_id": "string | null, if event is child of another event",
    "causation_id": "string | null, which event caused this event"
  },
  "payload": {
    "description": "object, event-specific data, no secrets, validated against schema for event type, no API keys, tokens, private keys, credentials, no commit/print/log secrets, no path traversal"
  }
}
```

### Event Types (examples, extensible)

**Task:**
- task.created — Task created, not yet queued
- task.queued — Task queued in State Store
- task.scheduled — Task scheduled, capabilities checked, policy pre-check PASS
- task.started — Task started, Run created
- task.completed — Task completed, Succeeded
- task.failed — Task failed
- task.cancelled — Task cancelled
- task.verified — Task verified with evidence
- task.unverified — Task unverified, missing evidence or verifier FAIL

**Run:**
- run.created — Run created
- run.running — Run running
- run.succeeded — Run succeeded
- run.failed — Run failed
- run.cancelled — Run cancelled
- run.blocked — Run blocked
- run.verified — Run verified
- run.unverified — Run unverified

**Action:**
- action.proposed — Action proposed by Planner
- action.validated — Action validated by Policy Engine
- action.authorized — Action authorized by Authorization Layer
- action.denied — Action denied by Policy/Authorization
- action.started — Action started by Execution Authority
- action.completed — Action completed, Succeeded
- action.failed — Action failed
- action.blocked — Action blocked during execution or validation
- action.cancelled — Action cancelled

**Runtime:**
- runtime.created, runtime.initializing, runtime.ready, runtime.running, runtime.pausing, runtime.paused, runtime.resuming, runtime.stopping, runtime.stopped, runtime.failed, runtime.terminated, runtime.health

**Verification/Evidence:**
- verification.started — Verification started
- verification.passed — Verification passed with evidence
- verification.failed — Verification failed or missing evidence
- evidence.created — Evidence created, with evidence_id, hash, no secrets

All events with event_id, timestamp, actor, correlation_id, no secrets.

## Event Bus Contract

Event Bus is append-only immutable log of events, no secrets, with ordering best-effort, retention policy, replay protection future, local/optional remote/replaceable, no vendor, free-first, vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB.

Interface (contract, no implementation):

```
EventBus
  ├── append(event) → event_id, appends event to log, immutable, no secrets, validates schema, fails closed on invalid schema → DENY
  ├── get(event_id) → event | null, retrieves event by id
  ├── list(filter) → events, lists events by filter (task_id, run_id, action_id, correlation_id, type, actor, timestamp range, result), no secrets in filter
  ├── subscribe(filter, handler) → subscription, subscribes to events matching filter, handler called for each event, no secrets
  ├── unsubscribe(subscription) → void
  ├── replay(correlation_id) → events, replays events for correlation_id in order, for recovery/learning, no secrets
  └── retention policy: how long events kept, when deleted, ownership, access policy, encryption, deletion — design only, no implementation P9

Invariants:
- Append-only: events never modified or deleted via append interface, only via retention policy with audit
- Immutable: event_id, timestamp, actor, correlation_id immutable after append
- No secrets: no API keys, tokens, private keys, credentials, no commit/print/log secrets, payload validated no secrets via secret-scan
- Ordering: best-effort ordering by timestamp, but not guaranteed strict, correlation_id ties related events
- Fail-closed: invalid schema → DENY, missing event_id/timestamp/actor/correlation_id → DENY, event with secrets → DENY + SECURITY EVENT
- No auto-success: event does not imply PASS, SUCCEEDED≠VERIFIED, need evidence
- Observability distinction: DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE — no mixing
- Local must work offline, optional remote sync, replaceable, no vendor chosen in P9
- Resource limits design only: max events, max payload size, max retention, no enforcement P9
- Low-resource modes CORE/STANDARD/HEAVY respected, no GPU/K8s assumed
```

## Observability Distinction (P8 frozen, P9 extends)

```
DEBUG LOG        — detailed execution logs, for debugging, may contain verbose info, no secrets, not audit, not security, not verification
AUDIT EVENT      — who did what when, with actor, action, capability, resource, scope, result, correlation_id, timestamp, for audit, no secrets
SECURITY EVENT   — policy violation, capability DENY, secret exfiltration attempt, path traversal, command injection, validation failure, for security, no secrets, with action, actor, reason
VERIFICATION EVIDENCE — PASS/FAIL/BLOCKED/NOT VERIFIED with STATUS/RESULT/EVIDENCE/NEXT, ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY, for verification, no secrets, no PASS without evidence
```

No mixing: DEBUG LOG must not be used as AUDIT, AUDIT must not contain secrets, SECURITY must not be ignored, VERIFICATION must not be faked.

## Event Correlation

- correlation_id ties all events in same workflow: task.created → task.queued → task.scheduled → run.created → action.proposed → action.validated → action.authorized → action.started → action.completed → result.created → verification.started → verification.passed → evidence.created → task.verified
- causation_id: which event caused this event (e.g., action.validated causation_id = action.proposed event_id)
- parent_event_id: if event is child of another event (e.g., action events child of task event)
- All events in same workflow share same correlation_id, even across Task/Run/Action/Runtime/Verification/Evidence
- Correlation enables replay, recovery, learning, audit

## Event Schema Validation

- Each event type has JSON Schema defining payload, no secrets, validated
- Invalid schema → DENY + event verification.failed + SECURITY EVENT if secret or injection attempt
- Unknown event type → DENY/BLOCKED/UNVERIFIED, fail-closed UNKNOWN→DENY
- Missing event_id/timestamp/actor/correlation_id → DENY
- Event with secrets → DENY + SECURITY EVENT, no commit/print/log secrets
- Payload no path traversal, no command injection, no eval, no curl|bash executable

## Invariants

- Event is immutable fact, append-only, no secrets, with event_id unique immutable, timestamp UTC immutable, actor, correlation_id, causation_id, parent_event_id, no secrets
- Event type explicit, e.g., task.created, action.proposed, runtime.health, verification.passed, evidence.created, extensible but known types validated, unknown→DENY/BLOCKED/UNVERIFIED
- Event has task_id, run_id, action_id, evidence_id if applicable, capability, resource validated no path traversal, scope explicit, result explicit, evidence hash SHA256 if applicable, metadata env runtime_id parent_event_id causation_id, payload no secrets validated
- Event Bus append-only immutable, no secrets, ordering best-effort, retention policy design only, replay protection future, local/optional remote/replaceable no vendor free-first vendor-neutral self-hostable local-capable no mandatory paid API/cloud DB
- Fail-closed: invalid schema→DENY, missing event_id/timestamp/actor/correlation_id→DENY, event with secrets→DENY + SECURITY EVENT, unknown event type→DENY/BLOCKED/UNVERIFIED
- No auto-success: event does not imply PASS, SUCCEEDED≠VERIFIED, EXECUTED≠SAFE, LOCAL≠PRODUCTION, MOCK≠PRODUCTION
- Observability distinction DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE no mixing no secrets
- Correlation_id ties all events in same workflow, causation_id which event caused, parent_event_id child relation, enables replay recovery learning audit
- No implementation language chosen, no product code, no package installation, no system changes, no /tmp inside repo, no *.deb inside repo
- UI client only UI→API only, LLM→shell forbidden, capability explicit DEFAULT DENY UNKNOWN→DENY, MCP via Gateway no unbounded host access, storage abstraction interfaces local/optional remote/replaceable no vendor
- Resource limits design only no enforcement P9, low-resource modes CORE/STANDARD/HEAVY respected no GPU/K8s assumed
- Respects P8 frozen baseline no violation without ADR

## May Do

- Define Event as immutable fact with declarative schema
- Append event to Event Bus via append interface, immutable, no secrets, validated
- Get event by id, list by filter, subscribe, unsubscribe, replay by correlation_id
- Emit task.*, run.*, action.*, runtime.*, verification.*, evidence.* events with event_id timestamp actor correlation_id no secrets
- Correlate events via correlation_id, causation_id, parent_event_id
- Validate event schema, fail-closed on invalid
- Distinguish DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE no mixing
- Support retention policy design only, replay protection future
- Support low-resource modes CORE/STANDARD/HEAVY

## Must Never Do

- Choose implementation language
- Implement Event Bus (no product code)
- Install packages
- Modify system
- Commit/print/log secrets, include secrets in payload
- Create /tmp inside repo, *.deb inside repo
- Allow LLM→shell direct, UI→privileged direct, Agent→prod DB direct, MCP→unrestricted host
- Bypass Policy, allow unknown event type as PASS, allow missing event_id/timestamp/actor/correlation_id as PASS, allow event with secrets
- Mutable events, delete events without audit, no event_id/timestamp/actor/correlation_id
- Implicit ordering guarantee strict, auto-success, SUCCEEDED=VERIFIED, LOCAL=PRODUCTION, MOCK=PRODUCTION
- Mix DEBUG LOG with AUDIT or SECURITY or VERIFICATION, include secrets in any log/event/evidence
- Choose vendor for storage, require paid API/cloud DB, require GPU/K8s
- Violate P8 frozen baseline without ADR

## References

- docs/architecture/frozen-baseline.md
- docs/architecture/event-model.md (P8)
- docs/architecture/data-model.md
- docs/architecture/security-boundaries.md (observability distinction, no secrets)
- docs/contracts/README.md
- docs/contracts/runtime.md, task.md, action.md, result.md, lifecycle.md
- docs/agent-contract.md (evidence model STATUS/RESULT/EVIDENCE/NEXT)
