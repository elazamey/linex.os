# LINEX.OS — Components (C4 Level 3) — P8

23 core components, each with Purpose, Inputs, Outputs, Trust, Dependencies, May Do, Must Never Do.

## 1. Core Runtime

- Purpose: OS detection, arch detection, package manager detection, environment abstraction, toolchain detection, bootstrap, verification
- Inputs: /etc/os-release, uname -m, uname -r, command -v checks, sudo -n true, df -h, free -h, curl -Is network checks
- Outputs: Environment info (OS, VERSION_ID, ARCH, PACKAGE_MANAGER, SUDO status, tools status), toolchain manifest, verification evidence
- Trust: Trusted (read-only detection)
- Dependencies: Host OS (read-only)
- May do: Detect, verify, produce evidence VERIFIED/NOT VERIFIED/BLOCKED/PASS, run bootstrap.sh, verify-environment.sh, doctor.sh
- Must never do: Modify /etc/sudoers, /etc/passwd, firewall, disk, boot, install without Gate, auto deploy, fake PASS

## 2. Agent Runtime

- Purpose: Provide governed runtime for AI agents, with identity, role, capabilities, context, memory, planner, tools, policies, evidence
- Inputs: User request, context, memory, policies, tool outputs, events
- Outputs: Action proposals (via Planner), not direct execution
- Trust: Semi-trusted (proposes, not authorizes)
- Dependencies: Core Runtime, Policy Engine, Tool Runtime, Memory Service, Event Bus
- May do: Propose actions via Planner, use tools via Tool Runtime with capability check, produce context
- Must never do: Direct execution without Policy/Authorization, bypass policy, expose secrets, modify sudoers, infer production state

## 3. Planner

- Purpose: Decision/planning entity, selects skills/tools, proposes actions
- Inputs: Agent context, memory, user request, tool outputs, events, policies
- Outputs: Action proposals with actor, action, capability, resource, scope, risk, justification
- Trust: Semi-trusted (proposes, not authorizes)
- Dependencies: Agent Runtime, Policy Engine (for capability check), Memory Service
- May do: Plan, propose, justify WHY/SOURCE/VERSION/LICENSE/RISK/ALTERNATIVES/REQUIRED_FOR for dependencies
- Must never do: Execute directly, bypass policy, use arbitrary shell, fake PASS

## 4. Policy Engine

- Purpose: Define what is allowed, capability model, risk, approval levels, allowlist, forbidden commands, fail-closed
- Inputs: Actor, Action, Capability, Resource, Scope, Risk, Environment, Context, Approval, Network state (from privilege-policy.md, AGENTS.md, ARENA.md, capability-model.md)
- Outputs: Decision ALLOW, DENY, REQUIRE_APPROVAL, DRY_RUN, plus reason, evidence, risk class CLASS-0..6
- Trust: Trusted
- Dependencies: Configuration Service, Capability Registry
- May do: Evaluate policy, produce decision with evidence, enforce DEFAULT DENY, UNKNOWN→BLOCKED
- Must never do: Execute, forge evidence, allow unknown capability, allow untrusted source without verification

## 5. Authorization Layer

- Purpose: Enforce Policy decision, check identity, scope, approval, network trust
- Inputs: Policy decision, actor identity (User, Agent, Service, Tool, MCP Server), approval (AUTO, DRY_RUN, EXPLICIT_APPROVAL, DENY), resource, scope
- Outputs: Authorized action or DENY/BLOCKED with reason, evidence
- Trust: Trusted
- Dependencies: Policy Engine, Identity/Auth
- May do: Authorize, deny, require approval, check scope elevation explicit, check network trust
- Must never do: Execute, bypass policy, allow ambiguous identity, allow missing evidence to become PASS

## 6. Capability Registry

- Purpose: Registry of capabilities CAP_FS_READ, CAP_FS_WRITE, CAP_PROCESS_READ, CAP_PROCESS_EXEC, CAP_NETWORK_READ, CAP_NETWORK_CONNECT, CAP_PACKAGE_INSTALL, CAP_BROWSER, CAP_COMPUTER, CAP_MCP, CAP_SECRET_ACCESS, etc., with Risk, Scope, Approval, Executor, Verifier
- Inputs: Capability definitions, risk classification, scope definitions
- Outputs: Capability info for Policy Engine
- Trust: Trusted
- Dependencies: Configuration Service
- May do: Register capabilities, define risk, scope, approval, executor, verifier
- Must never do: Allow unknown capability, allow capability elevation without explicit approval

