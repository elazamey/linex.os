# LINEX.OS

> **Agent Operating System — Repository Foundation (P5)**

LINEX.OS is being built as a disciplined, verifiable **Agent OS** — not a random collection of scripts. The project establishes a clear execution contract for AI agents (Arena) with fail-closed policy, structured privilege gate, and evidence-based verification before any product code.

---

## Purpose

- Provide a **governed runtime** for AI agents that can execute Linux and PowerShell tasks safely
- Separate **System privilege** (Linux sudoers, external) from **Project policy** (controlled by LINEX.OS Gate)
- Establish **reproducible developer baseline** (build toolchain) without blind installations
- Enable **cross-platform verification** (Linux + PowerShell 7) when network allows
- Become a foundation for a larger **Agent OS** with Core, Runtime, Agent Layer, Tool Layer, Policy Layer, Memory, Filesystem, Networking, Observability

**What LINEX.OS is NOT yet:**
- Not production ready
- Not fully complete
- Not cross-platform verified (PowerShell blocked in Arena network)
- Not an application framework (no React/Next/Python/Rust stack chosen yet)

---

## Current Status

Authoritative phase ledger: `docs/architecture/roadmap.md`, using ADR 0011 for phase order and
updated on this session branch for P13. P1-P12 baseline measurements were taken at `d349f92` and
are re-derivable via `docs/reports/baseline-audit-d349f92.md`; P13's separate local evidence is
listed in the roadmap. The most recent remote CI run on merged `main` is pre-P13 at `deb4d13`.

`COMPLETE` in this project means **the phase's documents/contracts exist, are self-consistent and
are machine-checked by a shipped suite that passes**. It never means "implemented" — the
repository intentionally contains no product code until Technology Selection (ADR 0011 D5).

| Milestone | Status | Evidence |
|-----------|--------|----------|
| **P0 Environment Discovery** | ✅ PASS | Debian 12 bookworm x86_64, apt-get, sudo NOPASSWD: ALL, Node 22, Python 3.11, Git 2.39.5 |
| **P1 Bootstrap Foundation** | ✅ COMPLETE | `ops/bootstrap/bootstrap.sh`, `ops/verify/verify-environment.sh`, `scripts/doctor.sh` — read-only, fail-closed, no install |
| **P2 Privilege Policy / Gate** | ✅ COMPLETE | `ops/security/privilege-gate.sh` — allowlist + structured actions + dry-run default, 28/28 tests PASS |
| **P3 Linux Toolchain** | ✅ COMPLETE with one ENVIRONMENT-DEPENDENT gap | gcc 12.2.0, g++ 12.2.0, make 4.3, python3 3.11.2, node 22, npm 10.9.8 present. **43/44 tests PASS in a fresh Arena sandbox**: `pkg-config` is MISSING here (a previous sandbox built pkgconf from source outside the repo, which is not re-derivable — ADR 0011 D2) and the apt mirror is unreachable, so it cannot be installed in-sandbox. CI Job 4 succeeds because `ci.yml` provisions the P3 baseline (including `pkg-config`) before running the verification test (CI-H4) |
| **P4 PowerShell 7** | ⛔ BLOCKED — Arena Network | `packages.microsoft.com` BLOCKED (SSL_ERROR_SYSCALL), `release-assets.githubusercontent.com` BLOCKED, `github.com` PASS, `api.github.com` PASS — Gate and install logic PASS (18/18 tests), but binary download blocked, no third-party used |
| **P5 Repository Foundation** | ✅ COMPLETE | docs/, config/, tests/, .github/workflows/ci.yml, README, CONTRIBUTING, SECURITY, LICENSE |
| **P6 Agent Contract** | ✅ COMPLETE | `AGENTS.md`, `ARENA.md`, `docs/agent-contract.md` — 15/15 tests PASS |
| **P7 Doctor + CI Hardening** | ✅ COMPLETE | `scripts/doctor.sh`, `ops/security/{policy-check,secret-scan,static-security-check}.sh` — all three PASS; doctor exit 3 in Arena, caused solely by the P3 pkg-config gap (ADR 0011 D3 keeps that FAIL honest) |
| **P8 Architecture Design** | ✅ COMPLETE + FROZEN | 14 architecture docs, ADRs 0001-0006, `frozen-baseline.md` — 15/15 tests PASS |
| **P9 Core Runtime Contract** | ✅ COMPLETE (contracts only) | `docs/contracts/{runtime,task,action,event,result,lifecycle}.md`, ADR 0007 — 15/15 tests PASS |
| **P10 Execution Authority Contract** | ✅ COMPLETE (contracts only) | `docs/contracts/execution-authority.md` + 5 executor contracts + matrix + lifecycle, ADR 0008 — 36/36 tests PASS |
| **P11 Policy Engine Contract** | ✅ COMPLETE (contracts only) | `docs/contracts/{policy,policy-matrix,policy-lifecycle}.md`, ADR 0009 — 40/40 tests PASS |
| **P12 Capability Registry Contract** | ✅ COMPLETE (contracts only) | `docs/contracts/{capability,capability-registry,capability-lifecycle}.md`, ADR 0010 — 45/45 tests PASS |
| **CI-H1…CI-H6 CI hardening** | ✅ COMPLETE (not a phase) | Self-matching CI checks fixed, dispatch-only debug runner added, P4 failure surfaced as an annotation, Job 4 provisions the P3 baseline before verifying it, PowerShell TEST-1 made distro-agnostic, doctor report made deterministic. Formerly mislabelled "P13 FIX" across `ci.yml`, `ci-debug.yml`, `powershell-install.test.sh`, `doctor.sh` |
| **Remote CI** | ✅ VERIFIED before P13 | Run `37278075520` on `main` at `deb4d13`: 6/6 jobs success. P13's session-branch changes have not yet had a remote run; runner log bodies remain subject to ADR 0011 D7 |
| **P13 Agent Runtime Contract** | ✅ COMPLETE (contracts only) | ADR 0012; Agent, lifecycle, audit, and 8 structured acceptance vectors; 28/28 local contract checks and 11/11 verifier checks PASS. No runtime or product code; remote CI for this branch is pending |


