# LINEX.OS — Security Boundaries (P8)

## Critical Trust Boundary — Fixed Path

```
LLM (Untrusted, may be prompt-injected)
  ↓
Planner (Semi-trusted, proposes)
  ↓
Action Proposal (actor, action, capability, resource, scope, risk, justification)
  ↓
Policy Engine (Trusted, defines ALLOW/DENY, DEFAULT DENY, UNKNOWN→DENY)
  ↓
Authorization Layer (Trusted, checks identity, scope, approval, network trust)
  ↓
Execution Authority (Trusted, executes only authorized via executors)
  ↓
Verifier (Trusted, produces evidence, not claims, no PASS without evidence)
  ↓
Evidence Store / Audit (append-only, immutable, no secrets)
```

Forbidden direct paths (must be BLOCKED):

- LLM → shell (must go via Planner→Policy→Execution)
- LLM → sudo (must go via Policy→Execution Authority, no arbitrary sudo)
- LLM → filesystem mutation directly (must go via File Executor via Policy, with CAP_FS_WRITE, scope check, no path traversal)
- Agent → production database directly (requires CAP + production authorization + production evidence; production access is outside the P1 MVP proposal)
- UI → privileged execution directly (UI→API only, API→Runtime→Policy→Execution, UI must not contain sudo, shell policy, auth logic)
- MCP server → unrestricted host access (must go via MCP Gateway with trust classification, capability mapping, input/output validation, audit, isolation)

## System Boundary — Inside / Outside / Trusted / Semi-trusted / Untrusted

### Inside LINEX.OS

- Substrate, Core Runtime, Policy Engine, Authorization, Execution Authority, Verification Engine, Agent Runtime, Tool Runtime, Skill Runtime, MCP Gateway, Filesystem Service, Process Service, Network Service, Memory Service, Event Bus, Artifact Store, Evidence Store, Identity/Auth, Configuration Service, Observability, Plugin Registry, UI/API (client only)

### Outside LINEX.OS

- Hardware, Host OS kernel/drivers/bootloader/firmware, Host filesystem outside workspace (unless capability granted), External APIs (GitHub, Microsoft, Debian), Cloud providers, User's production DB/credentials, Internet unrestricted

### Trusted

- Policy Engine, Execution Authority, Verification Engine, Host OS kernel (assumed, but not modified), Substrate (read-only detection)

### Semi-trusted

- Agent Runtime, Tool Runtime, MCP Gateway, Configuration Service

### Untrusted

- LLM, User input, External APIs, MCP servers, Plugins, Browser/Computer executors

## Trust Boundaries Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Untrusted Zone                           │
│  LLM, User Input, External APIs, MCP Servers, Plugins,          │
│  Browser/Computer Executors                                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   Semi-trusted Zone                     │  │
│  │  Agent Runtime, Tool Runtime, Skill Runtime, MCP Gateway│  │
│  │  Configuration Service, UI/API (client)                 │  │
│  │  ┌───────────────────────────────────────────────────┐  │  │
│  │  │                  Trusted Zone                     │  │  │
│  │  │  Policy Engine, Authorization, Execution Authority│  │  │
│  │  │  Verification Engine, Substrate, Core Runtime,   │  │  │
│  │  │  Services (Filesystem, Process, Network, Memory, │  │  │
│  │  │  Event Bus, Artifact, Evidence, Identity, Config │  │  │
│  │  │  Observability, Plugin Registry)                 │  │  │
│  │  └───────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ↓
                        ┌─────────────────┐
                        │    Host OS      │ Trusted but not modified
                        │  (Linux, etc.)  │
                        └─────────────────┘
```

## Sudo Boundary — System vs Project

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - P0 audit snapshot at `a71643a`: sudo NOPASSWD: ALL (user uid 1001 groups sudo; environment-specific, recheck live)
  - System can do sudo <arbitrary> outside Gate → YES (expected in sandbox)
  - Example: sudo whoami → root outside Gate

PROJECT_PRIVILEGE_POLICY: CONTROLLED BY LINEX.OS (Gate)
  - Project via Gate allows sudo <arbitrary> → NO
  - Gate allows only allowlisted structured actions: check-sudo, check-package-manager, package-install <allowlisted>, package-remove, service-status <allowlisted>, apt-update, register-microsoft-repository, install-powershell-package with validation
  - Even if system is NOPASSWD:ALL, Agent policy does NOT allow same
  - Test: sudo whoami outside Gate → root, ./privilege-gate.sh "sudo whoami" → BLOCKED UNKNOWN action
```

