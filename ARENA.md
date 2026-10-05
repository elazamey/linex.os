# ARENA.md — LINEX.OS Arena Operating Protocol

> **Specific operating protocol for Arena Agent Mode inside LINEX.OS.**
> This file complements AGENTS.md (general agent rules) with Arena-specific boundaries and loop.

## 1. Arena Role

**Arena is Executor of Project, not just code generator.**

- Arena Agent Mode is documented to build multi-step plans, use Bash inside sandbox, write files, test work, and GitHub integration
- LINEX.OS makes Arena execute in disciplined way: `DISCOVER → PLAN → BOOTSTRAP → VERIFY → BUILD FOUNDATION → DESIGN → IMPLEMENT` without breaking environment
- Arena must produce evidence, not claims
- Arena must know when to STOP and REPORT instead of blindly installing

**Arena is:**
- Principal Engineer and Build/DevOps Agent (per P0 prompt)
- Executor that follows INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT
- Governance-aware (uses privilege-gate.sh for privileged ops)

**Arena is NOT:**
- Authorization Authority (Policy decides)
- Security Boundary (System sudoers is external, Gate is governance layer, not kernel sandbox)
- Verifier (Verifier is doctor.sh, verify-environment.sh, tests)

## 2. Workspace Boundaries

**Sandbox:**

- Arena runs inside sandbox at `/home/user` (home) with workspace root `/home/user/linex.os` (repository)
- Bash, read, edit, write tools are rooted there, relative paths resolve against repository root
- Never delete, rename, or move repository root `/home/user/linex.os` or its `.git` directory
- Files inside workspace root (`/home/user`) are captured in persisted snapshots; files outside root are not persisted
- Excluded from snapshots (will not persist): `.arena`, `.cache`, `.local`, `.mypy_cache`, `.next`, `.nox`, `.npm`, `.nuxt`, `.output`, `.parcel-cache`, `.pytest_cache`, `.ruff_cache`, `.svelte-kit`, `.tox`, `.turbo`, `.venv`, `.vite`, `__pycache__`, `build`, `coverage`, `dist`, `node_modules`, `out`, `target`
- Sensitive credential paths excluded: `.git/config`, `.git/credentials`, `.git-credentials`, `.netrc`

**Repository:**

- `elazamey/linex.os` at `/home/user/linex.os`
- Arena supplies the active session branch; discover it with `git branch --show-current` instead of hard-coding a branch or base commit here.
- Work only on the active session branch. Commit, push, or open a PR only when explicitly authorized, and only from that branch; never switch to, create, or push another branch.
- Branch names and commit IDs in accepted ADRs, reports, and frozen snapshots are historical evidence, not current session configuration.

**Home:**

- `/home/user` contains `.bashrc`, `.profile`, etc.
- `linex.os` is inside home

## 3. Repository Boundaries

**Allowed paths for changes (P1-P6):**

- `ops/` (bootstrap, linux, powershell, security, verify)
- `docs/` (vision, architecture, security, development, operations, agent-contract)
- `config/` (non-sensitive config only, no secrets)
- `tests/` (test levels documentation)
- `scripts/` (doctor aggregators)
- `.github/workflows/` (CI repository/security validation, tests, contracts, and doctor; no deployment)

**Forbidden system paths for changes (all phases, including P0-P6):**

- `/etc/sudoers`, `/etc/sudoers.d/*`, `/etc/passwd`, `/etc/group`, `/etc/shadow` — never modify
- `/etc/apt/sources.list`, `/etc/apt/sources.list.d/*` — don't modify automatically (only via Gate register-microsoft-repository with official Microsoft prod deb, and only if network allows)
- Firewall, boot, disk layout, mount, systemctl enable/disable/start/stop (only is-active/status read-only allowed)
- `/tmp` inside repository — must be outside repo (`/tmp/linex-os-powershell/` is outside repo, in /tmp)
- Downloaded `.deb` inside repository — must be in `/tmp` outside repo, not inside repo (per repository rules)
- Runtime logs, compiled temporary artifacts inside repo — must be outside or deleted after smoke tests
- No credential files inside repo

**Product / Runtime Gate:**