**P4 Blocker Details:**
- Microsoft Repository: `https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb` → BLOCKED (Arena sandbox blocks packages.microsoft.com:443)
- GitHub Official Release: `https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell_7.6.6-1.deb_amd64.deb` → redirects to `release-assets.githubusercontent.com` → BLOCKED (same)
- `github.com` and `api.github.com` → PASS via E2B proxy, so detection and policy work, but binary assets are on blocked domain
- Official LTS version per Microsoft Learn: **PowerShell 7.6.6 LTS**, Debian 12 supported until **2028-06-30**
- No workaround with third-party, snap, or unofficial mirror — documented as known blocker

---

## Architecture Status

**Logical Layers (no framework chosen yet):**

```
UI
 ↓
API
 ↓
Runtime
 ↓
Policy Layer (privilege-policy.md)
 ↓
Privilege Layer (privilege-gate.sh)
 ↓
Execution (structured actions)
```

- **Core**: OS detection, arch detection, package manager detection (extensible)
- **Runtime**: Bootstrap + verification (P1)
- **Agent Layer**: Future — agent contracts (P6 AGENTS.md, ARENA.md)
- **Tool Layer**: Linux toolchain (P3), PowerShell (P4 blocked)
- **Policy Layer**: Allowlist, fail-closed, 5 levels: READ_ONLY, SAFE_USER_COMMAND, PACKAGE_INSTALL, PRIVILEGED_OPERATION, DESTRUCTIVE_OPERATION
- **Privilege Layer**: Gate with dry-run default, --execute explicit, no arbitrary sudo
- **Memory, Filesystem, Networking**: Future layers, dependency direction enforced
- **UI/API**: Future, must not directly call sudo
- **Observability**: Evidence logs with ACTION, CLASS, POLICY, DECISION, EXECUTION, EXIT_CODE, TIMESTAMP — no secrets
- **Verification**: doctor.sh aggregates checks, verify-environment.sh detailed

