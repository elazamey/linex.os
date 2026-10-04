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

Current phase (P5) is **Repository Foundation** — transforming an empty repository into a project with clear engineering contract, documentation, testing, CI, and configuration foundations, without product implementation.

## What Problem Does It Solve?

1. **Uncontrolled Agent Execution:** AI agents with `sudo NOPASSWD: ALL` can run `sudo <arbitrary-command>` outside any policy. LINEX.OS builds a **project privilege gate** as governance layer, so every privileged action must pass through allowlist + structured actions + dry-run default.

2. **Blind Installation:** Many agent setups do `curl | bash`, `apt upgrade`, install Docker/K8s/Rust/Go/Java/.NET/CUDA without justification, breaking the environment. LINEX.OS enforces `DETECT → VERIFY → PLAN MISSING → DRY-RUN → GATE → INSTALL ONLY APPROVED`.

3. **No Evidence:** Agents often claim PASS without evidence. LINEX.OS requires `VERIFIED / NOT VERIFIED / BLOCKED / PASS` with captured command outputs, version checks, test logs.

4. **Missing Developer Baseline:** Large projects need minimal reproducible build toolchain (gcc, g++, make, pkg-config, git, curl, jq, etc.) without assuming 100 tools. P3 defines minimal baseline.

5. **Cross-Platform Gap:** Linux and PowerShell scripts should both be verifiable. P4 aims for PowerShell 7 on Debian 12 via official Microsoft sources, with dual-path design (Microsoft repo primary, GitHub .deb fallback) when network allows.

6. **No Agent Contract:** Without `AGENTS.md` and `ARENA.md`, agents don't know when to inspect, propose, request permission, and stop. P6 will define this.

## Long-Term Goal

- Become a **Developer OS** and **Agent Platform** that can:
  - Run as local or cloud agent infrastructure
  - Provide Kernel/Core, Runtime, Agent Layer, Tool Layer, Permission Layer, Memory, Filesystem, Networking, UI, API, Plugin/MCP, Package Manager, Observability, Security, Deployment
  - Support multiple agents with clear policy
  - Be extensible without becoming random

- Potential identities (to be decided in P8 Architecture, not now):
  - Operating System (for agents)
  - Agent OS
  - Developer OS
  - AI Agent Platform
  - Automation Runtime
  - Cloud/Local Agent Infrastructure
  - Or hybrid

- The key is that **architecture decision comes after foundation**, not before. We don't pick React/Next/Python/Rust/.NET stack now. We build foundation that can support any stack later with justification.

## What Is NOT in Scope Currently?

- **P0-P5:** No product code, no application framework, no Docker/K8s/Rust/Go/Java/.NET/Android SDK/CUDA (unless architecture proves need later)
- **P4:** No third-party PowerShell source, no snap, no building PowerShell from source, no unofficial mirror — only `packages.microsoft.com` and `github.com/PowerShell/PowerShell` official
- **P5:** No AGENTS.md/ARENA.md (P6), no product architecture implementation (P8), no deployment
- **Security:** No modification of `/etc/sudoers`, `/etc/passwd`, firewall, disk, boot — repository-only in P2-P5

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
- **TEST**: bash -n, shellcheck if available, run P2/P3/P4 tests, no real install in tests (dry-run)
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

- Install only what is missing, not what already exists (P3: gcc/g++/make already VERIFIED via dpkg, so no install; only pkg-config missing)
- Use explicit package mapping on Debian/apt (tool → package), no `apt-get install "$RAW_USER_INPUT"`
- Avoid `apt upgrade`, `full-upgrade`, `dist-upgrade` — only `apt-get install -y <specific-allowlisted-package>` via Gate
- Document `TOOL | COMMAND | PACKAGE | REQUIRED | STATUS | VERSION | NOTES` in toolchain-manifest.txt, only VERIFIED after actual command

### 6. Network Reality and Official Sources Only

- P3 discovered Debian apt mirrors (deb.debian.org) BLOCKED in Arena sandbox (Empty reply, Fastly blocked), while github.com PASS via E2B proxy
- P4 discovered packages.microsoft.com BLOCKED (SSL_ERROR_SYSCALL) and release-assets.githubusercontent.com BLOCKED (where GitHub release binaries hosted), while github.com and api.github.com PASS
- Therefore P4 design has dual-path: Microsoft Repository primary, GitHub .deb official fallback, with integrity checks (dpkg-deb --info, size>0, Package=powershell Arch=amd64, checksum if available)
- No third-party source, no snap, no unofficial mirror, no binary from untrusted source — if both official paths BLOCKED, result is BLOCKED (not fake PASS)

### 7. Separation of Concerns: System vs Project

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - Current: sudo NOPASSWD: ALL
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
- M5 Product: actual product implementation only after M0-M4 PASS

Current: M0 partial (P5), M1 partial (P4 blocked), M2 partial, M3 in progress (P2 Gate).

---

## Vision for Arena

Arena Agent Mode is documented to build multi-step plans, use Bash inside sandbox, write files, test work, and GitHub integration. LINEX.OS makes Arena **executor of project** in disciplined way, not just code generator.

- Arena should be able to run `DISCOVER → PLAN → BOOTSTRAP → VERIFY → BUILD FOUNDATION → DESIGN → IMPLEMENT` without breaking environment
- Arena should know when to STOP and REPORT instead of blindly installing
- Arena should produce evidence, not claims

This vision will be formalized in P6 with `AGENTS.md` (constitution of Arena inside repo) and `ARENA.md` (how Arena works).

---

**Status:** P5 Vision documented, foundation in progress, P4 blocked as known network restriction, no third-party workaround.

**Next:** Architecture (logical layers), Security, Development, Operations docs, then Agent Contract (P6).
