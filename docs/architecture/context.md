# LINEX.OS — System Context (P8)

## System Context Diagram (C4 Level 1)

```
                    ┌─────────────────┐
                    │      User       │
                    │  (Human, CLI)   │
                    └────────┬────────┘
                             │ uses
                             ↓
                    ┌─────────────────┐
                    │   LINEX.OS UI   │  ← Client only, no privileged logic
                    │  (Future CLI,   │
                    │   Web, API)     │
                    └────────┬────────┘
                             │ UI → API only
                             ↓
┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│  External    │←──→│   LINEX.OS API  │←──→│   External   │
│  APIs        │    │  (Future REST,  │    │  MCP Servers │
│  (GitHub,    │    │   MCP Gateway)  │    │ (Untrusted)  │
│  Microsoft,  │    └────────┬────────┘    └──────────────┘
│  Debian)     │             │
└──────────────┘             │ depends on
                             ↓
                    ┌─────────────────┐
                    │  LINEX.OS Core  │
                    │   Substrate     │
                    │  + Runtime      │
                    │  + Policy       │
                    │  + Execution    │
                    │  + Verification │
                    └────────┬────────┘
                             │
                             ↓
                    ┌─────────────────┐
                    │    Host OS      │
                    │  (Linux /       │
                    │   macOS /       │
                    │   Windows)      │
                    └────────┬────────┘
                             │
                             ↓
                    ┌─────────────────┐
                    │    Hardware     │
                    └─────────────────┘

Legend:
- User: human, uses UI, provides approval for EXPLICIT_APPROVAL capabilities
- LINEX.OS UI: client only, no sudo, no shell policy, no auth logic, UI→API only
- LINEX.OS API: future REST, MCP Gateway, health, agents, actions, capabilities, tools, etc.
- External APIs: GitHub (PASS in Arena), packages.microsoft.com (BLOCKED in Arena), deb.debian.org (BLOCKED), release-assets (BLOCKED) — official sources only
- External MCP Servers: untrusted, via MCP Gateway with trust classification, capability mapping, isolation
- LINEX.OS Core: Substrate + Runtime + Policy + Execution + Verification — inside LINEX.OS boundary
- Host OS: Linux (initial), macOS, Windows — outside LINEX.OS, but LINEX.OS runs above it, does not modify /etc/sudoers, etc.
- Hardware: outside
```

## What is LINEX.OS?

**LINEX.OS in v1 is AI-native Execution Operating Environment above Linux, with roadmap to deeper OS integration.**

Not kernel replacement in v1. Decision ACCEPTED in ADR 0001, revisable via ADR.

Purpose: Provide governed runtime for AI agents that can execute Linux and PowerShell tasks safely, with fail-closed policy, structured privilege gate, evidence-based verification, before any product code.

## System Boundary

### Inside LINEX.OS

- Substrate (OS detection, arch detection, package manager abstraction) — `ops/bootstrap/`
- Core Runtime (bootstrap, verification, toolchain detection) — `ops/bootstrap/`, `ops/verify/`, `ops/linux/`, `ops/powershell/`
- Policy Engine (allowlist, capability model, risk, approval) — `ops/security/privilege-policy.md`
- Authorization Layer (actor, action, capability, resource, scope, environment) — part of Policy Engine
- Execution Authority (shell, process, file, browser, computer, network, package executors) — `ops/security/privilege-gate.sh` + future executors
- Verification Engine (logs, evidence, tests, attestations) — `scripts/doctor.sh`, `ops/verify/`, tests
- Agent Runtime (identity, role, capabilities, context, memory, planner, tools, policies, evidence) — future, model in `components.md`
- Tool Runtime, Skill Runtime, MCP Gateway, Filesystem Service, Process Service, Network Service, Memory Service, Event Bus, Artifact Store, Evidence Store, Identity/Auth, Configuration Service, Observability, Plugin Registry — future, interfaces in `components.md`
- UI/API as client only — future, no privileged logic

### Outside LINEX.OS

- Hardware
- Host OS kernel, drivers, bootloader, firmware
- Host filesystem outside workspace/repository boundary (unless capability granted)
- External APIs (GitHub, Microsoft, Debian mirrors)
- Cloud providers
- User's production databases, production credentials (unless explicit production capability + production evidence)
- Internet unrestricted (requires CAP_NETWORK_CONNECT + policy)

### Trusted

- Policy Engine (defines ALLOW/DENY)
- Execution Authority (executes only via policy)
- Verification Engine (produces evidence, not claims)
- Host OS kernel (assumed trusted, but LINEX.OS does not modify /etc/sudoers)
- Substrate (detection, read-only)

### Semi-trusted

- Agent Runtime (proposes, not authorization authority)
- Tool Runtime (executes via Execution Authority)
- MCP Gateway (validates, isolates, but MCP servers may be untrusted)
- Configuration Service (if compromised, affects policy, must be verified)

### Untrusted

