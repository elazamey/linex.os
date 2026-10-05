# LINEX.OS — Roadmap

## Active Delivery Plan (approved P0–P6 sequence)

This P0–P6 sequence is the active execution plan for the current work. The P1–P18 labels and
associated ledger below are retained as historical identifiers for existing artifacts; they do not
silently redefine the active sequence. ADR 0011 (D4/D5) is preserved unchanged as the accepted
pre-P0 decision record. P1 must explicitly reconcile or reaffirm any affected earlier ADR decisions
before P2 Runtime Core work; no Runtime implementation may begin before the required P1 ADRs are
accepted.

| Phase | Scope | Gate / position |
|---|---|---|
| P0 | Baseline Reconciliation | Current: reconcile live documentation, record separate repository/environment/remote-CI results, validate, and publish a scoped PR. |
| P1 | MVP Definition + ADRs | Next: establish MVP boundaries and decide language, storage, isolation boundary, execution model, evidence model, and failure semantics through ADRs. |
| P2 | P9 Runtime Core | After P1 ADR decisions are accepted; use legacy P9 contracts as inputs and keep implementation within the approved scope. |
| P3 | P11/P12 Policy + Capability | After P2; reconcile and deliver policy/capability behavior under fail-closed rules. |
| P4 | P10 Execution Authority | After P3; execution authority remains policy-bound and scoped. |
| P5 | P13/P14 Vertical Slice | After P4; bounded end-to-end slice, not general product completeness. |
| P6 | CI + Security + Release | After P5; harden verification and release controls. |

**P1 MVP scope proposal (not frozen):** Linux, CLI, local process; Planner → structured actions;
Mock Authority first, then Safe Local Authority; fail-closed policy; explicit, scoped, expiring
capabilities; append-only execution evidence; no Agent → shell path. MCP, browser, GUI, default
network, and production deployment are outside this proposal. P1 may accept, refine, or reject it
through ADRs; do not describe it as an established architecture before then.

The original phase-ledger reconciliation at `d349f92` remains preserved in
`docs/reports/baseline-audit-d349f92.md`; the P0 baseline was remeasured at `a71643a` in
`docs/reports/baseline-audit-a71643a.md`. Historical `COMPLETE` follows ADR 0011 (D2): the
phase's documents existed, were self-consistent, and were machine-checked by a shipped suite that
passed. It never meant "implemented".

## Latest Baseline Measurement (`a71643a`)

- **REPOSITORY_STATUS: PASS.** Existing foundation and contract artifacts (original P1-P12 labels)
  are present; repository security and contract verifiers pass. The default Arena PATH produces
  255/256 across the nine shipped suites because the legacy P3 test correctly detects the missing
  required `pkg-config` tool. With the audit-only temporary source build on PATH, the suites are
  256/256. The default test failure is attributed to the environment, not hidden or recast as a
  repository PASS.
- **ENVIRONMENT_STATUS: BLOCKED.** `pkg-config` is missing from the default PATH and the approved
  Debian package mirror is blocked. The official pinned pkgconf source build under `/tmp` was for
  verification only, not a system install or persistent fix. `scripts/doctor.sh` remains fail-closed
  and exits 3 on the default PATH (ADR 0011 D3). P4 PowerShell remains network-blocked.
- **REMOTE_CI_STATUS: VERIFIED.** GitHub Actions run `37246010719` on `main`, head `a71643a`,
  succeeded in all six jobs. Runner log bodies remain unavailable from Arena; conclusions are
  verified at job granularity.
- **Active phase position:** P0 Baseline Reconciliation is in progress; P1 MVP Definition + ADRs is
  next. Legacy P9-P12 contracts are inputs, not the current phase sequence. P1 must establish the
  required architecture decisions before any Runtime implementation.

The full commit-scoped evidence and the separate REPOSITORY / ENVIRONMENT / REMOTE CI assessment
are in `docs/reports/baseline-audit-a71643a.md`. This snapshot does not replace the historical
`d349f92` report or turn environment-dependent P3 into a persistent PASS.

## Legacy Foundation Inventory (original P1–P7 labels; historical status preserved)

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

REMOTE CI: VERIFIED at d349f92 — CI run 37233042304 on main, 6/6 jobs success (Job 1 static
validation, Job 2 security, Job 3 policy P2, Job 4 toolchain P3, Job 5 contracts P4/P6,
Job 6 doctor P7). Verified at job-conclusion granularity only: runner log bodies are NOT
RETRIEVABLE from Arena (results-receiver.actions.githubusercontent.com → EOF), so any claim
about log contents stays NOT VERIFIED (ADR 0011 D7).
The earlier "REMOTE CI: NOT VERIFIED — branch not pushed, main at 768bf39" statement described
the P7/P8 no-push policy of that time and is superseded. PR #1 and PR #2 were pushed and merged
before the `d349f92` measurement; PR #3 later merged the P0 baseline reconciliation whose merge
commit is `a71643a` (see the latest measurement section above).