**Dependency Rule:** UI → API → Runtime → Policy → Execution. Never UI → sudo or Agent → arbitrary shell.

---

## Environment

**Current Arena Sandbox (P0-P3 verified):**

```
OS: Debian GNU/Linux 12 (bookworm)
VERSION_ID: 12
ARCH: x86_64
KERNEL: Linux 6.1.158+ x86_64
USER: user (uid 1001, groups sudo)
SUDO: AVAILABLE_NOPASSWD - (ALL : ALL) ALL, NOPASSWD: ALL - EXTERNAL / NOT CONTROLLED
PACKAGE_MANAGER: apt-get
BASH: GNU bash 5.2.15
GIT: 2.39.5
CURL: 7.88.1
JQ: 1.6
PYTHON: 3.11.2
NODE: v22.22.3
NPM: 10.9.8
GCC: 12.2.0 (Debian 12.2.0-14+deb12u1)
G++: 12.2.0
MAKE: 4.3
PKG-CONFIG: 3.0.0 (pkgconf built from GitHub due to apt network block)
DOCKER: NOT INSTALLED (not required for P3)
PWSH: NOT VERIFIED / BLOCKED (P4 network restriction)
DISK: 21G total, 20G avail (4%)
MEMORY: 3.8Gi total, 3.6Gi available
NETWORK: github.com PASS, api.github.com PASS, deb.debian.org BLOCKED, packages.microsoft.com BLOCKED, release-assets.githubusercontent.com BLOCKED
```

**Extensibility:** Detection logic in `ops/bootstrap/bootstrap.sh` supports debian, ubuntu, rhel, fedora, arch, alpine, darwin, windows via /etc/os-release and uname, not hardcoded to Debian.

---

## Security Model

**Two distinct policies:**

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - Current: sudo NOPASSWD: ALL
  - Evidence: sudo -n true PASS, sudo -l shows (ALL : ALL) ALL
  - System can do sudo <arbitrary> outside Gate → YES (expected)

LINEX_OS_PROJECT_POLICY: CONTROLLED BY PROJECT GATE
  - Controlled by ops/security/privilege-gate.sh
  - Allowlist + structured actions + fail-closed + dry-run default
  - Project via Gate allows sudo <arbitrary> → NO (BLOCKED unless explicitly allowed action + allowlist)
  - Evidence: ./privilege-gate.sh "sudo whoami" → BLOCKED EXIT 3, ./privilege-gate.sh "rm -rf /" → BLOCKED
```

**Levels:**
- READ_ONLY: allowed without sudo (e.g., check-package-manager)
- SAFE_USER_COMMAND: allowed if explicitly safe (e.g., service-status ssh read-only)
- PACKAGE_INSTALL: DENY by default, requires Gate + allowlist + --execute
- PRIVILEGED_OPERATION: DENY by default, requires explicit action (e.g., register-microsoft-repository)
- DESTRUCTIVE_OPERATION: DENY always in P2/P3/P4 (rm -rf /, mkfs, dd, shutdown, etc.)

**Gate Principles:**
- Default DRY-RUN: shows ACTION, CLASS, POLICY, WOULD EXECUTE, but NOT EXECUTED
- Real execution requires explicit `--execute` flag
- No `sudo bash`, `sudo sh`, `sudo env`, `sudo -i`, `sudo su`, `sudo $USER_INPUT`
- No `eval`, no `bash -c "$INPUT"` with uncontrolled input
- No `curl | bash`, `curl | sh`, `wget | bash`, `wget | sh`
- Package name validation: regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no metacharacters `; & | $ ` \ " ' < > ( ) { } * ? ! ~ #`, no path traversal `/` or `..`, no leading `-`
- Allowlist: DEFAULT DENY, explicit list (P2: ca-certificates, curl, git, etc.; P3: +gcc, g++, make, pkg-config, build-essential; P4: +powershell, packages-microsoft-prod)
- Fail-closed: unknown action/package/invalid args/missing policy → BLOCKED non-zero exit
- Evidence: structured without secrets (no passwords, tokens, API keys)

