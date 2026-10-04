# LINEX.OS — Architecture (P8)

> **Architecture Design — AI-native Execution Operating Environment above Linux, with roadmap to deeper OS integration.**

## 0. Absolute Scope — P8

P8 is Architecture ONLY. No product code, no runtime implementation, no UI/API/Agent/MCP/Database implementation, no package installation, no PowerShell/Docker installation, no production deployment.

Allowed: documentation, ADR files, architecture diagrams-as-text (ASCII/Mermaid).

Workflow: INSPECT → MODEL → COMPARE → DECIDE → DOCUMENT → VALIDATE → FREEZE → REPORT

## 1. Architecture Mission

Define:
- What is LINEX.OS?
- What is its system boundary?
- What is its primary execution model?
- What components exist? What does NOT exist yet?
- How do trust boundaries work?
- How do agents execute actions?
- How are permissions granted?
- How is execution verified?
- How does the system scale?
- How can architecture evolve toward AI-native OS?

## 2. Important Architecture Assumption — ACCEPTED

LINEX.OS in v1 is **AI-native Execution Operating Environment**, not kernel replacement.

Layers:

```
Hardware
  ↓
Host OS (Linux / macOS / Windows - initial Linux)
  ↓
LINEX.OS Substrate (detection, abstraction, policy)
  ↓
Core Runtime
  ↓
Policy / Authorization
  ↓
Execution Authority
  ↓
Verification / Evidence
  ↓
Agents / Tools / Skills / MCP / Applications
```

This decision is ACCEPTED but revisable via ADR. No kernel development in P8.

Reason: Practical path to AI OS without building kernel from scratch now. Future deeper OS integration possible (Level 6 sandboxing roadmap).

## 3. Architecture Alternatives — Compared

### Model A: LINEX.OS = Linux distribution / OS layer

- Complexity: HIGH — building distro, kernel modules, drivers, package management, installer, hardware support
- Security: Requires kernel-level security expertise, larger attack surface
- Time-to-market: VERY LONG (years)
- Agent integration: Deep but hard to iterate
- Portability: LOW — tied to specific distro
- Resource usage: HIGH — full OS
- Maintainability: HARD — must track kernel, distro updates
- Hardware control: FULL
- Cloud compatibility: LOW — need to run as OS, not container
- Future OS evolution: Already OS, but hard to pivot

### Model B: LINEX.OS = AI-native execution environment above Linux

- Complexity: MEDIUM — runtime, policy, execution authority, verification, no kernel
- Security: MEDIUM — relies on host OS, but adds policy layer, fail-closed, capability model
- Time-to-market: MEDIUM (months)
- Agent integration: HIGH — designed for agents from start
- Portability: HIGH — runs on Linux, macOS, Windows (with abstraction), container-friendly
- Resource usage: LOW-MEDIUM — no kernel, runs as processes
- Maintainability: MEDIUM — focus on runtime, not kernel
- Hardware control: LIMITED — via host OS
- Cloud compatibility: HIGH — runs as container, VM, process
- Future OS evolution: LIMITED — stays above OS, not deeper

### Model C: Future hybrid — execution environment first, deeper OS integration later (RECOMMENDED)

- Complexity: MEDIUM now, HIGH later (incremental)
- Security: MEDIUM now, with roadmap to stronger isolation (Level 0 Gate → Level 6 OS integration)
- Time-to-market: FAST now (execution environment), with path to deeper
- Agent integration: HIGH now, deeper later
- Portability: HIGH now, with optional deeper later
- Resource usage: LOW now, scalable later (CORE, STANDARD, HEAVY)
- Maintainability: MEDIUM now, with modularity to replace components
- Hardware control: LIMITED now, roadmap to more later
- Cloud compatibility: HIGH now, with optional deeper
- Future OS evolution: HIGH — can evolve to deeper OS integration without rebuilding from scratch

**Recommendation: Model C — ACCEPTED**

Justification: Foundation P1-P7 already implements Model B (substrate, Gate, doctor, verification, no kernel). Model C preserves that, adds explicit roadmap to deeper OS integration (sandboxing Level 0-6), keeps free-first, vendor-neutral, self-hostable, local-capable. No benchmarks invented, qualitative scoring only.