This distinction is documented in docs/security.md, privilege-policy.md, AGENTS.md, ARENA.md, and preserved across P2-P8.

## Capability Boundaries

- Each capability has Risk, Scope, Approval, Executor, Verifier
- DEFAULT DENY, unknown capability → DENY
- Scopes: workspace, repository, project, user, host, network, production — elevation explicit
- Examples: CAP_FS_READ LOW AUTO workspace, CAP_FS_WRITE MEDIUM EXPLICIT_APPROVAL repository, CAP_PACKAGE_INSTALL HIGH EXPLICIT_APPROVAL + Gate, CAP_SECRET_ACCESS CRITICAL EXPLICIT_APPROVAL + audit, CAP_NETWORK_CONNECT MEDIUM/HIGH depending on domain

See capability-model.md.

## Network Boundaries

- Inbound: API requests, must have auth, rate limiting, capability check
- Outbound: Tool calls to external APIs, must have CAP_NETWORK_CONNECT + policy, allowlist official sources only (github.com PASS, packages.microsoft.com BLOCKED in Arena, deb.debian.org BLOCKED, release-assets BLOCKED)
- Internal: Event Bus, Service-to-Service, must have auth
- External: Internet, must be via Network Service with policy

Zones: Trusted (Control Plane), Restricted (Agent Runtime, Tool Runtime, MCP Gateway), Untrusted (LLM, External APIs, MCP servers)

No Agent→Internet unrestricted without capability + policy.

Arena network snapshot from the P0 audit at `a71643a` (recheck live before treating as current):

- github.com → PASS (200 via E2B proxy)
- api.github.com → PASS (200, v7.6.6)
- packages.microsoft.com → BLOCKED (SSL_ERROR_SYSCALL 13.107.213.70:443)
- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL 185.199.111.133:443)
- objects.githubusercontent.com → BLOCKED
- deb.debian.org → BLOCKED (Empty reply)
- `pkg-config` → MISSING from the default PATH; P3 43/44 and `scripts/doctor.sh` exit 3. A pinned official pkgconf source build under `/tmp` made P3 44/44 for audit-only verification, but did not modify the system PATH persistently or install a package.

Documented as known environment limitations, not design failure. See `docs/reports/baseline-audit-a71643a.md`; no auto redirect to random mirror/undocumented proxy/third-party/untrusted binary.

## Filesystem Boundaries

