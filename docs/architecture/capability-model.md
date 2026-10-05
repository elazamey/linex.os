# LINEX.OS — Capability Model (P8)

## Capability Model — Explicit, Default DENY, Fail-Closed

Instead of "Agent has terminal", use explicit capabilities with Risk, Scope, Approval, Executor, Verifier.

DEFAULT: DENY. Unknown capability → DENY.

## Capability List

### Filesystem

- **CAP_FS_READ**
  - Risk: LOW
  - Scope: workspace (default), repository, project, user, host (host requires explicit)
  - Approval: AUTO (workspace), EXPLICIT_APPROVAL (host)
  - Executor: File Executor (Filesystem Service)
  - Verifier: File content hash, evidence, no secrets
  - May do: Read files within allowed scope, with path validation, no path traversal
  - Must never do: Read outside scope without explicit host capability, read secrets without CAP_SECRET_ACCESS

- **CAP_FS_WRITE**
  - Risk: MEDIUM (workspace), HIGH (host)
  - Scope: workspace, repository, project, user, host (host requires explicit very strong auth)
  - Approval: AUTO (workspace safe files), DRY_RUN (risky), EXPLICIT_APPROVAL (host, config, service)
  - Executor: File Executor
  - Verifier: File hash, evidence, no /tmp inside repo, no *.deb inside repo, no credential files
  - May do: Write safe files in allowed paths (ops/, docs/, config/ non-sensitive, tests/, scripts/, .github/workflows/)
  - Must never do: Modify /etc/sudoers, /etc/passwd, /etc/group, /etc/shadow, /etc/apt/sources.list without Gate, write .env, *.key, *.pem inside repo, write /tmp inside repo

### Process

- **CAP_PROCESS_READ**
  - Risk: LOW
  - Scope: workspace, project, user
  - Approval: AUTO
  - Executor: Process Executor (Process Service)
  - Verifier: Process list, evidence
  - May do: Read process list, is-active/status read-only
  - Must never do: Read outside scope without explicit

- **CAP_PROCESS_EXEC**
  - Risk: HIGH (if arbitrary), MEDIUM (if allowlisted structured action)
  - Scope: workspace, repository, project
  - Approval: AUTO (BUILD_TEST), DRY_RUN (PACKAGE_INSTALL, PRIVILEGED), EXPLICIT_APPROVAL (PRIVILEGED with --execute)
  - Executor: Process Executor, Shell Executor
  - Verifier: Exit code, output, evidence, no arbitrary shell (no eval $INPUT, no bash -c "$INPUT")
  - May do: Execute via validated, allowlisted, structured actions via Gate, with resource limits, timeout
  - Must never do: Execute arbitrary shell (sudo $USER_INPUT, eval $INPUT, bash -c "$INPUT"), use arbitrary sudo outside Gate, use curl|bash executable

### Network

- **CAP_NETWORK_READ**
  - Risk: LOW (if official source, read-only), MEDIUM (if untrusted)
  - Scope: network, specific domains
  - Approval: AUTO per network policy (if official source and network PASS), BLOCKED if network BLOCKED must be documented with evidence
  - Executor: Network Executor (Network Service)
  - Verifier: curl -Is, curl -v output, evidence PASS/BLOCKED
  - May do: Read from official sources only (github.com PASS, api.github.com PASS, packages.microsoft.com BLOCKED in Arena, deb.debian.org BLOCKED, release-assets BLOCKED) — document BLOCKED with evidence
  - Must never do: Auto redirect to random mirror, undocumented proxy, third-party download, untrusted binary

- **CAP_NETWORK_CONNECT**
  - Risk: MEDIUM (allowlisted domains), HIGH (unrestricted), CRITICAL (production)
  - Scope: network, specific domains, production
  - Approval: EXPLICIT_APPROVAL (for unrestricted, for production), AUTO (for allowlisted official)
  - Executor: Network Executor
  - Verifier: Network logs, evidence, no secrets
  - May do: Connect to allowlisted official domains via Network Service with policy
  - Must never do: Agent→Internet unrestricted without capability + policy, allow untrusted mirror

### Package

- **CAP_PACKAGE_INSTALL**
  - Risk: HIGH
  - Scope: host (requires explicit), project
  - Approval: EXPLICIT_APPROVAL (DRY_RUN first via Gate, then --execute explicit)
  - Executor: Package Executor (via privilege-gate.sh)
  - Verifier: dpkg-query -W, --version, evidence ACTION/CLASS/POLICY/DECISION/EXECUTION/EXIT_CODE/TIMESTAMP
  - May do: Install allowlisted packages via Gate: P2 ca-certificates curl wget git jq tar gzip zip unzip bash coreutils findutils grep sed gawk; P3 +gcc g++ make pkg-config build-essential; P4 +powershell packages-microsoft-prod powershell_7.6.6-1.deb_amd64.deb pattern (official only)
  - Must never do: Install unallowlisted package, install via arbitrary sudo outside Gate, use third-party PowerShell source, use snap, build from source (per P4 spec), apt upgrade/full-upgrade/dist-upgrade/autoremove as executable

### Browser / Computer

- **CAP_BROWSER**
  - Risk: HIGH
  - Scope: workspace, project, user, network (if browser needs network)
  - Approval: EXPLICIT_APPROVAL
  - Executor: Browser Executor (future)
  - Verifier: Browser logs, evidence, no secrets
  - May do: Browser automation via policy
  - Must never do: Unrestricted host access, bypass policy