ADR: `0001-linex-os-scope.md`

## 4. System Boundary

### Inside LINEX.OS

- Substrate (OS detection, arch detection, package manager abstraction)
- Core Runtime (bootstrap, verification, toolchain detection)
- Policy Engine (allowlist, capability model, risk, approval)
- Authorization Layer (actor, action, capability, resource, scope, environment)
- Execution Authority (shell, process, file, browser, computer, network, package executors)
- Verification Engine (logs, evidence, tests, attestations)
- Agent Runtime (identity, role, capabilities, context, memory, planner, tools, policies, evidence)
- Tool Runtime (tool contract, capability required, risk class, timeout, resource limits)
- Skill Runtime (reusable higher-level procedures)
- MCP Gateway (registry, trust classification, capability mapping, validation, audit, isolation)
- Services: Filesystem Service, Process Service, Network Service, Memory Service, Event Bus, Artifact Store, Evidence Store, Identity/Auth, Configuration Service, Observability, Plugin Registry
- UI/API as client only (no privileged logic)

### Outside LINEX.OS

- Hardware
- Host OS kernel, drivers, bootloader, firmware
- Host filesystem outside workspace/repository boundary (unless capability granted)
- External APIs (GitHub, Microsoft, Debian mirrors, etc.)
- Cloud providers (AWS, GCP, Azure, etc.)
- User's production databases, production credentials (unless explicit production capability + production evidence)
- Internet unrestricted (requires CAP_NETWORK_CONNECT + policy)

### Trusted

- Policy Engine (defines ALLOW/DENY)
- Execution Authority (executes only via policy)
- Verification Engine (produces evidence, not claims)
- Host OS kernel (assumed trusted, but LINEX.OS does not modify /etc/sudoers, etc.)
- LINEX.OS Substrate (detection, read-only)

### Semi-trusted

- Agent Runtime (proposes, but not authorization authority)
- Tool Runtime (executes via Execution Authority, not directly)
- MCP Gateway (validates, isolates, but MCP servers themselves may be untrusted)
- Configuration Service (if compromised, can affect policy, so must be verified)

### Untrusted

- LLM (may be prompt-injected, must not directly invoke shell)
- User input (must be validated)
- External APIs (may be compromised, must have network policy)
- MCP servers (third-party, must have trust classification, capability mapping, isolation)
- Plugins (must be via Plugin Registry, provenance, version pinning)
- Browser/Computer executors (if compromised, can affect host)

## 5. Control Plane / Data Plane / Execution Plane / Verification Plane

### CONTROL PLANE

- Policy Engine
- Identity/Auth (User, Agent, Service, Tool, MCP Server, Execution Authority)
- Authorization Layer
- Configuration Service
- Orchestration (Planner, Workflow)
- Capability Registry

Dependency: No dependency on Data/Execution/Verification, but they depend on Control.

### DATA PLANE

- Events (action.proposed, validated, authorized, denied, started, completed, failed, verification.*, evidence.created)
- State (action lifecycle: PROPOSED→VALIDATING→AUTHORIZED→DENIED→DRY_RUN→EXECUTING→SUCCEEDED→FAILED→VERIFIED→UNVERIFIED→BLOCKED→CANCELLED)
- Memory (Ephemeral Context, Session Memory, Project Memory, User Memory, System Memory)
- Artifacts (Source, Build, Execution, Evidence, User)
- Metadata (owner, scope, hash, provenance, retention)

Dependency: Depends on Control Plane for authorization, produces data for Verification.

### EXECUTION PLANE

- Shell Executor
- Process Executor
- File Executor (Filesystem Service)
- Browser Executor
- Computer Executor
- Network Executor (Network Service)
- Package Executor (via Gate)

Dependency: Depends on Control Plane (must pass Policy/Authorization), produces Execution Artifacts and Events for Data and Verification.

### VERIFICATION PLANE

