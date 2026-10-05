# ADR 0012 — Agent Runtime Contract (P13)

- Status: ACCEPTED
- Date: 2026-10-05
- Phase: P13 — Agent Runtime Contract ONLY; contracts, lifecycle, audit requirements, acceptance vectors, verifier and tests; no product implementation
- Baseline: `deb4d13b07757ae10db650799536771e99f252fb` (main, before P13 changes)
- Related: ADRs 0001–0011; `docs/architecture/frozen-baseline.md`; P9 Task/Action/Event/Result contracts; P10 Execution Authority; P11 Policy Engine; P12 Capability Registry

## Context

P12 completed the capability contract and registry. The next authoritative phase is P13 Agent Runtime Contract (ADR 0011 D4). Agent behavior must now be specified without pre-empting Technology Selection at P18 or adding code. P8 fixes the trust boundary; P9–P12 already own task/action states, events/evidence, side effects, policy decisions, and capability semantics.

The supplied draft suggested `PENDING → VALIDATED → APPROVED → EXECUTING → COMPLETED/REJECTED`, a boolean validation result, a P6 Coordinator, and generic “P7/P8/P9” authorities. Those labels do not match the accepted contracts: P9 owns Task/Run and Action states, P11 decisions are `ALLOW`, `DENY`, `REQUIRE_APPROVAL`, `DRY_RUN`, or `BLOCKED`, and P12 supplies capability authority. `ALLOW` is not authorization; approval is not an Agent state; an unknown condition cannot be promoted to approval.

## Decision

1. Define a provider-neutral Agent descriptor and invocation response; Agent/Planner may propose schema-valid P9 Actions only.
2. Keep P9 Task/Run, Action, Event, Result/Evidence; P10 Execution Authority; P11 Policy; and P12 Capability Registry as the only authorities for their respective contracts. P13 references them and adds no competing permission, action, or verification state machine.
3. Make ambiguity produce `NEEDS_CLARIFICATION`, authoritative denial produce `REJECTED`, and missing/unknown trust inputs produce `BLOCKED`. `ACTION_PROPOSED` is a proposal only. Approval waits for an external bound approval and fresh policy evaluation.
4. Forbid LLM/Planner/Agent direct side effects, self-grant, implicit capability inheritance, permission inference from natural language, self-verification, and automatic escalation through handoff.
5. Add invocation lifecycle and audit requirements as documentation. P13 events use the P9 append-only Event Contract and carry safe decision references; retention, cryptographic signing, and physical tamper resistance are not claimed.
6. Store acceptance vectors in `docs/contracts/agent-acceptance-tests.yaml` using the YAML 1.2 JSON-compatible subset, validated with the already-required `jq`; add no parser or implementation-language dependency.
7. Put deliverables in the existing canonical `docs/contracts/` and `docs/architecture/adr/` structure, not a new `docs/phases/P13` or `contracts/P13` hierarchy. Add a repository-only test and verifier and wire them into CI.

## Alternatives considered

- **Adopt the draft's `APPROVED` Agent state.** Rejected: it conflates P11 `REQUIRE_APPROVAL`/`ALLOW` with P12 authorization and could bypass fresh policy evaluation.
- **Let a privileged Agent take over when scope is exceeded.** Rejected: automatic handoff can become privilege escalation; any handoff needs a distinct actor, bounded P12 delegation, and fresh P11 evaluation.
- **Claim the audit log cannot be deleted or is cryptographically signed.** Rejected: no Event Store implementation exists; P13 can require append-only use at the interface but cannot prove physical immutability or signatures.
- **Add YAML parser, agent runtime, or formal execution DSL.** Rejected: unnecessary dependency and implementation choice before P18. The existing `jq` can validate the structured acceptance vectors without a new parser.

## Consequences

- Positive: Agent identity, role, capability/context references, Planner boundary, lifecycle, rejection outcomes, and audit obligations are explicit; acceptance scenarios can be checked without simulating a nonexistent runtime.
- Negative: P13 proves contract presence/consistency, not model behavior, runtime sandboxing, Event Store immutability, or production security. Those require later implementation and evidence.
- Neutral: P14 Tool + Skill Contract remains next. Memory/Tool details remain owned by P15/P14; implementation technology remains pending until P18.

## Status

ACCEPTED — P13 Agent Runtime Contract is contracts-only. No Agent code, LLM integration, Executor implementation, package installation, system changes, implementation-language choice, or production claim is authorized by this ADR.

## References

- `docs/architecture/roadmap.md` — P13 scope and phase order
- `docs/architecture/adr/0011-baseline-reconciliation-and-phase-numbering.md` — D4 phase numbering and D5 implementation gate
- `docs/contracts/agent-runtime.md`, `agent-lifecycle.md`, `agent-audit.md`, `agent-acceptance-tests.yaml`
- `tests/agent-runtime.test.sh`, `ops/verify/verify-agent-runtime.sh`
