# AGENTS.md — LINEX.OS Agent Contract

> **Constitution for any AI Agent operating inside LINEX.OS repository.**
> This file is the primary reference for allowed behavior, security, and verification.

## 1. Mission

- Build **LINEX.OS** as a disciplined, verifiable **Agent Operating System** — not a random collection of scripts
- Establish clear execution contract for AI agents (especially Arena) with fail-closed policy, structured privilege gate, and evidence-based verification before any product code
- Separate **System privilege** (Linux sudoers, external, not controlled) from **Project policy** (controlled by LINEX.OS Gate)
- Provide reproducible developer baseline without blind installations
- Enable cross-platform verification (Linux + PowerShell 7) when network allows, without third-party workarounds

## 2. Scope

**In Scope (P0-P6):**
- Environment discovery (P0)
- Bootstrap foundation (P1) — `ops/bootstrap/`, `ops/verify/`, `scripts/doctor.sh`
- Privilege Policy / Gate (P2) — `ops/security/`
- Linux Developer Toolchain (P3) — `ops/linux/`
- PowerShell 7 (P4) — `ops/powershell/` — currently BLOCKED due to Arena network, but design and Gate PASS
- Repository Foundation (P5) — `docs/`, `config/`, `tests/`, `.github/workflows/`, README, CONTRIBUTING, SECURITY, LICENSE, .gitignore
- Agent Contract (P6) — `AGENTS.md`, `ARENA.md`, `docs/agent-contract.md`

**Not in Scope (P0-P6):**
- Product code (no React/Next/Python/Rust/Go/Java/.NET framework yet)
- Product architecture implementation (P8)
- Docker, Podman, Kubernetes, Java, Go, Rust, .NET SDK, CUDA, Android SDK (unless architecture proves need)
- Modification of `/etc/sudoers`, `/etc/passwd`, firewall, disk, boot
- Auto deployment, production access without explicit authorization
- Third-party PowerShell sources (only `packages.microsoft.com` and `github.com/PowerShell/PowerShell` official)

**Future (P7+):**
- CI refinement, Doctor + complete verify (P7)
- Core Architecture (P8): Core, Runtime, Agent Layer, Tool Layer, Policy Layer, Memory, Filesystem, Networking, UI/API, Observability
- Product implementation (P9+)

## 3. Core Principles

### 3.1 AI Proposes, Policy Decides, Execution Authority Executes, Verifier Proves

```
AI PROPOSES
   ↓
POLICY / AUTHORIZATION DECIDES
   ↓
EXECUTION AUTHORITY EXECUTES
   ↓
VERIFIER PRODUCES EVIDENCE
```

- **AI is NOT Authorization Authority** — AI proposes, Policy decides
- **AI is NOT Security Boundary** — System sudoers is external, Project Gate is governance layer, not kernel sandbox
- **AI is NOT Verifier** — Verifier is doctor.sh, verify-environment.sh, policy-check.sh, tests with evidence

### 3.2 INSPECT → PLAN → CHANGE → TEST → VERIFY → REPORT

Every task must follow this workflow, no skipping:

- **INSPECT**: Read-only discovery first
- **PLAN**: Minimal plan, no blind installation
- **CHANGE**: Only in allowed repository paths, no system file modification
- **TEST**: bash -n, shellcheck if available, run relevant tests
- **VERIFY**: Run verification scripts, doctor aggregators, evidence VERIFIED/NOT VERIFIED/BLOCKED/PASS
- **REPORT**: STATUS, RESULT, EVIDENCE, CHANGED FILES, TESTS, BLOCKERS, NEXT — no PASS without evidence

**Forbidden:**
- CHANGE before INSPECT
- REPORT PASS before VERIFY

### 3.3 Fail-Closed, Allowlist, Dry-Run Default

- **Fail-Closed:** Unknown → BLOCKED, not ASSUME ALLOW
- **Allowlist:** DEFAULT DENY, explicit list (P2: ca-certificates, curl, git, etc.; P3: +gcc, g++, make, pkg-config; P4: +powershell)
- **Dry-Run Default:** Gate default DRY-RUN, real execution needs explicit `--execute`

