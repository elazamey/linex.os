# Skill Contract — P14

> **CONTRACT ONLY.** No Skill implementation, no Skill runtime, no orchestration engine, no DSL, no expression evaluator, no package installation, no system changes, and no implementation-language decision. P14 consumes—not redefines—the P9–P13 contracts.

## Purpose and authority

A **Skill** is a reusable procedure: an ordered, **linear** list of steps over pinned Tools, with typed data binding between steps. A Skill is a *declaration template*, not an executor and not a permission. It composes; P10 executes; P11 decides; P12 owns capability; the Verifier owns evidence.

```
Skill descriptor (this contract)
        │  instantiated as
        ▼
P9 Task → parent P9 Action (skill.exec) → child P9 Actions (tool.call, parent_action_id)
        │                                        │
        │                          per child: P11 → P12 → P10 → P9 Result → Verifier
        ▼
P9 Evidence (per step, per run)
```

`docs/contracts/action.md` already defines `skill.exec` as "Skill execution, composes tools" and `parent_action_id` as "if action is part of workflow/skill, parent action". P14 uses exactly those fields. `skill.exec` is a plan-level admission step; it never authorizes the child calls.

## Skill descriptor

Immutable, versioned, secret-free. Schema: `skill-schema.yaml`. Example:

```json
{
  "skill_id": "skill.example.repo_audit",
  "version": "1.0.0",
  "name": "Repository audit",
  "description": "Reads repository status, then reads one workspace file selected from the previous step output.",
  "risk_class": "CLASS-2",
  "trust_level": "semi_trusted",
  "steps": [
    {
      "step_id": "step-01",
      "name": "Read repository status",
      "depends_on": null,
      "tool": {
        "tool_id": "tool.example.repo_status",
        "version": "1.0.0",
        "hash": "0000000000000000000000000000000000000000000000000000000000000000"
      },
      "capability_refs": ["CAP_PROCESS_EXEC"],
      "risk_class": "CLASS-2",
      "input_bindings": [
        {"target_input": "path", "source": "literal", "value": ".", "type": "string", "required": true}
      ]
    },
    {
      "step_id": "step-02",
      "name": "Read one workspace file",
      "depends_on": "step-01",
      "tool": {
        "tool_id": "tool.example.fs_read",
        "version": "1.0.0",
        "hash": "1111111111111111111111111111111111111111111111111111111111111111"
      },
      "capability_refs": ["CAP_FS_READ"],
      "risk_class": "CLASS-1",
      "input_bindings": [
        {"target_input": "path", "source": "step_output", "from_step": "step-01", "output_path": "status.path", "type": "string", "required": true}
      ]
    }
  ],
  "resource_budget": {
    "cpu_seconds": 20,
    "memory_mb": 512,
    "output_bytes": 131072,
    "process_count": 2,
    "file_descriptors": 64
  },
  "evidence_requirements": ["p9_action_id", "p9_result_hash", "verifier_evidence_ref"],
  "on_step_failure": "BLOCKED",
  "fallback": "NONE",
  "retry": "NONE",
  "deterministic": true
}
```

The hashes above are structurally valid placeholders and make no claim about any real artifact.

## Steps and the linear rule

1. **Linear steps only; no branching, no loops, no DSL, no expression evaluation before P18.** `steps` is an ordered array; `steps[0].depends_on` is `null`; each later step's `depends_on` must name the immediately preceding step. A graph, conditional, parallel, or expression-bearing procedure requires its own ADR after P18.
2. Step identifiers are unique within the Skill, and each step names exactly one pinned Tool (`tool_id`, `version`, `hash`).
3. Each step's `capability_refs` are descriptive references, not grants, and follow the P12-only identifier rule in `tool.md` — P14 must not invent `CAP_*` identifiers.
4. The step's declared `risk_class` is a declaration. P11 evaluates the realized risk of the child Action and may raise it; neither a Skill nor a Tool may lower it.

## Per-step authorization (no inheritance)

**Each step is authorized on its own.** For every step, the instantiated child P9 Action must independently complete:

