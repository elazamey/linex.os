# LINEX.OS — Roadmap (P8)

## Foundation (P1-P7) — COMPLETE

```
P1 ✅ COMPLETE — Environment Discovery, Bootstrap Foundation (read-only, fail-closed)
P2 ✅ COMPLETE — Privilege Policy / Gate (allowlist + structured actions + dry-run + evidence, 28 tests)
P3 ✅ COMPLETE — Linux Toolchain (gcc, g++, make, pkg-config, 44 tests, C/C++ smoke)
P4 ⛔ BLOCKED — PowerShell 7 (Arena network restriction: packages.microsoft.com and release-assets blocked, github.com PASS, Gate and logic PASS 18 tests, no third-party)
P5 ✅ COMPLETE — Repository Foundation (docs/, config/, tests/, .github/workflows/, README, LICENSE, SECURITY, CONTRIBUTING, .gitignore)
P6 ✅ COMPLETE — Agent Contract (AGENTS.md, ARENA.md, docs/agent-contract.md, 15 tests)
P7 ✅ COMPLETE — Doctor + CI Hardening + Final Foundation Verification (PASS WITH KNOWN BLOCKER P4)
  - Doctor aggregator true (47 PASS, 0 FAIL, 2 BLOCKED known)
  - Secret-scan repository-wide including tests/ and .github, no directory exclusion (P7 fix)
  - Static-security-check (no eval, curl|bash, etc. as executable, Test/Policy Boundary for tests/)
  - CI hardened: permissions contents: read, pinned checkout SHA 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1, 6 jobs, no Docker/PowerShell required
  - Verification-summary.txt artifact, no secrets
  - FOUNDATION STATUS: PASS WITH KNOWN BLOCKER

REMOTE CI: NOT VERIFIED — branch arena/01a107fc-linex-os not pushed, main at 768bf39, per P7/P8 spec no push

FOUNDATION = VERIFIED locally
```

## Architecture (P8) — CURRENT

```
P8 ▶ Architecture Design ONLY (this phase)
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
  - P4 preserved BLOCKED, Remote CI NOT VERIFIED, System changes NONE, Git no push
```

## Next — Core Runtime and Beyond (P9+)

```
P9 → Core Runtime Contract
  - Define interfaces for Core Runtime, Substrate, bootstrap, verification, toolchain detection
  - No implementation yet, only contracts and interfaces
  - Must respect P8 architecture freeze, any violation requires ADR

P10 → Execution Authority
  - Define executors Shell, Process, File, Network, Package with interfaces, capability required, risk, resource limits, evidence
  - Implement Gate as Execution Authority Level 0, with roadmap to Level 1-6
  - No product code that violates trust boundary

P11 → Policy Engine
  - Implement Policy Engine with inputs Actor/Action/Capability/Resource/Scope/Risk/Env/Context/Approval/Network, decisions ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN, fail-closed UNKNOWN→DENY
  - Capability Registry, risk scoring, approval levels
  - No bypass

P12 → Capability System
  - Implement CAP_* model with Risk, Scope, Approval, Executor, Verifier, DEFAULT DENY
  - Resource scoping workspace/repository/project/user/host/network/production with explicit elevation
  - Tests for capability elevation

P13 → Agent Runtime
  - Implement Agent model with Identity, Role, Capabilities, Context, Memory, Planner, Tools, Policies, Evidence
  - Planner proposes, not executes, via Policy
  - No LLM→shell direct

P14 → Tool Runtime
  - Implement Tool Contract with ID, Version, Input/Output schema, Capability required, Risk class, Execution authority, Timeout, Resource limits, Evidence
  - Unknown Tool → BLOCKED
  - Tool provenance, hash, version pinning

P15 → Skill Runtime
  - Implement Skill as reusable higher-level procedure composing tools
  - Skill registry, trust, capability mapping

P16 → MCP Gateway
  - Implement MCP Gateway with Registry, trust classification, capability mapping, input/output validation, timeout, network policy, audit, isolation
  - No unbounded host access

P17 → Services Layer
  - Filesystem Service, Process Service, Network Service, Memory Service, Event Bus, Artifact Store, Evidence Store, Identity/Auth, Configuration Service, Observability, Plugin Registry
  - Each with Purpose/Inputs/Outputs/Trust/Dependencies/May Do/Must Never Do, via Policy

P18 → Memory Service
  - Implement Ephemeral, Session, Project, User, System memory with ownership, retention, access policy, encryption, deletion

P19 → Event Bus and State Store
  - Implement Event Store append-only immutable, State Store lifecycle

P20 → Verification Engine
  - Implement Verification Engine with logs, evidence, tests, attestations, distinguishes SUCCEEDED vs VERIFIED

P21 → API Boundary
  - Implement conceptual API domains /health, /agents, /actions, etc. with auth, validation, rate limiting, no privileged logic in UI

P22 → UI Boundary
  - Implement UI as client only, UI→API only

P23 → Observability
  - Implement Logs, Metrics, Traces, Events, Audit, Evidence with distinction, no secrets

P24 → Security Hardening
  - Implement sandboxing Level 1-4, resource limits, network isolation, secret manager, signature verification

... (future)

Final: Product Code, Apps, etc. only after Core Runtime, Policy, Capability, Agent Runtime, etc. PASS
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
- ADRs 0001-0006
- AGENTS.md, ARENA.md, docs/security.md, privilege-policy.md, agent-contract.md
