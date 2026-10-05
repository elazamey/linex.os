# LINEX.OS — Architecture Frozen Baseline (P8)

> **Architecture Freeze — No implementation should violate documented baseline without an ADR.**

Architecture Freeze does NOT mean architecture immutable. Means: No implementation should violate baseline without ADR.

Timestamp: 2026-10-04T18:12:00Z
Branch: arena/01a107fc-linex-os
Commit: 768bf39
Foundation: P1-P7 PASS WITH KNOWN BLOCKER P4, Remote CI NOT VERIFIED (branch not pushed)

> The branch, commit, and remote-CI values above and below are historical provenance for the P8 freeze snapshot only. They do not describe the active session or current remote state; use `docs/reports/` for later measurements.

## Architectural Decisions — ACCEPTED

### ADR 0001 — LINEX.OS Scope

- Decision: Model C — Future hybrid: execution environment first, deeper OS integration later — ACCEPTED
- LINEX.OS in v1 is AI-native Execution Operating Environment above Linux, not kernel replacement
- Layers: Hardware → Host OS → LINEX.OS Substrate → Core Runtime → Policy/Authorization → Execution Authority → Verification/Evidence → Agents/Tools/Skills/MCP/Apps
- No kernel development in P8
- Status: ACCEPTED

### ADR 0002 — Execution Boundary

- Decision: Fixed path LLM→Planner→Policy→Authorization→Execution Authority→Verifier→Evidence — ACCEPTED
- Forbidden direct paths: LLM→shell, LLM→sudo, LLM→filesystem mutation directly, Agent→production DB directly, UI→privileged execution directly, MCP server→unrestricted host access — must be BLOCKED
- Execution Authority independent from AI: AI proposes, Policy decides, Execution executes, Verifier proves
- Status: ACCEPTED

### ADR 0003 — Capability Security Model

- Decision: Explicit capability model with Risk, Scope, Approval, Executor, Verifier, DEFAULT DENY, UNKNOWN→DENY, fail-closed — ACCEPTED
- Capabilities: CAP_FS_READ, CAP_FS_WRITE, CAP_PROCESS_READ/EXEC, CAP_NETWORK_READ/CONNECT, CAP_PACKAGE_INSTALL, CAP_BROWSER, CAP_COMPUTER, CAP_MCP, CAP_SECRET_ACCESS, each with Risk LOW/MEDIUM/HIGH/CRITICAL, Scope workspace/repository/project/user/host/network/production with explicit elevation, Approval AUTO/DRY_RUN/EXPLICIT_APPROVAL/DENY, Executor specific, Verifier evidence
- Resource scoping: workspace, repository, project, user, host, network, production, elevation explicit, Agent does not get host scope merely by getting workspace scope
- Status: ACCEPTED

### ADR 0004 — Policy vs Execution Separation

- Decision: AI Proposes → Policy Decides → Execution Executes → Verifier Proves, with separate components — ACCEPTED
- AI (Proposer): CLASS-0..3 AUTO, CLASS-4..5 Gate+EXPLICIT, CLASS-6 DENY
- Policy/Authorization (Decider): AGENTS.md, ARENA.md, privilege-policy.md, policy-check.sh, security.md, config/ non-sensitive, validation regex, no secrets, no /tmp inside repo, no *.deb inside repo
- Execution Authority (Gate): allowlist + structured actions + dry-run default + --execute explicit + evidence ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY, no arbitrary sudo, no eval, no bash -c "$INPUT", no curl|bash executable
- Verifier (Evidence Producer): bootstrap.sh, verify-environment.sh, doctor.sh, policy-check.sh, secret-scan.sh, static-security-check.sh, tests, PASS/VERIFIED/NOT VERIFIED/BLOCKED/SKIPPED, no PASS without evidence, no MOCK→PRODUCTION, no production claims without production evidence
- Workflow: INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT, no CHANGE before INSPECT, no REPORT PASS before VERIFY
- Status: ACCEPTED

### ADR 0005 — Storage Abstraction

