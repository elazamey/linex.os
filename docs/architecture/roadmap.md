# LINEX.OS — Roadmap

Baseline phase ledger reconciled to merged `main` at `deb4d13` per ADR 0011 (D4); P13 is the
contract-only work recorded on the current session branch after that baseline. Status values
follow ADR 0011 (D2): `COMPLETE` means the phase's documents exist, are self-consistent and are
machine-checked by a shipped suite that passes — it never means "implemented". The P1–P12
measurements are re-derivable via `docs/reports/baseline-audit-d349f92.md`; P13 has separate local
evidence in its test and verifier outputs.

## Foundation (P1-P7) — COMPLETE

```
P1 ✅ COMPLETE — Environment Discovery, Bootstrap Foundation (read-only, fail-closed)
P2 ✅ COMPLETE — Privilege Policy / Gate (allowlist + structured actions + dry-run + evidence, 28 tests)
P3 ✅ COMPLETE — Linux Toolchain (gcc, g++, make, pkg-config, 44 tests, C/C++ smoke)
  - Re-measured at d349f92: 43/44 PASS in a fresh Arena sandbox, 1 FAIL = pkg-config MISSING
  - pkg-config is ENVIRONMENT-DEPENDENT per ADR 0011 (D2): a previous sandbox built pkgconf
    from source outside the repository, which is not re-derivable from repository contents
  - Cause measured, not assumed: apt-get -s install pkg-config → "Unable to locate package";
    deb.debian.org → curl (52) Empty reply. Not remediable in-sandbox, no system changes made
  - CI Job 4 (Toolchain Tests P3) succeeds because ci.yml provisions the P3 baseline first
    (CI-H4) and then lets the test verify it — the runner image is not part of the contract
P4 ⛔ BLOCKED — PowerShell 7 (Arena network restriction: packages.microsoft.com and release-assets blocked, github.com PASS, Gate and logic PASS 18 tests, no third-party)
P5 ✅ COMPLETE — Repository Foundation (docs/, config/, tests/, .github/workflows/, README, LICENSE, SECURITY, CONTRIBUTING, .gitignore)
P6 ✅ COMPLETE — Agent Contract (AGENTS.md, ARENA.md, docs/agent-contract.md, 15 tests)
P7 ✅ COMPLETE — Doctor + CI Hardening + Final Foundation Verification (PASS WITH KNOWN BLOCKER P4)
  - Doctor aggregator: measured at d349f92 in Arena → Counts PASS=45 FAIL=1 BLOCKED=2
    NOT_VERIFIED=1, exit 3 (FAIL). Single root cause: pkg-config absent (see P3 above), which
    cascades P3 suite → doctor "P3 Toolchain Tests" → doctor "Tests" → exit 3. On the GitHub
    runner Job 6 (Doctor / Final Verification) is success. Exit semantics deliberately
    unchanged: a required tool missing is a real FAIL, and the classification lives in the
    evidence layer, not in the aggregator (ADR 0011 D3)
  - Secret-scan repository-wide including tests/ and .github, no directory exclusion (P7 fix)
  - Static-security-check (no eval, curl|bash, etc. as executable, Test/Policy Boundary for tests/)
  - CI hardened: permissions contents: read, pinned checkout SHA 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1, 6 jobs, no Docker/PowerShell required
  - Verification-summary.txt artifact, no secrets
  - FOUNDATION STATUS: PASS WITH KNOWN BLOCKER

REMOTE CI: VERIFIED on merged `main` at `deb4d13` before P13 — run 37278075520, 6/6 jobs
success. Job conclusions and step conclusions are available; runner log bodies remain subject
to the ADR 0011 D7 retrieval limit. The P13 changes on this session branch have local evidence
(28/28 contract tests, 11/11 verifier checks); a remote run for these unpushed changes is
PENDING and is not claimed here.
The earlier "REMOTE CI: NOT VERIFIED — branch not pushed, main at 768bf39" statement described
the P7/P8 no-push policy of that time and is superseded: PR #1 and PR #2 were both pushed and
merged.

FOUNDATION = VERIFIED locally, with one ENVIRONMENT-DEPENDENT gap (P3 pkg-config)
```

## Architecture (P8) — COMPLETE

