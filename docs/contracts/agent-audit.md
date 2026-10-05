# Agent Audit Requirements — P13

> Contract-only requirements for how Agent Runtime activity is recorded. P9 Event and Result/Evidence contracts remain the source of truth; no audit-store implementation or cryptographic signing is introduced here.

## Recording boundary

The Agent Runtime emits events only through the P9 append interface. It may append and read permitted references; it must not update or delete an event through the Agent Runtime boundary. The Event Store's persistence, retention, access control, deletion, and tamper-evidence implementation remain future work (P15 / implementation). P13 therefore specifies an append-only contract, not a claim that a deployed log is physically undeletable.

P13 extends the P9 event vocabulary with these invocation-level types:

| Event | When | Required safe references |
|---|---|---|
| `agent.invocation.received` | A P9 Task is accepted for validation | P9 `actor.id` (Agent identity), `task.id`, `correlation_id` |
| `agent.context.bound` | Identity, scope, and permitted context references are bound | `actor.id`, `task.id`, `payload.scope`, `payload.context_ref`, `correlation_id` |
| `agent.clarification.required` | Required intent/resource details are ambiguous | `task.id`, `payload.reason_code`, `correlation_id` |
| `agent.rejected` | Validation or an authoritative P11/P12 decision rejects the proposal | `task.id`, optional `action.id`, `payload.reason_code`, `payload.decision_ref` when one exists, `correlation_id` |
| `agent.blocked` | A required identity, schema, policy, capability, authorization, or evidence input is unknown/unavailable | `task.id`, `payload.reason_code`, safe source reference if available, `correlation_id` |
| `agent.invocation.completed` | A P9 Run is verified | `task.id`, `task.run_id`, `payload.result_id`, `evidence.id`, `correlation_id` |

P9 `action.proposed`, `policy.*`, execution, verification, and `evidence.created` events remain owned by their respective contracts; P13 references them rather than duplicating or rewriting their decisions. An Agent event is not itself verification evidence.

## Required event envelope

Every event uses the P9 Event Contract fields and schema: unique immutable `event_id`, UTC `timestamp`, `actor`, event `type`, `task`/`run`/`action` references as applicable, `result`, and `correlation_id`. P13 payloads add only:

- a stable `reason_code` for clarification, rejection, or blocking (not an LLM-generated authorization rationale);
- `decision_ref` to the authoritative P11/P12 decision when one exists;
- opaque `agent_id`, `context_ref`, and artifact references only where needed;
- `scope` and outcome needed to explain the transition.

Missing required fields, an unknown decision source, an invalid event schema, or an untrusted event reference fails closed. Keep correlation IDs consistent across Task, Run, Action, Policy, Result, and Evidence.

## Privacy and integrity

- Never put credentials, secret values, unredacted secret-bearing prompts, private keys, or raw tool output in an event. Prefer typed reason codes and opaque references; reject or safely redact sensitive values before append.
- Do not use logs as policy input or as proof of verification. Only the Verifier produces P9 Evidence; no Agent may attest its own success.
- No mutable audit API is exposed to the Agent Runtime. Append-only and immutability follow P9; any retention/deletion policy must be separately audited by the future store contract.
- A rejection record states what was rejected, the safe reason, and the authoritative decision reference when available. It never turns `DENY`, `BLOCKED`, or missing evidence into `PASS`.
- No claim of a digital signature, hash chain, write-once medium, or tamper-proof storage is made by P13. Such mechanisms require a later contract and implementation evidence.

## Audit acceptance

The P13 acceptance vectors require a denied/blocked path to carry a reason and correlation reference without secret payload, and a successful completion to reference P9 Result and Evidence. They validate the contract text and structured examples only; storage mutation resistance cannot be runtime-tested until an implementation exists.