- Logs (DEBUG LOG)
- Evidence (VERIFICATION EVIDENCE)
- Tests (unit, static, integration, smoke, system, production evidence)
- Outcomes (SUCCEEDED vs VERIFIED distinction)
- Attestations (who verified, when, how)
- Audit/Evidence Store
- Observability (Metrics, Traces, Audit, Security Events)

Dependency: Depends on Control, Data, Execution (verifies them), but does not allow them (Verifier is not Authorization Authority).

```
Control Plane → Data Plane → Execution Plane → Verification Plane
     ↑              ↑              ↑                ↑
     └──────────────┴──────────────┴────────────────┘
              (all depend on Control, Verification verifies all)
```

No dependency cycles allowed: UI → API → Application Services → Runtime → Policy/Authorization → Execution → Host/External.

## 6. Core Components (23)

See `components.md` for detailed Purpose/Inputs/Outputs/Trust/Dependencies/May Do/Must Never Do per component.

List:

1. Core Runtime
2. Agent Runtime
3. Planner
4. Policy Engine
5. Authorization Layer
6. Capability Registry
7. Execution Authority
8. Tool Runtime
9. Skill Runtime
10. MCP Gateway
11. Filesystem Service
12. Process Service
13. Network Service
14. Memory Service
15. Event Bus
16. Artifact Store
17. Verification Engine
18. Audit/Evidence Store
19. Identity/Auth
20. Configuration Service
21. User Interface/API
22. Observability
23. Plugin Registry

## 7. Critical Trust Boundary

Fixed path:

```
LLM
  ↓
Planner
  ↓
Action Proposal
  ↓
Policy Engine
  ↓
Authorization
  ↓
Execution Authority
  ↓
Verifier
  ↓
Evidence
```

Forbidden:

- LLM → shell (must go via Planner→Policy→Execution)
- LLM → sudo (must go via Policy→Execution Authority)
- LLM → filesystem mutation directly (must go via File Executor via Policy)
- Agent → production database directly (must have CAP + production auth + production evidence)
- UI → privileged execution directly (UI → API only, API → Runtime → Policy → Execution)
- MCP server → unrestricted host access (must go via MCP Gateway with trust classification, capability mapping, isolation)

## 8. Capability Model

Instead of "Agent has terminal", use explicit capabilities:

- CAP_FS_READ
- CAP_FS_WRITE
- CAP_PROCESS_READ
- CAP_PROCESS_EXEC
- CAP_NETWORK_READ
- CAP_NETWORK_CONNECT
- CAP_PACKAGE_INSTALL
- CAP_BROWSER
- CAP_COMPUTER
- CAP_MCP
- CAP_SECRET_ACCESS

Each capability has:

- Risk: LOW, MEDIUM, HIGH, CRITICAL (e.g., FS_READ LOW, FS_WRITE MEDIUM, PACKAGE_INSTALL HIGH, SECRET_ACCESS CRITICAL, PROCESS_EXEC HIGH)
- Scope: workspace, repository, project, user, host, network, production
- Approval: AUTO, DRY_RUN, EXPLICIT_APPROVAL, DENY (per AGENTS.md)
- Executor: which Execution Authority executor (File, Process, Network, Package, etc.)
- Verifier: how verified (logs, evidence, tests, attestation)

DEFAULT: DENY (fail-closed). Unknown capability → DENY.

See `capability-model.md`.

## 9. Resource Scoping

Scopes:

- workspace: `/home/user/linex.os` or current project workspace, safe file operations
- repository: git repository, .git, docs, ops, etc.
- project: broader project including config, but not host
- user: user home, but not system
- host: host OS, /etc, /usr, etc. (requires explicit host capability + policy)
- network: outbound network, specific domains (github.com PASS, packages.microsoft.com BLOCKED in Arena)
- production: production databases, production APIs, cloud production (requires production auth + production evidence, forbidden in P0-P7)

Agent does not get host scope merely by getting workspace scope. Capability elevation must be explicit via Policy Engine + Authorization.

## 10. Agent Model

