# LINEX.OS — Core Runtime Contracts (P9)

> **P9 — Contract First → Implementation Later**
> No product code, no runtime implementation, no package installation, no system changes.
> Only contracts, schemas, state machines, invariants, tests.
> Respects P8 Architecture Freeze (frozen-baseline.md). Any violation requires ADR.

## Principle

```
Contract First
      ↓
Implementation Later
```

P8 defined **What is LINEX.OS** and **23 components** with boundaries. P9 defines **the language** LINEX.OS speaks internally before writing first real Runtime.

If Arena starts writing runtime directly, it will assume Python/Node/Rust/database/event bus before interfaces stable. P9 prevents that.

```
P8 ✅ Architecture Freeze (Model C hybrid, 23 components, trust boundaries, capability model)
        ↓
P9  Core Runtime Contracts (this phase) — contracts + schemas + state machines + invariants + tests, no impl
        ↓
P10 Execution Authority Contracts
        ↓
P11 Policy Engine Contract
        ↓
P12 Capability System Contract
        ↓
P13 Agent Runtime Contract
        ↓
P14 Tool/Skill Contract
        ↓
P15 Memory + Event + State Contracts
        ↓
P16 Verification/Evaluation Contract
        ↓
P17 MCP Boundary Contract
        ↓
P18 Technology Selection ADRs
        ↓
Implementation
```

This makes LINEX.OS **platform architecture**, not big monolithic app.

## The 5 Core Contracts

P9 fixes 5 foundational contracts:

```
1. Runtime Contract  — lifecycle, task execution, state transitions, cancellation, recovery, config, health, events, verification hooks
2. Task/Run Contract — unit of work, execution instance, inputs/outputs, capabilities, risk, retry, timeout
3. Action Contract    — proposed by Agent/Planner, validated by Policy, authorized, executed by Execution Authority, verified
4. Event Contract     — append-only immutable events, no secrets, correlation, observability distinction
5. Result/Evidence Contract — output, error, metrics, evidence, attestation, SUCCEEDED≠VERIFIED
```

Then Agent can say:

```
Task created
→ Plan
→ Action proposed
→ Policy (ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN)
→ Execute (via Execution Authority)
→ Result
→ Verify
→ Evidence
→ Learn
```

Without being tied directly to Linux or LLM provider.

## CoreRuntime Structure (contract only, no impl language)

```
CoreRuntime
  ├── lifecycle        — Created → Initializing → Ready → Running → Pausing → Paused → Resuming → Stopping → Stopped → Failed → Terminated
  ├── task execution   — Task → Run → Actions → Results → Evidence
  ├── state transitions— explicit state machine, no implicit jumps, fail-closed UNKNOWN→BLOCKED/UNVERIFIED
  ├── cancellation     — cooperative, timeout, explicit, no orphaned resources
  ├── recovery         — retry, resume, compensation, no auto-success
  ├── configuration    — runtime config, env, resource limits, capabilities, no secrets in config files
  ├── health           — /health, readiness, liveness, resource usage, no privileged logic in UI
  ├── events           — task.*, action.*, runtime.*, verification.*, evidence.* with event_id, timestamp, actor, correlation_id, no secrets
  └── verification hooks — hooks for Verifier to produce evidence, no PASS without evidence, SUCCEEDED≠VERIFIED
```

## Contracts Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        CoreRuntime                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  Task    │→ │  Action  │→ │  Event   │→ │ Result/  │          │
│  │  /Run    │  │          │  │          │  │ Evidence │          │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │
│       │            │             │            │                  │
│       ↓            ↓             ↓            ↓                  │
│   State Store  Policy/Auth  Event Bus   Evidence Store           │
│   Memory Store Execution   Observability Verification           │
└─────────────────────────────────────────────────────────────────┘

