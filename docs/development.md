# LINEX.OS — Development Workflow

## Workflow (Mandatory for Arena and Contributors)

### Active Phase Order

Follow the approved P0–P6 plan in `docs/architecture/roadmap.md`: P0 Baseline Reconciliation; P1
MVP Definition + ADRs; P2 P9 Runtime Core; P3 P11/P12 Policy + Capability; P4 P10 Execution
Authority; P5 P13/P14 Vertical Slice; P6 CI + Security + Release. Parenthetical P9–P14 names are
legacy artifact identifiers, not the active order. P1 must decide language, storage, isolation
boundary, execution model, evidence model, and failure semantics before any Runtime implementation.

The proposed P1 MVP scope is Linux CLI/local process, Planner → structured actions, Mock Authority
first then Safe Local Authority, fail-closed policy, explicit/scoped/expiring capabilities,
append-only execution evidence, and no Agent → shell path. MCP, browser, GUI, default network, and
production deployment are outside the proposal; it is not frozen and must be decided by P1 ADRs.

### INSPECT → PLAN → CHANGE → TEST → VERIFY → REPORT

#### 1. INSPECT (Read-Only)

- `whoami`, `id`, `uname -a`, `arch`, `cat /etc/os-release`
- `command -v bash`, `sh`, `sudo`, `git`, `curl`, `wget`, `jq`, `python3`, `node`, `npm`, `pwsh`, `docker`, `podman`
- `sudo -n true`, `sudo -l` (read-only checks, no password bypass attempt)
- `df -h`, `free -h`, `env | grep -E "^(PATH|HOME|USER|SHELL)"`
- `git branch`, `git status`, `git log --oneline`, `git remote -v`
- Network: `curl -Is https://github.com`, `curl -Is https://packages.microsoft.com`, `curl -Is https://api.github.com`, `ping -c1 8.8.8.8` (if allowed)
- No installation, no system modification, no secrets

**Output format:**
```
ENVIRONMENT
OS: ...
VERSION: ...
ARCH: ...
USER: ...
SUDO: AVAILABLE / UNAVAILABLE
POWERSHELL: AVAILABLE / MISSING
GIT: ...
...
STATUS: ...
EVIDENCE: ...
BLOCKERS: ...
NEXT STEP: ...
```

- Distinguish VERIFIED / NOT VERIFIED / BLOCKED / PASS
- No PASS without evidence

#### 2. PLAN

- Propose minimal changes, not "install everything"
- Detect OS first, then package manager, then select install path
- For PowerShell: detect OS → detect package manager → select supported install path per Microsoft Learn → install pwsh → pwsh --version → verify
- For toolchain: detect missing packages only, not reinstall existing
- For privilege: Policy must precede any sudo install (because sudo NOPASSWD: ALL)
- No assumption of Ubuntu/Debian before reading /etc/os-release
- No blind installation of Docker/K8s/Rust/Go/Java/.NET/Android SDK/CUDA unless architecture proves need

**Plan must include:**
- Files to be created/modified (only in allowed paths: ops/, docs/, config/, tests/, scripts/, .github/)
- Security implications (does it need Gate? Is it allowlisted?)
- Testing strategy (bash -n, shellcheck if available, run relevant tests)
- Evidence strategy (what command output will prove PASS)
- Rollback plan (if fails, how to report BLOCKED)

#### 3. CHANGE

