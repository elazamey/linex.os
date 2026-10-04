# LINEX.OS — Development (P5 Foundation)

## Workflow (Mandatory for Arena and Contributors)

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
- No auto commit/push

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
- No auto commit, push, merge, deployment in P1-P5
- Show git status --short and changed files only
- CI is static validation only, no deployment, no write-all permissions, contents: read only

### No destructive operations by default
- DESTRUCTIVE_OPERATION always DENIED in P2-P4
- Includes rm -rf /, mkfs, dd, fdisk, shutdown, reboot, iptables -F, etc.
- See forbidden-commands.txt
- Primary control is allowlist, not blacklist

### No dependency without justification
- No addition of Docker, K8s, Rust, Go, Java, .NET, Android SDK, CUDA, etc. unless architecture proves need
- No npm install, pip install, cargo add just to create CI
- No application dependencies in P0-P5 (only system packages via Gate with allowlist)
- Document justification in privilege-policy.md or toolchain-manifest.txt

### Tests mandatory
- Every change must have tests or verification
- P2: 28 tests for privilege policy
- P3: 44 tests for toolchain including smoke tests
- P4: 18 tests for PowerShell install logic
- All tests must PASS for phase to be considered COMPLETE, except known BLOCKED due to network (documented as BLOCKED, not fake PASS)

### Evidence mandatory
- Every PASS must have evidence: captured command output, version, test log, dpkg-query, etc.
- Evidence format for Gate: ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY
- No evidence → no PASS

## Development Environment (Current)

- OS: Debian 12 bookworm x86_64
- Package manager: apt-get
- Sudo: NOPASSWD: ALL (external, not controlled)
- Tools: bash 5.2.15, git 2.39.5, curl 7.88.1, jq 1.6, python3 3.11.2, node 22.22.3, npm 10.9.8, gcc 12.2.0, g++ 12.2.0, make 4.3, pkg-config 3.0.0 (built from GitHub pkgconf)
- PowerShell: NOT VERIFIED / BLOCKED (P4 network restriction)
- Network: github.com PASS, api.github.com PASS, deb.debian.org BLOCKED, packages.microsoft.com BLOCKED, release-assets.githubusercontent.com BLOCKED
- Disk: 21G total, 20G avail
- Memory: 3.8Gi total, 3.6Gi available

## Branch and Git

- Current branch: arena/01a107fc-linex-os (not yet on GitHub, only main at 768bf39 on remote, per decision no auto commit/push)
- Workflow: work on arena branch, commit to it, push only to it, open PR from it, never switch to other branch (Arena tracking)
- No commit/push in P1-P5 phases (per prompts), only show git status

## Tools

- **bash**: Strict mode, bash -n syntax check, shellcheck if available
- **PowerShell**: Set-StrictMode, syntax validation only if pwsh available, cross-platform scripts (bootstrap.ps1, verify-environment.ps1, doctor.ps1)
- **Git**: git status, git diff, git log, git branch
- **Gate**: privilege-gate.sh with dry-run default
- **Doctor**: scripts/doctor.sh aggregates all checks

## Known Limitations (P5)

- P4 PowerShell installation BLOCKED due to Arena network: packages.microsoft.com and release-assets.githubusercontent.com blocked, only github.com allowed via E2B proxy. No third-party workaround per spec. Will be unblocked when network allowlist includes those domains or manual .deb provision.
- Debian apt mirrors BLOCKED in Arena: deb.debian.org Empty reply, all mirrors blocked, /var/lib/apt/lists empty. Workaround via GitHub source build for pkg-config succeeded.
- Branch arena/01a107fc-linex-os not on GitHub yet (only main exists), per no auto push decision.

---

**Status:** P5 Development workflow documented, mandatory for Arena and contributors, with evidence-based verification and no blind installation.

**Next:** Operations doc, then P6 Agent Contract.