```
Agent
├── Identity (unique, not shared)
├── Role (planner, executor, verifier, etc.)
├── Capabilities (explicit list, default DENY)
├── Context (ephemeral, session, project, user, system)
├── Memory (Ephemeral, Session, Project, User, System with ownership, retention, access policy)
├── Planner (proposes actions, not executes)
├── Tools (via Tool Runtime, capability required)
├── Policies (which policies apply to this agent)
└── Evidence (produced by Verifier, not by Agent itself)
```

No Agent runtime implementation in P8, only model.

## 11. Tool Model

Tool Contract:

- Tool ID (e.g., `fs.read`, `process.exec`, `network.fetch`)
- Version (semver)
- Input schema (JSON schema)
- Output schema
- Capability required (e.g., CAP_FS_READ)
- Risk class (CLASS-0 READ_ONLY to CLASS-6 DESTRUCTIVE per AGENTS.md)
- Execution authority (which executor)
- Timeout
- Resource limits (CPU, memory, disk, output size)
- Evidence requirements (what logs, what evidence)

Unknown Tool → BLOCKED.

## 12. Skill Model

Distinction:

- Tool = executable capability (e.g., `fs.read`)
- Skill = reusable higher-level procedure (e.g., `review PR`, `bootstrap environment`, `doctor check`) that composes tools
- Agent = decision/planning entity that selects skills/tools
- Workflow = orchestrated sequence of agent→skill→tool→execution→verifier

```
Agent
  → Skill (e.g., "verify environment")
    → Tool (e.g., "process.exec" with capability CAP_PROCESS_EXEC)
      → Execution Authority (Process Executor via Policy)
        → Verifier (produces evidence)
```

## 13. MCP Architecture

No MCP implementation in P8, only design:

- MCP Gateway: entry point, validates input, maps capability, enforces policy, audits
- MCP Server Registry: list of MCP servers, trust classification (trusted, semi-trusted, untrusted), version pinning, provenance
- Trust classification: official (LINEX.OS), verified (community with signature), untrusted (third-party)
- Capability mapping: each MCP server declares capabilities, mapped to LINEX.OS capabilities, default DENY
- Input validation: schema, size, timeout
- Output validation: schema, no secrets, no destructive commands
- Timeout, Network policy (which domains MCP can access), Audit (all MCP calls logged as events), Isolation boundary (MCP server cannot get unbounded host access, must go via Gateway)

MCP server must never get unbounded host access.

## 14. Execution Authority

Independent from AI:

```
Execution Authority
├── Shell Executor (bash, sh)
├── Process Executor (process spawn, not arbitrary)
├── File Executor (Filesystem Service)
├── Browser Executor (future)
├── Computer Executor (future)
├── Network Executor (Network Service)
└── Package Executor (via privilege-gate.sh, allowlist, structured actions)
```

Each executor must pass Policy/Authorization. No executor bypasses Policy.

## 15. Sandboxing Roadmap

Because P2 is not kernel sandbox, roadmap:

- Level 0: Project Gate (current) — allowlist + structured actions + dry-run + evidence, no kernel sandbox, but governance layer
- Level 1: Dedicated unprivileged process — run Execution Authority in separate unprivileged process, not as user with NOPASSWD:ALL
- Level 2: Filesystem isolation — chroot or mount namespace, workspace only
- Level 3: Network isolation — network namespace, allowlist domains only
- Level 4: Container / sandbox — Docker, Podman, or similar, with resource limits, no privileged
- Level 5: VM / stronger isolation — VM or microVM for high-risk capabilities
- Level 6: Optional deeper OS integration — custom OS layer, deeper control, but still modular

No implementation of these levels in P8, only roadmap. Current P2 is Level 0.

## 16. Policy Engine

Inputs:

- Actor (User, Agent, Service, Tool, MCP Server, Execution Authority identity)
- Action (what is proposed: package-install, fs-write, network-connect, etc.)
- Capability (which capability required)
- Resource (which file, process, network domain, etc.)
- Scope (workspace, repository, project, user, host, network, production)
- Risk (LOW, MEDIUM, HIGH, CRITICAL, derived from capability + resource + scope)
- Environment (OS, arch, network state, disk, memory)
- Context (session, project, user, ephemeral)
- Approval (AUTO, DRY_RUN, EXPLICIT_APPROVAL, DENY)
- Network state (AVAILABLE, PARTIALLY_AVAILABLE, BLOCKED)