## 7. Execution Authority

- Purpose: Independent from AI, executes only authorized actions via specific executors, with resource limits, timeout, evidence
- Inputs: Authorized action from Authorization Layer
- Outputs: Execution result, execution artifact, events (action.started, completed, failed), evidence
- Trust: Trusted (executes only via policy)
- Dependencies: Policy Engine, Authorization Layer, Services Layer (Filesystem, Process, Network, etc.)
- May do: Execute via validated, allowlisted, structured actions (e.g., package-install via Gate, fs-write via File Executor), with DRY-RUN default, --execute explicit, evidence ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP
- Must never do: Execute unknown tool, unknown capability, unknown executor, bypass policy, use arbitrary sudo outside Gate (sudo <input>, sudo bash/sh/env/-i/su, bash -c "$INPUT"), use eval with uncontrolled input, curl|bash executable, download unknown binaries, use untrusted mirrors, fake PASS, infer production state, auto deploy, force push, delete repo history, destroy data

## 8. Tool Runtime

- Purpose: Provide executable capabilities via Tool Contract (Tool ID, Version, Input schema, Output schema, Capability required, Risk class CLASS-0..6, Execution authority, Timeout, Resource limits, Evidence requirements)
- Inputs: Tool ID, inputs, capability check, authorization
- Outputs: Tool outputs via Execution Authority
- Trust: Semi-trusted (executes via Execution Authority)
- Dependencies: Execution Authority, Capability Registry, Policy Engine
- May do: Execute tools via Execution Authority with capability required, risk class, timeout, resource limits, evidence
- Must never do: Execute unknown tool (BLOCKED), bypass capability check, expose secrets

## 9. Skill Runtime

- Purpose: Reusable higher-level procedures that compose tools (e.g., "verify environment", "review PR", "bootstrap")
- Inputs: Skill ID, inputs, agent context
- Outputs: Sequence of tool calls via Tool Runtime
- Trust: Semi-trusted
- Dependencies: Tool Runtime, Agent Runtime
- May do: Compose tools, reusable procedures
- Must never do: Direct execution without Tool Runtime, bypass policy

## 10. MCP Gateway

- Purpose: Gateway for MCP (Model Context Protocol) servers, with registry, trust classification, capability mapping, input/output validation, timeout, network policy, audit, isolation boundary
- Inputs: MCP requests from Agents
- Outputs: Validated, authorized MCP calls to MCP servers, with audit events
- Trust: Semi-trusted (validates, isolates, but MCP servers may be untrusted)
- Dependencies: Policy Engine, Authorization Layer, Capability Registry, Network Service, Event Bus, Audit/Evidence Store
- May do: Register MCP servers, trust classification (trusted, semi-trusted, untrusted), capability mapping, input validation (schema, size, timeout), output validation (schema, no secrets, no destructive), audit, enforce isolation (no unbounded host access)
- Must never do: Grant MCP server unbounded host access, allow MCP to bypass policy, allow MCP to access secrets without CAP_SECRET_ACCESS + explicit approval

## 11. Filesystem Service

- Purpose: Filesystem operations with capability CAP_FS_READ, CAP_FS_WRITE, scopes workspace, repository, project, user, host, with path traversal protection
- Inputs: File path, operation (read, write, mkdir, etc.), capability, scope, actor
- Outputs: File content, evidence, events
- Trust: Trusted (if via Policy)
- Dependencies: Policy Engine, Authorization Layer, Execution Authority (File Executor)
- May do: Read/write within allowed scope, with validation (no /etc/sudoers modification, no /tmp inside repo as artifact unless outside repo, no *.deb inside repo)
- Must never do: Allow path traversal (../), allow host scope without explicit host capability, allow modification of /etc/sudoers, /etc/passwd, etc.

## 12. Process Service

- Purpose: Process operations with CAP_PROCESS_READ, CAP_PROCESS_EXEC, scope
- Inputs: Process command, capability, scope
- Outputs: Process result, evidence
- Trust: Trusted (if via Policy)
- Dependencies: Policy Engine, Authorization Layer, Execution Authority (Process Executor)
- May do: Spawn processes via validated, allowlisted actions, with resource limits, timeout
- Must never do: Allow arbitrary shell (eval $INPUT, bash -c "$INPUT"), allow sudo <arbitrary> outside Gate

## 13. Network Service