```
P8 ✅ COMPLETE — Architecture Design ONLY (this phase)
  - No product code, no runtime implementation, no UI/API/Agent/MCP/DB implementation
  - Documentation and ADR files and diagrams-as-text only
  - Model C recommended: AI-native execution environment above Linux first, deeper OS integration later (hybrid)
  - System boundary: Inside LINEX.OS (Substrate, Core Runtime, Policy, Authorization, Execution Authority, Verification, Agent/Tool/Skill/MCP Gateway, Services), Outside (Hardware, Host OS, External APIs, Cloud, Production DB), Trusted/Semi-trusted/Untrusted zones
  - Control Plane / Data Plane / Execution Plane / Verification Plane with dependency direction UI→API→Application Services→Runtime→Policy/Authorization→Execution→Host/External, no cycles
  - 23 core components with Purpose/Inputs/Outputs/Trust/Dependencies/May Do/Must Never Do
  - Critical trust boundary: LLM→Planner→Policy→Authorization→Execution Authority→Verifier→Evidence, forbidden direct paths
  - Capability model: CAP_FS_READ, CAP_FS_WRITE, CAP_PROCESS_READ/EXEC, CAP_NETWORK_READ/CONNECT, CAP_PACKAGE_INSTALL, CAP_BROWSER, CAP_COMPUTER, CAP_MCP, CAP_SECRET_ACCESS, each with Risk, Scope, Approval, Executor, Verifier, DEFAULT DENY, UNKNOWN→DENY
  - Resource scoping: workspace, repository, project, user, host, network, production, elevation explicit
  - Agent model, Tool model (Tool Contract), Skill model (Tool vs Skill vs Agent vs Workflow)
  - MCP architecture: Gateway, Registry, trust classification, capability mapping, validation, audit, isolation, no unbounded host access
  - Execution Authority: independent from AI, Shell/Process/File/Browser/Computer/Network/Package executors, each via Policy
  - Sandboxing roadmap: Level 0 Gate (current) → Level 1 unprivileged process → Level 2 filesystem isolation → Level 3 network isolation → Level 4 container/sandbox → Level 5 VM → Level 6 deeper OS integration (no implementation in P8)
  - Policy Engine: inputs Actor/Action/Capability/Resource/Scope/Risk/Env/Context/Approval/Network, decisions ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN, UNKNOWN→DENY
  - State model: PROPOSED→VALIDATING→AUTHORIZED→DRY_RUN→EXECUTING→SUCCEEDED→VERIFIED etc., SUCCEEDED≠VERIFIED, EXECUTED≠SAFE, LOCAL PASS≠PRODUCTION PASS, MOCK≠PRODUCTION
  - Event model: action.proposed, validated, authorized, denied, started, completed, failed, verification.*, evidence.created with event_id, timestamp, actor, action, scope, result, correlation_id, no secrets
  - Memory architecture: Ephemeral Context, Session, Project, User, System with ownership, retention, access policy, encryption, deletion
  - Artifact model: Source, Build, Execution, Evidence, User with owner, scope, hash, provenance, retention
  - Storage abstraction: State Store, Event Store, Memory Store, Artifact Store, Evidence Store interfaces, local/optional remote/replaceable, no vendor chosen, vendor-neutral, free-first
  - Network architecture: Inbound/Outbound/Internal/External, Trusted/Restricted/Untrusted zones, no Agent→Internet unrestricted without capability+policy, current Arena network PASS/BLOCKED documented
  - Identity: User, Agent, Service, Tool, MCP Server, Execution Authority separate identity/context
  - Observability: Logs (DEBUG), Metrics, Traces, Events, Audit, Evidence (VERIFICATION), distinguish, no secrets, no mixing
  - Failure model: Policy, Authorization, Validation, Execution, Network, Dependency, Resource, Verification failures, each not auto success, fail-closed
  - Fail-closed architecture: unknown capability/tool/executor→DENY, missing auth→DENY, missing evidence→UNVERIFIED, untrusted network→BLOCKED, invalid schema→DENY, ambiguous identity→DENY
  - Resource limits design only: CPU, memory, disk, process count, FD, network, execution time, output size
  - Threat model: 16 threats with Asset/Attack/Boundary/Mitigation/Residual Risk, no claim of non-existing mitigations
  - Supply chain: dependency/tool/plugin/MCP provenance, artifact hashes SHA256, version pinning full SHA, signature verification roadmap
  - Multi-tenancy readiness: User/Project/Workspace/Agent/Session separation, no global mutable state
  - API boundary conceptual: /health, /agents, /actions, /capabilities, /tools, /skills, /mcp, /files, /memory, /events, /evidence, /policies
  - UI boundary: client only, no sudo/shell policy/auth logic/secret execution, UI→API only
  - Dependency direction fixed, no cycles
  - Modularity: replaceable LLM Provider, Storage Provider, MCP Provider, Browser Engine, Execution Sandbox, Identity Provider, Observability backend via interfaces
  - Free-first compatibility: vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB
  - Low-resource mode: CORE (minimal), STANDARD (CORE+toolchain+agents+MCP), HEAVY (STANDARD+browser+computer+advanced sandbox), no GPU/K8s assumed
  - Documentation output: context.md, container.md, components.md, execution-model.md, security-boundaries.md, capability-model.md, event-model.md, data-model.md, networking.md, extensibility.md, threat-model.md, roadmap.md, frozen-baseline.md, ADRs 0001-0006, diagrams ASCII/Mermaid
  - Architecture freeze: frozen-baseline.md with decisions, non-goals, interfaces, trust boundaries, security invariants, open/pending/deferred decisions, no implementation should violate baseline without ADR
  - Open decisions: Programming Language, Runtime tech, Database, Event bus, Sandbox, UI framework, API framework, Browser engine, MCP transport, Deployment topology — all DECISION PENDING with criteria
  - Architecture tests: tests/architecture.test.sh, verify-architecture.sh
  - P7 security fix continuation: static-security-check Test/Policy Boundary for tests/ fixtures non-executable vs executable
  - P4 preserved BLOCKED, System changes NONE
  - Historical scope note: at the time P8 executed, its own constraint was "Remote CI NOT
    VERIFIED, Git no push". That constraint bound P8, not the project: PR #1 and PR #2 were
    subsequently pushed and merged, and remote CI is now VERIFIED at d349f92 (see Foundation)
```

