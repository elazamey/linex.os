# ADR 0005 — Storage Abstraction

## Context

Need to design storage for State, Events, Memory, Artifacts, Evidence without choosing vendor in P8, to keep free-first, vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB.

Foundation P1-P7 has filesystem organization docs/, config/, tests/, ops/, scripts/, .github, but no storage abstraction. Need to define interfaces for State Store, Event Store, Memory Store, Artifact Store, Evidence Store, with local/optional remote/replaceable.

Also need to define Memory architecture (Ephemeral Context, Session Memory, Project Memory, User Memory, System Memory) with ownership, retention, access policy, encryption, deletion, and Artifact model (Source, Build, Execution, Evidence, User) with owner, scope, hash, provenance, retention.

## Decision

**Storage abstraction with interfaces, no vendor chosen, local-first, optional remote, replaceable, vendor-neutral, free-first — ACCEPTED**

Interfaces:

- **State Store:** stores action states PROPOSED, VALIDATING, AUTHORIZED, DENIED, REQUIRE_APPROVAL, DRY_RUN, EXECUTING, SUCCEEDED, FAILED, VERIFIED, UNVERIFIED, BLOCKED, CANCELLED. Interface with CRUD, local (must work offline, local file or SQLite), optional remote sync (future), replaceable (local file, SQLite, Postgres, etc.)
- **Event Store:** stores events action.proposed, validated, authorized, denied, started, completed, failed, verification.started, passed, failed, evidence.created with event_id, timestamp, actor, action, scope, result, correlation_id, no secrets. Append-only, immutable, queryable with policy, correlation_id, local, optional remote, replaceable.
- **Memory Store:** stores memory Ephemeral Context (current turn, not persisted, short-lived), Session Memory (current session, persisted for session), Project Memory (project-specific, persisted in project), User Memory (user-specific, persisted per user), System Memory (system-wide for LINEX.OS). For each: ownership, retention, access policy, encryption, deletion. Local, optional remote, replaceable.
- **Artifact Store:** stores artifacts Source (code, docs, config), Build (compiled output, toolchain manifest), Execution (temporary files, must be outside repo or deleted after smoke tests, e.g., test.c, test binary, /tmp/linex-os-powershell/*.deb), Evidence (logs, verification-summary.txt, test logs, doctor output, no secrets), User (user-created). For each: owner, scope, hash SHA256, provenance (who created, when, how), retention. Local, optional remote, replaceable.
- **Evidence Store:** stores verification evidence logs, attestations, audit, append-only, immutable, no secrets, with hash, provenance, retention, local, optional remote, replaceable.

For each interface, define what is local (must work offline, no cloud), optional remote (can sync if configured), replaceable (vendor-neutral, interface-based, not tied to specific DB).

No vendor chosen in P8 to keep free-first, vendor-neutral, self-hostable, local-capable, no assumption of paid API, cloud database, paid observability, mandatory SaaS.

## Alternatives

- **Alternative 1: Choose specific vendor now (e.g., Postgres for State Store, Redis for Event Bus, S3 for Artifact Store)** — Rejected for P8: Would tie architecture to specific vendor, not free-first, not self-hostable, not local-capable, requires cloud, paid, not vendor-neutral, hard to replace later. Must be interface-based, not vendor-based, in P8.
- **Alternative 2: Single global mutable state** — Rejected: Violates multi-tenancy readiness (User, Project, Workspace, Agent, Session separation), violates no global mutable state as primary design, hard to scale, hard to isolate, security risk.
- **Alternative 3: No storage abstraction, direct filesystem only** — Considered for P1-P7 (current foundation uses filesystem directly docs/, config/, etc.), but for future need abstraction for State, Events, Memory, Artifacts, Evidence with ownership, retention, access policy, encryption, deletion, hash, provenance. Direct filesystem only not sufficient for future.
- **Alternative 4 (Chosen): Interfaces with local/optional remote/replaceable, no vendor chosen, free-first, vendor-neutral, self-hostable, local-capable** — ACCEPTED: Local-first (must work offline), optional remote (can sync if configured), replaceable (vendor-neutral), free-first, no mandatory paid services, aligns with P8 low-resource mode CORE/STANDARD/HEAVY, no GPU/K8s assumed, modularity replaceable.

## Consequences

- Positive:
  - Free-first, vendor-neutral, self-hostable, local-capable, no mandatory paid API/cloud DB
  - Local-first (must work offline), optional remote, replaceable
  - Modularity: Storage Provider replaceable via interfaces
  - Supports multi-tenancy readiness (User, Project, Workspace, Agent, Session separation, no global mutable state)
  - Supports memory architecture with ownership, retention, access policy, encryption, deletion
  - Supports artifact model with owner, scope, hash, provenance, retention
  - Supports event model append-only immutable, no secrets
  - Aligns with P8 architecture, roadmap, low-resource mode
- Negative:
  - More abstraction, more interfaces, need to implement in P9+ (not in P8)
  - Need to define criteria for choosing vendor later (DECISION PENDING with criteria, not chosen now to avoid filling gap)
- Neutral:
  - No product code in P8, only documentation

## Status

ACCEPTED

## References

- docs/architecture/data-model.md (state model, memory architecture, artifact model, storage abstraction, resource limits, failure model, fail-closed)
- docs/architecture/event-model.md (event model, Event Store)
- docs/architecture/components.md (Memory Service, Event Bus, Artifact Store, Evidence Store, Audit/Evidence Store)
- docs/architecture/roadmap.md (P9+ storage implementation, open decisions)
- docs/architecture/extensibility.md (Storage Provider replaceable, free-first compatibility)
- AGENTS.md (Evidence Rules, Secrets Rules)
- ARENA.md (Workspace Boundaries, Repository Boundaries)
