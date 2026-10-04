# LINEX.OS — Container Diagram (C4 Level 2) — P8

## Container Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        LINEX.OS System                          │
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐   │
│  │     UI      │──→│     API     │──→│ Application Services│   │
│  │ (CLI, Web)  │   │ (REST, MCP  │   │  (Agents, Skills,   │   │
│  │ Client only │   │  Gateway)   │   │   Tools, Workflows) │   │
│  └─────────────┘   └─────────────┘   └──────────┬──────────┘   │
│                                                  │              │
│                                    ┌─────────────┴──────────┐   │
│                                    │      Core Runtime      │   │
│                                    │  (Bootstrap, Verify,  │   │
│                                    │   Toolchain Detect)   │   │
│                                    └─────────────┬──────────┘   │
│                                                  │              │
│                                    ┌─────────────┴──────────┐   │
│                                    │    Policy Engine       │   │
│                                    │  (Allowlist, Capability│   │
│                                    │   Registry, Risk)      │   │
│                                    └─────────────┬──────────┘   │
│                                                  │              │
│                                    ┌─────────────┴──────────┐   │
│                                    │   Authorization Layer  │   │
│                                    │ (Actor, Action, Scope) │   │
│                                    └─────────────┬──────────┘   │
│                                                  │              │
│                                    ┌─────────────┴──────────┐   │
│                                    │ Execution Authority    │   │
│                                    │ (Shell, Process, File, │   │
│                                    │  Browser, Network,     │   │
│                                    │  Package Executors)    │   │
│                                    └─────────────┬──────────┘   │
│                                                  │              │
│                                    ┌─────────────┴──────────┐   │
│                                    │ Verification Engine    │   │
│                                    │ (Logs, Evidence, Tests,│   │
│                                    │  Attestations, Audit)  │   │
│                                    └─────────────┬──────────┘   │
│                                                  │              │
│                                    ┌─────────────┴──────────┐   │
│                                    │   Services Layer       │   │
│                                    │ (Filesystem, Process,  │   │
│                                    │  Network, Memory,      │   │
│                                    │  Event Bus, Artifact,  │   │
│                                    │  Evidence, Identity,   │   │
│                                    │  Config, Observability,│   │
│                                    │  Plugin Registry, MCP) │   │
│                                    └────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ↓
                        ┌─────────────────┐
                        │    Host OS      │
                        │  (Linux Host)   │
                        └─────────────────┘
