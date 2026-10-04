# LINEX.OS — Data Model (P8)

## State Model — Action Lifecycle

```
PROPOSED
  ↓
VALIDATING (Policy Engine validates actor, action, capability, resource, scope, risk, env, context, approval, network)
  ↓
AUTHORIZED / DENIED / REQUIRE_APPROVAL / DRY_RUN / BLOCKED
  ↓ (if AUTHORIZED)
EXECUTING (Execution Authority via executor)
  ↓
SUCCEEDED / FAILED / BLOCKED / CANCELLED
  ↓
VERIFIED / UNVERIFIED (Verification Engine)
```

### States

- PROPOSED: Agent proposes action via Planner
- VALIDATING: Policy Engine validates
- AUTHORIZED: Authorization Layer authorizes (ALLOW)
- DENIED: Policy denies (DENY)
- REQUIRE_APPROVAL: Requires explicit approval (EXPLICIT_APPROVAL)
- DRY_RUN: Shows WOULD EXECUTE, NOT EXECUTED (for risk)
- EXECUTING: Execution Authority executing
- SUCCEEDED: Execution succeeded (exit 0)
- FAILED: Execution failed (non-zero exit, timeout, etc.)
- VERIFIED: Verification Engine verified with evidence (PASS/VERIFIED)
- UNVERIFIED: Verification failed or evidence insufficient (NOT VERIFIED, BLOCKED)
- BLOCKED: Blocked due to policy missing, unknown capability, untrusted network, etc. (fail-closed)
- CANCELLED: Cancelled by user or system

Important distinctions:

- SUCCEEDED ≠ VERIFIED (execution may succeed but verification may fail)
- EXECUTED ≠ SAFE (execution may happen but be unsafe)
- LOCAL PASS ≠ PRODUCTION PASS (Arena sandbox PASS is REAL LOCAL TEST, not PRODUCTION EVIDENCE)
- MOCK PASS ≠ PRODUCTION PASS

## Memory Architecture

Split:

- Ephemeral Context: current turn, not persisted, short-lived, owned by Agent, retention turn, access Agent only, no encryption needed, deletion after turn
- Session Memory: current session, persisted for session, owned by Session, retention session, access Agent + User (if authorized), encryption optional, deletion after session
- Project Memory: project-specific, persisted in project (e.g., config/, docs/), owned by Project, retention project lifetime, access Project members with capability, encryption optional, deletion via policy
- User Memory: user-specific, persisted per user, owned by User, retention user-defined, access User only (or explicit shared), encryption at rest if sensitive, deletion via user request
- System Memory: system-wide for LINEX.OS itself, not user data, owned by System, retention system lifetime, access System only, encryption if needed, deletion via system policy

For each: ownership, retention, access policy, encryption, deletion.

No storage implementation in P8, only model. Interface: Memory Store (local, optional remote, replaceable).

## Artifact Model

Types:

- Source Artifact: code, docs, config (e.g., README.md, AGENTS.md, ops/security/privilege-gate.sh) — owner: project, scope: repository, hash SHA256, provenance: git commit, retention: permanent (via git)
- Build Artifact: compiled output, toolchain manifest (e.g., ops/linux/toolchain-manifest.txt) — owner: build system, scope: project, hash SHA256, provenance: build executor, retention: build lifetime or permanent if needed
- Execution Artifact: temporary files created during execution (e.g., test.c, test binary, /tmp/linex-os-powershell/*.deb) — owner: execution authority, scope: workspace or /tmp outside repo, hash optional, provenance: executor, retention: temporary, must be outside repo or deleted after smoke tests (per repository rules: no /tmp inside repo, no *.deb inside repo)
- Evidence Artifact: logs, verification-summary.txt, test logs, doctor output — owner: verification engine, scope: project, hash SHA256, provenance: verifier, retention: evidence retention policy, no secrets
- User Artifact: user-created files — owner: user, scope: user, hash SHA256, provenance: user, retention: user-defined

For each: owner, scope, hash, provenance, retention.

## Database / Storage Abstraction — No Vendor Chosen

Define interfaces, not vendors:

- State Store: stores action states (PROPOSED, VALIDATING, etc.), interface with CRUD, local (must work offline), optional remote sync, replaceable (local file, SQLite, Postgres, etc.)
- Event Store: stores events (append-only, immutable, queryable with policy, correlation_id), local, optional remote, replaceable
- Memory Store: stores memory (Ephemeral, Session, Project, User, System), local, optional remote, replaceable, with ownership, retention, access policy, encryption, deletion
- Artifact Store: stores artifacts (Source, Build, Execution, Evidence, User), local, optional remote, replaceable, with hash, provenance, retention
- Evidence Store: stores verification evidence (logs, attestations), append-only, immutable, no secrets, local, optional remote, replaceable

For each interface, define what is local (must work offline, no cloud), optional remote (can sync if configured), replaceable (vendor-neutral).

No vendor chosen in P8 to keep free-first, vendor-neutral, self-hostable, local-capable.

## Resource Limits — Design Only

On design level only, not implemented in P8:

- CPU: limit per execution (e.g., 1 core for CORE, more for HEAVY)
- Memory: limit per execution (e.g., 512MB CORE, 2GB STANDARD, more HEAVY)
- Disk: limit per artifact, per execution (e.g., 100MB per execution artifact)
- Process count: max processes per agent
- File descriptors: max FD per execution
- Network: bandwidth, domains allowlist, no unrestricted without capability
- Execution time: timeout per execution (e.g., 30s for simple, 300s for build)
- Output size: max log size, max artifact size (e.g., 10MB log)

No implementation now, only design. Future enforcement via Execution Authority with resource limits.

## Failure Model

- Policy Failure: policy missing, invalid, contradictory → BLOCKED
- Authorization Failure: not authorized, missing approval → DENY/BLOCKED
- Validation Failure: input schema invalid, resource not found → DENY
- Execution Failure: executor fails, process fails, timeout → FAILED
- Network Failure: network BLOCKED, timeout, DNS failure → BLOCKED or FAILED depending on essential
- Dependency Failure: dependency missing, not installed → NOT VERIFIED or BLOCKED
- Resource Failure: disk full, memory low, CPU high → BLOCKED
- Verification Failure: verification fails, evidence insufficient → UNVERIFIED

Each failure must not automatically become success. Fail-closed.

## Fail-Closed Architecture

- Unknown capability → DENY
- Unknown tool → DENY (BLOCKED)
- Unknown executor → DENY
- Missing authorization → DENY
- Missing evidence → UNVERIFIED (not PASS)
- Untrusted network → BLOCKED (if official source required, but allow alternative official sources)
- Invalid schema → DENY
- Ambiguous identity → DENY

## References

- execution-model.md (action lifecycle, execution authority)
- event-model.md (events)
- capability-model.md (capability, risk, scope, approval)
- security-boundaries.md (trust boundaries, secret boundaries)