Decision:

- ALLOW
- DENY
- REQUIRE_APPROVAL
- DRY_RUN (show WOULD EXECUTE, not executed)

UNKNOWN → DENY (fail-closed).

## 17. State Model — Action Lifecycle

```
PROPOSED → VALIDATING → AUTHORIZED → DRY_RUN → EXECUTING → SUCCEEDED → VERIFIED
                ↓           ↓                      ↓          ↓          ↓
             DENIED      DENIED                FAILED   UNVERIFIED   BLOCKED
                ↓           ↓                      ↓          ↓          ↓
             BLOCKED     BLOCKED              BLOCKED   BLOCKED    CANCELLED
```

Important distinctions:

- SUCCEEDED ≠ VERIFIED (execution may succeed but verification may fail or be missing)
- EXECUTED ≠ SAFE (execution may happen but be unsafe, need policy check)
- LOCAL PASS ≠ PRODUCTION PASS (Arena sandbox PASS is REAL LOCAL TEST, not PRODUCTION EVIDENCE)
- MOCK PASS ≠ PRODUCTION PASS

## 18. Event Model

Events:

- action.proposed
- action.validated
- action.authorized
- action.denied
- action.started
- action.completed
- action.failed
- verification.started
- verification.passed
- verification.failed
- evidence.created

Each event needs:

- event_id (unique)
- timestamp (UTC ISO8601)
- actor (identity)
- action (what)
- scope (workspace, etc.)
- result (ALLOW, DENY, SUCCEEDED, FAILED, etc.)
- correlation_id (to link related events)
- No secrets in event (must not log secret value)

See `event-model.md`.

## 19. Memory Architecture

Split:

- Ephemeral Context: current turn, not persisted, short-lived
- Session Memory: current session, persisted for session, deleted after
- Project Memory: project-specific, persisted in project, scoped to project
- User Memory: user-specific, persisted per user, access policy per user
- System Memory: system-wide, for LINEX.OS itself, not user data

For each:

- ownership (who owns)
- retention (how long)
- access policy (who can read/write)
- encryption (at rest, in transit, if needed)
- deletion (how deleted, when)

No storage implementation in P8, only model.

## 20. Artifact Model

Types:

- Source Artifact: code, docs, config (e.g., README.md, AGENTS.md)
- Build Artifact: compiled output, toolchain manifest, etc.
- Execution Artifact: temporary files created during execution (e.g., test.c, test binary), must be outside repo or deleted after
- Evidence Artifact: logs, verification-summary.txt, test logs, doctor output (no secrets)
- User Artifact: user-created files, scoped to user

For each:

- owner
- scope
- hash (SHA256 for provenance)
- provenance (who created, when, how)
- retention (how long kept)

## 21. Database / Storage Abstraction

No vendor chosen in P8. Define interfaces:

- State Store: stores action states (PROPOSED, etc.)
- Event Store: stores events (append-only, immutable)
- Memory Store: stores memory (ephemeral, session, project, user, system)
- Artifact Store: stores artifacts (source, build, execution, evidence, user)
- Evidence Store: stores verification evidence (logs, attestations)

For each interface, define what is:

- local (must work offline, no cloud)
- optional remote (can sync to remote if configured)
- replaceable (vendor-neutral, interface-based, not tied to specific DB)

## 22. Network Architecture

Define:

- Inbound: API requests from UI, from external? Must have auth, rate limiting, capability check
- Outbound: Tool calls to external APIs (GitHub, Microsoft, Debian mirrors), must have network capability + policy, allowlist official sources only
- Internal: Event Bus, Service-to-Service, must have auth
- External: Internet, must be via Network Service with policy

Zones:

- Trusted: Control Plane, Policy Engine, Execution Authority (but still verify)
- Restricted: Agent Runtime, Tool Runtime, MCP Gateway (semi-trusted, must be validated)
- Untrusted: LLM, User input, External APIs, MCP servers, Plugins, Browser/Computer executors

