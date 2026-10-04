# ADR 0006 — Extensibility Model

## Context

Need to design extensibility model: how LINEX.OS can grow without rebuilding later, how to add new LLM providers, storage providers, MCP providers, browser engines, execution sandboxes, identity providers, observability backends, tools, skills, plugins, without coupling Core to commercial provider, without assuming paid API/cloud DB.

Foundation P1-P7 has dependency rule UI→API→Runtime→Policy→Execution, no huge feature at once MILESTONE→SUBTASK→CHANGE→TEST→VERIFY→EVIDENCE, and tool selection least tool priority Existing repo tooling→OS tooling→approved package→external service, no new tools without need.

Need to define Tool Contract, Skill model, MCP architecture, Plugin Registry, API boundary, UI boundary, dependency direction, modularity, free-first compatibility, low-resource mode, multi-tenancy readiness.

## Decision

**Extensibility model with modularity, replaceable modules via interfaces/contracts, vendor-neutral, free-first, self-hostable, local-capable — ACCEPTED**

### Replaceable Modules via Interfaces

- LLM Provider: interface LLM Provider (propose action, generate text, with context, memory), implementations OpenAI, Anthropic, local LLM, etc., trust Untrusted, must go via Planner→Policy→Execution→Verifier, must never direct shell/sudo/filesystem mutation
- Storage Provider: interfaces State Store, Event Store, Memory Store, Artifact Store, Evidence Store, implementations local file, SQLite, Postgres, etc., trust Trusted if via Policy, local must work offline, optional remote sync, replaceable, no vendor chosen in P8
- MCP Provider: interface MCP Gateway, MCP Server Registry, implementations official, verified community, untrusted third-party, trust Untrusted for servers, semi-trusted for Gateway, must have trust classification, capability mapping, input/output validation, timeout, network policy, audit, isolation boundary, no unbounded host access
- Browser Engine: interface Browser Executor, implementations future Playwright, Puppeteer, etc., trust Untrusted, capability CAP_BROWSER HIGH risk EXPLICIT_APPROVAL, must have isolation, resource limits, no unrestricted host access
- Execution Sandbox: interface Execution Authority executors, implementations Level 0 Gate (current, allowlist + structured actions + dry-run) → Level 1 unprivileged process → Level 2 filesystem isolation → Level 3 network isolation → Level 4 container/sandbox → Level 5 VM → Level 6 deeper OS integration, trust Trusted, roadmap Level 0 now Level 1-6 future
- Identity Provider: interface Identity/Auth, implementations local file, future OAuth, etc., trust Trusted, must have separate identity for User, Agent, Service, Tool, MCP Server, Execution Authority, no ambiguous identity→DENY
- Observability Backend: interface Observability (Logs, Metrics, Traces, Events, Audit, Evidence), implementations local file, future Prometheus, etc., trust Trusted, must distinguish DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE, no secrets, no mixing

### Tool Contract

- Tool ID (e.g., fs.read)
- Version (semver)
- Input schema (JSON schema)
- Output schema
- Capability required (e.g., CAP_FS_READ)
- Risk class (CLASS-0 READ_ONLY to CLASS-6 DESTRUCTIVE)
- Execution authority (which executor)
- Timeout
- Resource limits (CPU, memory, disk, output size)
- Evidence requirements

Unknown Tool → BLOCKED.

### Skill Model

- Tool = executable capability
- Skill = reusable higher-level procedure that composes tools (e.g., verify environment, review PR, bootstrap)
- Agent = decision/planning entity that selects skills/tools
- Workflow = orchestrated sequence Agent→Skill→Tool→Execution Authority→Verifier

```
Agent → Skill → Tool → Execution Authority → Verifier
```

### Plugin Registry

- Purpose: registry for plugins with provenance, trust classification, version pinning, signature verification roadmap, capability mapping
- Trust: Semi-trusted (plugins may be untrusted, must be via registry)
- Must have: provenance (where from, version, hash), trust classification, version pinning (full-length commit SHA for GitHub Actions per P7), capability mapping, audit, no unbounded host access

### Supply Chain

- Dependency provenance: where dependency comes from, version, hash, official source only, no third-party PowerShell source, no random mirror, WHY/SOURCE/VERSION/LICENSE/RISK/ALTERNATIVES/REQUIRED_FOR per AGENTS.md Dependency Rules
- Tool provenance: tool ID, version, provider, hash
- Plugin provenance: registry, trust, pinning
- MCP provenance: registry, trust, capability mapping
- Artifact hashes: SHA256 for all artifacts, provenance
- Version pinning: full-length commit SHA for GitHub Actions (per P7 secure-use, actions/checkout v7.0.1 SHA 3d3c42e5aac5ba805825da76410c181273ba90b1), not moving tag, no branch main/master as source
- Signature verification roadmap: Level 0 no signing, Level 1 hash verification, Level 2 signature verification (future)