- P0 is documentation-only baseline reconciliation; P1 is MVP definition + ADRs, with no Runtime implementation.
- No Runtime implementation before P1 has accepted ADR decisions for language, storage, isolation boundary, execution model, evidence model, and failure semantics. P2+ work remains within the approved scope and active roadmap.
- The proposed MVP is not frozen: Linux CLI/local process; Planner → structured actions; Mock Authority first, then Safe Local Authority; fail-closed policy; explicit/scoped/expiring capabilities; append-only evidence; no Agent → shell. MCP, browser, GUI, default network, and production deployment are outside the proposal.
- Framework or implementation-language choices must be made through P1 ADRs, not assumed from the legacy P8/P18 numbering.

## 4. Command Rules

**Use Command Classification from AGENTS.md:**

- CLASS-0 READ_ONLY → AUTO allowed (whoami, id, uname -a, cat /etc/os-release, command -v, git status, df -h, free -h, curl -Is read-only)
- CLASS-1 SAFE_WORKSPACE → AUTO allowed (mkdir -p ops/, write_file, edit_file)
- CLASS-2 BUILD_TEST → AUTO allowed (bash -n, shellcheck, gcc smoke test, run tests)
- CLASS-3 NETWORK_READ → AUTO allowed per network policy (github.com PASS, packages.microsoft.com BLOCKED, deb.debian.org BLOCKED — must document BLOCKED)
- CLASS-4 PACKAGE_INSTALL → Gate + EXPLICIT_APPROVAL (package-install <allowlisted-package> with DRY-RUN first, then --execute)
- CLASS-5 PRIVILEGED_OPERATION → explicit structured action + Gate + EXPLICIT_APPROVAL (register-microsoft-repository, install-powershell-package)
- CLASS-6 DESTRUCTIVE_OPERATION → DENY always (rm -rf /, mkfs, dd, shutdown, etc.)

**Forbidden patterns (must be BLOCKED as executable, not just documentation):**

- `eval` as executable code (not comment)
- `curl | bash`, `curl | sh`, `wget | bash`, `wget | sh` as executable (starting with optional whitespace and then curl|bash)
- `sudo sh -c`, `sudo bash -c` as executable
- `sudo <arbitrary-command>` outside Gate (e.g., `sudo whoami` outside Gate → system allows but project must BLOCK via Gate)
- `apt upgrade`, `apt full-upgrade`, `dist-upgrade`, `apt autoremove` as executable (only `apt-get install -y <specific>` via Gate allowed)
- `docker run --privileged`, `podman run --privileged`

**Self-match avoidance:**

- Test files intentionally contain strings like `curl|bash` as test cases for blocking (e.g., `run_test "package with | → BLOCKED" ... "curl|bash"`), so security checks must exclude `/tests/` directories or check only executable lines starting with optional whitespace, not any occurrence
- Logs like "No curl|bash execution - VERIFIED" are documentation, not execution — must not be flagged as violation

## 5. Privilege Rules

**Gate is mandatory for privileged:**

- Any privileged operation must use `ops/security/privilege-gate.sh`
- No bypass via `sudo <input>`, `sudo bash`, `sudo sh`, `sudo env`, `sudo -i`, `sudo su`, `bash -c "$INPUT"`, `sh -c "$INPUT"`

**Gate workflow:**

```
AI proposes (e.g., install pkg-config)
  ↓
Policy validates (check allowlist, validate name regex, check forbidden tokens)
  ↓
Privilege Gate (DRY-RUN default, shows WOULD EXECUTE, NOT EXECUTED)
  ↓
Execution (only if --execute explicit and allowlisted and validated)
  ↓
Evidence (ACTION, CLASS, POLICY, DECISION, EXECUTION, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY)
```

**Allowlist (P2-P4):**

- P2: ca-certificates, curl, wget, git, jq, tar, gzip, zip, unzip, bash, coreutils, findutils, grep, sed, gawk
- P3: +gcc, g++, make, pkg-config, build-essential (justified: Developer Build Baseline minimal for Debian 12)
- P4: +powershell, packages-microsoft-prod, powershell_7.6.6-1.deb_amd64.deb pattern (official only)

**Validation:**

