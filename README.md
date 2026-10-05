# LINEX.OS

> **Agent Operating System — P0 baseline reconciliation complete; P1 MVP definition is next (no product/runtime implementation)**

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

## Current Phase Plan (approved P0–P6 sequence)

The active delivery order is recorded in `docs/architecture/roadmap.md`:

| Phase | Scope | Position / gate |
|---|---|---|
| P0 | Baseline reconciliation | COMPLETE — documentation-only reconciliation, baseline tests, evidence, and PR #4 open; repository, environment, and remote CI stay separate. |
| P1 | MVP Definition + ADRs | Next: establish the MVP and ADR decisions for language, storage, isolation boundary, execution model, evidence model, and failure semantics. |
| P2 | P9 Runtime Core | Gated on P1 decisions; contracts/core work only as authorized by the roadmap. |
| P3 | P11/P12 Policy + Capability | Follow P2; fail-closed policy and capability behavior. |
| P4 | P10 Execution Authority | Follow P3; no authority implementation before P1 decisions and scoped authorization. |
| P5 | P13/P14 Vertical Slice | Follow P4; a bounded end-to-end slice, not a general product launch. |
| P6 | CI + Security + Release | Follow P5; verification and release controls. |

**Proposed MVP scope for P1 (not frozen):** Linux, CLI, local process; Planner → structured actions;
Mock Authority first, then Safe Local Authority; fail-closed policy; explicit, scoped, expiring
capabilities; append-only execution evidence; no Agent → shell path. MCP, browser, GUI, default
network, and production deployment are outside this proposal. P1 must decide or revise this scope
through ADRs; no runtime implementation is authorized before the required P1 decisions are
accepted.

The P0 baseline measurement is recorded in `docs/reports/baseline-audit-a71643a.md` at commit
`a71643a`; the earlier audit at `d349f92` remains immutable historical evidence. Status dimensions
are separate; see the table below.

## Historical Foundation and Contract Inventory (original phase labels)

The following P0–P13 milestone labels document how the existing foundation/contracts were delivered;
they are retained for traceability and are **not** the active P0–P6 sequence above. ADR 0011 and its
D4/D5 decisions remain unchanged historical records. P1 must explicitly reconcile any necessary
supersession through ADRs rather than silently rewriting that history.

`COMPLETE` in this historical inventory means the artifact set existed, was self-consistent, and
was machine-checked by its shipped suite; it never meant product code was implemented.

| Milestone | Status | Evidence |
|-----------|--------|----------|
| **P0 Environment Discovery** | ✅ PASS | Debian 12 bookworm x86_64, apt-get, sudo NOPASSWD: ALL, Node 22, Python 3.11, Git 2.39.5 |
| **P1 Bootstrap Foundation** | ✅ COMPLETE | `ops/bootstrap/bootstrap.sh`, `ops/verify/verify-environment.sh`, `scripts/doctor.sh` — read-only, fail-closed, no install |
| **P2 Privilege Policy / Gate** | ✅ COMPLETE | `ops/security/privilege-gate.sh` — allowlist + structured actions + dry-run default, 28/28 tests PASS |
| **P3 Linux Toolchain** | ✅ COMPLETE with an ENVIRONMENT-DEPENDENT gap | Core tools are present. In the default Arena PATH, `pkg-config` is missing and P3 is 43/44. The P0 audit built official `pkgconf-lite` 3.0.0 from pinned GitHub commit `d908d63634c13b9a4f88d2fe4578d95048a6b13c` under `/tmp`; with that temporary PATH, P3 is 44/44. No system package was installed, so the ambient environment remains missing `pkg-config`. CI Job 4 provisions the P3 baseline before verification (CI-H4) |
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
| **Remote CI** | ✅ VERIFIED at `a71643a` | GitHub Actions run `37246010719` on `main`: 6/6 jobs success. Job-level granularity only — runner log bodies are not retrievable from Arena (ADR 0011 D7) |
| **P13 Agent Runtime Contract (legacy label)** | Previously next under the pre-P0 ledger | Existing contract-stage planning is retained for traceability; current next phase is P1 MVP Definition + ADRs |