**Important:** Gate is governance layer, NOT kernel-level sandbox. Real isolation needs container/user isolation later.

---

## Agent Execution Model

**Workflow (mandatory for Arena):**

```
INSPECT → PLAN → CHANGE → TEST → VERIFY → REPORT
```

1. **INSPECT**: Read-only discovery (whoami, id, uname -a, /etc/os-release, command -v checks, sudo -n true, network checks)
2. **PLAN**: Propose minimal changes, no blind installation, no assumption of Ubuntu/Debian before detection
3. **CHANGE**: Create files only in allowed paths (ops/, docs/, config/, tests/, scripts/, .github/), no /etc/sudoers modification, no secrets
4. **TEST**: bash -n for all scripts, shellcheck if available (SKIPPED if not), run P2/P3/P4 tests, no real package install in tests (dry-run)
5. **VERIFY**: Run verify-environment.sh, doctor.sh, policy-check.sh, toolchain tests, evidence with VERIFIED/NOT VERIFIED/BLOCKED/PASS
6. **REPORT**: Output STATUS, RESULT, EVIDENCE, CHANGED FILES, TESTS, BLOCKERS, NEXT — no claim PASS without evidence

**Agent Contract (P6 will formalize in AGENTS.md, ARENA.md):**

- No blind installation
- No destructive commands
- No secrets in repository
- No production claims from local tests (Local PASS ≠ Production PASS)
- No deploy without explicit authorization
- No dependency addition without justification
- Every major change requires verification
- No third-party source for PowerShell (only packages.microsoft.com and github.com/PowerShell/PowerShell)

---

## Development Workflow

**Phase Order (enforced):**

```
P0 Environment Discovery → PASS
  ↓
P1 Bootstrap + verification → COMPLETE (read-only, no install)
  ↓
P2 Privilege Policy / Gate → COMPLETE (must precede any sudo install, because sudo NOPASSWD: ALL)
  ↓
P3 Linux Toolchain → COMPLETE (detect missing, Gate dry-run, Gate --execute only approved)
  ↓
P4 PowerShell → BLOCKED (Arena network: packages.microsoft.com and release-assets.githubusercontent.com blocked, github.com PASS, no third-party)
  ↓
P5 Repository Foundation → COMPLETE
  ↓
P6 Agent Contract (AGENTS.md, ARENA.md) → COMPLETE (15/15)
  ↓
P7 Doctor + CI + complete verify → COMPLETE
  ↓
P8 Architecture Design → COMPLETE + FROZEN (15/15)
  ↓
P9 Core Runtime Contract → COMPLETE (15/15, contracts only)
  ↓
P10 Execution Authority Contract → COMPLETE (36/36, contracts only)
  ↓
P11 Policy Engine Contract → COMPLETE (40/40, contracts only)
  ↓
P12 Capability Registry Contract → COMPLETE (45/45, contracts only)
  ↓
P13 Agent Runtime Contract → COMPLETE (contracts only; 28/28 tests, 11/11 verifier checks)
  ↓
P14 Tool + Skill Contract → IN PROGRESS (contracts + schemas validated locally; remote CI pending)
  ↓
P15 Memory/State/Event → P16 Verification/Eval → P17 MCP
  ↓
P18 Technology Selection → implementation language decided here, by ADR
  ↓
Implementation phases → Product Code (only after P18)
```

**Not `P9+ Product Code`:** P9-P13 delivered *contracts*, not product implementation. No product
runtime exists in this repository, and none may until Technology Selection decides the
implementation language at P18 (ADR 0011 D5). Introducing a language earlier would violate the
P8 freeze.

**Why this order?** Because `sudo NOPASSWD: ALL` means system does not enforce fine-grained limits on Arena. So `privilege-gate.sh` must be built as project control layer BEFORE any script that uses sudo. This prevents `install-pwsh.sh` from becoming first channel of root execution without restrictions.