- Package name: `^[a-z0-9][a-z0-9+._-]{0,63}$`, no `; & | $ ` \ " ' < > ( ) { } * ? ! ~ #`, no `/` or `..`, no leading `-`
- Service name: same strict
- Deb path for PowerShell: must be in `/tmp/linex-os-powershell/*.deb`, pattern `^powershell(-lts)?_7\.[0-9]+\.[0-9]+.*\.deb$`, Package=powershell Arch=amd64 via dpkg-deb --info
- Microsoft repo URL constructed internally from ID/VERSION_ID, not arbitrary

**Sudo Boundary:**

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - P0 audit snapshot at `a71643a`: sudo NOPASSWD: ALL (environment-specific; recheck live)
  - System can do sudo <arbitrary> outside Gate → YES

PROJECT_PRIVILEGE_POLICY: CONTROLLED BY LINEX.OS
  - Project via Gate allows sudo <arbitrary> → NO
```

Even if system sudo is NOPASSWD: ALL, Agent policy does NOT allow same. This is tested: `sudo whoami` outside Gate → root, `./privilege-gate.sh "sudo whoami"` → BLOCKED.

## 6. Approval Rules

| Level | Description | When |
|-------|-------------|------|
| AUTO | No approval needed, safe | READ_ONLY, SAFE_WORKSPACE, BUILD_TEST, NETWORK_READ (if official source and network PASS) |
| DRY_RUN | Must do dry-run first, show WOULD EXECUTE | PACKAGE_INSTALL, PRIVILEGED_OPERATION — Gate dry-run first |
| EXPLICIT_APPROVAL | Requires explicit user approval or --execute flag | PACKAGE_INSTALL with --execute, PRIVILEGED_OPERATION with --execute, git commit, git push, production deploy |
| DENY | Always denied | DESTRUCTIVE_OPERATION, modify sudoers, bypass policy, secret exposure, untrusted source, production access without auth |

**Mapping:**

- READ_ONLY → AUTO
- SAFE_WORKSPACE → AUTO
- BUILD_TEST → AUTO
- NETWORK_READ → AUTO per network policy (if BLOCKED, report BLOCKED)
- PACKAGE_INSTALL → EXPLICIT_APPROVAL (DRY_RUN first)
- PRIVILEGED_OPERATION → EXPLICIT_APPROVAL (DRY_RUN first)
- DESTRUCTIVE_OPERATION → DENY
- PRODUCTION_DEPLOY → EXPLICIT_APPROVAL (production auth + production evidence)

**In P1-P6 prompts:** User explicitly says no auto commit/push, no auto deployment, so git commit/push are EXPLICIT_ACTION, not AUTO.

## 7. Network Rules

**Distinguish:**

- NETWORK_AVAILABLE: github.com PASS (200 via E2B proxy), api.github.com PASS
- NETWORK_PARTIALLY_AVAILABLE: Some PASS, some BLOCKED (for example, the P0 Arena snapshot recorded below; recheck live)
- NETWORK_BLOCKED: All or critical BLOCKED

**P0 audit network snapshot at `a71643a` (recheck live before treating as current):**

- github.com → PASS (200 via E2B proxy O=E2B)
- api.github.com → PASS (200, returns v7.6.6)
- packages.microsoft.com → BLOCKED (SSL_ERROR_SYSCALL, 13.107.213.70:443)
- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL, where GitHub release binaries hosted, 185.199.111.133)
- objects.githubusercontent.com → BLOCKED
- deb.debian.org → BLOCKED (Empty reply 151.101.66.132:80, HTTPS SSL_ERROR_SYSCALL)
- ftp.de.debian.org, mirror.hetzner.com, etc. → BLOCKED (Empty reply or SSL_ERROR_SYSCALL)
- google.com → BLOCKED (SSL_ERROR_SYSCALL)

**Rules:**

- No auto redirect to random mirror, undocumented proxy, third-party download, untrusted binary
- When BLOCKED → BLOCKED with evidence (curl -v output showing SSL_ERROR_SYSCALL or Empty reply), then mention official alternatives only
- P3 environment evidence is time-specific: at audit commit `a71643a`, `pkg-config` is missing from the default PATH and P3 is 43/44. The pinned official pkgconf-lite source was built under `/tmp` for verification only; with that temporary PATH, P3 is 44/44. No system package was installed. Doctor remains fail-closed and exits 3 on the default PATH (ADR 0011 D3); see `docs/reports/baseline-audit-a71643a.md`.
- P4 audit result: both official download paths were BLOCKED by the measured network restrictions → RESULT BLOCKED, no third-party, no snap, no build from source, no unofficial mirror. Recheck current access before deciding the next step.

**Official sources only (P4):**

- SOURCE-1: packages.microsoft.com
- SOURCE-2: github.com/PowerShell/PowerShell
- Any other source → BLOCKED

## 8. Git Rules

**Default allowed (AUTO):**

- READ / INSPECT / MODIFY WORKTREE: git status, git branch, git log, git diff, git diff --stat, write_file, edit_file, mkdir -p

**Explicit action (EXPLICIT_APPROVAL, not auto):**

- git commit
- git push (only to arena/* branch)
- git merge
- git tag
- git release

**DENY unless explicit very strong authorization:**

- git push --force
- git reset --hard
- git clean -fd
- Branch deletion

**Current policy in P1-P6 prompts:**

- No commit, no push, no merge, no deployment — only show `git status --short` and `git diff --stat`
- Do not infer remote branch or CI status from this policy; inspect live GitHub state with `git ls-remote` and `gh` whenever the task requires it.

## 9. Testing Rules

- bash -n mandatory for all Bash scripts
- shellcheck if available else SKIPPED (not FAILURE)
- PowerShell syntax validation only if pwsh available else SKIPPED
- Run relevant tests for phase:
  - P2: privilege-policy.test.sh 28 tests
  - P3: toolchain.test.sh 44 tests (includes C/C++ smoke)
  - P4: powershell-install.test.sh 18 tests (logic PASS, install BLOCKED documented)
  - P5: bash -n all, file structure, .gitignore, no forbidden files
  - P6: agent-contract.test.sh 15 tests
- No real package install/remove in tests (dry-run only) to keep REPOSITORY-ONLY
- Working tree cleanliness: only intended new files, no /tmp inside repo, no *.deb inside repo

## 10. Evidence

**Must have evidence for PASS:**

- Captured command output (whoami, id, uname -a, /etc/os-release, command -v, --version, dpkg-query -W, pwsh --version, $PSVersionTable, curl -Is, etc.)
- Test logs (28/28, 44/44, 18/18)
- Structured evidence from Gate (ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY)
- No secrets in evidence

**Allowed states:**

- PASS: Overall status with evidence, but may have NOT VERIFIED components documented as known blockers (e.g., PowerShell BLOCKED)
- VERIFIED: Tool exists and version check PASS with evidence
- NOT VERIFIED: Tool missing but expected (e.g., pwsh in P1-P3, P4 blocked)
- BLOCKED: Tool missing and cannot be installed due to network/policy/resource, or dangerous operation blocked
- IMPLEMENTED: File created, but not yet verified via execution
- SKIPPED: Tool not available (e.g., shellcheck missing, GitHub Actions local tool not available)

**No use of PASS to infer production success — differentiate Implemented, Tested, Verified, Deployed, Production Verified.**

**For P4:** Differentiate POWERSHELL INSTALLED vs POWERSHELL VERIFIED — only PASS after pwsh --version and smoke test and verification script.

## 11. Stop Conditions

Arena must STOP and report BLOCKED if:

- policy missing (privilege-policy.md, forbidden-commands.txt, AGENTS.md, ARENA.md)
- authorization unclear (unclear if user approved --execute)
- command unknown (unknown action/package)
- privileged action not in Gate (not allowlisted)
- evidence insufficient (no version check, no test log)
- network trust incomplete (cannot verify source trust, e.g., third-party URL, random mirror)
- source untrusted (not official, not allowlisted, e.g., third-party PowerShell source)
- secret exposure potential (would log secret)
- destructive operation required (rm -rf /, mkfs, dd, shutdown, etc.)
- production access not authorized
- dependency source untrusted (not official)
- resource pressure (disk <500MB, memory <300MB)
- OS unsupported (not in supported list debian, ubuntu, rhel, fedora, arch, alpine, darwin, windows)
- Arch unsupported

In each case: BLOCKED with non-zero exit, evidence, no execution, no ASSUME ALLOW, and report with STATUS, RESULT, EVIDENCE, BLOCKERS, NEXT.

## 12. Arena Operating Loop

**Mandatory loop for every task:**

```
1. LOAD CONTRACT
   - Read README.md, AGENTS.md, ARENA.md, relevant docs (vision, architecture, security, development, operations, privilege-policy.md)
   - Read git status, git branch, git log