- Purpose: Network operations with CAP_NETWORK_READ, CAP_NETWORK_CONNECT, allowlist official sources only, network state AVAILABLE/PARTIALLY_AVAILABLE/BLOCKED
- Inputs: URL, domain, capability, scope, network state
- Outputs: Network response, evidence PASS/BLOCKED with curl -v output
- Trust: Trusted (if via Policy)
- Dependencies: Policy Engine, Authorization Layer, Execution Authority (Network Executor)
- May do: Fetch from official sources only (github.com PASS, packages.microsoft.com BLOCKED in Arena, deb.debian.org BLOCKED), document BLOCKED with evidence, no auto redirect to random mirror/undocumented proxy/third-party/untrusted binary
- Must never do: Allow Agent→Internet unrestricted without capability + policy, allow untrusted mirror, allow third-party PowerShell source

## 14. Memory Service

- Purpose: Memory with Ephemeral Context, Session Memory, Project Memory, User Memory, System Memory, with ownership, retention, access policy, encryption, deletion
- Inputs: Memory type, owner, content, access request
- Outputs: Memory content (if authorized), evidence
- Trust: Trusted
- Dependencies: Policy Engine, Authorization Layer, Identity/Auth, Storage abstraction (Memory Store)
- May do: Store memory with ownership, retention, access policy, encryption, deletion, scoped to User/Project/Workspace/Agent/Session
- Must never do: Allow global mutable state as primary design, allow cross-user access without explicit policy, store secrets without encryption, log secret value

## 15. Event Bus

- Purpose: Event-driven architecture with events action.proposed, validated, authorized, denied, started, completed, failed, verification.started, passed, failed, evidence.created, each with event_id, timestamp, actor, action, scope, result, correlation_id, no secrets
- Inputs: Events from all components
- Outputs: Events to subscribers (Verification Engine, Observability, Audit)
- Trust: Trusted
- Dependencies: Policy Engine (for event authorization), Identity/Auth
- May do: Publish events, subscribe, with correlation_id, no secrets
- Must never do: Lose events, allow event forgery without attestation, log secrets

## 16. Artifact Store

- Purpose: Store artifacts Source, Build, Execution, Evidence, User with owner, scope, hash (SHA256), provenance, retention
- Inputs: Artifact, owner, scope, provenance
- Outputs: Artifact with hash, evidence
- Trust: Trusted
- Dependencies: Policy Engine, Filesystem Service, Storage abstraction (Artifact Store)
- May do: Store artifacts with hash, provenance, retention, scoped, with evidence
- Must never do: Store secrets as artifacts without encryption, store temporary binaries inside repo (must be /tmp outside repo or deleted after smoke tests), store large generated artifacts without cleanup

## 17. Verification Engine

- Purpose: Verify execution, produce evidence, not claims, with logs, evidence, tests, outcomes, attestations, distinguishes SUCCEEDED vs VERIFIED, EXECUTED vs SAFE, LOCAL PASS vs PRODUCTION PASS, MOCK vs Real
- Inputs: Execution results, events, artifacts, test outputs
- Outputs: Verification evidence STATUS/RESULT/EVIDENCE/NEXT, with PASS/VERIFIED/NOT VERIFIED/BLOCKED/SKIPPED, no PASS without evidence
- Trust: Trusted (verifier, not authorizer)
- Dependencies: Execution Authority, Event Bus, Artifact Store, Evidence Store, Test runners
- May do: Verify, produce evidence, run tests (unit, static, integration, smoke, system, production evidence), distinguish Implemented/Tested/Verified/Deployed/Production Verified, no overclaim
- Must never do: Authorize, execute, fake PASS, infer production state from local tests (MOCK PASS→PRODUCTION PASS), claim deployed successfully without production evidence

## 18. Audit/Evidence Store

- Purpose: Store audit events and verification evidence, append-only, immutable, no secrets, with hash, provenance, retention
- Inputs: Audit events, evidence artifacts
- Outputs: Stored evidence with hash, queryable (with policy)
- Trust: Trusted
- Dependencies: Event Bus, Storage abstraction (Evidence Store)
- May do: Store audit, evidence, with hash, provenance, retention, no secrets
- Must never do: Allow evidence forgery without attestation, store secrets, allow deletion without policy

## 19. Identity/Auth