- Decision: Storage abstraction with interfaces, no vendor chosen, local-first, optional remote, replaceable, vendor-neutral, free-first — ACCEPTED
- Interfaces: State Store (PROPOSED→VERIFIED lifecycle), Event Store (append-only immutable, event_id, timestamp, actor, action, scope, result, correlation_id, no secrets), Memory Store (Ephemeral Context, Session, Project, User, System with ownership, retention, access policy, encryption, deletion), Artifact Store (Source, Build, Execution, Evidence, User with owner, scope, hash SHA256, provenance, retention), Evidence Store (append-only immutable, no secrets, hash, provenance)
- For each: local must work offline, optional remote sync, replaceable vendor-neutral
- No vendor chosen in P8 to keep free-first, self-hostable, local-capable, no mandatory paid API/cloud DB
- Status: ACCEPTED

### ADR 0006 — Extensibility Model

- Decision: Modular, replaceable via interfaces/contracts, vendor-neutral, free-first, self-hostable, local-capable — ACCEPTED
- Replaceable modules: LLM Provider, Storage Provider, MCP Provider, Browser Engine, Execution Sandbox Level 0-6, Identity Provider, Observability Backend via interfaces
- Tool Contract: Tool ID, Version, Input/Output schema, Capability required, Risk class CLASS-0..6, Execution authority, Timeout, Resource limits, Evidence requirements, Unknown Tool→BLOCKED
- Skill model: Tool=executable capability, Skill=reusable higher-level procedure composing tools, Agent=decision/planning entity, Workflow=orchestrated sequence Agent→Skill→Tool→Execution→Verifier
- Plugin Registry: provenance, trust classification, version pinning full SHA, capability mapping, audit, no unbounded host access
- Supply chain: dependency/tool/plugin/MCP provenance, artifact hashes SHA256, version pinning full SHA for GitHub Actions (checkout v7.0.1 SHA 3d3c42e5aac5ba805825da76410c181273ba90b1), signature verification roadmap Level 0 no signing → Level 1 hash → Level 2 signature
- API boundary conceptual: /health, /agents, /actions, /capabilities, /tools, /skills, /mcp, /files, /memory, /events, /evidence, /policies — no implementation in P8
- UI boundary: client only, no sudo/shell policy/auth logic/secret execution, UI→API only
- Dependency direction fixed: UI→API→Application Services→Runtime→Policy/Authorization→Execution→Host/External, no cycles
- Free-first compatibility: vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB
- Low-resource mode: CORE (minimal), STANDARD (CORE+toolchain+agents+MCP), HEAVY (STANDARD+browser+computer+advanced sandbox), no GPU/K8s assumed
- Multi-tenancy readiness: User/Project/Workspace/Agent/Session separation, no global mutable state
- Status: ACCEPTED

## Non-goals — P8

- Not kernel replacement in v1 (per ADR 0001)
- Not product code, runtime implementation, UI/API/Agent/MCP/Database implementation
- Not package installation, PowerShell installation, Docker installation, production deployment, cloud provisioning, schema migration, infrastructure deployment
- Not choosing programming language, runtime tech, database, event bus, sandbox, UI framework, API framework, browser engine, MCP transport, deployment topology (all DECISION PENDING with criteria)
- Not implementing sandboxing Level 1-6 (only roadmap Level 0 Gate current)
- Not implementing signing system (only roadmap)
- Not implementing resource limits enforcement (only design)
- Not production ready, not fully complete, not cross-platform verified (PowerShell BLOCKED in Arena)

## Interfaces — Frozen

### Core Interfaces (Contracts, not implementation)