- Create files only in repository, not system files
- No modification of `/etc/sudoers`, `/etc/sudoers.d`, `/etc/passwd`, `/etc/group`, firewall, boot, disk
- No `sudo sh -c`, `curl | sudo bash`, `curl | sh`, `wget | sh`
- No secrets in repository (no API keys, tokens, passwords, private credentials)
- No destructive commands (`rm -rf /`, `mkfs`, `dd`, `fdisk`, `wipefs`, `shutdown`, `reboot`)
- Use strict mode in Bash: `set -Eeuo pipefail`
- Use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = "Stop"` in PowerShell
- For package installation: must go via `ops/security/privilege-gate.sh` with DRY-RUN first, then --execute, with explicit allowlist
- For PowerShell: only official sources `packages.microsoft.com` and `github.com/PowerShell/PowerShell`, no third-party, no snap, no build from source
- For apt: no `apt upgrade`, `full-upgrade`, `dist-upgrade`, no `apt autoremove` — only `apt-get install -y <specific-allowlisted-package>` via Gate

#### 4. TEST

- `bash -n` for all shell scripts (mandatory)
- `shellcheck` if available, else SKIPPED (not FAILURE)
- PowerShell syntax validation only if pwsh available, else SKIPPED
- Run relevant tests:
  - P2: `ops/security/tests/privilege-policy.test.sh` (28 tests) — must be all PASS, no real package install/remove
  - P3: `ops/linux/tests/toolchain.test.sh` (44 tests) — includes C/C++ smoke tests, no docker/pwsh install
  - P4: `ops/powershell/tests/powershell-install.test.sh` (18 tests) — logic PASS, install may be BLOCKED due to network
- Check forbidden patterns: no `eval`, no `curl | bash` as executable (exclude test files that intentionally test blocking with self-match avoidance)
- Check no secrets
- Check working tree cleanliness: `git status --short`, only intended new files, no unintended artifacts
- No commit or push unless explicitly authorized; respect any stricter per-phase restrictions.

#### 5. VERIFY

- Run verification scripts:
  - `ops/bootstrap/bootstrap.sh` — OS, arch, package manager detection, toolchain checks, fail-closed
  - `ops/verify/verify-environment.sh` — Repository, Git, Linux shell, sudo, PowerShell, package manager, network, required tools, disk, memory, security
  - `scripts/doctor.sh` — aggregator, outputs PASS/NOT VERIFIED/BLOCKED for each component, final STATUS
  - `ops/linux/doctor.sh` — toolchain verification
  - `ops/security/policy-check.sh` — policy files existence, executable, no dangerous constructions, no secrets, no sudoers modification
  - `ops/powershell/doctor.ps1` — PowerShell verification (if pwsh available)

- Verify evidence:
  - `command -v <tool>` → FOUND
  - `<tool> --version` → actual version output
  - `dpkg-query -W` for installed packages
  - `pwsh --version` and `$PSVersionTable` for PowerShell
  - Smoke tests: C source → gcc → executable → run → expected output, then delete artifact

- Distinguish:
  - VERIFIED: tool exists and version check PASS with evidence
  - NOT VERIFIED: tool missing but expected (e.g., pwsh in P1-P3, P4 blocked)
  - BLOCKED: tool missing and cannot be installed due to network/policy/resource, or dangerous operation blocked
  - PASS: overall status with evidence, but with NOT VERIFIED components documented as known blockers

#### 6. REPORT

Must output:

```
STATUS:
RESULT:
EVIDENCE:
CHANGED FILES:
TESTS:
SECURITY INVARIANTS: (for P2)
BLOCKED CASES: (for P2/P4)
SYSTEM CHANGES:
GIT:
BLOCKERS:
NEXT:
P<X> COMPLETE: YES/NO
```

- No claim PASS without evidence
- Report `REPOSITORY_STATUS` (PASS/FAIL), `ENVIRONMENT_STATUS` (READY/BLOCKED), and `REMOTE_CI_STATUS` (VERIFIED/NOT VERIFIED) separately, each with measured commit/time and evidence.
- A BLOCKED environment may coexist with `scripts/doctor.sh` FAIL / exit 3 for a missing required tool. Do not let repository tests or remote CI soften or override the actual doctor result.
- No claim production ready, fully complete, cross-platform verified unless actually verified with evidence
- For P4: If Microsoft repo BLOCKED but GitHub fallback VERIFIED → RESULT PASS — OFFICIAL GITHUB FALLBACK with MICROSOFT_REPOSITORY → BLOCKED, GITHUB_OFFICIAL_RELEASE → VERIFIED. If both BLOCKED → RESULT BLOCKED, no third-party
- For P3: If toolchain already satisfied → RESULT P3 TOOLCHAIN ALREADY SATISFIED, no install for sake of phase
- For P5: Differentiate IMPLEMENTED, VERIFIED, NOT VERIFIED, BLOCKED, SKIPPED

## Rules (Mandatory)

### No blind installation
- Detect OS, version, arch, package manager first
- Check if tool already exists via command -v before installing
- Install only missing, not existing
- Use explicit package mapping, no raw user input

### No secrets
- No API keys, tokens, passwords, private credentials in repo
- No secrets in logs (evidence must not contain passwords, tokens)
- config/ is for non-sensitive config only
- .env, secrets, credentials excluded via .gitignore
- Forbidden-commands.txt may document secret patterns as examples (e.g., # password=) but not actual secrets

### No arbitrary privileged command
- No `sudo <arbitrary-command>` via Gate
- No `sudo bash`, `sudo sh`, `sudo env`, `sudo -i`, `sudo su`
- No `sudo "$USER_INPUT"`
- Only structured actions allowlisted: check-sudo, package-install <allowlisted-package>, etc.
- Package name validation strict: regex, no metacharacters, no path traversal

### No production claims from local tests
- Local PASS in Arena sandbox ≠ Production PASS
- Tests in sandbox prove logic, not production deployment
- Document in tests/README.md: Local PASS ≠ Production PASS
- No claim "production ready" in README unless actually deployed and verified in production

### No auto deployment
- No commit, push, merge, or deployment unless explicitly authorized; follow any stricter per-phase rule
- Show `git status --short` and changed files
- CI runs repository validation, security checks, tests, and doctor; it does not deploy and uses least-privilege permissions (`contents: read`).

### No destructive operations by default
- DESTRUCTIVE_OPERATION always DENIED in P2-P4
- Includes rm -rf /, mkfs, dd, fdisk, shutdown, reboot, iptables -F, etc.
- See forbidden-commands.txt
- Primary control is allowlist, not blacklist

### No dependency without justification
- No addition of Docker, K8s, Rust, Go, Java, .NET, Android SDK, CUDA, etc. unless P1 ADRs justify the need and an authorized phase requires it
- No npm install, pip install, cargo add just to create CI
- No Runtime implementation or implementation dependencies before the required P1 ADR decisions are accepted; system-package changes still require explicit approval and the privilege Gate.
- Document justification in privilege-policy.md or toolchain-manifest.txt

### Tests mandatory
- Every change must have tests or verification
- The existing foundation suites retain legacy labels P2 (28 privilege-policy tests), P3 (44 toolchain tests), and P4 (18 PowerShell-install tests); these labels are not the active P0–P6 phase order.
- All required tests must pass for a phase to be COMPLETE. Classify an unavailable external tool as an environment blocker without changing test expectations or doctor semantics.

### Evidence mandatory
- Every PASS must have evidence: captured command output, version, test log, dpkg-query, etc.
- Evidence format for Gate: ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY
- No evidence → no PASS

## Environment and Branch Evidence

Environment, branch, remote, and CI state are time-sensitive. Use the latest commit-scoped report under `docs/reports/`; do not copy a branch name, commit ID, or tool status from an older sandbox into this guide. The P0 measurement at `a71643a` is recorded in `docs/reports/baseline-audit-a71643a.md`.

- Discover the active session branch with `git branch --show-current`; never hard-code its name here.
- Inspect GitHub branch, PR, and CI state with `git ls-remote` and `gh` before reporting.
- `scripts/doctor.sh` remains fail-closed: with `pkg-config` absent from the default PATH it exits 3. The audit report separately classifies repository checks, Arena environment readiness, and remote CI; it does not soften the doctor result.
- Per-phase no-commit/no-push instructions remain in force unless the user explicitly authorizes an exception.

## Tools

- **bash**: Strict mode, bash -n syntax check, shellcheck if available
- **PowerShell**: Set-StrictMode, syntax validation only if pwsh available, cross-platform scripts (bootstrap.ps1, verify-environment.ps1, doctor.ps1)
- **Git**: git status, git diff, git log, git branch
- **Gate**: privilege-gate.sh with dry-run default
- **Doctor**: scripts/doctor.sh aggregates all checks

## Known Environment Limitations

- PowerShell runtime remains BLOCKED in this Arena environment because the official Microsoft package and GitHub release-asset hosts are unreachable; no third-party source is permitted.
- Debian apt mirrors are BLOCKED. The P0 audit verified that the official `pkgconf/pkgconf` GitHub source is reachable and built a temporary `pkgconf-lite` binary under `/tmp`; it was not installed system-wide and the default PATH remains without `pkg-config`.
- Remote branch, PR, and CI state must be inspected live. The audit at `a71643a` records its measured state in `docs/reports/baseline-audit-a71643a.md`.

---

**Status:** This file defines the inspect → plan → change → test → verify → report workflow. The active phase plan is in `docs/architecture/roadmap.md`; P0 Baseline Reconciliation is current and P1 MVP Definition + ADRs is next. No Runtime implementation before P1 decisions are accepted.
