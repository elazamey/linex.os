# LINEX.OS — Vision

## What is LINEX.OS?

LINEX.OS is envisioned as an **Agent Operating System** — a disciplined runtime and governance layer for AI agents (like Arena) that need to execute real-world tasks on Linux and PowerShell environments safely, verifiably, and reproducibly.

It is not a traditional operating system kernel, nor a simple script collection. It is:

```
Repository Foundation
  +
Runtime Foundation (Linux + PowerShell)
  +
Agent Contract (how AI should behave inside the repo)
  +
Security Policy (allowlist + structured actions + fail-closed)
  +
Verification System (evidence-based)
  +
System Architecture (layers with enforced dependency direction)
  +
Product Runtime (future)
```

The active delivery plan is P0 Baseline Reconciliation → P1 MVP Definition + ADRs → P2 P9 Runtime
Core → P3 P11/P12 Policy + Capability → P4 P10 Execution Authority → P5 P13/P14 Vertical Slice
→ P6 CI + Security + Release, as recorded in `docs/architecture/roadmap.md`. The P1–P18 labels
elsewhere in this vision identify historical artifacts, not the active phase order. P1 must decide
language, storage, isolation boundary, execution model, evidence model, and failure semantics by ADR
before Runtime implementation.

**P1 MVP scope proposal (not frozen):** Linux, CLI, local process; Planner → structured actions;
Mock Authority first, then Safe Local Authority; fail-closed policy; explicit, scoped, expiring
capabilities; append-only execution evidence; no Agent → shell path. MCP, browser, GUI, default
network, and production deployment are outside this proposal unless P1 ADRs change scope.

## What Problem Does It Solve?

1. **Uncontrolled Agent Execution:** AI agents with `sudo NOPASSWD: ALL` can run `sudo <arbitrary-command>` outside any policy. LINEX.OS builds a **project privilege gate** as governance layer, so every privileged action must pass through allowlist + structured actions + dry-run default.

2. **Blind Installation:** Many agent setups do `curl | bash`, `apt upgrade`, install Docker/K8s/Rust/Go/Java/.NET/CUDA without justification, breaking the environment. LINEX.OS enforces `DETECT → VERIFY → PLAN MISSING → DRY-RUN → GATE → INSTALL ONLY APPROVED`.

3. **No Evidence:** Agents often claim PASS without evidence. LINEX.OS requires `VERIFIED / NOT VERIFIED / BLOCKED / PASS` with captured command outputs, version checks, test logs.

4. **Missing Developer Baseline:** Large projects need minimal reproducible build toolchain (gcc, g++, make, pkg-config, git, curl, jq, etc.) without assuming 100 tools. P3 defines minimal baseline.

5. **Cross-Platform Gap:** Linux and PowerShell scripts should both be verifiable. P4 aims for PowerShell 7 on Debian 12 via official Microsoft sources, with dual-path design (Microsoft repo primary, GitHub .deb fallback) when network allows.

6. **No Agent Contract:** `AGENTS.md`, `ARENA.md`, and `docs/agent-contract.md` now define when agents inspect, propose, request permission, and stop (P6).

## Long-Term Goal

- Become a **Developer OS** and **Agent Platform** that can:
  - Run as local or cloud agent infrastructure
  - Provide Kernel/Core, Runtime, Agent Layer, Tool Layer, Permission Layer, Memory, Filesystem, Networking, UI, API, Plugin/MCP, Package Manager, Observability, Security, Deployment
  - Support multiple agents with clear policy
  - Be extensible without becoming random

- The legacy P8 architecture record describes an **AI-native execution environment above the host OS** with a roadmap to deeper OS integration. P1 must review and reconcile that record through ADRs; it is not automatically the frozen MVP architecture.
- P1 ADRs decide the MVP implementation language and other required architecture choices. No application stack is assumed before those decisions; the proposed MVP remains Linux CLI/local-process until P1 accepts or revises it.