**Branch model:** `main` is the only long-lived branch and is the source of truth for status.
Work happens on per-session `arena/*` branches which **are pushed** and merged by pull request
(PR #1 delivered P1-P12 contracts, PR #2 delivered CI hardening). An unpushed branch is not
evidence and does not survive its sandbox — ADR 0011 (D1) records a handoff that was lost
exactly this way.

**Git Hygiene:** No force push, no history rewrite, no merge to `main` outside a reviewed pull
request. Show `git status --short` and changed files for every change.

---

## Verification Model

**Single command to get project status:**

```bash
./scripts/doctor.sh
# and
./ops/linux/doctor.sh
./ops/security/policy-check.sh
./ops/security/tests/privilege-policy.test.sh
./ops/linux/tests/toolchain.test.sh
./ops/powershell/tests/powershell-install.test.sh
```

**Output measured at `d349f92` in a fresh Arena sandbox (not an idealised example):**

```
Repository       → PASS
Git              → PASS
Linux shell      → PASS
sudo             → PASS (AVAILABLE_NOPASSWD - requires P2 policy)
PowerShell       → BLOCKED (P4 network restriction, expected)
Package manager  → PASS (apt-get present; mirror unreachable, see Known Blockers)
Network          → PASS (github.com), BLOCKED (deb.debian.org, packages.microsoft.com)
Required tools   → NOT VERIFIED (pkg-config MISSING)
Disk             → PASS
Memory           → PASS
Security policy  → PASS
Secrets          → PASS
Tests            → FAIL (P3 43/44 — pkg-config; P2 28/28, P4 18/18, P6 15/15 all PASS)

Counts: PASS=45 FAIL=1 BLOCKED=2 NOT_VERIFIED=1
FOUNDATION STATUS: FAIL
EXIT CODE: 3 (FAIL)
```

**Read that FAIL correctly.** Its single root cause is `pkg-config` being absent in this
sandbox, where the apt mirror is unreachable and no system changes are permitted. The same
commit is green on GitHub Actions (6/6 jobs, including Job 4 Toolchain). `scripts/doctor.sh`
deliberately still reports FAIL rather than softening it: a required tool that is missing is a
real unmet baseline, and the environment explanation belongs in the evidence layer
(`docs/reports/`), not inside the aggregator — see ADR 0011 (D2, D3).

**No claim PASS without evidence:** Every PASS must have captured command output, version check, or test log.

---

## Known Blockers

| Component | Status | Reason | Evidence | Next |
|-----------|--------|--------|----------|------|
| PowerShell 7.6.6 LTS | BLOCKED / NOT VERIFIED | Arena sandbox network blocks packages.microsoft.com:443 and release-assets.githubusercontent.com:443 (where GitHub release binaries hosted) with SSL_ERROR_SYSCALL, while github.com and api.github.com PASS via E2B proxy | curl -v https://packages.microsoft.com → SSL_ERROR_SYSCALL, curl -v https://release-assets.githubusercontent.com → SSL_ERROR_SYSCALL, curl -Is https://github.com → 200 PASS, gh release download → EOF | Requires network allowlist for packages.microsoft.com and release-assets.githubusercontent.com or manual .deb provision into /tmp/linex-os-powershell/ per official Microsoft Learn (Debian 12 supported until 2028-06-30) |
| Debian apt mirrors | BLOCKED | deb.debian.org Empty reply, all Fastly and non-Fastly Debian mirrors blocked in Arena sandbox | `curl -sSI http://deb.debian.org/debian/dists/bookworm/Release` → curl (52) Empty reply from server; `apt-cache policy pkg-config` → empty; `apt-get -s install pkg-config` → "Unable to locate package" | Install allowlisted packages through `ops/security/privilege-gate.sh` only in an environment with a reachable mirror |
| `pkg-config` | ENVIRONMENT-DEPENDENT (ADR 0011 D2) | Absent in a fresh Arena sandbox and not installable there (mirror blocked). Present on the GitHub runner | Local: `toolchain.test.sh` → 43/44, `version succeeds: pkg-config → FAIL (MISSING)`. Remote: CI Job 4 success | A previous sandbox built pkgconf 3.0.0 from GitHub source — that build lived outside the repository and is gone, so it cannot be claimed as VERIFIED. Re-install via the Gate where a mirror is reachable |
| Runner log bodies | NOT RETRIEVABLE from Arena | GitHub serves the log archive from a host that Arena cannot reach | `gh run view 37233042304 --log` → `results-receiver.actions.githubusercontent.com … EOF`; job conclusions still readable via `--json jobs` | Assert `REMOTE CI` from job conclusions only (ADR 0011 D7); this is why `ci.yml` emits P4 failures as annotations |
| Docker/Podman | NOT INSTALLED / NOT REQUIRED | Not needed for P0-P12, will be considered only if architecture proves need | command -v docker → MISSING (expected) | Post-P18 implementation phases if needed |

**What is NOT a blocker:**
- gcc 12.2.0, g++ 12.2.0, make 4.3, build-essential → VERIFIED (already installed via dpkg in base image)
- jq 1.6, sha256sum, openssl, git, python3 3.11.2, node 22, npm 10.9.8 → VERIFIED present
- All P2/P4/P6/P8/P9/P10/P11/P12 suites → PASS (255 of 256 checks overall; the one FAIL is pkg-config)
- `pytest`, `PyYAML`, `shellcheck`, `yamllint`, `bc` → ABSENT, and **not required**: the verification layer stays inside the shipped toolchain (ADR 0011 D5)

---

## Project Structure (P5)

```
linex.os/
├── .github/
│   └── workflows/
│       └── ci.yml              # Static/security checks, foundation suites, and P13 contract checks
├── docs/
│   ├── vision.md               # What is LINEX.OS, problem, long-term goal, principles
│   ├── architecture.md         # Logical layers, dependency direction, no framework
│   ├── security.md             # Project vs System policy, allowlist, fail-closed
│   ├── development.md          # INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT workflow
│   ├── operations.md           # bootstrap, doctor, verification, toolchain, Gate, network limits, P4 blocker table
│   └── contracts/              # P9-P13 contract-only specifications
│       ├── agent-runtime.md     # P13 Agent/Planner, authority, and capability boundaries
│       ├── agent-lifecycle.md   # P13 invocation state and handoff diagrams
│       ├── agent-audit.md       # P13 event, rejection, and privacy requirements
│       └── agent-acceptance-tests.yaml # Eight structured contract vectors
├── ops/
│   ├── bootstrap/
│   │   ├── bootstrap.sh        # P1 - strict mode, OS/arch/pkg manager detection, no install
│   │   └── bootstrap.ps1       # P1 - PowerShell 7 compatible
│   ├── linux/
│   │   ├── install-base.sh     # P3 - DETECT→VERIFY→PLAN→DRY-RUN→GATE→INSTALL only approved
│   │   ├── doctor.sh           # P3 - verifies toolchain
│   │   ├── toolchain-manifest.txt # Tool|Command|Package|Required|Status|Version|Notes
│   │   └── tests/
│   │       └── toolchain.test.sh # 44 tests
│   ├── powershell/
│   │   ├── install-pwsh.sh     # P4 - dual path: Microsoft repo primary, GitHub .deb fallback, official only
│   │   ├── doctor.ps1          # P4 - verifies pwsh, version, edition, OS, arch
│   │   └── tests/
│   │       └── powershell-install.test.sh # 18 tests
│   ├── security/
│   │   ├── privilege-policy.md # P2 - 5 levels, allowlist, fail-closed, sudo distinction
│   │   ├── forbidden-commands.txt # Defense-in-depth blacklist
│   │   ├── privilege-gate.sh   # P2/P3/P4 - allowlist + structured actions + dry-run default
│   │   ├── policy-check.sh     # P2 - verifies policy files, no dangerous constructions
│   │   └── tests/
│   │       └── privilege-policy.test.sh # 28 tests
│   └── verify/
│       ├── verify-environment.sh  # P1 - comprehensive verification
│       ├── verify-environment.ps1 # P1 - PowerShell verification
│       └── verify-agent-runtime.sh # P13 - contract-only validation
├── config/
│   └── README.md               # Non-sensitive config only, no secrets
├── tests/
│   ├── README.md               # Test levels, Local PASS ≠ Production PASS
│   └── agent-runtime.test.sh   # P13 contract and structured-vector checks
├── scripts/
│   ├── doctor.sh               # P1 aggregator - Repository, Git, Linux shell, sudo, PowerShell, etc.
│   └── doctor.ps1              # P1 aggregator PowerShell
├── README.md                   # This file
├── CONTRIBUTING.md             # Contribution rules
├── SECURITY.md                 # Security reporting, secret handling
├── LICENSE                     # PENDING OWNER DECISION (placeholder)
└── .gitignore                  # Excludes .env, secrets, logs, build artifacts, OS junk
```

**Historical phase note:** P5 was followed by P6 (`AGENTS.md`, `ARENA.md`, and `docs/agent-contract.md`). The current ledger is `docs/architecture/roadmap.md`: P13 Agent Runtime Contract is complete as a contract-only phase; P14 Tool + Skill Contract is in progress as a contract-only phase and is NOT complete until the validator adoption, full JSON Schema validation, the verifier, and a green remote CI run have all been recorded.

---

## Quick Start (P5)

```bash
# 1. Bootstrap detection (read-only, no install)
./ops/bootstrap/bootstrap.sh

# 2. Verify environment
./ops/verify/verify-environment.sh

# 3. Doctor (aggregator)
./scripts/doctor.sh
./ops/linux/doctor.sh

# 4. Policy check
./ops/security/policy-check.sh

# 5. Run tests (all should PASS, P4 install BLOCKED but logic PASS)
./ops/security/tests/privilege-policy.test.sh
./ops/linux/tests/toolchain.test.sh
./ops/powershell/tests/powershell-install.test.sh

# P13 Agent Runtime contracts only (no Agent execution)
./tests/agent-runtime.test.sh
./ops/verify/verify-agent-runtime.sh

# 6. Try PowerShell install (will be BLOCKED in Arena due to network, but logic PASS)
./ops/powershell/install-pwsh.sh
```

**Measured in the current Arena sandbox:**
- P1, P2 → PASS; P3 → 43/44 (only `pkg-config` missing; apt mirrors are unreachable), so the local P7 doctor exits 3
- P4 → BLOCKED (network) with evidence; install logic tests pass 18/18, no third-party
- P13 → 28/28 contract checks and 11/11 verifier checks PASS locally; no Agent runtime is implemented
- Remote CI on the current P13 change → PENDING until the branch is pushed and a run completes

---

## References

- Arena Agent Mode: https://help.arena.ai/articles/5432423882-how-to-use-agent-mode
- Microsoft PowerShell on Debian: https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian
- PowerShell 7.6.6 LTS Release: https://github.com/PowerShell/PowerShell/releases/tag/v7.6.6
- Debian 12 bookworm supported until 2028-06-30 per Microsoft Learn
- GitHub Actions GITHUB_TOKEN least privilege: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token

---

**Current status:** P14 Tool + Skill Contract — IN PROGRESS, contracts only (40/40 local contract checks including JSON Schema draft 2020-12 meta-schema validation and valid/invalid fixtures; verifier 17/17 PASS locally). The remaining gate is a green remote CI run, see ADR 0013. P13 Agent Runtime Contract remains COMPLETE as documentation and contract checks only (28/28 local tests; 11/11 verifier checks). The P3 `pkg-config` and P4 PowerShell network blockers remain environment-dependent; neither P13 nor P14 implements a runtime.

**Next:** confirm the P14 suite and verifier on the remote CI runner (Job 5/Job 6), then record P14 as complete in the roadmap. Technology selection remains reserved for P18; no product runtime or implementation language has been chosen.
