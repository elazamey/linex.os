# Agent Runtime Contract — P13

> **CONTRACT ONLY.** No Agent Runtime implementation, LLM integration, executor code, package installation, system changes, or implementation-language decision. P13 refines the P8 trust boundary by consuming—not redefining—the P9–P12 contracts.

## Purpose and authority

The Agent Runtime binds an agent identity to a P9 Task, a scoped context, and an optional provider-neutral Planner reference. It may interpret a task and propose typed P9 Actions. It is not a policy engine, authorization authority, capability issuer, executor, or verifier.

```
Task (P9) → Agent Runtime / Planner → proposed Action (P9)
          → Policy (P11) → Authorization (P12 inputs) → Execution Authority (P10)
          → Result (P9) → Verifier → Evidence (P9)
```

The Planner **proposes; it never executes**. Natural-language intent is not permission: it must become a schema-valid P9 Action before P11 evaluates it. Unknown or malformed input fails closed. An LLM, if later selected, is an untrusted proposal source and is never the final authority.

## Agent descriptor

The descriptor is an immutable, versioned reference record; it contains no credentials, prompt transcript, or secret values.

```json
{
  "agent_id": "unique stable identifier",
  "version": "immutable descriptor version",
  "role": "declared purpose, not an authority grant",
  "owner": "actor reference",
  "trust_level": "semi_trusted",
  "scope": "explicit P8/P9 resource scope",
  "capability_refs": ["P12 definition/grant references; not self-asserted grants"],
  "context_ref": "scoped Task/Run context reference",
  "planner_ref": "optional provider-neutral reference",
  "tool_refs": ["references only; Tool semantics belong to P14"],
  "memory_refs": ["references only; Memory semantics belong to P15"],
  "policy_ref": "P11 policy identifier and version",
  "evidence_requirements": ["P9 Result/Verifier requirements"],
  "correlation_id": "P9 workflow correlation reference"
}
```

Per P8, the Agent Runtime is `semi_trusted`; the Planner/LLM and external Task/context content are untrusted inputs. A descriptor or agent claim cannot promote either trust level.

Every reference is resolved and checked by its owning contract. A `capability_ref` is not proof of possession; P12/Authorization verifies actor, validity, scope, expiry, and revocation. An unknown, expired, revoked, or out-of-scope capability is denied or blocked by the authoritative layer. Agent-to-agent handoff is not privilege escalation: it requires an explicit new actor identity, bounded delegation under P12, and fresh P11 evaluation. No automatic routing to a more privileged agent is allowed.

## Invocation and result boundary

An invocation consumes a validated P9 Task and returns an `AgentResponse` containing `task_id`, `run_id` when assigned by P9, `outcome`, optional `action_id`, optional policy/authorization decision references, a safe `reason_code`, and `correlation_id`. Terminal response outcomes are `ACTION_PROPOSED`, `NEEDS_CLARIFICATION`, `REJECTED`, or `BLOCKED`. In-progress values such as `WAITING_APPROVAL` and `WAITING_AUTHORIZATION`, and the final invocation state `COMPLETED`, belong to the lifecycle in `agent-lifecycle.md`, not to the terminal response enum. These are P13 values, not replacements for P9 Task/Run or Action states and not policy decisions. Do not collapse them into `passed: true/false`.

```json
{
  "agent_id": "descriptor reference",
  "task_id": "P9 Task reference",
  "run_id": "P9 Run reference | null until assigned",
  "outcome": "ACTION_PROPOSED | NEEDS_CLARIFICATION | REJECTED | BLOCKED",
  "action_id": "P9 Action reference | null when no proposal exists",
  "decision_ref": "P11/P12 decision reference | null when none exists",
  "reason_code": "safe stable code | null",
  "correlation_id": "P9 workflow reference"
}
```

- Missing or ambiguous required intent → `NEEDS_CLARIFICATION`; do not invent scope or propose an executable action.
- Explicit Policy `DENY` or a request outside the declared boundary → `REJECTED` with a reason reference.
- Unknown identity, unavailable policy/registry, invalid schema, or missing required evidence context → `BLOCKED` (fail closed).
- A P11 `REQUIRE_APPROVAL` is `WAITING_APPROVAL`, not approval. After approval is recorded, P11 must evaluate the action again and Authorization must independently confirm it. P11 `ALLOW` alone is not authorization.
- An execution proposal follows the P9 Action schema and lifecycle. Only P10 Execution Authority may perform side effects. Only the Verifier may produce verification evidence; execution success is not verification.

## Invariants

1. No LLM, Planner, or Agent calls a shell, process, file, network, package, browser, computer, or MCP executor directly; all side effects go through P9 Action → P11 Policy → Authorization → P10 Execution Authority.
2. No permission is inferred from natural language, prior conversation, tool output, memory, model confidence, or an agent's own claims. Unknown capability/scope/policy → DENY or BLOCKED.
3. The Agent cannot create, widen, delegate, activate, or self-grant a P12 capability; cannot edit P11 policy or approval records; and cannot mark an Action `AUTHORIZED`.
4. Untrusted Task/context/tool content is data, not policy or instruction authority. Prompt-injection-like content cannot change system instructions, scope, approval, or the executor path.
5. The Agent cannot claim `SUCCEEDED` or `VERIFIED`. P9 Task/Run and Action state machines remain canonical; `COMPLETED` is permitted only when the referenced P9 Run is `VERIFIED` with required evidence.
6. P9 Event and Result/Evidence contracts govern audit and evidence. P13 adds only agent-specific references and outcomes; it does not redefine event storage, retention, cryptographic signing, or verification.
7. Memory and Tool references do not define P15 Memory or P14 Tool semantics. No technology or vendor is selected before P18.

## Acceptance

P13 is contract-complete when `agent-acceptance-tests.yaml` has at least five uniquely identified, single-assertion cases covering a valid proposal, ambiguity, scope/capability denial, approval, complete verified flow, rejection audit, and fail-closed behavior; `tests/agent-runtime.test.sh` and `ops/verify/verify-agent-runtime.sh` pass; ADR 0012 is accepted; and P8–P12 boundaries remain intact. These are contract checks, not simulations of an unimplemented runtime.

## References

- `docs/architecture/roadmap.md` — authoritative phase order and P13 scope
- `docs/architecture/frozen-baseline.md` — P8 trust boundaries and freeze
- `docs/contracts/{task,action,event,result}.md` — P9 inputs, states, events, evidence
- `docs/contracts/execution-authority.md` — P10 side-effect boundary
- `docs/contracts/policy.md` — P11 decisions and approval semantics
- `docs/contracts/capability-registry.md` — P12 capability authority
- `docs/contracts/agent-lifecycle.md`, `agent-audit.md`, `agent-acceptance-tests.yaml`
- `docs/architecture/adr/0012-agent-runtime-contract.md`