```
child P9 Action (tool.call, parent_action_id = parent skill.exec action)
  → fresh P11 decision (ALLOW | DENY | REQUIRE_APPROVAL | DRY_RUN | BLOCKED)
  → independent P12 possession/scope/validity/expiry/revocation check
  → P10 Execution Authority (only if the two checks above permit)
```

- **`ALLOW` for step N never authorizes step N+1**, another run, another task, or a different Tool version. There is no skill-level blanket approval and no "approve once, run all".
- The parent `skill.exec` Action does not grant the children and cannot mark them `AUTHORIZED`.
- Missing, denied, unknown, or stale P11/P12 authorization for any step means that step does not reach P10; the run is `BLOCKED` at that step.
- A step whose Tool is unknown, unpinned, suspended, revoked, or hash-mismatched is `BLOCKED` before any executor call. There is **no fallback to `latest`** and no substitution of another Tool version.
- `DRY_RUN` is not execution authority: a dry-run step produces `WOULD_EXECUTE` evidence only.

## Typed data binding

- **Typed bindings only.** Every step input is an explicit binding: either a `literal` with a declared type, or a `step_output` reference naming `from_step`, `output_path`, and a declared type.
- A `step_output` binding may reference only an **earlier** step in the same Skill. Forward references, self references, cross-run references, and references to undeclared outputs are invalid.
- Bindings are schema-checked before the step is proposed: a missing required binding, a type mismatch, an unknown output path, or an unresolved reference is `BLOCKED` before execution — never coerced, defaulted, or guessed.
- No templating language, no expression evaluation, no string interpolation of code, no implicit environment access, and no secret values. Secrets may only appear as `SECRET_REFERENCE`, consistent with P9/P10.
- The Skill cannot widen a Tool's declared input contract; validated inputs are the only inputs passed to the child Action.

## Failure, retry, and fallback semantics

```
on_step_failure = BLOCKED     # declared, not optional
fallback        = NONE        # no alternate Tool, no alternate version
retry           = NONE        # no automatic retry; a retry is a new, separately authorized Action
```

- **`on_step_failure = BLOCKED` means: no skip, no continue, no fallback, no automatic retry.** Remaining steps are not executed.
- Already completed steps keep their P9 Results, events, and evidence; a later block does not rewrite earlier evidence.
- P14 claims no rollback or compensation. Reverting a completed side effect requires its own authorized Action and is not implied by the Skill.
- A blocked or failed step never becomes `SUCCEEDED`, and no step becomes `VERIFIED` without verifier evidence (`SUCCEEDED ≠ VERIFIED`).

## Resource budget and limits

- A Skill declares a `resource_budget` (`cpu_seconds`, `memory_mb`, `output_bytes`, `process_count`, `file_descriptors`). A Skill without a budget is invalid.
- Step limits are constrained by the Skill budget; a step may not declare a budget larger than the Skill's, and P10 binds and enforces the effective limits per call.
- A call that exceeds a declared limit yields limit evidence and `RESOURCE_EXCEEDED`; it is not a success and must not be verified.
- Limits are design and contract requirements in P14. Enforcement is P10's and its executors'.

## Registry governance

- Registering, activating, or modifying a Skill (or a Tool) requires an **explicit P12 delegation** that is valid, unexpired, unrevoked, and in scope, plus a **fresh P11 decision**. No Skill, Tool, Agent, or Planner can self-register, self-activate, or self-delegate.
- Provenance (source, version, hash, issuer/owner where applicable) is mandatory; missing or untrusted provenance is `DENY`/`BLOCKED`.
- Published versions are immutable: a content change requires a new version. Re-registering an existing version with a different hash is `BLOCKED`.
- Registry lifecycle state values are P12's; P14 introduces no new registry state vocabulary.
- Registry unavailability fails closed (`BLOCKED`), never "unrestricted".

## Invocation flow