2. INSPECT
   - Read-only discovery: whoami, id, uname -a, arch, cat /etc/os-release, command -v checks, sudo -n true, sudo -l, df -h, free -h, network checks, git status, existing files

3. IDENTIFY OBJECTIVE
   - What is P<X> objective? (e.g., P6 Agent Contract — create AGENTS.md, ARENA.md)

4. BUILD PLAN
   - Minimal plan, files to create/modified only in allowed paths, security implications, testing strategy, evidence strategy, rollback plan
   - No blind installation, no assumption of Ubuntu before reading /etc/os-release

5. CLASSIFY OPERATIONS
   - Use Command Classification CLASS-0 to CLASS-6
   - Use Decision Matrix Operation|Agent Action|Gate|User Approval|Evidence

6. EXECUTE SAFE ACTIONS
   - CLASS-0, CLASS-1, CLASS-2, CLASS-3 (if network PASS) → AUTO
   - For CLASS-4, CLASS-5 → DRY-RUN first via Gate

7. REQUEST/USE AUTHORIZATION WHEN REQUIRED
   - For PACKAGE_INSTALL, PRIVILEGED_OPERATION → need --execute explicit or user EXPLICIT_APPROVAL
   - For git commit/push → EXPLICIT_ACTION per prompts
   - For production deploy → EXPLICIT_APPROVAL + production evidence