**P0 baseline dimensions (separate assessments, not one blended health score):**

| Dimension | Status | Evidence |
|-----------|--------|----------|
| `REPOSITORY_STATUS` | PASS | Repository security and contract verifiers pass. Default suites are 255/256 only because P3 correctly detects the missing environment tool; with the temporary audit binary, 256/256 pass. |
| `ENVIRONMENT_STATUS` | BLOCKED | `pkg-config` is missing and the approved Debian package mirror is blocked. P3 remains 43/44 and `scripts/doctor.sh` remains FAIL / exit 3; do not soften either result. |
| `REMOTE_CI_STATUS` | VERIFIED | Run `37246010719` on `main` at `a71643a`, 6/6 jobs success; job-level evidence only. |

`verification-summary.txt` remains the append-only Arena measurement at `d349f92`; the current P0
snapshot is `docs/reports/baseline-audit-a71643a.md` (per `docs/reports/README.md` R6).

**Legacy P4 PowerShell Blocker Details:**
- Microsoft Repository: `https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb` → BLOCKED (Arena sandbox blocks packages.microsoft.com:443)
- GitHub Official Release: `https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell_7.6.6-1.deb_amd64.deb` → redirects to `release-assets.githubusercontent.com` → BLOCKED (same)
- `github.com` and `api.github.com` → PASS via E2B proxy, so detection and policy work, but binary assets are on blocked domain
- Official LTS version per Microsoft Learn: **PowerShell 7.6.6 LTS**, Debian 12 supported until **2028-06-30**
- No workaround with third-party, snap, or unofficial mirror — documented as known blocker

---

## Existing Architecture Artifacts

These logical-layer descriptions and their milestone references are legacy foundation/architecture
artifacts. P1 MVP ADRs will decide their alignment with the active MVP; the proposal above is not a
frozen architecture.

**Logical Layers (technology decisions pending the P1 ADRs):**

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
- **Runtime foundation**: Existing bootstrap + verification scripts (legacy P1); product runtime is not implemented
- **Agent Layer**: Future — existing agent governance docs carry legacy P6 labels
- **Tool Layer**: Existing Linux toolchain (legacy P3), PowerShell environment check (legacy P4, blocked)
- **Policy Layer**: Allowlist, fail-closed, 5 levels: READ_ONLY, SAFE_USER_COMMAND, PACKAGE_INSTALL, PRIVILEGED_OPERATION, DESTRUCTIVE_OPERATION
- **Privilege Layer**: Gate with dry-run default, --execute explicit, no arbitrary sudo
- **Memory, Filesystem, Networking**: Future layers, dependency direction enforced
- **UI/API**: Future, must not directly call sudo
- **Observability**: Evidence logs with ACTION, CLASS, POLICY, DECISION, EXECUTION, EXIT_CODE, TIMESTAMP — no secrets
- **Verification**: doctor.sh aggregates checks, verify-environment.sh detailed

**Dependency Rule:** UI → API → Runtime → Policy → Execution. Never UI → sudo or Agent → arbitrary shell.

---

## Environment

**Arena environment recorded by the P0 audit:**

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
PKG-CONFIG: MISSING from default PATH; temporary pkgconf-lite 3.0.0 built under /tmp for audit only (see baseline-audit-a71643a.md)
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
  - P0 audit snapshot at `a71643a`: sudo NOPASSWD: ALL (environment-specific; recheck live)
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

**Agent Contract (formalized in P6 by AGENTS.md, ARENA.md, and docs/agent-contract.md):**

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

**Active phase order (P0–P6):**

```
P0 Baseline Reconciliation → COMPLETE; documentation-only, evidence and validation recorded; PR #4 open
  ↓
P1 MVP Definition + ADRs → next; decide language, storage, isolation, execution, evidence, and failure semantics
  ↓
P2 P9 Runtime Core → only after P1 decisions are accepted
  ↓
P3 P11/P12 Policy + Capability
  ↓
P4 P10 Execution Authority
  ↓
P5 P13/P14 Vertical Slice
  ↓
P6 CI + Security + Release
```