No signing system implementation now.

### API Boundary — Conceptual Only

Domains (no implementation in P8):

- /health, /agents, /actions, /capabilities, /tools, /skills, /mcp, /files, /memory, /events, /evidence, /policies

### UI Boundary

UI is client only, no sudo, no shell policy, no authorization logic, no secret execution, UI→API only.

### Dependency Direction

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

No cycles, no UI→sudo, no LLM→shell.

### Free-First Compatibility

Core must be vendor-neutral, self-hostable, local-capable, free-first, no assumption of paid API, cloud database, paid observability, mandatory SaaS in P8.

### Low-Resource Mode

- CORE: minimal (Core Runtime, Policy, Execution Authority Shell/File/Process, Verification, Filesystem, Event Bus, Artifact Store, Evidence Store, Identity, Config, Observability minimal) — low memory, works in Arena 21G disk 3.8Gi memory
- STANDARD: CORE + Build Toolchain, PowerShell, Agent Runtime, Planner, Tool Runtime, Skill Runtime, MCP Gateway, Network Service (allowlisted), Memory Service, Plugin Registry
- HEAVY: STANDARD + Browser, Computer, advanced sandboxing Level 4-6, heavier observability, optional cloud sync

No GPU or Kubernetes assumed.

### Multi-Tenancy Readiness

Even if not multi-tenant now, architecture must allow separation between User, Project, Workspace, Agent, Session, no global mutable state as primary design.

## Alternatives

- **Alternative 1: Monolithic architecture with direct coupling to commercial providers** — Rejected: Ties Core to specific vendor (e.g., OpenAI for LLM, Postgres for DB, specific browser engine), not vendor-neutral, not free-first, not self-hostable, hard to replace, supply-chain risk, not low-resource mode.
- **Alternative 2: No extensibility, hard-coded tools** — Rejected: Cannot grow without rebuilding, violates MILESTONE→SUBTASK→CHANGE→TEST→VERIFY→EVIDENCE large project rule (no huge feature at once), violates modularity, not scalable.
- **Alternative 3: Plugin system with unbounded host access** — Rejected: HIGH security risk, allows plugin to bypass policy, get host scope without explicit, exfiltrate secrets, privilege escalation. Must have Plugin Registry with trust classification, capability mapping, isolation boundary, no unbounded host access.
- **Alternative 4 (Chosen): Modular, replaceable via interfaces/contracts, vendor-neutral, free-first, self-hostable, local-capable, with Tool Contract, Skill model, Plugin Registry, Supply Chain with provenance and version pinning, API/UI boundaries, dependency direction fixed, low-resource mode CORE/STANDARD/HEAVY, multi-tenancy readiness** — ACCEPTED: Enables growth without rebuilding, aligns with P8 architecture, roadmap, free-first compatibility, low-resource mode, no GPU/K8s assumed.

## Consequences

- Positive:
  - Growth without rebuilding, modular, replaceable, vendor-neutral, free-first, self-hostable, local-capable
  - Clear Tool Contract, Skill model, Plugin Registry, Supply Chain with provenance and pinning
  - API/UI boundaries, dependency direction fixed, no cycles
  - Low-resource mode CORE/STANDARD/HEAVY, no GPU/K8s assumed
  - Multi-tenancy readiness, no global mutable state
  - Aligns with Foundation P1-P7, P8 architecture, roadmap
- Negative:
  - More abstraction, more interfaces, need to implement in P9+ (not in P8)
  - Need to define criteria for choosing implementations later (DECISION PENDING with criteria)
- Neutral:
  - No product code in P8, only documentation

## Status

ACCEPTED

## References

- docs/architecture/extensibility.md (full extensibility model)
- docs/architecture/components.md (23 components with May Do/Must Never Do)
- docs/architecture/container.md (containers, dependency direction)
- docs/architecture/roadmap.md (P9+ extensibility implementation)
- docs/architecture/security-boundaries.md (MCP boundaries, Plugin Registry, supply chain)
- docs/architecture/capability-model.md (capability model, Tool Contract)
- AGENTS.md (Dependency Rules WHY/SOURCE/VERSION/LICENSE/RISK/ALTERNATIVES/REQUIRED_FOR, Tool selection least tool priority)
- ARENA.md (Workspace Boundaries, Repository Boundaries)
- .github/workflows/ci.yml (version pinning full SHA, permissions contents: read)