- **CAP_COMPUTER**
  - Risk: HIGH
  - Scope: workspace, project, user, host (if computer needs host)
  - Approval: EXPLICIT_APPROVAL
  - Executor: Computer Executor (future)
  - Verifier: Computer logs, evidence
  - May do: Computer use via policy
  - Must never do: Unrestricted host access

### MCP

- **CAP_MCP**
  - Risk: MEDIUM (trusted MCP), HIGH (untrusted MCP)
  - Scope: workspace, project, network (if MCP needs network)
  - Approval: EXPLICIT_APPROVAL (for untrusted), AUTO (for trusted with capability mapping)
  - Executor: MCP Gateway
  - Verifier: MCP audit logs, input/output validation, no secrets, no destructive
  - May do: Call MCP servers via Gateway with trust classification, capability mapping, validation, timeout, network policy, audit, isolation
  - Must never do: Grant MCP server unbounded host access, allow MCP to bypass policy, allow MCP to access secrets without CAP_SECRET_ACCESS

### Secret

- **CAP_SECRET_ACCESS**
  - Risk: CRITICAL
  - Scope: project, user, production (production requires production auth + production evidence)
  - Approval: EXPLICIT_APPROVAL (always), with audit
  - Executor: Secret Manager (future) or env vars, not file inside repo
  - Verifier: Audit, no secret value logged, evidence without secret
  - May do: Access secrets via env vars, secret manager, platform secrets, with audit, not log secret value
  - Must never do: Commit/print/log secrets, echo env credentials, copy API keys to docs, put tokens into tests as literal full credential, log secret value

## Capability Flow Diagram

```
Agent (Identity, Role, Capabilities explicit)
  ↓ (requests capability)
Capability Registry (defines Risk, Scope, Approval, Executor, Verifier, DEFAULT DENY)
  ↓
Policy Engine (evaluates Actor, Action, Capability, Resource, Scope, Risk, Env, Context, Approval, Network)
  ↓ (decision ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN, UNKNOWN→DENY)
Authorization Layer (checks identity, scope elevation explicit, approval, network trust)
  ↓ (authorized)
Execution Authority (specific executor: File, Process, Network, Package, Browser, Computer, MCP Gateway)
  ↓
Verifier (produces evidence, no secrets, STATUS/RESULT/EVIDENCE/NEXT)
  ↓
Evidence Store / Audit
```

## Resource Scoping

- workspace: /home/user/linex.os, safe file operations, AUTO
- repository: git repo, .git, docs, ops, etc., AUTO for READ/INSPECT/MODIFY WORKTREE
- project: broader project including config/ non-sensitive, but not host, DRY_RUN for risk
- user: user home, not system, EXPLICIT_APPROVAL for write
- host: host OS, /etc, /usr, etc., EXPLICIT_APPROVAL very strong auth, even if SYSTEM_SUDO_POLICY NOPASSWD:ALL, PROJECT_POLICY DENY for arbitrary sudo
- network: outbound network, specific domains; no default network in the P1 MVP proposal, with any allowance to be decided through scoped ADR/policy
- production: production DB, production APIs, cloud production; outside the P1 MVP proposal and requires separate production authorization + production evidence

Agent does not get host scope merely by getting workspace scope. Capability elevation explicit.

## Approval Mapping (from AGENTS.md)

- READ_ONLY (CLASS-0) → AUTO
- SAFE_WORKSPACE (CLASS-1) → AUTO
- BUILD_TEST (CLASS-2) → AUTO
- NETWORK_READ (CLASS-3) → AUTO per network policy
- PACKAGE_INSTALL (CLASS-4) → EXPLICIT_APPROVAL (DRY_RUN first)
- PRIVILEGED_OPERATION (CLASS-5) → EXPLICIT_APPROVAL (explicit structured action + Gate)
- DESTRUCTIVE_OPERATION (CLASS-6) → DENY always
- PRODUCTION_DEPLOY → EXPLICIT_APPROVAL + production evidence

## Decision Matrix (from AGENTS.md)

| Operation | Agent Action | Gate | User Approval | Evidence |
|-----------|--------------|------|---------------|----------|
| Read file | ALLOW | NO | NO | YES |
| Write safe file in repo | ALLOW | NO | NO | YES |
| Run test | ALLOW | NO | NO | YES |
| Install approved package | PLAN/DRY-RUN | YES | EXPLICIT | YES |
| Modify sudoers | DENY | N/A | EXPLICIT SYSTEM ADMIN ONLY | YES |
| Reboot | DENY | N/A | N/A | YES |
| Deploy production | BLOCKED unless separately authorized | YES | EXPLICIT | YES |
| Arbitrary sudo | DENY via Gate (system may allow outside) | YES (BLOCKED) | DENY | YES |

## Fail-Closed

- Unknown capability → DENY
- Unknown tool → BLOCKED
- Unknown executor → DENY
- Missing authorization → DENY
- Missing evidence → UNVERIFIED
- Untrusted network → BLOCKED
- Invalid schema → DENY
- Ambiguous identity → DENY

## References

- AGENTS.md (Command Classification CLASS-0..6, Decision Matrix, Approval levels)
- ARENA.md (Privilege Rules, Approval Rules)
- docs/security.md (System vs Project privilege)
- ops/security/privilege-policy.md (5 levels, allowlist, fail-closed)
- security-boundaries.md (trust boundaries)
- execution-model.md (action lifecycle)
