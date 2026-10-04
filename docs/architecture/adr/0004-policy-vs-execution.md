# ADR 0004 — Policy vs Execution Separation

## Context

Foundation P1-P7 established architectural principle AI PROPOSES→POLICY/AUTHORIZATION DECIDES→EXECUTION AUTHORITY EXECUTES→VERIFIER PRODUCES EVIDENCE, with AI not Authorization Authority/Security Boundary/Verifier. AGENTS.md has Core Principles, Execution Rules, Security Rules, Privilege Rules, etc., ARENA.md has operating loop LOAD CONTRACT→STOP, docs/agent-contract.md has separation Policy vs Execution.

Need to formalize Policy vs Execution separation for P8 architecture freeze: Policy Engine defines what is allowed, Authorization Layer enforces, Execution Authority executes only authorized via executors, Verifier produces evidence.

Current Gate (privilege-gate.sh) is Level 0 Execution Authority with allowlist + structured actions + dry-run + evidence, but Policy is in privilege-policy.md, forbidden-commands.txt, AGENTS.md, ARENA.md. Need to ensure no bypass.

## Decision

**Policy vs Execution separation ACCEPTED:**

- **AI (Proposer):** Proposes actions, reads, plans, writes safe workspace changes, runs tests (read-only first). Allowed CLASS-0 READ_ONLY, CLASS-1 SAFE_WORKSPACE, CLASS-2 BUILD_TEST, CLASS-3 NETWORK_READ (official sources only, per network policy). Not allowed without Gate + explicit approval: CLASS-4 PACKAGE_INSTALL, CLASS-5 PRIVILEGED_OPERATION, CLASS-6 DESTRUCTIVE_OPERATION → always DENY.

- **Policy / Authorization (Decider):** Decides if proposed action is allowed, based on allowlist, validation, network policy, security rules, capability model, risk, scope, approval, environment, context. Artifacts: AGENTS.md (constitution), ARENA.md (Arena protocol), privilege-policy.md (5 levels, allowlist, fail-closed), policy-check.sh (checks forbidden patterns), security.md (System vs Project), config/ non-sensitive only. Policy checks: package name regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no forbidden tokens, service name strict, deb path validation, Microsoft repo URL constructed internally, no secrets, no /tmp inside repo, no *.deb inside repo.

- **Execution Authority (Gate):** Executes only allowlisted, validated actions, with DRY-RUN default, structured evidence. Artifact: privilege-gate.sh. Enforces no sudo <input>, no sudo bash/sh/env/-i/su, no bash -c "$INPUT", no sh -c "$INPUT", allowlist check P2/P3/P4, validation, DRY-RUN default WOULD EXECUTE NOT EXECUTED, only --execute explicit runs, fail-closed UNKNOWN→BLOCKED, structured evidence ACTION/CLASS/POLICY/DECISION/EXECUTION/WOULD EXECUTE/EXIT_CODE/TIMESTAMP/SYSTEM_SUDO/PROJECT_POLICY.

- **Verifier (Evidence Producer):** Produces evidence, does not allow. Artifacts: bootstrap.sh, verify-environment.sh, doctor.sh, policy-check.sh, secret-scan.sh, static-security-check.sh, tests. Outputs PASS/VERIFIED/NOT VERIFIED/BLOCKED/SKIPPED with evidence, never PASS without evidence, no MOCK PASS→PRODUCTION PASS, no production claims from local tests.

Workflow mandatory: INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT, no CHANGE before INSPECT, no REPORT PASS before VERIFY.

## Alternatives

- **Alternative 1: AI is Authorization Authority** — Rejected: AI may be prompt-injected, untrusted, must not be authorization authority. Policy must be separate, explicit, versioned, auditable.
- **Alternative 2: Policy and Execution in same component** — Rejected: Violates separation of concerns, if Policy compromised, Execution also compromised. Separation allows independent verification, audit, replaceability.
- **Alternative 3: Execution Authority as part of Policy Engine** — Rejected: Similar to Alternative 2, Policy should define, Execution should execute, not same. Execution Authority independent from AI and Policy, so even if Policy has bug, Execution still has allowlist and validation.
- **Alternative 4: Verifier as part of Execution Authority** — Rejected: Verifier must be independent, so that Execution cannot fake PASS. Verifier produces evidence, does not allow. AI is not Verifier.
- **Alternative 5 (Chosen): AI Proposes → Policy Decides → Execution Executes → Verifier Proves, with separate components, fail-closed, evidence, no bypass** — ACCEPTED: Clear separation, aligns with AGENTS.md Core Principles, ARENA.md operating loop, docs/agent-contract.md, security-boundaries.md, execution-model.md, capability-model.md.

## Consequences

- Positive:
  - Clear separation of concerns, least privilege, default DENY, fail-closed, audit, evidence, no secrets
  - Prevents policy bypass (fixed path, forbidden direct paths BLOCKED)
  - Prevents evidence forgery (Verifier independent, no PASS without evidence, no MOCK→PRODUCTION)
  - Enables modularity, replaceability (Policy Engine, Execution Authority, Verification Engine replaceable via interfaces)
  - Aligns with Foundation P1-P7 and P8 architecture
- Negative:
  - More components, more interfaces, additional latency, but necessary for security
  - Need to implement Policy Engine, Authorization Layer, Execution Authority executors, Verification Engine in P9+ (not in P8)
- Neutral:
  - No product code in P8, only documentation

## Status

ACCEPTED

## References

- docs/agent-contract.md (Policy vs Execution separation, with Gate workflow, allowlist, validation, evidence)
- AGENTS.md (Core Principles AI PROPOSES→POLICY→EXECUTION→VERIFIER, Execution Rules, Security Rules, Privilege Rules, Evidence Rules)
- ARENA.md (Arena operating loop LOAD CONTRACT→STOP, Privilege Rules, Approval Rules)
- docs/architecture/execution-model.md (primary execution model, trust boundary path)
- docs/architecture/security-boundaries.md (critical trust boundary, sudo boundary, forbidden paths)
- docs/architecture/components.md (Policy Engine, Authorization Layer, Execution Authority, Verification Engine with Purpose/Inputs/Outputs/Trust/Dependencies/May Do/Must Never Do)
- ops/security/privilege-policy.md (5 levels, allowlist, fail-closed, sudo distinction)
- ops/security/privilege-gate.sh (Gate as Execution Authority Level 0)
