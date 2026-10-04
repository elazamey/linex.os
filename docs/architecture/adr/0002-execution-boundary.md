# ADR 0002 — Execution Boundary

## Context

Need to define execution boundary: how agents execute actions, where trust lies, how to prevent LLM→shell direct, LLM→sudo direct, Agent→production DB direct, UI→privileged execution direct, MCP server→unrestricted host access.

Foundation P1-P7 already has privilege-gate.sh with allowlist + structured actions + dry-run + evidence, and AGENTS.md with CLASS-0..6 and Decision Matrix, and ARENA.md with operating loop LOAD CONTRACT→STOP. Need to formalize execution boundary for P8 architecture freeze.

Current Arena has SYSTEM_SUDO_POLICY EXTERNAL / NOT CONTROLLED (NOPASSWD:ALL) vs PROJECT_POLICY CONTROLLED BY LINEX.OS (Gate). Need to ensure execution authority is independent from AI.

## Decision

**Execution boundary fixed as:**

```
LLM (Untrusted)
  ↓ (proposes)
Planner (Semi-trusted, Agent Runtime)
  ↓ (action proposal: actor, action, capability, resource, scope, risk, justification)
Policy Engine (Trusted, DEFAULT DENY, UNKNOWN→DENY, fail-closed)
  ↓ (decision ALLOW/DENY/REQUIRE_APPROVAL/DRY_RUN)
Authorization Layer (Trusted, checks identity, scope, approval, network trust)
  ↓ (authorized)
Execution Authority (Trusted, independent from AI, executors Shell/Process/File/Browser/Computer/Network/Package)
  ↓ (execution result, artifact, events)
Verifier (Trusted, produces evidence, no PASS without evidence, no MOCK→PRODUCTION)
  ↓
Evidence Store / Audit (append-only, immutable, no secrets)
```

Forbidden direct paths must be BLOCKED:

- LLM → shell
- LLM → sudo
- LLM → filesystem mutation directly
- Agent → production database directly
- UI → privileged execution directly (UI→API only)
- MCP server → unrestricted host access (via MCP Gateway)

Execution Authority is independent from AI: AI proposes, Policy decides, Execution Authority executes, Verifier proves (AI PROPOSES→POLICY/AUTHORIZATION DECIDES→EXECUTION AUTHORITY EXECUTES→VERIFIER PRODUCES EVIDENCE, per AGENTS.md Core Principles).

## Alternatives

- **Alternative 1: LLM directly invokes shell** — Rejected: HIGH risk, prompt injection can lead to arbitrary execution, no policy check, violates fail-closed, violates capability model, violates trust boundary. Must be BLOCKED.
- **Alternative 2: Agent directly executes without Policy** — Rejected: Agent is semi-trusted, not authorization authority, not security boundary, not verifier. Direct execution bypasses allowlist, capability model, resource scoping, audit. Must go via Policy.
- **Alternative 3: UI directly controls privileged execution** — Rejected: UI is client only, must not contain sudo, shell policy, auth logic, secret execution. Must go UI→API→Runtime→Policy→Execution.
- **Alternative 4: Execution Authority as part of Agent Runtime** — Rejected: Execution Authority must be independent from AI, so that even if Agent is compromised, Execution Authority still enforces policy. Separation of concerns: AI proposes, Policy decides, Execution executes, Verifier proves.
- **Alternative 5 (Chosen): Fixed path with independent Execution Authority** — ACCEPTED: Clear separation, fail-closed, capability model explicit, default DENY, audit, evidence, no secrets, resource limits design, sandboxing roadmap Level 0-6.

## Consequences

- Positive:
  - Clear trust boundary, fail-closed, explicit capabilities, default DENY
  - Prevents prompt injection from leading to arbitrary shell (LLM untrusted, must go via Policy)
  - Prevents privilege escalation (SYSTEM_SUDO_POLICY EXTERNAL vs PROJECT_POLICY CONTROLLED, Gate blocks arbitrary sudo)
  - Allows audit, evidence, verification, no PASS without evidence
  - Enables future sandboxing Level 1-6 without changing core boundary (Execution Authority replaceable)
  - Aligns with AGENTS.md, ARENA.md, docs/agent-contract.md, docs/security.md
- Negative:
  - Additional latency (Planner→Policy→Authorization→Execution→Verifier) vs direct execution, but necessary for security
  - Need to implement Policy Engine, Authorization, Execution Authority executors, Verification Engine in P9+ (not in P8)
- Neutral:
  - No product code in P8, only documentation, so decision is low-cost

## Status

ACCEPTED

## References

- docs/architecture/execution-model.md (primary execution model, action lifecycle, DRY-RUN, approval levels)
- docs/architecture/security-boundaries.md (critical trust boundary, sudo boundary, forbidden paths)
- docs/architecture/capability-model.md (capability model, Decision Matrix)
- AGENTS.md (Core Principles AI PROPOSES→POLICY→EXECUTION→VERIFIER, Command Classification, Must NOT list)
- ARENA.md (operating loop, privilege rules)
- docs/agent-contract.md (Policy vs Execution separation)
- ops/security/privilege-policy.md (5 levels, allowlist, fail-closed)
- ops/security/privilege-gate.sh (Gate as Execution Authority Level 0)