The parenthetical P9–P14 labels identify earlier contract artifacts; they do not replace the active
P0–P6 delivery order. Existing ADRs and legacy phase records remain historical; any change to them
must be explicit and ADR-backed. No runtime implementation before the P1 ADR decisions are accepted.

**Proposed MVP scope for P1 (not frozen):** Linux CLI, local process; Planner → structured actions;
Mock Authority first, then Safe Local Authority; fail-closed policy; explicit/scoped/expiring
capabilities; append-only execution evidence; no Agent → shell path. MCP, browser, GUI, default
network, and production deployment are outside the proposal pending P1 ADRs.

**Why this order?** Because `sudo NOPASSWD: ALL` means system does not enforce fine-grained limits on Arena. So `privilege-gate.sh` must be built as project control layer BEFORE any script that uses sudo. This prevents `install-pwsh.sh` from becoming first channel of root execution without restrictions.

**Branch model:** `main` is the only long-lived branch and is the source of truth for status.
Work happens on per-session `arena/*` branches which **are pushed** and merged by pull request
(PR #1 delivered the initial foundation/contracts, PR #2 delivered CI hardening, and PR #3 reconciled the baseline, phase ledger, and audit evidence). An unpushed branch is not
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
| PowerShell 7.6.6 LTS | BLOCKED / NOT VERIFIED | Arena sandbox network blocks packages.microsoft.com:443 and release-assets.githubusercontent.com:443 (where GitHub release binaries hosted) with SSL_ERROR_SYSCALL, while github.com and api.github.com PASS via E2B proxy | `curl -I https://packages.microsoft.com` → SSL_ERROR_SYSCALL; `curl -I https://release-assets.githubusercontent.com` → SSL_ERROR_SYSCALL; GitHub API → 200 | Requires network allowlist for the official package and release-asset hosts or an official .deb provisioned in `/tmp/linex-os-powershell/`; no third-party source |
| Debian apt mirrors | BLOCKED | deb.debian.org Empty reply, all Fastly and non-Fastly Debian mirrors blocked in Arena sandbox | `curl -sSI http://deb.debian.org/debian/dists/bookworm/Release` → curl (52) Empty reply from server; `apt-cache policy pkg-config` → empty; `apt-get -s install pkg-config` → "Unable to locate package" | Install allowlisted packages through `ops/security/privilege-gate.sh` only in an environment with a reachable mirror |
| `pkg-config` | ENVIRONMENT-DEPENDENT (ADR 0011 D2) | Missing from the default Arena PATH; Debian package mirror blocked. Official GitHub source is reachable | Default PATH: `toolchain.test.sh` → 43/44 and doctor exit 3. P0 audit: pinned source build in `/tmp`, then P3 → 44/44 and doctor → PASS WITH KNOWN BLOCKER | No system package was installed. The temporary build validates the tests but does not make the default environment persistently READY; see `docs/reports/baseline-audit-a71643a.md` |
| Runner log bodies | NOT RETRIEVABLE from Arena | GitHub serves the archive from a host that Arena cannot reach, even when Actions metadata is available | `gh run view 37246010719 --log` → `results-receiver.actions.githubusercontent.com … EOF`; run metadata and all six job conclusions remain readable | Per ADR 0011 D7, report remote CI from job conclusions only; this is why `ci.yml` emits P4 failures as annotations |
| Docker/Podman | NOT INSTALLED / NOT REQUIRED | Not in the proposed local-process MVP; isolation boundaries/technology are P1 ADR decisions | `command -v docker` → MISSING (expected) | No installation or Runtime implementation before P1 decisions |

**What is NOT a blocker:**
- gcc 12.2.0, g++ 12.2.0, make 4.3, build-essential → VERIFIED (already installed via dpkg in base image)
- jq 1.6, sha256sum, openssl, git, python3 3.11.2, node 22, npm 10.9.8 → VERIFIED present
- At measured commit `d349f92`, the default Arena run had 255/256 checks pass; the single P3 failure was missing `pkg-config`. The current P0 audit records both default and temporary-source-build results in `docs/reports/baseline-audit-a71643a.md`.
- `pytest`, `PyYAML`, `shellcheck`, `yamllint`, `bc` → ABSENT, and **not required**: the verification layer stays inside the shipped toolchain (ADR 0011 D5)

---

## Repository Structure

```
linex.os/
├── .github/
│   └── workflows/
│       └── ci.yml              # Six static/security/test/doctor jobs; no Docker or PowerShell installation assumed
├── docs/
│   ├── vision.md               # What is LINEX.OS, problem, long-term goal, principles
│   ├── architecture.md         # Logical layers, dependency direction, no framework
│   ├── security.md             # Project vs System policy, allowlist, fail-closed
│   ├── development.md          # INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT workflow
│   └── operations.md           # bootstrap, doctor, verification, toolchain, Gate, network limits, P4 blocker table
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
│       └── verify-environment.ps1 # P1 - PowerShell verification
├── config/
│   └── README.md               # Non-sensitive config only, no secrets
├── tests/
│   └── README.md               # Test levels, Local PASS ≠ Production PASS
├── scripts/
│   ├── doctor.sh               # P1 aggregator - Repository, Git, Linux shell, sudo, PowerShell, etc.
│   └── doctor.ps1              # P1 aggregator PowerShell
├── README.md                   # This file
├── CONTRIBUTING.md             # Contribution rules
├── SECURITY.md                 # Security reporting, secret handling
├── LICENSE                     # PENDING OWNER DECISION (placeholder)
└── .gitignore                  # Excludes .env, secrets, logs, build artifacts, OS junk
```

**Current phase:** P0 Baseline Reconciliation is complete (PR #4 open); P1 MVP Definition + ADRs is next. No Runtime implementation before P1 decisions are accepted. Legacy contract numbers (P9–P14) are retained to identify existing artifacts, not as the active phase order. See `docs/architecture/roadmap.md`.

---

## Foundation Verification Quick Start

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

# 5. Run suites; default Arena may report the P3 pkg-config environment gap (see P0 audit report)
./ops/security/tests/privilege-policy.test.sh
./ops/linux/tests/toolchain.test.sh
./ops/powershell/tests/powershell-install.test.sh

# 6. Optional only: PowerShell installation requires explicit approval and may be BLOCKED here.
# Do not execute this installer as part of the read-only baseline check.
# ./ops/powershell/install-pwsh.sh
```

**P0 baseline in this Arena environment (measured at `a71643a`):**
- `REPOSITORY_STATUS: PASS` for repository-owned security and contract verifiers; the default aggregate suite result is 255/256 because the legacy P3 test correctly detects missing `pkg-config`.
- `ENVIRONMENT_STATUS: BLOCKED`: default P3 is 43/44 and `scripts/doctor.sh` correctly exits 3. A temporary official-source build permits audit-only verification but does not repair the default environment; see the P0 report.
- `REMOTE_CI_STATUS: VERIFIED`: run `37246010719`, 6/6 jobs, job-level evidence only.
- Legacy P4 PowerShell remains network-blocked. The older P8–P12 deliverables are architecture/contracts, not implemented Runtime.

---

## References

- Arena Agent Mode: https://help.arena.ai/articles/5432423882-how-to-use-agent-mode
- Microsoft PowerShell on Debian: https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian
- PowerShell 7.6.6 LTS Release: https://github.com/PowerShell/PowerShell/releases/tag/v7.6.6
- Debian 12 bookworm supported until 2028-06-30 per Microsoft Learn
- GitHub Actions GITHUB_TOKEN least privilege: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token

---

**Status:** P0 baseline reconciliation is complete (PR #4 open); no product/runtime implementation has started. At baseline commit `a71643a`, `REPOSITORY_STATUS: PASS`, `ENVIRONMENT_STATUS: BLOCKED`, and `REMOTE_CI_STATUS: VERIFIED` are reported separately in `docs/reports/baseline-audit-a71643a.md`.

**Next:** P1 MVP Definition + ADRs. The MVP scope remains a proposal until P1 decisions are recorded; do not implement Runtime before those ADRs are accepted.