No Agent → Internet unrestricted without CAP_NETWORK_CONNECT + Policy.

Current Arena: github.com PASS, api.github.com PASS, packages.microsoft.com BLOCKED, release-assets.githubusercontent.com BLOCKED, deb.debian.org BLOCKED — documented as known limitations, not design failure.

## 23. Identity

Identity boundaries:

- User: human user, has identity, role, capabilities
- Agent: AI agent, has identity, role, capabilities, not same as user
- Service: internal service (Filesystem Service, etc.), has identity
- Tool: tool has ID, version, capability required, not same as agent
- MCP Server: MCP server has identity, trust classification, capabilities
- Execution Authority: has identity, executes via policy, not same as agent

Each must have separate identity/context architecturally, not shared mutable global.

## 24. Observability

Define:

- Logs: DEBUG LOG for debugging, not audit
- Metrics: CPU, memory, disk, execution time, success/failure counts
- Traces: action execution trace, correlation_id
- Events: action.proposed, etc. (see Event Model)
- Audit: who did what, when, with what authorization, for security
- Evidence: VERIFICATION EVIDENCE for verification, not debug

Distinguish:

- DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE — do not mix.

No secrets in any observability.

## 25. Failure Model

Failure classes:

- Policy Failure: policy missing, invalid, contradictory → BLOCKED
- Authorization Failure: not authorized, missing approval → DENY/BLOCKED
- Validation Failure: input schema invalid, resource not found → DENY
- Execution Failure: executor fails, process fails, timeout → FAILED
- Network Failure: network BLOCKED, timeout, DNS failure → BLOCKED or FAILED depending on essential
- Dependency Failure: dependency missing, not installed → NOT VERIFIED or BLOCKED
- Resource Failure: disk full, memory low, CPU high → BLOCKED
- Verification Failure: verification fails, evidence insufficient → UNVERIFIED

Each failure must not automatically become success. Fail-closed.

## 26. Fail-Closed Architecture

Invariants:

- Unknown capability → DENY
- Unknown tool → DENY (BLOCKED)
- Unknown executor → DENY
- Missing authorization → DENY
- Missing evidence → UNVERIFIED (not PASS)
- Untrusted network → BLOCKED (if network required for official source, but allow alternative official sources)
- Invalid schema → DENY
- Ambiguous identity → DENY

## 27. Resource Limits — Design Only

On design level only, not implemented in P8:

- CPU (limit per execution)
- Memory (limit per execution)
- Disk (limit per artifact, per execution)
- Process count
- File descriptors
- Network (bandwidth, domains)
- Execution time (timeout)
- Output size (max log size, max artifact size)

No implementation now, only design.

## 28. Security Threat Model

See `threat-model.md` for full.

Threats:

- Prompt injection
- Tool injection
- MCP compromise
- Malicious skill
- Malicious plugin
- Privilege escalation
- Secret exfiltration
- Path traversal
- Command injection
- Supply-chain attack
- Policy bypass
- Agent impersonation
- Evidence forgery
- Replay
- Resource exhaustion
- Network abuse

For each: Asset, Attack, Boundary, Mitigation, Residual Risk. No claim of mitigations not existing.

## 29. Supply Chain

Design:

- Dependency provenance: where dependency comes from, version, hash, official source only
- Tool provenance: tool ID, version, who provides, hash
- Plugin provenance: plugin registry, trust classification, signature roadmap
- MCP provenance: MCP server registry, trust, capability mapping
- Artifact hashes: SHA256 for all artifacts, provenance
- Version pinning: full-length commit SHA for GitHub Actions (per P7), not moving tag
- Signature verification roadmap: Level 0 no signing, Level 1 hash verification, Level 2 signature verification (future)

No signing system implementation now.

## 30. Multi-Tenancy Readiness

Even if not multi-tenant now, architecture must allow separation between:

- User
- Project
- Workspace
- Agent
- Session

No global mutable state as primary design. Each has identity, scope, capabilities, memory, artifacts.