- State Store: CRUD for action states PROPOSED→VERIFIED, local/optional remote/replaceable
- Event Store: append-only immutable events with event_id, timestamp, actor, action, scope, result, correlation_id, no secrets, local/optional remote/replaceable
- Memory Store: Ephemeral, Session, Project, User, System with ownership, retention, access policy, encryption, deletion, local/optional remote/replaceable
- Artifact Store: Source, Build, Execution, Evidence, User with owner, scope, hash SHA256, provenance, retention, local/optional remote/replaceable
- Evidence Store: append-only immutable verification evidence, no secrets, hash, provenance, local/optional remote/replaceable
- LLM Provider: propose action, generate text, with context, memory, trust Untrusted, must go via Planner→Policy→Execution→Verifier
- Tool Runtime: Tool Contract with ID, Version, Input/Output schema, Capability required, Risk class, Execution authority, Timeout, Resource limits, Evidence, Unknown Tool→BLOCKED
- Execution Authority: executors Shell, Process, File, Browser, Computer, Network, Package with capability required, risk, resource limits, evidence, independent from AI
- Policy Engine: inputs Actor/Action/Capability/Resource/Scope/Risk/Env/Context/Approval/Network, decisions ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN, UNKNOWN→DENY, fail-closed
- Authorization Layer: checks identity, scope elevation explicit, approval, network trust
- Verification Engine: verifies execution, produces evidence STATUS/RESULT/EVIDENCE/NEXT, PASS/VERIFIED/NOT VERIFIED/BLOCKED/SKIPPED, no PASS without evidence, no MOCK→PRODUCTION, no production claims without production evidence
- MCP Gateway: registry, trust classification, capability mapping, input/output validation, timeout, network policy, audit, isolation boundary, no unbounded host access
- Filesystem Service: FS_READ/WRITE with CAP_FS_READ/WRITE, scope workspace/repository/project/user/host with host explicit, path traversal protection, no /etc/sudoers modification
- Process Service: PROCESS_READ/EXEC with CAP_PROCESS_*, allowlist structured actions, no arbitrary shell
- Network Service: NETWORK_READ/CONNECT with CAP_NETWORK_*, allowlist official sources only, network state AVAILABLE/PARTIALLY/BLOCKED, no auto redirect to random mirror/undocumented proxy/third-party/untrusted binary
- Identity/Auth: User, Agent, Service, Tool, MCP Server, Execution Authority separate identity/context, no ambiguous identity→DENY
- Configuration Service: non-sensitive config only, no secrets, versioning, provenance, validation
- Observability: Logs (DEBUG), Metrics, Traces, Events, Audit, Evidence (VERIFICATION), distinguish, no secrets, no mixing
- Plugin Registry: provenance, trust classification, version pinning full SHA, capability mapping, audit, no unbounded host access

All interfaces vendor-neutral, free-first, self-hostable, local-capable.

## Trust Boundaries — Frozen

