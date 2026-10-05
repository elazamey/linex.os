# Agent Invocation Lifecycle — P13

> Contract-only orchestration view. P9 remains authoritative for Task/Run and Action states; P11 remains authoritative for policy decisions; P12 remains authoritative for capability possession and scope.

## Invocation state machine

```mermaid
stateDiagram-v2
    [*] --> RECEIVED
    RECEIVED --> VALIDATING
    VALIDATING --> NEEDS_CLARIFICATION: required intent or resource is ambiguous
    VALIDATING --> REJECTED: explicit invalid or out-of-bound request
    VALIDATING --> BLOCKED: identity, schema, policy, or registry is unknown/unavailable
    VALIDATING --> PLANNING: P9 Task and scoped context are valid
    PLANNING --> ACTION_PROPOSED: emit a schema-valid P9 Action, no side effect
    ACTION_PROPOSED --> WAITING_POLICY
    WAITING_POLICY --> REJECTED: P11 DENY
    WAITING_POLICY --> BLOCKED: P11 BLOCKED or UNKNOWN
    WAITING_POLICY --> WAITING_APPROVAL: P11 REQUIRE_APPROVAL
    WAITING_APPROVAL --> WAITING_POLICY: approval recorded; obtain a fresh P11 decision
    WAITING_POLICY --> DRY_RUN: P11 DRY_RUN
    DRY_RUN --> WAITING_POLICY: record simulation; re-evaluate any real action
    WAITING_POLICY --> WAITING_AUTHORIZATION: P11 ALLOW (not execution authorization)
    WAITING_AUTHORIZATION --> REJECTED: explicit authorization denial
    WAITING_AUTHORIZATION --> BLOCKED: authorization context is missing or unknown
    WAITING_AUTHORIZATION --> EXECUTING: Authorization confirms P12 grant; hand off only to P10
    EXECUTING --> VERIFYING: P9 Result is returned
    EXECUTING --> FAILED: referenced P9 Run is FAILED
    VERIFYING --> COMPLETED: P9 Run is VERIFIED and evidence exists
    VERIFYING --> UNVERIFIED: evidence is missing or verifier did not pass
```

`RECEIVED → VALIDATING → PLANNING → ACTION_PROPOSED → WAITING_POLICY → WAITING_AUTHORIZATION → EXECUTING → VERIFYING → COMPLETED` is the complete success path. `COMPLETED` is only an Agent invocation outcome; the underlying P9 Run must already be `VERIFIED`. No transition may skip policy, authorization, Execution Authority, or verification.

## Existing-contract mapping

| P13 invocation state | Owning contract and meaning |
|---|---|
| `RECEIVED`, `VALIDATING`, `PLANNING`, `NEEDS_CLARIFICATION` | P13 orchestration; does not authorize an Action |
| `ACTION_PROPOSED` | P9 Action is `PROPOSED`; this is a proposal, not approval |
| `WAITING_POLICY`, `WAITING_APPROVAL`, `DRY_RUN` | P11 decisions: `ALLOW`, `DENY`, `REQUIRE_APPROVAL`, `DRY_RUN`, `BLOCKED`; P13 must not invent new policy decisions |
| `WAITING_AUTHORIZATION` | Authorization checks P12 capability possession, actor, scope, validity, expiry, revocation, and approval |
| `EXECUTING` | P10 only; the Agent Runtime hands off an already-authorized P9 Action |
| `VERIFYING`, `COMPLETED`, `UNVERIFIED`, `FAILED` | P9 Result/Run and Verifier/Evidence determine the outcome; no self-verification |
| `REJECTED`, `BLOCKED` | P13 response outcomes that reference the owning P9/P11/P12 reason; not permission grants |

The labels `PENDING`, `VALIDATED`, and `APPROVED` are not substituted for P9/P11/P12 state. In particular, P11 `ALLOW` is not `AUTHORIZED`, and `REQUIRE_APPROVAL` is not an approval. A granted approval is bound to the action and context, then policy is evaluated again.

## End-to-end interaction

```mermaid
sequenceDiagram
    actor Caller
    participant AR as Agent Runtime / Planner
    participant P as Policy Engine (P11)
    participant A as Authorization (consumes P12 Registry)
    participant EA as Execution Authority (P10)
    participant V as Verifier (P9)
    participant E as Event Bus (P9)

    Caller->>AR: P9 Task + scoped context
    AR->>E: agent.invocation.received
    AR->>AR: validate identity, schema, scope, ambiguity
    AR-->>Caller: NEEDS_CLARIFICATION / REJECTED / BLOCKED (if applicable)
    AR->>AR: plan; convert intent to typed P9 Action
    AR->>E: action.proposed (actor=agent, correlation_id)
    AR->>P: P9 Action + policy reference
    P-->>AR: ALLOW / DENY / REQUIRE_APPROVAL / DRY_RUN / BLOCKED
    alt P11 DENY or BLOCKED
        AR->>E: agent.rejected or agent.blocked (decision reference)
    else P11 REQUIRE_APPROVAL
        AR-->>Caller: WAITING_APPROVAL (no execution)
        Caller->>A: explicit approval bound to this Action/context
        A-->>AR: verified approval reference
        AR->>P: fresh Policy evaluation of the Action
        P-->>AR: new authoritative decision
    else P11 DRY_RUN
        AR->>EA: no-side-effect simulation through P10
        EA-->>AR: dry-run Result
        Note over AR,P: A real action requires a new evaluation and authorization
    else P11 ALLOW
        AR->>A: check actor, capability, scope, validity, approval
        A-->>AR: AUTHORIZED / DENY / BLOCKED
        alt Authorization is AUTHORIZED
            AR->>EA: authorized Action only
            EA-->>AR: P9 Result
            AR->>V: Result + required verification context
            V-->>AR: P9 Evidence or UNVERIFIED
            AR->>E: invocation outcome referencing Result/Evidence
        else Authorization is DENY or BLOCKED
            AR->>E: agent.rejected or agent.blocked (decision reference)
        end
    end
```

If P11 returns `REQUIRE_APPROVAL`, the invocation waits; approval does not jump directly to execution. The action is re-evaluated by P11, then independently authorized. Unknown or unavailable decision inputs stop the flow fail-closed. Cancellation and retry use P9 Task/Run rules and cannot bypass policy or authorization.

## Transition invariants

- Every transition has one current state, one explicit event, actor, timestamp, and correlation reference; invalid transitions are rejected.
- `ACTION_PROPOSED` does not imply `ALLOW`; `ALLOW` does not imply `AUTHORIZED`; `SUCCEEDED` does not imply `VERIFIED`.
- A DRY_RUN has no real side effect. Any subsequent real action is revalidated and requires its own applicable approval.
- `NEEDS_CLARIFICATION`, `REJECTED`, `BLOCKED`, `FAILED`, and `UNVERIFIED` never silently become success or authorization.
- No automatic agent handoff may increase capability, scope, risk, or approval level; P12 delegation and fresh P11 evaluation are required.