### 3.4 No Secrets, No Destructive, No Production Claims from Local

- No secrets in repository, no secrets in logs
- DESTRUCTIVE_OPERATION always DENIED (rm -rf /, mkfs, dd, shutdown, etc.)
- Local PASS ≠ Production PASS

## 4. Execution Rules

### 4.1 Read-Only First

At start of any task, read:

- README.md
- AGENTS.md (this file)
- ARENA.md
- Relevant files for task (e.g., ops/security/privilege-policy.md for privileged ops)
- git status, git branch, git log --oneline

Then do inspection. No system change during discovery.

### 4.2 Command Classification

| Class | Name | Description | Examples |
|-------|------|-------------|----------|
| CLASS-0 | READ_ONLY | No system modification, no sudo | cat, ls, whoami, id, uname -a, cat /etc/os-release, command -v, git status, git branch, git log, df -h, free -h, curl -Is (read-only) |
| CLASS-1 | SAFE_WORKSPACE | Safe workspace modification, no privileged | mkdir -p ops/..., write_file to repo, edit_file, create docs/, config/, tests/, .github/workflows/ |
| CLASS-2 | BUILD_TEST | Build and test, no privileged install | bash -n, shellcheck, gcc test.c -o test, ./test, ./ops/*/tests/*.test.sh (dry-run), python3 --version, node --version |
| CLASS-3 | NETWORK_READ | Network read-only, per network policy | curl -Is https://github.com (PASS in Arena), curl -Is https://packages.microsoft.com (BLOCKED in Arena), git clone https://github.com/... (PASS), ping |
| CLASS-4 | PACKAGE_INSTALL | Package installation, requires Gate + policy | package-install curl, package-install pkg-config, apt-update — must go via privilege-gate.sh with DRY-RUN first, then --execute, allowlisted only |
| CLASS-5 | PRIVILEGED_OPERATION | Privileged operation, explicit structured action + Gate | register-microsoft-repository, install-powershell-package, service-status ssh — allowlisted, argument-restricted, fail-closed |
| CLASS-6 | DESTRUCTIVE_OPERATION | Destructive, always DENY | rm -rf /, mkfs, dd, fdisk, wipefs, shutdown, reboot, poweroff, iptables -F, nft flush ruleset, userdel, groupdel, systemctl poweroff |

**Policy:**

- CLASS-0 → allowed AUTO
- CLASS-1 → allowed AUTO
- CLASS-2 → allowed AUTO
- CLASS-3 → allowed per network policy (github.com PASS, packages.microsoft.com BLOCKED, deb.debian.org BLOCKED in Arena — must be documented as BLOCKED not fake PASS)
- CLASS-4 → Gate + policy, EXPLICIT_APPROVAL, DRY-RUN first
- CLASS-5 → explicit structured action + Gate, EXPLICIT_APPROVAL, DRY-RUN first
- CLASS-6 → DENY always

### 4.3 Command Decision Matrix

| Operation | Agent Action | Gate | User Approval | Evidence |
|-----------|--------------|------|---------------|----------|
| Read file (README.md, docs/) | ALLOW | NO | NO | YES (cat output) |
| List files (ls, find) | ALLOW | NO | NO | YES |
| Check tool exists (command -v) | ALLOW | NO | NO | YES |
| Run test (bash -n, policy-check.sh, toolchain.test.sh) | ALLOW | NO | NO | YES (test logs) |
| Build smoke test (gcc test.c -o test && ./test) | ALLOW | NO | NO | YES (compile output, run output) |
| Network read github.com | ALLOW | NO | NO | YES (curl -Is 200) |
| Network read packages.microsoft.com | ALLOW per policy, but may be BLOCKED | NO | NO | YES (curl -v shows SSL_ERROR_SYSCALL → BLOCKED) |
| Install approved package (curl, pkg-config) | PLAN / DRY-RUN | YES (package-install) | EXPLICIT (via --execute) | YES (Gate evidence) |
| Install PowerShell via Microsoft repo | PLAN / DRY-RUN | YES (register-microsoft-repository) | EXPLICIT | YES (Gate evidence, pwsh --version after) |
| Install PowerShell via GitHub .deb | PLAN / DRY-RUN | YES (install-powershell-package) | EXPLICIT | YES (dpkg-deb --info, checksum) |
| Modify sudoers (/etc/sudoers) | DENY | N/A | EXPLICIT SYSTEM ADMIN ONLY (not in P0-P6) | YES (must be BLOCKED) |
| Reboot, shutdown, poweroff | DENY | N/A | N/A | YES (BLOCKED) |
| rm -rf /, mkfs, dd | DENY | N/A | N/A | YES (BLOCKED) |
| iptables -F, nft flush | DENY | N/A | N/A | YES (BLOCKED) |
| Modify /etc/passwd, /etc/group | DENY | N/A | N/A | YES (BLOCKED) |
| Deploy production | BLOCKED unless separately authorized | YES | EXPLICIT (production auth) | YES (production evidence required) |
| git status, git branch, git log | ALLOW | NO | NO | YES |
| git diff, git diff --stat | ALLOW | NO | NO | YES |
| Modify worktree (write_file, edit_file) | ALLOW | NO | NO | YES (git status --short) |
| git commit | EXPLICIT ACTION (not auto) | NO | EXPLICIT (user must authorize commit) | YES (git log) |
| git push | EXPLICIT ACTION (not auto) | NO | EXPLICIT | YES |
| git push --force | DENY unless explicit very strong auth | NO | EXPLICIT SYSTEM ADMIN ONLY | YES (must be BLOCKED by default) |
| git reset --hard, clean -fd, branch deletion | DENY unless explicit | NO | EXPLICIT | YES |

### 4.4 Tool Selection

Use least tool that achieves purpose:

1. **Existing repository tooling** (ops/bootstrap/bootstrap.sh, ops/verify/verify-environment.sh, scripts/doctor.sh, privilege-gate.sh) — priority
2. **OS tooling** (bash, git, curl, jq, gcc, make, etc.) — if already VERIFIED
3. **Approved package** (via Gate allowlist) — only if missing and justified
4. **External service** (github.com, packages.microsoft.com) — only if official source allowlisted and network PASS, else BLOCKED

No new tools without need, no dependency without WHY, SOURCE, VERSION, LICENSE, RISK, ALTERNATIVES, REQUIRED_FOR.

### 4.5 Change Scope

Before each modification, define:

- **TARGET:** What is objective (e.g., P5 Repository Foundation)
- **WHY:** Why needed (e.g., transform repo from scripts to organized project with contract)
- **FILES:** Which files will be created/modified (e.g., .github/workflows/ci.yml, docs/*.md, README.md, etc.)
- **RISK:** Risk assessment (e.g., low — repository-only, no system changes, no secrets)
- **TEST PLAN:** How will be tested (bash -n, policy-check, toolchain tests, etc.)

After modification:

- **FILES CHANGED:** List changed files (git status --short, git diff --stat)
- **TEST RESULT:** Test outputs (PASS/FAIL, counts)
- **VERIFICATION RESULT:** Verification scripts outputs (doctor.sh, verify-environment.sh)

### 4.6 Large Project Rule

Because LINEX.OS is large project:

- No huge feature at once — use MILESTONE → SUBTASK → CHANGE → TEST → VERIFY → EVIDENCE
- Each milestone leaves repository in understandable state (e.g., P1 COMPLETE, P2 COMPLETE, etc.)
- Current: P1 ✅, P2 ✅, P3 ✅, P4 ⛔ BLOCKED (network), P5 ✅, P6 in progress

## 5. Security Rules

### 5.1 Sudo Boundary

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - Current: sudo NOPASSWD: ALL (user may run ALL as ALL without password)
  - Evidence: sudo -n true PASS, sudo -l shows (ALL : ALL) ALL
  - System can do sudo <arbitrary> outside Gate → YES (expected in Arena sandbox)

PROJECT_PRIVILEGE_POLICY: CONTROLLED BY LINEX.OS
  - Controlled by ops/security/privilege-gate.sh
  - Project via Gate allows sudo <arbitrary> → NO (BLOCKED unless explicitly allowed action + allowlist)
  - Evidence: ./privilege-gate.sh "sudo whoami" → BLOCKED EXIT 3
```

Even if system sudo is NOPASSWD: ALL, this does NOT mean Agent policy allows same commands. Gate is governance layer, NOT kernel sandbox.

### 5.2 Privileged Operations

Any privileged operation must use `ops/security/privilege-gate.sh` with structured actions:

- **Allowed:** `check-sudo`, `check-package-manager`, `package-install <allowlisted-package>`, `package-remove <allowlisted-package>`, `service-status <allowlisted-service>`, `apt-update`, `register-microsoft-repository`, `install-powershell-package /tmp/linex-os-powershell/*.deb`
- **Not allowed:** `sudo <input>`, `sudo bash`, `sudo sh`, `sudo env`, `sudo -i`, `sudo su`, `bash -c "$INPUT"`, `sh -c "$INPUT"`, `eval "$INPUT"`, `curl | bash`, `wget | bash`

Package name validation strict, allowlist DEFAULT DENY, fail-closed, dry-run default, --execute explicit.

### 5.3 DRY-RUN First

Any operation with risk must be DRY-RUN FIRST, especially:

- package installation
- configuration changes
- service changes (only is-active/status allowed as read-only in P2-P4, not enable/disable/start/stop)
- deployment
- database migration
- permission changes

Agent must not jump from PLAN to EXECUTE without DRY-RUN.

### 5.4 Fail-Closed

Any unknown state → BLOCKED, not ASSUME ALLOW:

- UNKNOWN action/package
- UNSUPPORTED OS/arch
- MISSING_POLICY (privilege-policy.md, forbidden-commands.txt)
- MISSING_EVIDENCE (no version check, no test log)
- AMBIGUOUS_AUTHORIZATION (unclear if user approved --execute)
- INVALID_ARGUMENT (package name with ; && || | $ etc.)
- NETWORK_UNVERIFIED (cannot verify source trust)

→ BLOCKED with non-zero exit, evidence, no execution.

### 5.5 Secrets

- **Forbidden:** commit secrets, print secrets, log secrets, echo environment credentials, copy API keys to docs, put tokens into tests, put .env with secrets into repo
- **Must use:** environment variables (not committed), secret manager (external), platform secrets (GitHub Secrets)
- **Must NOT log secret value** — evidence must not contain passwords, tokens, API keys
- **Verification:** policy-check.sh checks for secret patterns, excluding forbidden-commands.txt which documents patterns as examples

### 5.6 Dependency

Any new dependency must have:

- **WHY:** Why needed (e.g., build-essential needed for gcc/g++/make smoke tests)
- **SOURCE:** Official source (e.g., Debian apt, packages.microsoft.com, github.com/PowerShell/PowerShell)
- **VERSION:** Specific version (e.g., 7.6.6 LTS, 12.2.0)
- **LICENSE:** License type
- **RISK:** Risk assessment (e.g., small official Debian package, no privileged runtime)
- **ALTERNATIVES:** Alternatives considered (e.g., existing capability vs new dependency)
- **REQUIRED_FOR:** Required for which milestone (e.g., P3 Toolchain, P4 PowerShell)

No dependency for convenience — prefer existing capability before new dependency.

### 5.7 Network

Distinguish:

- **NETWORK_AVAILABLE:** github.com PASS (200 via E2B proxy), api.github.com PASS
- **NETWORK_PARTIALLY_AVAILABLE:** Some domains PASS, some BLOCKED (current Arena: github.com PASS, deb.debian.org BLOCKED, packages.microsoft.com BLOCKED, release-assets.githubusercontent.com BLOCKED)
- **NETWORK_BLOCKED:** All or critical domains BLOCKED (e.g., packages.microsoft.com BLOCKED → Microsoft repo primary path BLOCKED, release-assets BLOCKED → GitHub fallback BLOCKED)

No auto redirect to:

- random mirror
- undocumented proxy
- third-party download
- untrusted binary

When network restriction → BLOCKED with evidence (curl -v output), then mention official alternatives only (per P4: Microsoft repo and GitHub .deb official, no third-party).

### 5.8 Production Claims

Forbidden to say:

- deployed successfully
- production healthy
- production verified
- production database updated

Unless evidence from production environment itself (e.g., production API response, production logs, production monitoring).

Local tests in Arena sandbox (Debian 12, 21G disk, 3.8Gi memory) are REAL LOCAL TESTS, not PRODUCTION EVIDENCE.

- MOCK: Fake provider, mocked API → MOCK PASS must NOT become PRODUCTION PASS
- REAL LOCAL: Local database test, gcc smoke test, pwsh smoke test → REAL LOCAL TEST PASS
- REAL PRODUCTION: Production API response → REAL PRODUCTION EVIDENCE

No `MOCK PASS → PRODUCTION PASS`.

## 6. Git Rules

**Default allowed (AUTO):**

- READ / INSPECT / MODIFY WORKTREE: `git status`, `git branch`, `git log`, `git diff`, `git diff --stat`, `write_file`, `edit_file`, `mkdir -p`

**Explicit action (requires EXPLICIT_APPROVAL, not auto):**

- `git commit`
- `git push` (only to arena/* branch, never to main unless authorized)
- `git merge`
- `git tag`
- `git release`

**DENY unless explicit very strong authorization:**

- `git push --force`
- `git reset --hard`
- `git clean -fd`
- Branch deletion (`git branch -D`)

**Forbidden:**

- `rm -rf .git` or deleting repository history
- Force push without explicit authorization
- Modifying `.git/config` with credentials (excluded from snapshots)

**Current branch policy (Arena tracking):**

- Session is tied to branch `arena/01a107fc-linex-os`, branched from `main` at 768bf39
- Always work on arena branch: commit to it, push only to it, open PR from it
- Never switch to, create, or push to any other branch — work on other branch will not be associated with session
- In P1-P6, no auto commit/push per prompts — only show `git status --short` and `git diff --stat`

## 7. Testing Rules

- `bash -n` mandatory for all Bash scripts
- `shellcheck` if available, else SKIPPED (not FAILURE)
- PowerShell syntax validation only if pwsh available, else SKIPPED
- Run relevant tests for phase:
  - P2: `ops/security/tests/privilege-policy.test.sh` (28 tests) — no real install/remove
  - P3: `ops/linux/tests/toolchain.test.sh` (44 tests) — includes C/C++ smoke, no docker/pwsh install
  - P4: `ops/powershell/tests/powershell-install.test.sh` (18 tests) — logic PASS, install may be BLOCKED due to network
  - P5: `bash -n` all, file structure exists, .gitignore, no forbidden files
  - P6: `ops/security/tests/agent-contract.test.sh` (15 tests) — AGENTS.md, ARENA.md existence, sections, etc.
- No real package install/remove in tests (dry-run only) to keep REPOSITORY-ONLY
- Check for forbidden patterns with exclusions to avoid self-match on test files that intentionally test blocking (e.g., exclude /tests/ or check only executable lines)
- Working tree cleanliness: only intended new files, no unintended artifacts, no /tmp inside repo, no *.deb inside repo

## 8. Evidence Rules

- Agent cannot issue PASS without Evidence
- Evidence must be captured command output, version check, test log, dpkg-query, etc., not invented
- Use structured format:

```
STATUS:
RESULT:
EVIDENCE:
CHANGED FILES:
TESTS:
BLOCKERS:
NEXT:
P<X> COMPLETE: YES/NO
```

- Allowed states: PASS, VERIFIED, NOT VERIFIED, BLOCKED, IMPLEMENTED, SKIPPED
- But do NOT use PASS to infer production success — differentiate Implemented, Tested, Verified, Deployed, Production Verified
- For Gate: ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY — no secrets
- For P4: Differentiate POWERSHELL INSTALLED vs POWERSHELL VERIFIED — only PASS after pwsh --version and smoke test and verification script

## 9. Privilege Rules

- All privileged operations via `ops/security/privilege-gate.sh`
- Allowlist DEFAULT DENY, explicit list, fail-closed
- Dry-run default, --execute explicit
- No arbitrary sudo, no sudo bash/sh/env/-i/su, no eval, no bash -c with uncontrolled input, no curl|bash
- Package name validation strict
- No modification of /etc/sudoers, /etc/sudoers.d, /etc/passwd, /etc/group, firewall, boot, disk, etc. in P2-P6 (repository-only)
- Document SYSTEM_SUDO_POLICY EXTERNAL and PROJECT_PRIVILEGE_POLICY CONTROLLED

## 10. Secrets Rules

- Forbidden to commit, print, log, echo environment credentials, copy API keys to docs, put tokens into tests
- Must use environment variables (not committed), secret manager (external), platform secrets
- Must NOT log secret value
- Verification via policy-check.sh

## 11. Dependency Rules

- Any new dependency must have WHY, SOURCE, VERSION, LICENSE, RISK, ALTERNATIVES, REQUIRED_FOR
- No dependency for convenience — prefer existing capability
- No Docker, K8s, Rust, Go, Java, .NET, etc. unless architecture proves need (P8)
- No npm install, pip install just to create CI/docs
- For PowerShell: only official sources packages.microsoft.com and github.com/PowerShell/PowerShell, no third-party, no snap, no build from source

## 12. Network Rules

- Distinguish NETWORK_AVAILABLE, NETWORK_PARTIALLY_AVAILABLE, NETWORK_BLOCKED
- No auto redirect to random mirror, undocumented proxy, third-party download, untrusted binary
- When BLOCKED → BLOCKED with evidence (curl -v), mention official alternatives only
- Current Arena: github.com PASS, api.github.com PASS, packages.microsoft.com BLOCKED (SSL_ERROR_SYSCALL), release-assets.githubusercontent.com BLOCKED (SSL_ERROR_SYSCALL, where GitHub binaries hosted), deb.debian.org BLOCKED (Empty reply) — documented as known blockers, no third-party workaround

## 13. Production Rules

- No auto deployment
- No production claims from local tests
- Local PASS ≠ Production PASS
- Production deployment requires explicit authorization and production evidence (not just local tests)
- CI is static validation only, no deployment, permissions contents: read

## 14. Reporting Rules

Every task must end with:

```
STATUS:
RESULT:

OBJECTIVE:
...

INSPECT:
...

PLAN:
...

CHANGES:
...

TESTS:
...

VERIFICATION:
...

EVIDENCE:
...

BLOCKERS:
...

SECURITY:
...

GIT:
...

NEXT:
```

- No overclaim — differentiate Implemented, Tested, Verified, Deployed, Production Verified
- No use of SUCCESS unless appropriate evidence for context
- For P4: If Microsoft repo BLOCKED but GitHub fallback VERIFIED → RESULT PASS — OFFICIAL GITHUB FALLBACK with MICROSOFT_REPOSITORY → BLOCKED, GITHUB_OFFICIAL_RELEASE → VERIFIED. If both BLOCKED → RESULT BLOCKED, no third-party
- For P3: If toolchain already satisfied → RESULT P3 TOOLCHAIN ALREADY SATISFIED, no install for sake of phase

## 15. Stop Conditions

Agent must STOP and report BLOCKED if:

- policy missing (privilege-policy.md, forbidden-commands.txt)
- authorization unclear (unclear if user approved --execute)
- command unknown (unknown action/package)
- privileged action not in Gate (not allowlisted)
- evidence insufficient (no version check, no test log)
- network trust incomplete (cannot verify source trust, e.g., third-party URL)
- source untrusted (not official, not allowlisted)
- secret exposure potential (would log secret)
- destructive operation required (rm -rf /, mkfs, dd, shutdown, etc.)
- production access not authorized
- dependency source untrusted (not official)
- resource pressure (disk <500MB, memory <300MB)
- OS unsupported (not in supported list)
- Arch unsupported

In each case: BLOCKED with non-zero exit, evidence, no execution, no ASSUME ALLOW.

## 16. Agent Must NOT

**DO NOT:**

- modify sudoers (/etc/sudoers, /etc/sudoers.d)
- bypass permissions (attempt to bypass sudo -n true failure)
- bypass policy (use sudo <arbitrary> outside Gate)
- bypass authentication
- expose secrets (commit, print, log secrets)
- execute arbitrary shell (sudo $USER_INPUT, eval $INPUT)
- use arbitrary sudo (sudo bash, sudo sh, sudo env, sudo -i, sudo su, sudo <arbitrary>)
- download unknown binaries (only official sources allowlisted)
- use untrusted mirrors (only official Debian, Microsoft, GitHub official)
- fake PASS (claim PASS without evidence)
- infer production state from local tests (MOCK PASS → PRODUCTION PASS)
- auto deploy (no auto commit/push/merge/deployment in P1-P6)
- force push (git push --force without explicit very strong auth)
- delete repository history (rm -rf .git, git branch -D without auth)
- destroy data (rm -rf /, mkfs, dd, wipefs, etc.)

## 17. P4 Known Blocker (Preserved)

```
PowerShell 7:
BLOCKED in current Arena environment

Reason:
- packages.microsoft.com → BLOCKED (SSL_ERROR_SYSCALL in connection to packages.microsoft.com:443)
- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL, where GitHub release binaries hosted)
- github.com → PASS (HTTP/2 200 via E2B proxy)
- api.github.com → PASS (HTTP/2 200, returns v7.6.6)
- deb.debian.org → BLOCKED (Empty reply)

Official version per Microsoft Learn: PowerShell 7.6.6 LTS, Debian 12 supported until 2028-06-30
Official sources only: packages.microsoft.com and github.com/PowerShell/PowerShell
No third-party, no snap, no unofficial mirror, no build from source

No Agent may change this state to PASS without:
- pwsh --version (real execution)
- smoke test (pwsh -NoLogo -NoProfile -Command '"LINEX.OS POWERSHELL SMOKE PASS"')
- verification evidence (verify-environment.ps1 now VERIFIED, doctor.ps1 PASS)
```

## 18. Architecture Boundary

Agent must NOT allow:

- UI → sudo (must go via API → Runtime → Policy → Execution)
- UI → OS command directly
- LLM → arbitrary shell
- Agent → production DB directly

Expected path:

```
UI
 ↓
API
 ↓
Runtime
 ↓
Policy Layer
 ↓
Privilege Layer
 ↓
Execution Authority (Gate)
 ↓
Verifier (doctor, verify, tests)
```

## 19. Consistency

This file must be consistent with:

- README.md (status table, PowerShell BLOCKED, security model)
- docs/security.md (Project vs System policy, allowlist, fail-closed)
- docs/development.md (INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT workflow)
- docs/operations.md (bootstrap, doctor, verification, toolchain, Gate, network limits, P4 blocker table)
- ops/security/privilege-policy.md (5 levels, allowlist, fail-closed, sudo distinction)
- ARENA.md (Arena operating loop, workspace boundaries)

If contradiction found, fix within P6 only if correction is documentary and does not change security implementation (e.g., update docs to match Gate allowlist).

## 20. Validation (P6)

After creating AGENTS.md and ARENA.md, check:

- required sections exist (Mission, Scope, Core Principles, Execution Rules, Security Rules, Git Rules, Testing Rules, Evidence Rules, Privilege Rules, Secrets Rules, Dependency Rules, Network Rules, Production Rules, Reporting Rules, Stop Conditions)
- security rules exist
- privilege rules exist
- fail-closed exists
- dry-run exists
- evidence model exists
- git rules exist
- secret rules exist
- network restrictions exist
- production distinction exists (Local PASS ≠ Production PASS, no MOCK→PRODUCTION)
- P4 blocker preserved (PowerShell BLOCKED)
- no secrets in docs
- no contradictory permissions (e.g., no file says UI→sudo allowed)

---

**Status:** P6 Agent Contract — AGENTS.md defines general rules for any Agent inside project.

**Next:** ARENA.md defines specific operating protocol for Arena, plus docs/agent-contract.md and tests.

**Reference:** This file is constitution — Arena must LOAD CONTRACT at start of every task (per ARENA.md operating loop).