## Contract Phases (P9-P12) — COMPLETE

Contracts only. No implementation language was chosen and no product code exists, per the P8
freeze and ADR 0009 (`DECISION PENDING` until Technology Selection). Every `COMPLETE` below
means "contract written, self-consistent, machine-checked" — not "implemented".

```
P9  ✅ COMPLETE — Core Runtime Contract (ADR 0007 ACCEPTED)
      docs/contracts/{runtime,task,action,event,result,lifecycle}.md
      tests/contracts.test.sh → 15/15 PASS · verify-contracts.sh → 46 PASS / 0 FAIL

P10 ✅ COMPLETE — Execution Authority Contract (ADR 0008 ACCEPTED)
      docs/contracts/execution-authority.md, executor-{shell,process,file,network,package}.md,
      executor-matrix.md, execution-lifecycle.md — 5 executor contracts, no executor code
      tests/execution-authority.test.sh → 36/36 PASS · verify-execution-authority.sh → 67/0

P11 ✅ COMPLETE — Policy Engine Contract (ADR 0009 ACCEPTED)
      docs/contracts/{policy,policy-matrix,policy-lifecycle}.md — decision model, risk classes,
      fail-closed cases, determinism, no policy engine code
      tests/policy.test.sh → 40/40 PASS · verify-policy.sh → 104 PASS / 0 FAIL

P12 ✅ COMPLETE — Capability Registry Contract (ADR 0010 ACCEPTED)
      docs/contracts/{capability,capability-registry,capability-lifecycle}.md — CAP_* model,
      scope, risk, approval, executor, verifier, DEFAULT DENY, no registry code
      tests/capability.test.sh → 45/45 PASS · verify-capability.sh → 87 PASS / 0 FAIL

CI-H1…CI-H6 ✅ COMPLETE — CI hardening (NOT a phase; formerly mislabelled "P13 FIX")
      CI-H1 self-matching grep checks fixed in ci.yml: the configuration step and the security
            patterns step matched their own source text and failed every run
      CI-H2 workflow_dispatch-only debug runner added (ci-debug.yml) to recover runner evidence
      CI-H3 P4 failure surfaced as a workflow annotation, because the runner log archive is
            unreachable from Arena
      CI-H4 Job 4 provisions the P3 toolchain baseline before verifying it — the runner image is
            not part of the LINEX.OS contract, so a runner missing pkg-config used to turn P3
            into a false FAIL
      CI-H5 powershell TEST-1 no longer asserts the host is Debian 12 (an Arena property); it
            verifies the installer's OS gate distro-agnostically, including fail-closed
      CI-H6 scripts/doctor.sh final report reuses cached verdicts instead of re-running every
            suite inside concurrent $(...) substitutions, which made rows nondeterministic
      Touched: .github/workflows/ci.yml, ci-debug.yml,
               ops/powershell/tests/powershell-install.test.sh, scripts/doctor.sh
      Evidence: CI run 37233042304 on main → 6/6 jobs success
```