## What Is NOT in Scope Currently?

- **Before P1 decisions are accepted:** No Runtime implementation. P1 is MVP Definition + ADRs; P2+ work must stay within the accepted scope.
- **Proposed MVP exclusions (subject to P1 ADRs):** MCP, browser, GUI, default network, and production deployment. These are outside the proposal, not permanently frozen exclusions.
- **PowerShell:** No third-party source, snap, source build, or unofficial mirror — only official `packages.microsoft.com` and `github.com/PowerShell/PowerShell` sources.
- **Architecture:** The P8 freeze is a legacy record; P1 must explicitly review/reconcile it by ADR before Runtime work. Deployment is not authorized by this vision.
- **Security:** No modification of `/etc/sudoers`, `/etc/passwd`, firewall, disk, or boot without explicit authorization and the applicable security controls.

## Design Principles

### 1. AI proposes, Policy decides, Execution authority executes, Verifier proves

```
AI proposes
   ↓
Policy validates (allowlist + structured actions + fail-closed)
   ↓
Privilege Gate (dry-run default, --execute explicit)
   ↓
Execution (only approved, no arbitrary)
   ↓
Evidence / Result (structured, no secrets, with TIMESTAMP)
```

- AI never directly does `sudo <arbitrary>` via Gate
- Policy is explicit, reviewable, versioned in `ops/security/privilege-policy.md`
- Execution is via structured actions like `package-install <allowlisted-package>`, not `sudo "$USER_INPUT"`
- Verifier (doctor.sh, verify-environment.sh, tests) proves with evidence

### 2. INSPECT → PLAN → CHANGE → TEST → VERIFY → REPORT

Mandatory workflow for Arena:

- **INSPECT**: Read-only discovery (whoami, id, uname -a, /etc/os-release, command -v, sudo -n true, network)
- **PLAN**: Propose minimal changes, no blind installation, no Ubuntu assumption before reading /etc/os-release
- **CHANGE**: Only in allowed paths (ops/, docs/, config/, tests/, scripts/, .github/), no system file modification
- **TEST**: bash -n, shellcheck if available, run the relevant existing foundation tests (legacy P2/P3/P4 labels), no real install in tests (dry-run)
- **VERIFY**: Run verification scripts, doctor aggregators, evidence with VERIFIED/NOT VERIFIED/BLOCKED/PASS
- **REPORT**: STATUS, RESULT, EVIDENCE, CHANGED FILES, TESTS, BLOCKERS, NEXT — no PASS without evidence

### 3. Fail-Closed, Allowlist, Dry-Run Default

- **Fail-Closed:** Unknown action/package/invalid args/missing policy/malformed input → BLOCKED non-zero exit, not sudo <input>
- **Allowlist:** DEFAULT DENY, explicit list (P2: ca-certificates, curl, git, etc.; P3: +gcc, g++, make, pkg-config; P4: +powershell, packages-microsoft-prod)
- **Dry-Run Default:** `privilege-gate.sh` default is DRY-RUN, shows WOULD EXECUTE but NOT EXECUTED. Real execution needs explicit `--execute` flag, and even with --execute, unknown/invalid → BLOCKED

### 4. No Secrets, No Destructive, No Production Claims from Local

- No API keys, tokens, passwords, private credentials in repository
- No `rm -rf /`, `mkfs`, `dd`, `fdisk`, `shutdown`, `reboot`, `iptables -F`, `nft flush ruleset` — always BLOCKED in P2
- Local PASS ≠ Production PASS — tests in Arena sandbox prove logic, not production deployment
- No auto deployment, no `curl | bash`, no `wget | sh`, no `sudo sh -c`

### 5. Reproducibility and Minimalism