- LLM (prompt injection risk, must not directly invoke shell)
- User input (must be validated)
- External APIs (may be compromised, network policy)
- MCP servers (third-party, trust classification, capability mapping, isolation)
- Plugins (via Plugin Registry, provenance, version pinning)
- Browser/Computer executors (if compromised, affect host)

## Primary Execution Model

```
LLM
  ↓ (proposes)
Planner
  ↓ (action proposal)
Policy Engine (inputs: actor, action, capability, resource, scope, risk, env, context, approval, network)
  ↓ (decision: ALLOW, DENY, REQUIRE_APPROVAL, DRY_RUN, UNKNOWN→DENY)
Authorization
  ↓
Execution Authority (Shell, Process, File, Browser, Computer, Network, Package executors)
  ↓ (execution)
Verifier (logs, evidence, tests, attestations)
  ↓
Evidence (no secrets)
```

Forbidden direct paths: LLM→shell, LLM→sudo, LLM→filesystem mutation directly, Agent→production DB directly, UI→privileged execution directly, MCP server→unrestricted host access.

## Components Exist vs Not Yet

### Exist (P1-P7 Foundation)

- Substrate: OS detection, arch detection, package manager detection (bootstrap.sh)
- Core Runtime: bootstrap, verification (verify-environment.sh)
- Policy Engine: privilege-policy.md 5 levels READ_ONLY, SAFE_USER_COMMAND, PACKAGE_INSTALL, PRIVILEGED_OPERATION, DESTRUCTIVE_OPERATION, DEFAULT DENY
- Privilege Layer: privilege-gate.sh allowlist + structured actions + dry-run default + evidence
- Tool Layer: Linux toolchain gcc/g++/make/pkg-config (P3), PowerShell install logic (P4 BLOCKED but logic PASS)
- Security: policy-check.sh, secret-scan.sh (P7 repository-wide including tests/), static-security-check.sh (P7)
- Agent Contract: AGENTS.md, ARENA.md, docs/agent-contract.md (P6)
- Verification: doctor.sh aggregator (P7) covering Repository, Git, OS, Architecture, Linux Shell, sudo, Package Manager, Required Tools, Build Toolchain, PowerShell, Privilege Policy, Security Policy, Agent Contract, P1-P7 Verification, CI Configuration, Secrets Hygiene, Disk, Memory, Network
- CI: .github/workflows/ci.yml hardened with permissions contents: read, pinned checkout SHA 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1, 6 jobs, no Docker/PowerShell required, no pull_request_target

### Not Yet (P8+)

- Core Runtime Contract (P9)
- Execution Authority executors beyond Gate (Shell, Process, File, Browser, Computer, Network)
- Policy Engine implementation (beyond privilege-policy.md)
- Capability System (P12)
- Agent Runtime (P13)
- Tool Runtime, Skill Runtime, MCP Gateway, Filesystem Service, Process Service, Network Service, Memory Service, Event Bus, Artifact Store, Verification Engine, Audit/Evidence Store, Identity/Auth, Configuration Service, UI/API, Observability, Plugin Registry
- Database/Storage abstraction (State Store, Event Store, etc.)
- UI, API, MCP, Browser, Computer Use, etc.

## Trust Boundaries

See `security-boundaries.md` for detailed trust boundaries and `threat-model.md` for threats.

## How System Scales

- Modularity: any module replaceable via interfaces (LLM Provider, Storage Provider, MCP Provider, Browser Engine, Sandbox, Identity, Observability)
- Low-resource mode: CORE (minimal), STANDARD (CORE+toolchain+agents+MCP), HEAVY (STANDARD+browser+computer+advanced sandbox)
- No global mutable state as primary design, multi-tenancy readiness (User, Project, Workspace, Agent, Session separation)
- Dependency direction: UI→API→Application Services→Runtime→Policy/Authorization→Execution→Host/External, no cycles
- Free-first, vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB

## How Architecture Evolves Toward AI-native OS

- Model C hybrid: execution environment first, deeper OS integration later
- Sandboxing roadmap Level 0 Gate (current) → Level 1 unprivileged process → Level 2 filesystem isolation → Level 3 network isolation → Level 4 container/sandbox → Level 5 VM → Level 6 optional deeper OS integration
- No kernel development in P8, but architecture allows future deeper integration without rebuilding from scratch, via replaceable Execution Sandbox interface
- Storage abstraction: local first, optional remote, replaceable
- Capability model: explicit, default DENY, elevation explicit

## Open Decisions

- Programming Language for Core Runtime: DECISION PENDING (criteria: portability, security, performance, ecosystem, team familiarity)
- Runtime implementation technology: DECISION PENDING
- Database: DECISION PENDING (criteria: local-first, replaceable, free-first)
- Event bus, Sandbox, UI framework, API framework, Browser engine, MCP transport, Deployment topology: all DECISION PENDING

See `roadmap.md` and `frozen-baseline.md`.

## References

- docs/architecture.md (overview)
- container.md (C4 Level 2)
- components.md (C4 Level 3, 23 components)
- ADRs 0001-0006
