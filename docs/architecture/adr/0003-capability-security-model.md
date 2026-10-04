# ADR 0003 — Capability Security Model

## Context

Need to design capability model instead of "Agent has terminal" broad permission. Foundation P1-P7 has Command Classification CLASS-0 READ_ONLY to CLASS-6 DESTRUCTIVE DENY, Decision Matrix Operation|Agent Action|Gate|User Approval|Evidence, Approval levels AUTO/DRY_RUN/EXPLICIT_APPROVAL/DENY, but not yet explicit CAP_* model with Risk, Scope, Approval, Executor, Verifier.

Also need resource scoping: workspace, repository, project, user, host, network, production, with explicit elevation.

Need to ensure DEFAULT DENY, UNKNOWN→DENY, fail-closed, no secrets, no production claims without production evidence.

## Decision

**Capability model explicit, default DENY, fail-closed, with Risk, Scope, Approval, Executor, Verifier:**

Capabilities:

- CAP_FS_READ (LOW, workspace/repository/project/user/host with host explicit, AUTO, File Executor)
- CAP_FS_WRITE (MEDIUM workspace, HIGH host, AUTO safe files, DRY_RUN risky, EXPLICIT_APPROVAL host/config/service, File Executor)
- CAP_PROCESS_READ (LOW, workspace/project/user, AUTO, Process Executor)
- CAP_PROCESS_EXEC (HIGH if arbitrary, MEDIUM if allowlisted structured action, workspace/repository/project, AUTO BUILD_TEST, DRY_RUN PACKAGE_INSTALL/PRIVILEGED, EXPLICIT_APPROVAL PRIVILEGED with --execute, Process/Shell Executor)
- CAP_NETWORK_READ (LOW official allowlisted read-only, MEDIUM untrusted, AUTO per network policy, Network Executor, allowlist official sources only github.com PASS, packages.microsoft.com BLOCKED in Arena)
- CAP_NETWORK_CONNECT (MEDIUM allowlisted domains, HIGH unrestricted, CRITICAL production, EXPLICIT_APPROVAL unrestricted/production, Network Executor)
- CAP_PACKAGE_INSTALL (HIGH, host/project, EXPLICIT_APPROVAL DRY_RUN first via Gate then --execute explicit, Package Executor via privilege-gate.sh, allowlist P2/P3/P4 official only)
- CAP_BROWSER (HIGH, workspace/project/user/network, EXPLICIT_APPROVAL, Browser Executor future)
- CAP_COMPUTER (HIGH, workspace/project/user/host, EXPLICIT_APPROVAL, Computer Executor future)
- CAP_MCP (MEDIUM trusted MCP, HIGH untrusted MCP, workspace/project/network, EXPLICIT_APPROVAL untrusted, AUTO trusted with capability mapping, MCP Gateway)
- CAP_SECRET_ACCESS (CRITICAL, project/user/production, EXPLICIT_APPROVAL always with audit, Secret Manager future, env vars, not file inside repo, not log secret value)

Each capability has Risk, Scope, Approval, Executor, Verifier.

DEFAULT: DENY. Unknown capability → DENY.

Resource scoping: workspace, repository, project, user, host, network, production, with explicit elevation (Agent does not get host scope merely by getting workspace scope).

## Alternatives

- **Alternative 1: Broad permissions like "Agent has terminal"** — Rejected: Violates principle of least privilege, HIGH risk, no scoping, no approval levels, no audit, allows privilege escalation, secret exfiltration, production DB access without explicit. Must be BLOCKED.
- **Alternative 2: Role-based access control (RBAC) only** — Considered, but RBAC alone not sufficient for fine-grained capabilities like FS_READ vs FS_WRITE vs PACKAGE_INSTALL vs SECRET_ACCESS with different risk, scope, approval. Capability model more explicit, complements RBAC (Role has Capabilities).
- **Alternative 3: Access control lists (ACL) only** — Considered, but ACL per resource not sufficient for action-based capabilities like PROCESS_EXEC vs NETWORK_CONNECT. Capability model better for execution authority.
- **Alternative 4 (Chosen): Explicit capability model with Risk, Scope, Approval, Executor, Verifier, DEFAULT DENY, fail-closed** — ACCEPTED: Explicit, least privilege, default DENY, unknown→DENY, resource scoping explicit elevation, approval levels AUTO/DRY_RUN/EXPLICIT_APPROVAL/DENY, aligns with AGENTS.md CLASS-0..6 and Decision Matrix, enables audit, evidence, verification, no secrets, no production claims without evidence, future sandboxing Level 1-6 can enforce capability via isolation.

## Consequences

- Positive:
  - Least privilege, explicit, default DENY, fail-closed, unknown→DENY
  - Prevents privilege escalation (host scope requires explicit very strong auth, even if SYSTEM_SUDO_POLICY NOPASSWD:ALL, PROJECT_POLICY DENY for arbitrary sudo)
  - Prevents secret exfiltration (CAP_SECRET_ACCESS CRITICAL, EXPLICIT_APPROVAL always, audit, no log secret value)
  - Prevents production DB access without explicit production capability + production auth + production evidence
  - Enables audit, evidence, verification, resource limits, sandboxing roadmap
  - Aligns with AGENTS.md, ARENA.md, privilege-policy.md, security-boundaries.md, execution-model.md
  - Free-first, vendor-neutral, self-hostable, local-capable
- Negative:
  - More complex than broad permissions, need to define and maintain capability registry, need to check capability for each action (additional latency, but necessary for security)
  - Need to implement Capability Registry, Policy Engine, Authorization Layer in P9+ (not in P8)
- Neutral:
  - No product code in P8, only documentation, so decision low-cost

## Status

ACCEPTED

## References

- docs/architecture/capability-model.md (full capability list with Risk, Scope, Approval, Executor, Verifier, flow diagram, Decision Matrix, approval mapping)
- docs/architecture/security-boundaries.md (capability boundaries, filesystem boundaries, network boundaries, secret boundaries, production boundaries)
- docs/architecture/execution-model.md (approval levels, resource scoping, DRY-RUN)
- AGENTS.md (Command Classification CLASS-0..6, Decision Matrix, Approval levels, Must NOT list)
- ARENA.md (Privilege Rules, Approval Rules)
- ops/security/privilege-policy.md (5 levels, allowlist, fail-closed, sudo distinction)
- docs/agent-contract.md (Policy vs Execution separation)