```mermaid
sequenceDiagram
    participant A as Agent / Planner (P13)
    participant P as Policy (P11)
    participant C as Capability Registry (P12)
    participant E as Execution Authority (P10)
    participant V as Verifier (P16)
    A->>P: propose parent Action (skill.exec)
    P-->>A: decision (plan admission only)
    loop each step, in order
        A->>P: propose child Action (tool.call, parent_action_id)
        P-->>A: fresh decision ALLOW / DENY / REQUIRE_APPROVAL / DRY_RUN / BLOCKED
        alt decision permits
            A->>C: check possession, scope, validity, expiry, revocation
            C-->>A: capability verdict
            alt capability valid
                A->>E: execute through the declared executor
                E-->>A: Result (or RESOURCE_EXCEEDED / TIMEOUT / failure)
                A->>V: submit Result for verification
                V-->>A: evidence (or no evidence)
            else capability invalid
                C-->>A: DENY / BLOCKED
            end
        else not permitted
            P-->>A: no execution
        end
    end
    Note over A,V: any blocking condition stops the run before the next step; no skip / no fallback
```

## Evidence chain

- Each step produces its own P9 Action reference, Result reference, events, executor identity, exit status, and limit evidence. The Skill adds no private log and no parallel evidence model.
- The run's evidence is the ordered set of step evidence plus the parent invocation reference. Aggregation does not upgrade any step's status.
- Evidence carries a hash for integrity; **a hash is an integrity check, not a signature**, and P14 claims no attestation, no signer identity, and no tamper-proof storage.
- Evidence storage belongs to P15; verification belongs to P16. P14 states what must be recorded and never issues `PASS` on its own.
- No secrets in descriptors, bindings, events, results, or evidence; `SECRET_REFERENCE` only.

## Invariants

1. A Skill declares and composes; it never executes and never grants.
2. Steps are linear and explicitly ordered; no branching, loops, DSL, or expression evaluation exists before P18.
3. Every step is a separate P9 Action with its own fresh P11 decision and independent P12 check before P10.
4. `ALLOW` for one step never authorizes another; approvals are never inherited.
5. Every Tool reference is pinned by exact version and hash; unknown or mismatched references are `BLOCKED` with no fallback to `latest`.
6. Published Tool and Skill versions are immutable; content changes require a new version.
7. Bindings are typed, explicit, and backward-only inside the same run; invalid bindings block before execution.
8. `on_step_failure` is `BLOCKED`; there is no skip, continue, fallback, or automatic retry, and no rollback claim.
9. The Skill `risk_class` must be greater than or equal to the highest step `risk_class`; `CLASS-6` is `DENY Always`; risk is never lowered by declaration.
10. Registry writes require explicit valid P12 delegation and a fresh P11 decision; no self-grant, no invented `CAP_*`.
11. Evidence is per step under P9 contracts and is neither signed nor stored by P14.
12. No Skill runtime, orchestration engine, or implementation language is introduced before P18.

## Acceptance

P14-Skill is contract-complete when `skill-schema.yaml` validates against the JSON Schema draft 2020-12 meta-schema and against the valid/invalid instances in `tool-skill-examples.yaml` (including the non-schema invariants checked by `tests/tool-skill.test.sh`); the acceptance vectors cover missing per-step authorization, hash mismatch, resource-limit breach, version immutability, risk bounds, registry governance, and the evidence chain; and ADR 0013 is accepted. These are contract checks, not a Skill runtime.

## References

- `docs/architecture/roadmap.md` — authoritative phase order and P14 scope
- `docs/architecture/frozen-baseline.md` — P8 trust boundaries and freeze
- `docs/contracts/tool.md` — Tool Contract (same phase)
- `docs/contracts/action.md` — P9 `skill.exec`, `tool.call`, `parent_action_id`
- `docs/contracts/task.md`, `lifecycle.md` — P9 Task/Run and state machines
- `docs/contracts/execution-authority.md` — P10 limits, timeout, DRY-RUN, verification hooks
- `docs/contracts/policy.md` — P11 decisions and `CLASS-0`…`CLASS-6`
- `docs/contracts/capability-registry.md` — P12 grants, delegation, lifecycle, provenance
- `docs/contracts/agent-runtime.md` — P13 proposal boundary
- `docs/contracts/skill-schema.yaml`, `tool-schema.yaml`, `tool-skill-examples.yaml`, `tool-skill-acceptance-tests.yaml`
- `docs/architecture/adr/0013-tool-skill-contract.md`