Dependency Direction (P8 frozen):
UI→API→App Services→Runtime→Policy/Auth→Execution→Host/External
No cycles, no UI→sudo, no LLM→shell, no Agent→prod DB direct, no MCP→unrestricted host
```

## Relation to P8

- P8 frozen-baseline.md: Model C hybrid, trust boundary LLM→Planner→Policy→Auth→Execution→Verifier→Evidence, capability DEFAULT DENY, fail-closed, 23 components
- P9 respects P8: no violation without ADR, no product code, no package install, no system changes, repository-only
- P9 extends P8: defines internal language for Runtime, Task/Run, Action, Event, Result/Evidence with schemas, state machines, invariants
- Open decisions from P8 remain PENDING: Programming Language, Runtime tech, DB, Event bus, Sandbox, UI/API framework, Browser engine, MCP transport, Deployment topology — P9 does NOT choose them, only defines contracts vendor-neutral free-first self-hostable local-capable

## Files

- README.md — this overview
- runtime.md — Runtime Contract
- task.md — Task/Run Contract
- action.md — Action Contract
- event.md — Event Contract
- result.md — Result/Evidence Contract
- lifecycle.md — State machines for Runtime, Task/Run, Action, Event, Result with Mermaid diagrams
- ADR 0007 — Core Runtime Contracts ADR

## Invariants (P9)

- No implementation language chosen in P9
- No product code (no src/*.py/*.js/*.go/*.rs)
- No package installation (no apt install as executable)
- No system changes (no sudo, systemctl, user/group, firewall, disk, boot, PowerShell, Docker)
- No secrets in repo (no API keys, tokens, private keys, credentials, no commit/print/log secrets)
- No /tmp inside repo, no *.deb inside repo
- Contracts are vendor-neutral, free-first, self-hostable, local-capable, no mandatory paid API/cloud DB
- Fail-closed: unknown contract field → DENY/BLOCKED/UNVERIFIED, missing auth → DENY, missing evidence → UNVERIFIED, ambiguous identity → DENY
- State transitions explicit, no implicit jumps, no auto-success, SUCCEEDED≠VERIFIED, EXECUTED≠SAFE, LOCAL≠PRODUCTION, MOCK≠PRODUCTION
- Events append-only immutable, no secrets, with event_id, timestamp, actor, correlation_id
- Evidence with STATUS/RESULT/EVIDENCE/NEXT, ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY, no PASS without evidence
- UI client only, UI→API only, no privileged logic in UI
- LLM→shell forbidden, must go via Planner→Policy→Execution Authority→Verifier
- Capability explicit, DEFAULT DENY, UNKNOWN→DENY
- MCP via Gateway, no unbounded host access
- Storage abstraction interfaces local/optional remote/replaceable, no vendor
- Resource limits design only (CPU, memory, disk, process count, FD, network, execution time, output size), no enforcement in P9
- Low-resource modes CORE/STANDARD/HEAVY respected, no GPU/K8s assumed
- Diagrams ASCII/Mermaid, no product code
- Tests verify contracts existence, invariants, no implementation, no contradictions with P8 frozen baseline

## Verification

- tests/contracts.test.sh — 15 checks similar to architecture.test.sh
- ops/verify/verify-contracts.sh — invariants, no product code, no package install, repository-only
- scripts/doctor.sh — still PASS WITH KNOWN BLOCKER P4, no new failures
- bash -n for all shell scripts
- No secrets, no destructive patterns as executable (Test/Policy Boundary from P7/P8 preserved)

## Historical phase progression

P9's immediate next phase was P10 Execution Authority Contracts, which are now recorded in
`execution-authority.md` and ADR 0008. P11 Policy Engine and P12 Capability Registry followed.
The current contract phase is P13 Agent Runtime (accepted by ADR 0012); the authoritative next
phase is P14 Tool + Skill Contract, per `docs/architecture/roadmap.md`.

## References

- docs/architecture.md (P8 full)
- docs/architecture/frozen-baseline.md (freeze)
- docs/architecture/adr/0001-0006 (ADRs)
- docs/architecture/components.md (23 components)
- docs/architecture/execution-model.md (LLM→Planner→Policy→Execution→Verifier)
- docs/architecture/security-boundaries.md (trust boundaries, Test/Policy Boundary)
- docs/architecture/capability-model.md (CAP_*)
- docs/architecture/event-model.md (events)
- docs/architecture/data-model.md (state, memory, artifact, storage)
- docs/agent-contract.md (AI PROPOSES→POLICY→EXECUTION→VERIFIER)
- ADR 0007 (this phase)

## P13 — Agent Runtime Contract (ACCEPTED; contracts only)

P13 specifies an Agent identity/role descriptor, scoped context references, a Planner that emits
P9 Action proposals only, invocation outcomes (`ACTION_PROPOSED`, `NEEDS_CLARIFICATION`,
`REJECTED`, `BLOCKED`), and explicit handoffs to P11 Policy, P12 Authorization/capability
checks, P10 Execution Authority, and the P9 Verifier. It does not redefine the P9 Task/Run,
Action, Event, or Evidence states. `ALLOW` is not `AUTHORIZED`; `REQUIRE_APPROVAL` is not an
approval. There is no direct LLM/Planner/Agent-to-executor path or self-grant.

P13 deliverables:

- `agent-runtime.md` — concise Agent/Planner and authority contract
- `agent-lifecycle.md` — Mermaid invocation state machine and component interaction
- `agent-audit.md` — append-only P9 event use, rejection reasons, and privacy boundaries
- `agent-acceptance-tests.yaml` — eight YAML 1.2 JSON-compatible structured acceptance vectors,
  validated with existing `jq` (no YAML parser dependency)
- `../architecture/adr/0012-agent-runtime-contract.md` — accepted P13 decision
- `../../tests/agent-runtime.test.sh` — 28/28 local contract checks
- `../../ops/verify/verify-agent-runtime.sh` — 11/11 local verification checks

The vectors and checks verify contract presence and consistency only; they do not simulate an
Agent Runtime, prove immutable deployed storage, or constitute production verification. P14
Tool + Skill Contract is next; technology selection remains reserved for P18.