## Phase Sequence (P13 onward) — AUTHORITATIVE

Authority: ADR 0011 (D4) establishes the P13→P18 order after the P9–P12 sequence recorded
in ADRs 0007→0010; ADR 0012 accepts the P13 contract without changing that order. Where the
P8-era sketch below differed, the ADR sequence prevails.

```
P13 ✅ COMPLETE — Agent Runtime Contract (CONTRACTS ONLY, no implementation)
  - Provider-neutral Agent identity/role, scoped context, Planner, and references to P12
    capabilities, P14 Tools, P15 Memory, P11 policy, and P9 evidence requirements
  - Planner PROPOSES, never executes; path stays Planner → Policy → Authorization →
    Execution Authority → Verifier → Evidence
  - No LLM → shell direct path, no LLM as final authority, no permission inferred from
    natural-language intent alone (intent → structured Action → schema validation → Policy)
  - Consumes P9 Task/Action/Event/Result, P10 Execution Authority, P11 Policy decisions,
    P12 Capability Registry; does not duplicate or redefine their state or authority
  - Ambiguity → NEEDS_CLARIFICATION; denial → REJECTED; missing/unknown authority → BLOCKED
  - `APPROVED` is not an Agent or Policy state; P11 REQUIRE_APPROVAL needs bound approval,
    fresh policy evaluation, and independent authorization
  - Deliverables: docs/contracts/agent-runtime.md, agent-lifecycle.md, agent-audit.md,
    agent-acceptance-tests.yaml; ADR 0012; tests/agent-runtime.test.sh (28/28 local PASS);
    ops/verify/verify-agent-runtime.sh (11/11 local PASS)
  - CI Job 5 includes the P13 tests and verifier; current P13 change's remote run is pending
  - Explicitly NOT delivered: no Agent code, runtime, LLM integration, package install,
    new implementation language, cryptographic audit signing, or production evidence

P14 ▶ NEXT — Tool + Skill Contract (CONTRACTS ONLY)
  - Tool Contract: ID, semver Version, Input/Output schema, Capability required, Risk class,
    Execution authority, Timeout, Resource limits, Evidence requirements; Unknown Tool → BLOCKED
  - Tool provenance: source, version, hash, version pinning
  - Skill model: Skill = reusable procedure composing Tools; Tool vs Skill vs Agent vs Workflow
  - Skill registry, trust classification, capability mapping

P15 → Memory / State / Event Contracts
  - Memory: Ephemeral, Session, Project, User, System with ownership, retention, access policy,
    encryption, deletion
  - Event Store append-only immutable, State Store lifecycle, storage abstraction interfaces

P16 → Verification / Eval Contract
  - Verification Engine: logs, evidence, tests, attestations; enforces SUCCEEDED ≠ VERIFIED,
    EXECUTED ≠ SAFE, LOCAL PASS ≠ PRODUCTION PASS, MOCK ≠ PRODUCTION

P17 → MCP Contract
  - MCP Gateway, Server Registry, trust classification, capability mapping, input/output
    validation, timeout, network policy, audit, isolation; no unbounded host access

P18 → Technology Selection ← IMPLEMENTATION LANGUAGE IS DECIDED HERE
  - Resolve the Open Decisions below against their stated criteria, each with its own ADR
  - Implementation begins only after P18; until then every phase is contracts and gates only
  - Note: introducing an implementation language earlier would violate the P8 freeze
    (ADR 0011 D5 records a rejected attempt to do exactly that)

IMPLEMENTATION PHASES (post-P18, numbered only after Technology Selection)
  - Services Layer, API Boundary, UI Boundary, Observability, Security Hardening / sandboxing
    Level 1-4 — see Superseded Backlog below for the subject list
```

### Superseded Backlog (subjects preserved, old numbering retired)

The P8-era sketch numbered twelve further phases before implementation (P13 Agent Runtime,
P14 Tool Runtime, P15 Skill Runtime, P16 MCP Gateway, P17 Services Layer, P18 Memory Service,
P19 Event Bus and State Store, P20 Verification Engine, P21 API Boundary, P22 UI Boundary,
P23 Observability, P24 Security Hardening). ADR 0011 (D4) supersedes that numbering from P15
onward. No subject is dropped; each maps to its new home:

```
Skill Runtime                          → P14 (Tool + Skill Contract)
MCP Gateway                            → P17
Memory Service                         → P15
Event Bus and State Store              → P15
Verification Engine                    → P16
Services Layer                         → post-P18 implementation
API Boundary                           → post-P18 implementation
UI Boundary                            → post-P18 implementation
Observability                          → post-P18 implementation
Security Hardening (sandbox Level 1-4,
  resource limits, network isolation,
  secret manager, signature verify)    → post-P18 implementation
```

### Retired Labels

```
"P14 Control Plane MVP"  → RETIRED. Never an authoritative phase: it matches neither this
                           roadmap nor the ADR sequence, and its claimed deliverable (a
                           control/ package, a digest CLI, 181 pytest tests, a git bundle)
                           does not exist in the repository or on the remote — the referenced
                           commit is absent from GitHub (ADR 0011 D1, D4).
"P13 FIX" labels         → RELABELLED CI-H1…CI-H6 in ci.yml, ci-debug.yml,
                           powershell-install.test.sh and doctor.sh. Those were CI repairs,
                           not phase P13; P13 is Agent Runtime Contract.
```

### Implementation Gate (unchanged)

```
Final: Product Code, Apps, etc. only after Core Runtime, Policy, Capability, Agent Runtime,
Tool/Skill, Memory/State/Event, Verification, MCP contracts PASS and Technology Selection
(P18) has decided the implementation language via ADR.
```

## Sandboxing Roadmap (from P8)

- Level 0: Project Gate (current, P2) — allowlist + structured actions + dry-run + evidence, no kernel sandbox, governance layer
- Level 1: Dedicated unprivileged process — Execution Authority in separate unprivileged process, not NOPASSWD:ALL
- Level 2: Filesystem isolation — chroot or mount namespace, workspace only
- Level 3: Network isolation — network namespace, allowlist domains only
- Level 4: Container / sandbox — Docker/Podman with resource limits, no privileged
- Level 5: VM / stronger isolation — VM/microVM for high-risk
- Level 6: Optional deeper OS integration — custom OS layer, modular

No implementation in P8, only roadmap.

## Architecture Freeze

- At end of P8, `frozen-baseline.md` contains Architectural Decisions, Non-goals, Interfaces, Trust Boundaries, Security Invariants, Open Decisions, Deferred Decisions
- Freeze means: No implementation should violate documented baseline without an ADR
- Architecture not immutable, but changes require ADR

## Open Decisions (DECISION PENDING)

- Programming Language: criteria portability, security, performance, ecosystem, team familiarity
- Runtime implementation technology: criteria isolation, resource limits, portability, complexity
- Database: criteria local-first, replaceable, free-first, vendor-neutral
- Event bus: criteria local-first, replaceable, no mandatory cloud
- Sandbox: criteria security, complexity, resource usage, portability
- UI framework: criteria free-first, self-hostable, no mandatory SaaS
- API framework: criteria vendor-neutral, local-capable
- Browser engine: criteria isolation, resource limits, free-first
- MCP transport: criteria security, portability
- Deployment topology: criteria self-hostable, local-capable, cloud-compatible, low-resource mode

No technologies chosen merely to fill gap.

## References

- context.md (system context)
- container.md (containers)
- components.md (23 components)
- execution-model.md (action lifecycle, execution authority)
- security-boundaries.md (trust boundaries, P7 security fix continuation)
- capability-model.md (capability model)
- event-model.md (event model)
- data-model.md (state, memory, artifact, storage abstraction, resource limits, failure model, fail-closed)
- networking.md (network architecture, P4 blocker)
- extensibility.md (modularity, supply chain, API/UI boundaries)
- threat-model.md (16 threats)
- frozen-baseline.md (freeze)
- ADRs 0001-0006 (P8 architecture decisions)
- ADRs 0007-0010 (P9-P12 contract phases, the sequence D4 adopts)
- ADR 0012 (P13 Agent Runtime Contract, accepted on the current session branch)
- adr/0011-baseline-reconciliation-and-phase-numbering.md (status authority, evidence rules,
  phase numbering authority, retired labels — the reason this ledger reads the way it does)
- docs/reports/README.md (evidence report convention R1-R6)
- docs/reports/baseline-audit-d349f92.md (the measurements behind every status above)
- AGENTS.md, ARENA.md, docs/security.md, privilege-policy.md, agent-contract.md