- Install only what is missing, not what already exists. In the P0 audit, gcc/g++/make were present and `pkg-config` was missing from the default PATH; a temporary source build under `/tmp` was used for tests only and did not install a system package (see `docs/reports/baseline-audit-a71643a.md`).
- Use explicit package mapping on Debian/apt (tool → package), no `apt-get install "$RAW_USER_INPUT"`
- Avoid `apt upgrade`, `full-upgrade`, `dist-upgrade` — only `apt-get install -y <specific-allowlisted-package>` via Gate
- Document `TOOL | COMMAND | PACKAGE | REQUIRED | STATUS | VERSION | NOTES` in toolchain-manifest.txt, only VERIFIED after actual command

### 6. Network Reality and Official Sources Only

- The P0 audit measured Debian apt mirrors (`deb.debian.org`) BLOCKED (Empty reply), while `github.com` and `api.github.com` were reachable. These are environment measurements, not timeless network guarantees.
- In that same audit, `packages.microsoft.com` and `release-assets.githubusercontent.com` were BLOCKED; PowerShell remained NOT VERIFIED. See `docs/reports/baseline-audit-a71643a.md`.
- Therefore P4 design has dual-path: Microsoft Repository primary, GitHub .deb official fallback, with integrity checks (dpkg-deb --info, size>0, Package=powershell Arch=amd64, checksum if available)
- No third-party source, no snap, no unofficial mirror, no binary from untrusted source — if both official paths BLOCKED, result is BLOCKED (not fake PASS)

### 7. Separation of Concerns: System vs Project

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - Measured in the P0 audit at `a71643a`: sudo NOPASSWD: ALL (environment-specific; recheck live)
  - System can do sudo <arbitrary> outside Gate → YES

LINEX_OS_PROJECT_POLICY: CONTROLLED BY PROJECT GATE
  - Project via Gate allows sudo <arbitrary> → NO
  - Only structured actions allowlisted
```

Gate is governance layer, NOT kernel-level sandbox. Real isolation needs container/user isolation later. This distinction is documented and tested (P2 tests prove `sudo whoami` outside Gate → root, inside Gate → BLOCKED).

### 8. Milestones, Not File Count

Measure project by milestones, not number of files:

- M0 Repository Ready: Git, README, AGENTS.md, ARENA.md, docs/, ops/, tests/, CI
- M1 Environment Ready: Linux, Bash, sudo, Git, PowerShell, verification
- M2 Developer Platform: bootstrap, doctor, cross-platform scripts, dependency management, CI
- M3 Security Foundation: privilege policy, command policy, audit logs, secret handling, fail-closed
- M4 Core Architecture: core, runtime, agents, tools, permissions, events
- M5 Product: any implementation must follow the active P0–P6 roadmap; no Runtime implementation before the required P1 ADR decisions are accepted.

Current phase and environment status are maintained in `docs/architecture/roadmap.md` and the latest commit-scoped report. At baseline commit `a71643a`, prior P1–P12 artifact labels were complete as recorded; those are historical status, not the active phase position.

---

## Vision for Arena

Arena Agent Mode is documented to build multi-step plans, use Bash inside sandbox, write files, test work, and GitHub integration. LINEX.OS makes Arena **executor of project** in disciplined way, not just code generator.

- Arena should be able to run `DISCOVER → PLAN → BOOTSTRAP → VERIFY → BUILD FOUNDATION → DESIGN → IMPLEMENT` without breaking environment
- Arena should know when to STOP and REPORT instead of blindly installing
- Arena should produce evidence, not claims

The agent operating contract was delivered under the legacy P6 label through `AGENTS.md`, `ARENA.md`, and `docs/agent-contract.md`; those rules govern the active P0–P6 work.

---

**Status:** Vision and project constraints are subject to the active P1 MVP ADRs; current phase and baseline measurements are delegated to `docs/architecture/roadmap.md` and commit-scoped reports. No Runtime implementation has started.

**Next:** Complete P0 reconciliation, then P1 MVP Definition + ADRs. The proposed MVP is not frozen, and Runtime implementation remains prohibited until the P1 decisions are accepted.