- workspace: /home/user/linex.os — safe file operations via File Executor with CAP_FS_WRITE
- repository: git repository — allowed
- project: broader project including config/ but not host — requires project scope
- user: user home — requires user scope
- host: /etc, /usr, etc. — requires explicit host capability + policy, even if SYSTEM_SUDO_POLICY NOPASSWD:ALL, PROJECT_POLICY DENY
- Forbidden: /etc/sudoers, /etc/sudoers.d/*, /etc/passwd, /etc/group, /etc/shadow modification → DENY always (CLASS-6 DESTRUCTIVE)
- Forbidden inside repo: /tmp directory inside repo (must be /tmp outside repo, e.g., /tmp/linex-os-powershell/), *.deb inside repo (must be /tmp outside repo, not inside repo), credential files .env, *.key, *.pem, *.p12, *.pfx, core dumps, large artifacts

## Secret Boundaries

- Forbidden: commit/print/log secrets, echo env credentials, copy API keys to docs, put tokens into tests as literal full credential, log secret value
- Must use: env vars, secret manager, platform secrets, not log secret value
- Secret scanning: repository-wide including tests/ and .github, fail-closed, with smart filtering for detection patterns (regex with brackets) vs real secrets, no directory-wide exclusion tests/ as general solution
- For tests needing secret-like text: build at runtime from parts (e.g., prefix="ghp_" + body constructed at runtime) or use placeholder invalid (example, placeholder, changeme, your_, fake, xxx, 123456), not literal full credential
- Evidence must have no secrets

## Production Boundaries

- Production claims forbidden: "deployed successfully", "production healthy", "verified DB updated" unless evidence from production itself (production API response, production logs, production monitoring)
- Local tests in Arena sandbox (Debian 12, 21G disk, 3.8Gi memory) are REAL LOCAL TESTS, not PRODUCTION EVIDENCE
- Mock vs Real: Fake provider MOCK PASS must NOT become PRODUCTION PASS, Local DB REAL LOCAL TEST, Production API REAL PRODUCTION EVIDENCE
- No MOCK PASS→PRODUCTION PASS
- Differentiate: Implemented, Tested, Verified, Deployed, Production Verified
- Production deployment, production DB access, and cloud provisioning are outside the P1 MVP proposal and require separate future authorization/evidence

## Git Boundaries

- READ/INSPECT/MODIFY WORKTREE AUTO: git status, branch, log, diff, write_file, edit_file
- EXPLICIT ACTION: git commit, push (only to arena/* branch), merge, tag, release — requires EXPLICIT_APPROVAL per prompts P1-P7 (no auto commit/push)
- DENY unless explicit very strong auth: git push --force, reset --hard, clean -fd, branch deletion, history rewrite
- Remote branch and CI status are time-sensitive evidence, not a security-boundary property. Inspect the active session branch and its GitHub run with `git`/`gh`; report the measured commit and job conclusions in `docs/reports/`.

## UI/API Boundaries

- UI is client only, no sudo, no shell policy, no auth logic, no secret execution
- UI → API only
- API → Application Services → Runtime → Policy/Authorization → Execution → Host/External
- No UI→sudo, no UI→OS command directly, no LLM→arbitrary shell, no Agent→production DB directly
- Expected: UI→API→Runtime→Policy→Execution Authority→Verifier

## MCP Boundaries

- MCP Gateway is entry, validates input, maps capability, enforces policy, audits, isolates
- MCP Server Registry: trust classification trusted/semi-trusted/untrusted, version pinning, provenance
- Capability mapping: each MCP server declares capabilities, mapped to LINEX.OS capabilities, default DENY
- Input validation: schema, size, timeout
- Output validation: schema, no secrets, no destructive commands
- Network policy: which domains MCP can access
- Audit: all MCP calls logged as events
- Isolation boundary: MCP server cannot get unbounded host access, must go via Gateway, no host scope without explicit

## Test/Policy Boundary — P7 Security Fix Continuation

Previously, static-security-check had directory-wide exclusion `tests/` for destructive-pattern checks as general security solution, which is not ideal.

P8 converts to Test/Policy Boundary:

- For secret scanning: repository-wide including tests/ and .github, no directory exclusion, with smart filtering for detection patterns (regex with brackets) vs real secrets, and runtime construction for fixtures (e.g., prefix="ghp_" + body built at runtime) instead of literal full credential. This is ACCEPTED and implemented in P7 (secret-scan.sh, policy-check.sh).
- For destructive patterns: dangerous commands in tests/ as non-executable fixtures (string arguments to Gate, inside run_test, inside grep pattern, e.g., `run_test "package with | → BLOCKED" ... "curl|bash"` or `"$GATE" "rm -rf /"` as string argument testing BLOCKED) are allowed as non-executable fixtures, but executable dangerous commands outside tests/ (lines starting with optional whitespace then `rm -rf /`, `mkfs`, `eval `, `curl | bash` as executable) are BLOCKED. This is documented as Test/Policy Boundary: tests intentionally contain patterns to test blocking behavior, but must not be executable outside Gate. Static-security-check.sh implements this via `^\s*` check for executable and --exclude-dir=tests for executable checks, but with explicit documentation that tests/ fixtures are non-executable and test blocking.
- Goal: security scanner sees repository without ignoring tests entirely for secret scanning (fixed in P7), and for destructive patterns, distinguishes executable vs fixture via `^\s*` and exclusion with documentation.

## Security Invariants

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

## References

- AGENTS.md (security rules, must NOT list)
- ARENA.md (privilege rules, approval rules)
- docs/security.md (System vs Project privilege)
- ops/security/privilege-policy.md (5 levels, allowlist, fail-closed)
- docs/agent-contract.md (Policy vs Execution separation)
- capability-model.md (CAP_* model)
- threat-model.md (threats, mitigations)