```

## Containers

### UI (Client Only)

- Purpose: User interface, CLI, future Web
- Inputs: User actions, approvals
- Outputs: API calls (UI→API only)
- Trust: Semi-trusted (must not contain sudo, shell policy, auth logic, secret execution)
- Dependencies: API
- May do: Display state, events, evidence, request approval
- Must never do: Direct privileged execution, direct filesystem mutation, contain secrets

### API (REST, MCP Gateway)

- Purpose: Conceptual API domains /health, /agents, /actions, /capabilities, /tools, /skills, /mcp, /files, /memory, /events, /evidence, /policies
- Inputs: UI requests, external requests (with auth)
- Outputs: Calls to Application Services
- Trust: Semi-trusted (validates input, enforces auth, but not authorization authority)
- Dependencies: Application Services, Identity/Auth
- May do: Input validation, auth check, rate limiting
- Must never do: Direct execution, bypass policy

### Application Services (Agents, Skills, Tools, Workflows)

- Purpose: Orchestrate agents, skills, tools, workflows
- Inputs: API requests, events
- Outputs: Action proposals to Policy Engine
- Trust: Semi-trusted (proposes, not authorizes)
- Dependencies: Core Runtime, Policy Engine
- May do: Plan, propose actions via Planner
- Must never do: Direct execution without Policy/Authorization

### Core Runtime (Bootstrap, Verification, Toolchain Detection)

- Purpose: OS detection, arch detection, package manager detection, environment abstraction, toolchain detection
- Inputs: Host OS info (/etc/os-release, uname, command -v)
- Outputs: Environment info, toolchain status
- Trust: Trusted (read-only detection)
- Dependencies: Host OS (read-only)
- May do: Detect, verify, produce evidence
- Must never do: Modify system files, install without Gate

### Policy Engine (Allowlist, Capability Registry, Risk)

- Purpose: Define what is allowed, capability model, risk, approval levels
- Inputs: Actor, Action, Capability, Resource, Scope, Risk, Environment, Context, Approval, Network state
- Outputs: Decision ALLOW, DENY, REQUIRE_APPROVAL, DRY_RUN, plus reason, plus evidence
- Trust: Trusted (defines policy)
- Dependencies: Configuration Service, Capability Registry
- May do: Evaluate policy, produce decision with evidence
- Must never do: Execute, bypass verification

### Authorization Layer (Actor, Action, Scope)

- Purpose: Enforce Policy decision, check identity, scope, approval
- Inputs: Policy decision, actor identity, approval
- Outputs: Authorized action or DENY/BLOCKED
- Trust: Trusted
- Dependencies: Policy Engine, Identity/Auth
- May do: Authorize, deny, require approval
- Must never do: Execute, forge evidence

### Execution Authority (Shell, Process, File, Browser, Network, Package Executors)

- Purpose: Execute only authorized actions via specific executors
- Inputs: Authorized action
- Outputs: Execution result, execution artifact, events
- Trust: Trusted (executes only via policy)
- Dependencies: Policy Engine, Authorization Layer, Services Layer
- May do: Execute via validated, allowlisted, structured actions, with resource limits, timeout, evidence
- Must never do: Execute unknown tool, unknown capability, bypass policy, use arbitrary sudo outside Gate, use eval with uncontrolled input, curl|bash executable

### Verification Engine (Logs, Evidence, Tests, Attestations, Audit)

- Purpose: Verify execution, produce evidence, not claims
- Inputs: Execution results, events, artifacts
- Outputs: Verification evidence, logs, audit events, test results
- Trust: Trusted (verifier, not authorizer)
- Dependencies: Execution Authority, Event Bus, Artifact Store, Evidence Store
- May do: Verify, produce evidence STATUS/RESULT/EVIDENCE/NEXT, run tests
- Must never do: Authorize, execute, fake PASS, infer production state from local tests

### Services Layer

Includes:

- Filesystem Service: FS_READ, FS_WRITE with capability CAP_FS_READ/WRITE, scope workspace/repository/project/user/host
- Process Service: PROCESS_READ, PROCESS_EXEC with CAP_PROCESS_*
- Network Service: NETWORK_READ, NETWORK_CONNECT with CAP_NETWORK_*, allowlist official sources only
- Memory Service: Ephemeral, Session, Project, User, System memory with ownership, retention, access policy
- Event Bus: action.proposed, validated, authorized, denied, started, completed, failed, verification.*, evidence.created with event_id, timestamp, actor, action, scope, result, correlation_id, no secrets
- Artifact Store: Source, Build, Execution, Evidence, User artifacts with owner, scope, hash, provenance, retention
- Evidence Store: verification evidence, audit
- Identity/Auth: User, Agent, Service, Tool, MCP Server, Execution Authority identities
- Configuration Service: non-sensitive config only, no secrets
- Observability: Logs (DEBUG), Metrics, Traces, Events, Audit, Evidence — distinguish DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE
- Plugin Registry: plugin provenance, trust classification, version pinning
- MCP Gateway: MCP Server Registry, trust classification, capability mapping, input/output validation, timeout, network policy, audit, isolation boundary

All services depend on Policy/Authorization for privileged operations.

## Dependency Direction

```
UI → API → Application Services → Core Runtime → Policy Engine → Authorization → Execution Authority → Verification Engine → Services Layer → Host OS
```

No cycles. No UI→Execution, no LLM→Execution directly.

## Interfaces

- UI ↔ API: REST, conceptual domains /health, /agents, etc.
- API ↔ Application Services: internal calls, with auth
- Application Services ↔ Core Runtime: detection info
- Application Services ↔ Policy Engine: action proposals
- Policy Engine ↔ Authorization: decisions
- Authorization ↔ Execution Authority: authorized actions
- Execution Authority ↔ Verification: execution results
- All ↔ Services Layer: via service interfaces, with policy checks

## Modularity

Each container replaceable via interfaces:

- LLM Provider: OpenAI, Anthropic, local
- Storage Provider: local file, SQLite, Postgres
- MCP Provider
- Browser Engine
- Execution Sandbox: Level 0 Gate → Level 6 OS integration
- Identity Provider
- Observability backend

Core vendor-neutral, free-first, self-hostable, local-capable.

## Low-Resource Mode

- CORE: minimal containers (Core Runtime, Policy, Execution Authority with Shell/File/Process, Verification, Filesystem, Event Bus, Artifact Store) — low memory
- STANDARD: CORE + Build Toolchain, PowerShell, basic agents, skills, MCP Gateway, Network Service (allowlisted), Memory Service, Identity, Config
- HEAVY: STANDARD + Browser, Computer, advanced sandboxing, heavier observability, optional cloud sync

## Open Decisions

- Programming Language for Core Runtime: PENDING
- Runtime implementation technology: PENDING
- Database: PENDING
- Event bus, Sandbox, UI framework, API framework, Browser engine, MCP transport, Deployment topology: all PENDING with criteria

See roadmap.md and ADRs.

## Diagrams

- System Context: context.md
- Runtime Layers: execution-model.md
- Action Execution: execution-model.md
- Trust Boundaries: security-boundaries.md
- Capability Flow: capability-model.md
- Event Flow: event-model.md