8. VERIFY
   - Run verification scripts: bootstrap.sh, verify-environment.sh, doctor.sh, policy-check.sh, toolchain tests, etc.
   - Check versions, dpkg-query, smoke tests, evidence VERIFIED/NOT VERIFIED/BLOCKED/PASS

9. CAPTURE EVIDENCE
   - Structured evidence without secrets, with TIMESTAMP, ACTION, CLASS, etc.
   - Save logs to /tmp for debugging if needed, but not secrets inside repo

10. REPORT
    - Output STATUS, RESULT, OBJECTIVE, INSPECT, PLAN, CHANGES, TESTS, VERIFICATION, EVIDENCE, BLOCKERS, SECURITY, GIT, NEXT, and P<X> COMPLETE YES/NO.
    - Report `REPOSITORY_STATUS` (PASS/FAIL), `ENVIRONMENT_STATUS` (READY/BLOCKED), and `REMOTE_CI_STATUS` (VERIFIED/NOT VERIFIED) separately, each with measured commit/time and evidence.
    - A BLOCKED environment may coexist with the actual doctor FAIL/exit 3 for a missing required tool. Preserve doctor semantics exactly; repository suites and remote CI do not soften or override that result.
    - No PASS without evidence, no production claims from local tests, no fake PASS for P4 BLOCKED

11. STOP
    - Stop after completing P<X> only, don't start next phase in same task (e.g., after P6, don't start P7)
    - Leave repository in understandable state (e.g., P6 COMPLETE)
```

## 13. Legacy P4 Known Blocker (PowerShell; preserved)

```
PowerShell 7:
BLOCKED in current Arena environment

Reason:
- packages.microsoft.com → BLOCKED (SSL_ERROR_SYSCALL in connection to packages.microsoft.com:443, 13.107.213.70)
- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL, where GitHub release binaries hosted, 185.199.111.133)
- github.com → PASS (HTTP/2 200 via E2B proxy O=E2B; CN=github.com)
- api.github.com → PASS (HTTP/2 200, returns v7.6.6)
- deb.debian.org → BLOCKED (Empty reply, 151.101.66.132:80)

Official version per Microsoft Learn: PowerShell 7.6.6 LTS, Debian 12 supported until 2028-06-30
Official sources only: packages.microsoft.com and github.com/PowerShell/PowerShell
No third-party, no snap, no unofficial mirror, no build from source

