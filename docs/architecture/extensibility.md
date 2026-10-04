# LINEX.OS — Extensibility (P8)

## Extensibility Model — Modular, Replaceable, Vendor-Neutral

Any module must be replaceable via interfaces/contracts, not direct commercial coupling.

## Replaceable Modules

### LLM Provider

- Interface: LLM Provider (propose action, generate text, with context, memory)
- Implementations: OpenAI, Anthropic, local LLM, etc.
- Trust: Untrusted (may be prompt-injected)
- Must go via: Planner → Policy Engine → Authorization → Execution Authority → Verifier
- Must never: Direct shell, direct sudo, direct filesystem mutation

### Storage Provider

- Interfaces: State Store, Event Store, Memory Store, Artifact Store, Evidence Store
- Implementations: local file, SQLite, Postgres, etc.
- Trust: Trusted (if via Policy)
- Local: must work offline, no cloud required
- Optional remote: can sync if configured
- Replaceable: vendor-neutral
- No vendor chosen in P8 to keep free-first, self-hostable, local-capable

### MCP Provider

- Interface: MCP Gateway, MCP Server Registry
- Implementations: official LINEX.OS MCP servers, verified community, untrusted third-party
- Trust: Untrusted for servers, semi-trusted for Gateway
- Must have: trust classification, capability mapping, input/output validation, timeout, network policy, audit, isolation boundary, no unbounded host access

### Browser Engine

- Interface: Browser Executor
- Implementations: future (Playwright, Puppeteer, etc.)
- Trust: Untrusted (if compromised, affects host)
- Capability: CAP_BROWSER, HIGH risk, EXPLICIT_APPROVAL
- Must have: isolation, resource limits, no unrestricted host access

### Execution Sandbox

- Interface: Execution Authority executors
- Implementations: Level 0 Gate (current, allowlist + structured actions + dry-run), Level 1 unprivileged process, Level 2 filesystem isolation, Level 3 network isolation, Level 4 container/sandbox, Level 5 VM, Level 6 deeper OS integration
- Trust: Trusted (executes only via policy)
- Roadmap: Level 0 now, Level 1-6 future, no implementation in P8

### Identity Provider

- Interface: Identity/Auth
- Implementations: local file, future OAuth, etc.
- Trust: Trusted
- Must have: separate identity for User, Agent, Service, Tool, MCP Server, Execution Authority, no ambiguous identity → DENY

### Observability Backend

- Interface: Observability (Logs, Metrics, Traces, Events, Audit, Evidence)
- Implementations: local file, future Prometheus, etc.
- Trust: Trusted
- Must distinguish: DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE, no secrets, no mixing

## Tool Contract

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

## Skill Model

- Tool = executable capability
- Skill = reusable higher-level procedure that composes tools (e.g., verify environment, review PR, bootstrap)
- Agent = decision/planning entity that selects skills/tools
- Workflow = orchestrated sequence Agent→Skill→Tool→Execution Authority→Verifier

## Plugin Registry

- Purpose: Registry for plugins with provenance, trust classification, version pinning, signature verification roadmap, capability mapping
- Trust: Semi-trusted (plugins may be untrusted, must be via registry)
- Must have: provenance (where from, version, hash), trust classification, version pinning (full-length commit SHA for GitHub Actions per P7), capability mapping, audit, no unbounded host access

## Supply Chain

- Dependency provenance: where dependency comes from, version, hash, official source only, no third-party PowerShell source, no random mirror
- Tool provenance: tool ID, version, provider, hash
- Plugin provenance: registry, trust, pinning
- MCP provenance: registry, trust, capability mapping
- Artifact hashes: SHA256 for all artifacts, provenance
- Version pinning: full-length commit SHA for GitHub Actions (per P7 secure-use, actions/checkout v7.0.1 SHA 3d3c42e5aac5ba805825da76410c181273ba90b1), not moving tag, no branch main/master as Action source
- Signature verification roadmap: Level 0 no signing, Level 1 hash verification, Level 2 signature verification (future)

No signing system implementation now.

## API Boundary — Conceptual Only

Domains (no implementation in P8):

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

## UI Boundary

UI is client only, no sudo, no shell policy, no authorization logic, no secret execution, UI→API only.

## Dependency Direction

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

No cycles. No UI→sudo, no LLM→shell.

## Free-First Compatibility

Core must be vendor-neutral, self-hostable, local-capable, free-first, no assumption of paid API, cloud database, paid observability, mandatory SaaS in P8.

## Low-Resource Mode

- CORE: minimal (Core Runtime, Policy, Execution Authority Shell/File/Process, Verification, Filesystem, Event Bus, Artifact Store, Evidence Store, Identity, Config, Observability minimal) — low memory, works in Arena 21G disk 3.8Gi memory
- STANDARD: CORE + Build Toolchain, PowerShell, Agent Runtime, Planner, Tool Runtime, Skill Runtime, MCP Gateway, Network Service (allowlisted), Memory Service, Plugin Registry
- HEAVY: STANDARD + Browser, Computer, advanced sandboxing Level 4-6, heavier observability, optional cloud sync

No GPU or Kubernetes assumed.

## Multi-Tenancy Readiness

Even if not multi-tenant now, architecture must allow separation between User, Project, Workspace, Agent, Session, no global mutable state as primary design.

## Roadmap

See roadmap.md for P8→P9→... and sandboxing roadmap Level 0-6.

## References

- architecture.md (overview, modularity, free-first, low-resource)
- container.md (containers, dependency direction)
- components.md (23 components with May Do/Must Never Do)
- capability-model.md (capability model)
- security-boundaries.md (trust boundaries, supply chain)
- threat-model.md (supply-chain attack)
- ADRs 0006 extensibility-model