## 31. API Boundary — Conceptual Only

Domains:

- /health
- /agents
- /actions
- /capabilities
- /tools
- /skills
- /mcp
- /files
- /memory
- /events
- /evidence
- /policies

No endpoints implementation in P8, only conceptual domains.

## 32. UI Boundary

UI is client only.

UI must NOT contain:

- sudo logic
- shell policy
- authorization logic
- secret execution

UI → API only.

## 33. Dependency Direction

Fixed:

```
UI
 ↓
API
 ↓
Application Services
 ↓
Runtime
 ↓
Policy / Authorization
 ↓
Execution
 ↓
Host / External Systems
```

No dependency cycles allowed. No UI→sudo, no LLM→shell.

## 34. Modularity

Any module must be replaceable:

- LLM Provider (OpenAI, Anthropic, local, etc.)
- Storage Provider (local file, SQLite, Postgres, etc.)
- MCP Provider
- Browser Engine
- Execution Sandbox (Level 0 Gate → Level 6 OS integration)
- Identity Provider
- Observability backend

Use interfaces/contracts, not direct commercial coupling. Core must be vendor-neutral.

## 35. Free-First Compatibility

While keeping project goal, Core should be:

- vendor-neutral
- self-hostable
- local-capable
- free-first

Do not assume in P8:

- paid API
- cloud database
- paid observability
- mandatory SaaS

## 36. Low-Resource Mode

Design:

- LINEX.OS CORE: minimal, detection, policy, gate, verification, doctor, no browser/computer, low memory
- LINEX.OS STANDARD: CORE + build toolchain, PowerShell, basic agents, skills, MCP gateway, filesystem, process, network (allowlisted)
- LINEX.OS HEAVY: STANDARD + browser, computer, advanced sandboxing, heavier observability, optional cloud sync

System must work in CORE mode in limited resources (Debian 12, 21G disk, 3.8Gi memory as in Arena).

No GPU or Kubernetes assumed.

## 37. Documentation Output

Created in P8:

- docs/architecture/context.md
- docs/architecture/container.md
- docs/architecture/components.md
- docs/architecture/execution-model.md
- docs/architecture/security-boundaries.md
- docs/architecture/capability-model.md
- docs/architecture/event-model.md
- docs/architecture/data-model.md
- docs/architecture/networking.md
- docs/architecture/extensibility.md
- docs/architecture/threat-model.md
- docs/architecture/roadmap.md
- docs/architecture/frozen-baseline.md
- docs/architecture/adr/0001-linex-os-scope.md
- docs/architecture/adr/0002-execution-boundary.md
- docs/architecture/adr/0003-capability-security-model.md
- docs/architecture/adr/0004-policy-vs-execution.md
- docs/architecture/adr/0005-storage-abstraction.md
- docs/architecture/adr/0006-extensibility-model.md

And updated docs/architecture.md (this file).

## 38. ADRs

See `adr/` folder for 6 ADRs, each with Context, Decision, Alternatives, Consequences, Status (ACCEPTED or PROVISIONAL).

## 39. Architecture Diagrams

Use ASCII diagrams or Mermaid only, no external images.

Diagrams at least for:

- System Context
- Runtime Layers
- Action Execution
- Trust Boundaries
- Capability Flow
- Event Flow

See individual docs for diagrams.

## 40. Architecture Freeze

At end of P8, `frozen-baseline.md` contains:

- Architectural Decisions
- Non-goals
- Interfaces
- Trust Boundaries
- Security Invariants
- Open Decisions
- Deferred Decisions

Freeze means: No implementation should violate documented baseline without an ADR.

## 41. Open Decisions

Decisions not yet made (DECISION PENDING with criteria):

- Programming Language (for Core Runtime)
- Runtime implementation technology (process model)
- Database (State Store, Event Store, etc.)
- Event bus implementation
- Sandbox implementation (Level 1-6)
- UI framework
- API framework
- Browser engine
- MCP transport
- Deployment topology

No technologies chosen merely to fill gap. Use DECISION PENDING with criteria.