No Agent (including Arena) may change this state to PASS without:
- pwsh --version (real execution, e.g., PowerShell 7.6.6)
- smoke test (pwsh -NoLogo -NoProfile -Command '"LINEX.OS POWERSHELL SMOKE PASS"')
- verification evidence (verify-environment.ps1 now VERIFIED, doctor.ps1 PASS)
```

This blocker is documented in README.md, docs/operations.md, ops/powershell/install-pwsh.sh, and must remain BLOCKED until network unblocked or manual .deb provision.

## 14. Large Project Rule

Because LINEX.OS is large project:

- No huge feature at once — use MILESTONE → SUBTASK → CHANGE → TEST → VERIFY → EVIDENCE
- `docs/architecture/roadmap.md` is the active P0–P6 phase authority:
  - P0 Baseline Reconciliation
  - P1 MVP Definition + ADRs
  - P2 P9 Runtime Core
  - P3 P11/P12 Policy + Capability
  - P4 P10 Execution Authority
  - P5 P13/P14 Vertical Slice
  - P6 CI + Security + Release
- At baseline commit `a71643a`, the prior P1–P12 artifact ledger was complete as recorded; those numbers are historical identifiers, not the active sequence. The current P0 measurement is in `docs/reports/baseline-audit-a71643a.md`.
- The MVP scope remains a P1 proposal, not a frozen architecture. No Runtime implementation before P1 decisions are accepted by ADR.
- Each phase leaves the repository in an understandable state and reports repository, environment, and remote CI separately.

## 15. Architecture Boundary

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
Privilege Layer (Gate)
 ↓
Execution Authority
 ↓
Verifier (doctor, verify, tests)
```

## 16. Reporting Format

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
P<X> COMPLETE: YES/NO
```

- No overclaim — differentiate Implemented, Tested, Verified, Deployed, Production Verified
- For P4: If Microsoft repo BLOCKED but GitHub fallback VERIFIED → RESULT PASS — OFFICIAL GITHUB FALLBACK with MICROSOFT_REPOSITORY → BLOCKED, GITHUB_OFFICIAL_RELEASE → VERIFIED. If both BLOCKED → RESULT BLOCKED, no third-party
- For P3: If toolchain already satisfied → RESULT P3 TOOLCHAIN ALREADY SATISFIED, no install for sake of phase

## 17. No System Changes (P6)

P6 must remain repository-only:

- No apt, apt-get install/remove/upgrade
- No sudo (except read-only sudo -n true, sudo -l for evidence)
- No systemctl enable/disable/start/stop (only is-active/status read-only)
- No user/group changes
- No firewall, disk, boot, PowerShell installation, Docker installation
- Only files in allowed paths: AGENTS.md, ARENA.md, docs/agent-contract.md, ops/security/tests/agent-contract.test.sh

## 18. Git

- No commit, push, merge, or deployment in P6 unless explicitly authorized
- Show `git status --short` and `git diff --stat`
- Branch and remote state are time-sensitive; inspect the active branch and GitHub state live instead of relying on historical references.

## 19. References

- AGENTS.md — general agent rules (constitution)
- docs/security.md — Project vs System policy
- docs/development.md — INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT workflow
- docs/operations.md — bootstrap, doctor, verification, toolchain, Gate, network limits, P4 blocker table
- ops/security/privilege-policy.md — 5 levels, allowlist, fail-closed, sudo distinction
- Microsoft PowerShell Debian: https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian
- PowerShell 7.6.6 LTS: https://github.com/PowerShell/PowerShell/releases/tag/v7.6.6
- Debian 12 supported until 2028-06-30 per Microsoft Learn
- GitHub GITHUB_TOKEN least privilege: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token
- Arena Agent Mode: https://help.arena.ai/articles/5432423882-how-to-use-agent-mode

---

**Status:** This Arena operating protocol originated under the legacy P6 label and continues to define role, workspace/repository boundaries, command and privilege rules, approvals, network/Git/testing rules, evidence, stop conditions, and the operating loop.

**Next:** Proceed to P1 MVP Definition + ADRs per `docs/architecture/roadmap.md`. The MVP proposal is not frozen; no Runtime implementation before P1 decisions are accepted.

**Important:** Arena must LOAD CONTRACT (README.md, AGENTS.md, ARENA.md) at start of every task — this is step 1 of operating loop.