- Purpose: Identity boundaries for User, Agent, Service, Tool, MCP Server, Execution Authority, each with separate identity/context, with role, capabilities
- Inputs: Identity request, authentication (future)
- Outputs: Identity, role, capabilities, context
- Trust: Trusted
- Dependencies: Configuration Service, Policy Engine
- May do: Provide identity, role, capabilities, context, with separation (no shared mutable global)
- Must never do: Allow ambiguous identity → must DENY, allow agent impersonation without attestation

## 20. Configuration Service

- Purpose: Non-sensitive config only, no secrets, with versioning, provenance, validation
- Inputs: Config files in config/ (non-sensitive only)
- Outputs: Config with validation, evidence
- Trust: Semi-trusted (if compromised, affects policy, must be verified)
- Dependencies: Filesystem Service, Verification Engine
- May do: Provide config, with validation, no secrets
- Must never do: Store secrets, allow secret exposure, allow untrusted config without verification

## 21. User Interface/API

- Purpose: UI as client only, API as conceptual domains /health, /agents, /actions, /capabilities, /tools, /skills, /mcp, /files, /memory, /events, /evidence, /policies, with auth, input validation, rate limiting
- Inputs: User requests
- Outputs: API calls to Application Services
- Trust: Semi-trusted (client only, no privileged logic)
- Dependencies: API, Application Services, Identity/Auth
- May do: Display state, events, evidence, request approval for EXPLICIT_APPROVAL capabilities
- Must never do: Contain sudo logic, shell policy, authorization logic, secret execution, direct privileged execution (UI→API only, API→Runtime→Policy→Execution)

## 22. Observability

- Purpose: Logs (DEBUG LOG), Metrics, Traces, Events, Audit, Evidence (VERIFICATION EVIDENCE), distinguish DEBUG LOG vs AUDIT EVENT vs SECURITY EVENT vs VERIFICATION EVIDENCE, no secrets, no mixing
- Inputs: Events, execution results, verification evidence
- Outputs: Observability data with policy (who can read)
- Trust: Trusted
- Dependencies: Event Bus, Verification Engine, Audit/Evidence Store
- May do: Provide logs, metrics, traces, events, audit, evidence, with distinction, no secrets
- Must never do: Mix DEBUG LOG with AUDIT EVENT, log secrets, allow observability to bypass policy

## 23. Plugin Registry

- Purpose: Registry for plugins with provenance, trust classification, version pinning, signature verification roadmap, capability mapping
- Inputs: Plugin ID, version, provenance, trust classification
- Outputs: Plugin info for Policy Engine
- Trust: Semi-trusted (plugins may be untrusted, must be via registry)
- Dependencies: Policy Engine, Capability Registry, Artifact Store, Configuration Service
- May do: Register plugins, provenance, trust classification, version pinning, capability mapping, audit
- Must never do: Allow plugin with unbounded host access, allow plugin without provenance, allow plugin without capability mapping

## Dependency Direction

```
UI → API → Application Services → Core Runtime → Policy Engine → Authorization → Execution Authority → Verification Engine → Services Layer → Host OS
```

No cycles.

## Modularity

Each component replaceable via interfaces:

- LLM Provider: OpenAI, Anthropic, local, etc.
- Storage Provider: local file, SQLite, Postgres, etc.
- MCP Provider
- Browser Engine
- Execution Sandbox: Level 0 Gate → Level 6 OS integration
- Identity Provider
- Observability backend

Core vendor-neutral, free-first, self-hostable, local-capable.

## Low-Resource Mode

- CORE: Core Runtime, Policy Engine, Authorization, Execution Authority (Shell, File, Process), Verification Engine, Filesystem Service, Event Bus, Artifact Store, Evidence Store, Identity/Auth, Configuration Service, Observability minimal
- STANDARD: CORE + Build Toolchain, PowerShell, Agent Runtime, Planner, Tool Runtime, Skill Runtime, MCP Gateway, Network Service (allowlisted), Memory Service, Plugin Registry
- HEAVY: STANDARD + Browser Executor, Computer Executor, advanced sandboxing Level 4-6, heavier observability, optional cloud sync

No GPU or Kubernetes assumed.

## Open Decisions

- Programming Language: PENDING
- Runtime implementation technology: PENDING
- Database: PENDING
- Event bus, Sandbox, UI framework, API framework, Browser engine, MCP transport, Deployment topology: all PENDING

See roadmap.md and ADRs.

## Diagrams

- System Context: context.md
- Container: container.md
- Runtime Layers, Action Execution, Trust Boundaries, Capability Flow, Event Flow: execution-model.md, security-boundaries.md, capability-model.md, event-model.md