## 42. Architecture Tests

Created `tests/architecture.test.sh` testing:

- architecture docs exist
- ADRs exist
- trust boundary exists
- capability model exists
- fail-closed documented
- AI/Policy/Execution separation exists
- UI does not directly control privileged execution
- LLM does not directly invoke shell
- MCP has trust boundary
- Production distinction exists
- P4 BLOCKED preserved
- system vs project sudo distinction preserved
- no contradictory architecture statements

## 43. Static Architecture Check

Created `ops/verify/verify-architecture.sh` to check architectural invariants, no package install, no product code.

## 44. P7 Security Fix Continuation

Reviewed `ops/security/static-security-check.sh`:

- Previously had directory-wide exclusion `tests/` for destructive-pattern checks as general security solution, which is not ideal
- P8 converts to Test/Policy Boundary: dangerous commands in tests/ as non-executable fixtures (string arguments to Gate, inside run_test, inside grep pattern) are allowed, but executable dangerous commands outside tests/ are BLOCKED
- Documented in static-security-check.sh header and in docs/architecture/security-boundaries.md
- Goal: security scanner sees repository without ignoring tests entirely for secret scanning (already fixed in P7), and for destructive patterns, distinguishes executable vs fixture via `^\s*` check and --exclude-dir=tests for executable checks, but with explicit documentation that tests/ fixtures are non-executable and test blocking behavior.

## 45. P4

Preserved: P4 = BLOCKED, no attempt to install PowerShell in P8.

## 46. Remote CI

No commit, push, merge. Status: REMOTE CI = NOT VERIFIED — branch arena/01a107fc-linex-os not pushed, main still at 768bf39, per P7/P8 spec no push.

## 47. System Changes

P8 repository-only, no apt, sudo, systemctl, user/group, firewall, disk, boot, PowerShell, Docker, package installation.

## 48. Architecture Quality Gate

- Does every component have boundary? YES — see components.md with Purpose/Inputs/Outputs/Trust/Dependencies/May Do/Must Never Do
- Does every privileged operation pass Policy? YES — via Policy Engine → Authorization → Execution Authority, per AGENTS.md and security-boundaries.md
- Is AI separated from Execution? YES — LLM → Planner → Policy → Execution Authority → Verifier, forbidden LLM→shell
- Are capabilities explicit? YES — CAP_* model, default DENY, explicit approval
- Is default deny? YES — fail-closed, unknown → DENY
- Is unknown state fail-closed? YES — see fail-closed architecture
- Is MCP logically isolated? YES — MCP Gateway with trust classification, capability mapping, isolation boundary, no unbounded host access
- Is storage replaceable? YES — interfaces State Store, Event Store, Memory Store, Artifact Store, Evidence Store, local/optional remote/replaceable, vendor-neutral
- Are external providers optional? YES — LLM Provider, Storage Provider, etc. replaceable via interfaces, free-first, self-hostable, local-capable
- Is architecture scalable? YES — modular, replaceable, CORE/STANDARD/HEAVY, low-resource mode, no global mutable state, multi-tenancy readiness
- Is low-resource mode present? YES — CORE, STANDARD, HEAVY
- Is deployment model changeable? YES — runs as process, container, VM, optional deeper OS integration later, not tied to specific deployment

## 49. References

- AGENTS.md — general agent rules
- ARENA.md — Arena operating protocol
- docs/security.md — System vs Project privilege
- docs/development.md — INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT
- docs/operations.md — bootstrap, doctor, verification, toolchain, Gate, network limits, P4 blocker
- ops/security/privilege-policy.md — 5 levels, allowlist, fail-closed
- docs/agent-contract.md — Policy vs Execution separation
- GitHub Docs secure-use: permissions contents: read, pin to full-length commit SHA, no pull_request_target for untrusted PR code

---

**Status:** P8 Architecture Design — context, container, components, execution-model, security-boundaries, capability-model, event-model, data-model, networking, extensibility, threat-model, roadmap, ADRs, frozen-baseline, tests, verification.

**Next:** P9 Core Runtime Contract (interfaces before implementation)
