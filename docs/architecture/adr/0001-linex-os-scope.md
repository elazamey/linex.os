# ADR 0001 — LINEX.OS Scope

## Context

LINEX.OS started as repository foundation (P1-P7) with bootstrap, privilege gate, toolchain, PowerShell logic (BLOCKED), repository foundation, agent contract, doctor aggregator, CI hardening. Need to define what LINEX.OS is in v1: Linux distribution / OS layer, AI-native execution environment above Linux, or future hybrid.

Foundation P1-P7 already implements execution environment above Linux (substrate, Gate, doctor, verification, no kernel). Building full Linux distribution / OS layer from scratch would be HIGH complexity, VERY LONG time-to-market, LOW portability, HIGH resource usage, HARD maintainability, but FULL hardware control. Execution environment above Linux is MEDIUM complexity, MEDIUM time-to-market, HIGH portability, LOW-MEDIUM resource, MEDIUM maintainability, LIMITED hardware control, HIGH cloud compatibility. Hybrid (execution environment first, deeper OS integration later) is MEDIUM now, HIGH later, FAST now, with path to deeper, HIGH future OS evolution, HIGH portability now.

Need to choose model for P8 architecture freeze.

## Decision

**Model C — Future hybrid: execution environment first, deeper OS integration later — ACCEPTED**

LINEX.OS in v1 is **AI-native Execution Operating Environment above Linux**, with roadmap to deeper OS integration (Level 0 Gate → Level 6 OS integration). Not kernel replacement in v1.

Layers:

```
Hardware
  ↓
Host OS (Linux / macOS / Windows - initial Linux)
  ↓
LINEX.OS Substrate (detection, abstraction, policy)
  ↓
Core Runtime
  ↓
Policy / Authorization
  ↓
Execution Authority
  ↓
Verification / Evidence
  ↓
Agents / Tools / Skills / MCP / Applications
```

This decision is ACCEPTED but revisable via ADR. No kernel development in P8.

## Alternatives

- **Model A: Linux distribution / OS layer** — Rejected for v1 due to HIGH complexity, VERY LONG time-to-market, LOW portability, HIGH resource, HARD maintainability, though FULL hardware control. Would require building distro, kernel modules, drivers, installer, hardware support. Not practical for P8.
- **Model B: AI-native execution environment above Linux only** — Considered, but LIMITED future OS evolution (stays above OS, not deeper). Model C preserves Model B benefits (MEDIUM complexity, HIGH portability, FAST time-to-market, free-first) and adds explicit roadmap to deeper OS integration without rebuilding from scratch, via replaceable Execution Sandbox interface.
- **Model C: Hybrid** — Chosen: execution environment first, deeper OS integration later. FAST now, with path to deeper, HIGH future OS evolution, HIGH portability now, LOW resource now scalable to HEAVY, vendor-neutral, self-hostable, local-capable, free-first.

## Consequences

- Positive:
  - Practical path to AI OS without building kernel from scratch now
  - Foundation P1-P7 already implements Model B, so Model C preserves existing work
  - Portability HIGH now (runs on Linux, macOS, Windows with abstraction, container-friendly)
  - Time-to-market FAST for execution environment, with path to deeper
  - Free-first, vendor-neutral, self-hostable, local-capable
  - Modularity: Execution Sandbox replaceable via interfaces Level 0-6
  - Future OS evolution HIGH — can evolve to deeper without rebuilding
  - Low-resource mode CORE/STANDARD/HEAVY possible
- Negative:
  - LIMITED hardware control in v1 (via host OS)
  - Need to maintain abstraction for future deeper integration (additional complexity later)
  - Must ensure architecture does not assume kernel replacement, but allows it later via ADR
- Neutral:
  - No product code in P8, only documentation, so decision is low-cost to revise via ADR if needed

## Status

ACCEPTED

## References

- docs/architecture/context.md (system context)
- docs/architecture/roadmap.md (P1-P7 foundation, P8 architecture, P9+ runtime)
- docs/architecture.md (overview, alternatives comparison)
- P7 doctor.sh (foundation PASS WITH KNOWN BLOCKER, P4 BLOCKED preserved)