- Critical path: LLM→Planner→Policy→Authorization→Execution Authority→Verifier→Evidence, forbidden direct paths BLOCKED (LLM→shell, LLM→sudo, LLM→filesystem mutation directly, Agent→production DB directly, UI→privileged execution directly, MCP server→unrestricted host access)
- System boundary: Inside LINEX.OS (Substrate, Core Runtime, Policy, Authorization, Execution Authority, Verification, Agent/Tool/Skill/MCP Gateway, Services), Outside (Hardware, Host OS, External APIs, Cloud, Production DB), Trusted (Policy Engine, Execution Authority, Verification Engine, Host OS kernel assumed but not modified, Substrate read-only), Semi-trusted (Agent Runtime, Tool Runtime, MCP Gateway, Configuration Service, UI/API client), Untrusted (LLM, User input, External APIs, MCP servers, Plugins, Browser/Computer executors)
- Sudo boundary: SYSTEM_SUDO_POLICY EXTERNAL / NOT CONTROLLED (NOPASSWD:ALL in Arena) vs PROJECT_POLICY CONTROLLED BY LINEX.OS (Gate), even if system NOPASSWD:ALL, project does NOT allow same, tested sudo whoami outside Gate→root, Gate→BLOCKED
- Capability boundaries: explicit CAP_*, default DENY, unknown→DENY, resource scoping workspace/repository/project/user/host/network/production with explicit elevation
- Network boundaries: Inbound (API with auth, rate limiting), Outbound (allowlist official sources only, no random mirror), Internal (Event Bus with auth), External (Internet via Network Service with policy), zones Trusted/Restricted/Untrusted, no Agent→Internet unrestricted without capability+policy, current Arena network github.com PASS, packages.microsoft.com BLOCKED, release-assets BLOCKED, deb.debian.org BLOCKED documented as known limitations
- Filesystem boundaries: workspace/repository/project/user/host with host explicit, forbidden /etc/sudoers modification CLASS-6 DENY, no /tmp inside repo, no *.deb inside repo, no credential files .env/*.key/*.pem
- Secret boundaries: forbidden commit/print/log secrets, echo env credentials, copy API keys to docs, put tokens into tests as literal full credential, log secret value, must use env vars/secret manager/platform secrets not log value, secret scanning repository-wide including tests/ and .github fail-closed smart filtering, tests needing secret-like text build at runtime from parts or use placeholder invalid
- Production boundaries: production claims forbidden without production evidence, LOCAL PASS≠PRODUCTION PASS, MOCK≠PRODUCTION, differentiate Implemented/Tested/Verified/Deployed/Production Verified, P0-P7 no production deployment
- Git boundaries: READ/INSPECT/MODIFY WORKTREE AUTO, commit/push/merge/tag/release EXPLICIT_APPROVAL per P1-P7 no auto commit/push, DENY push --force, reset --hard, clean -fd, branch deletion unless explicit very strong auth, current branch arena/01a107fc-linex-os local only main 768bf39 remote per no auto push decision not failure
- UI/API boundaries: UI client only no sudo/shell policy/auth logic/secret execution, UI→API only, API→Application Services→Runtime→Policy/Authorization→Execution→Host/External, no cycles, no UI→sudo, no LLM→shell
- MCP boundaries: MCP Gateway entry validates input, maps capability, enforces policy, audits, isolates, MCP Server Registry trust classification trusted/semi-trusted/untrusted, version pinning, provenance, capability mapping default DENY, input validation schema/size/timeout, output validation schema/no secrets/no destructive, network policy, audit events, isolation boundary no unbounded host access
- Test/Policy Boundary (P7 fix continuation, P8 formalized): secret scanning repository-wide including tests/ with smart filtering for detection patterns (regex with brackets) vs real secrets, no directory-wide exclusion tests/ as general security solution; for destructive patterns, dangerous commands in tests/ as non-executable fixtures (string arguments to Gate, inside run_test, inside grep pattern) allowed as non-executable fixtures testing BLOCKED behavior, but executable dangerous commands outside tests/ (lines starting with optional whitespace then rm -rf /, mkfs, eval, curl|bash as executable) BLOCKED, documented in static-security-check.sh header and security-boundaries.md

## Security Invariants — Frozen

- Unknown capability → DENY
- Unknown tool → DENY (BLOCKED)
- Unknown executor → DENY
- Missing authorization → DENY
- Missing evidence → UNVERIFIED (not PASS)
- Untrusted network → BLOCKED (if official source required, but allow alternative official sources)
- Invalid schema → DENY
- Ambiguous identity → DENY
- No secrets in repo, logs, evidence, events
- No destructive operation without explicit very strong auth (CLASS-6 DENY always)
- No production claims without production evidence
- No PASS without evidence, evidence model STATUS/RESULT/EVIDENCE/NEXT, ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY
- Fail-closed: UNKNOWN, UNSUPPORTED, MISSING_POLICY, MISSING_EVIDENCE, AMBIGUOUS_AUTHORIZATION, INVALID_ARGUMENT, NETWORK_UNVERIFIED → BLOCKED not ASSUME ALLOW
- Capability model explicit, default DENY, resource scoping explicit elevation
- Execution boundary fixed LLM→Planner→Policy→Authorization→Execution Authority→Verifier→Evidence, forbidden direct paths BLOCKED
- Sudo boundary SYSTEM_SUDO_POLICY EXTERNAL vs PROJECT_POLICY CONTROLLED preserved
- P4 BLOCKED preserved (PowerShell BLOCKED due to Arena network, not allowed to change to PASS without pwsh --version real execution verification evidence)
- Git safety: no force push unless explicit very strong auth, no auto commit/push in P1-P8
- Dependency direction fixed UI→API→Application Services→Runtime→Policy/Authorization→Execution→Host/External, no cycles
- Modularity: replaceable via interfaces, vendor-neutral, free-first, self-hostable, local-capable, low-resource mode CORE/STANDARD/HEAVY, no GPU/K8s assumed

## Open Decisions — DECISION PENDING with Criteria

- Programming Language for Core Runtime: PENDING, criteria portability, security, performance, ecosystem, team familiarity
- Runtime implementation technology: PENDING, criteria isolation, resource limits, portability, complexity
- Database for State Store, Event Store, Memory Store, Artifact Store, Evidence Store: PENDING, criteria local-first, replaceable, free-first, vendor-neutral, self-hostable, no mandatory paid API/cloud DB
- Event bus implementation: PENDING, criteria local-first, replaceable, no mandatory cloud
- Sandbox implementation Level 1-6: PENDING, criteria security, complexity, resource usage, portability
- UI framework: PENDING, criteria free-first, self-hostable, no mandatory SaaS
- API framework: PENDING, criteria vendor-neutral, local-capable
- Browser engine: PENDING, criteria isolation, resource limits, free-first
- MCP transport: PENDING, criteria security, portability
- Deployment topology: PENDING, criteria self-hostable, local-capable, cloud-compatible, low-resource mode CORE/STANDARD/HEAVY

No technologies chosen merely to fill gap. Use DECISION PENDING with criteria.

## Deferred Decisions

- Deeper OS integration Level 6: deferred to after execution environment stable, via ADR
- Signing system Level 1-2: deferred, only roadmap Level 0 no signing now
- Resource limits enforcement: deferred, only design in P8
- Secret Manager service: deferred, only policy and scanning in P7-P8
- Browser/Computer executors: deferred to HEAVY mode, not in CORE
- Production deployment, cloud provisioning, schema migration, infrastructure deployment: deferred, forbidden in P0-P8

## Non-goals — P8

- Not kernel replacement in v1
- Not product code, runtime implementation, UI/API/Agent/MCP/Database implementation
- Not package installation, PowerShell installation, Docker installation, production deployment, cloud provisioning, schema migration, infrastructure deployment
- Not choosing programming language, runtime tech, database, etc. (all PENDING)
- Not implementing sandboxing Level 1-6 (only roadmap)
- Not implementing signing system (only roadmap)
- Not implementing resource limits enforcement (only design)
- Not production ready, not fully complete, not cross-platform verified (PowerShell BLOCKED in Arena)

## Architecture Tests and Verification

- tests/architecture.test.sh: checks architecture docs exist, ADRs exist, trust boundary exists, capability model exists, fail-closed documented, AI/Policy/Execution separation exists, UI does not directly control privileged execution, LLM does not directly invoke shell, MCP has trust boundary, production distinction exists, P4 BLOCKED preserved, system vs project sudo distinction preserved, no contradictory architecture statements
- ops/verify/verify-architecture.sh: checks architectural invariants, no package install, no product code, repository-only
- Both must PASS for P8 COMPLETE

## P4 Blocker Preservation

P4 = BLOCKED preserved in P8, no attempt to install PowerShell, no package installation, repository-only.

Evidence:

- packages.microsoft.com → BLOCKED SSL_ERROR_SYSCALL 13.107.213.70:443
- release-assets.githubusercontent.com → BLOCKED SSL_ERROR_SYSCALL 185.199.111.133:443
- github.com → PASS 200 via E2B proxy
- api.github.com → PASS 200 v7.6.6
- deb.debian.org → BLOCKED

Official: PowerShell 7.6.6 LTS, Debian 12 supported until 2028-06-30
Sources: packages.microsoft.com and github.com/PowerShell/PowerShell only
No third-party, no snap, no unofficial mirror, no build from source
No Agent may change to PASS without pwsh --version real execution + smoke test + verification evidence

Preserved in README, operations, AGENTS, ARENA, install-pwsh.sh, architecture docs, frozen-baseline.

## Remote CI

REMOTE CI = NOT VERIFIED — branch arena/01a107fc-linex-os not pushed, main still at 768bf39, per P7/P8 spec no commit/push/merge, only document, no attempt to make Remote CI VERIFIED without remote run.

## System Changes

P8 repository-only, no apt, sudo, systemctl, user/group, firewall, disk, boot, PowerShell, Docker, package installation.

## Git

Branch arena/01a107fc-linex-os local only, main 768bf39 remote, per no auto push decision not failure, no push --force, no reset --hard, no clean -fd, no branch deletion, no history rewrite.

## References

- docs/architecture/context.md, container.md, components.md, execution-model.md, security-boundaries.md, capability-model.md, event-model.md, data-model.md, networking.md, extensibility.md, threat-model.md, roadmap.md
- ADRs 0001-0006
- AGENTS.md, ARENA.md, docs/security.md, docs/development.md, docs/operations.md, docs/agent-contract.md, privilege-policy.md
- GitHub Docs secure-use: permissions contents: read, pin to full SHA

---

**Architecture Freeze: YES**

**Status:** P8 Architecture Design frozen baseline — no implementation should violate baseline without ADR.

**Next:** P9 Core Runtime Contract (interfaces before implementation)