FOUNDATION = VERIFIED locally, with one ENVIRONMENT-DEPENDENT gap (P3 pkg-config)
```

## Legacy Architecture Inventory (original P8 label; historical status preserved)

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
  - Network architecture: Inbound/Outbound/Internal/External, Trusted/Restricted/Untrusted zones, no Agent→Internet unrestricted without capability+policy; Arena network evidence is recorded as a measured snapshot, not a timeless claim
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

## Legacy Contract Inventory (original P9–P12 labels; historical status preserved)

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

## Legacy Phase Sequence (P13 onward; historical authority)

This section preserves the sequence ADR 0011 (D4) made authoritative before the current P0–P6
plan. It records the old P13–P18 backlog and accepted contract sequence for provenance; it is not
the active delivery order. The active sequence is at the top of this roadmap. P1 must explicitly
reconcile or reaffirm any affected decisions via ADR before P2 work; do not silently rewrite ADR
0011, the accepted ADRs 0007–0010, or their historical phase labels.

```
P13 ▶ NEXT — Agent Runtime Contract (CONTRACTS ONLY, no implementation)
  - Agent model: Identity, Role, Capabilities, Context, Memory reference, Planner, Tools,
    Policies, Evidence requirements
  - Planner PROPOSES, never executes; path stays Planner → Policy → Authorization →
    Execution Authority → Verifier → Evidence
  - No LLM → shell direct path, no LLM as final authority, no permission inferred from
    natural-language intent alone (intent → structured Action → schema validation → Policy)
  - Consumes P9 Action/Task contracts, P10 Execution Authority, P11 Policy decisions,
    P12 Capability Registry; must not duplicate or redefine any of them
  - Must respect the P8 freeze; any violation requires an ADR
  - Deliverables: docs/contracts/agent*.md, ADR 0012, tests/agent-runtime.test.sh,
    ops/verify/verify-agent-runtime.sh
  - Explicitly NOT delivered: no agent code, no runtime, no LLM integration, no package
    install, no new implementation language

P14 → Tool + Skill Contract (CONTRACTS ONLY)
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

### Historical Implementation Gate (ADR 0011 D5)

The pre-P0 gate required all listed contract phases and Technology Selection at legacy P18. That
decision is preserved in ADR 0011 and is not silently edited here. Under the active P0–P6 plan,
Runtime implementation remains prohibited until P1 has accepted ADR decisions for language,
storage, isolation boundary, execution model, evidence model, and failure semantics. P1 must
explicitly document whether it amends, supersedes, or reaffirms ADR 0011 D5 and related freeze
language before P2 work begins.

## Historical Sandboxing Roadmap (legacy P8 sketch; review in P1)

- Level 0: Existing Project Gate (legacy P2) — allowlist + structured actions + dry-run + evidence; governance layer, not a kernel sandbox
- Level 1: Dedicated unprivileged process
- Level 2: Filesystem isolation
- Level 3: Network isolation
- Level 4: Container / sandbox
- Level 5: VM / stronger isolation
- Level 6: Optional deeper OS integration

These are prior design possibilities, not committed MVP requirements or technology decisions. P1 must
establish the MVP isolation boundary; no sandbox implementation is authorized by this historical
sketch.

## Historical Architecture Freeze (legacy P8)

`frozen-baseline.md` and the P8 freeze record remain preserved historical inputs. The active P1
MVP ADRs must explicitly review and reconcile them where needed. The proposed P1 MVP scope above is
not a frozen architecture, and old freeze language must not bypass the required P1 decisions.

## P1 ADR Decisions (pending; no Runtime implementation before acceptance)

Required decision areas:

- **Language:** implementation language and relevant portability, security, performance, ecosystem, and maintenance criteria
- **Storage:** local-first data/evidence storage and replacement/migration boundary
- **Isolation boundary:** local process and filesystem/network/resource limits appropriate to the MVP
- **Execution model:** CLI/local process flow, Planner → structured action, Mock Authority first, then Safe Local Authority
- **Evidence model:** append-only execution evidence, provenance, verification, and retention semantics
- **Failure semantics:** fail-closed policy, timeouts, denial, partial execution, cancellation, and unverified outcomes

P1 must record the proposed MVP scope as a proposal and accept, refine, or reject it through ADRs.
MCP, browser, GUI, default network, and production deployment remain outside the proposal unless P1
explicitly changes scope. Additional decisions (UI/API frameworks, MCP transport, browser engine,
event bus, deployment topology, deeper sandbox levels) stay deferred unless needed for an accepted
MVP decision. No technologies are chosen merely to fill a gap.

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
- adr/0011-baseline-reconciliation-and-phase-numbering.md (status/evidence rules and the historical
  pre-P0 phase numbering; P1 must explicitly reconcile affected decisions via ADR)
- docs/reports/README.md (evidence report convention R1-R6)
- docs/reports/baseline-audit-d349f92.md (the measurements behind every status above)
- AGENTS.md, ARENA.md, docs/security.md, privilege-policy.md, agent-contract.md
