# LINEX.OS — Agent Contract (Policy vs Execution Separation)

## Overview

This document clarifies the separation between **Policy** (what is allowed), **Execution** (who executes), and **Verification** (how we prove). This separation is fundamental to LINEX.OS and governs any AI Agent, especially Arena.

LINEX.OS principle: **AI PROPOSES → POLICY/AUTHORIZATION DECIDES → EXECUTION AUTHORITY EXECUTES → VERIFIER PRODUCES EVIDENCE**

- AI Agent is NOT Authorization Authority
- AI Agent is NOT Security Boundary
- AI Agent is NOT Verifier (it produces actions, Verifier validates)

Related files:
- `AGENTS.md` — General Agent rules (constitution for any Agent)
- `ARENA.md` — Arena-specific operating protocol (role, boundaries, loop, stop conditions)
- `docs/security.md` — System vs Project privilege, allowlist, fail-closed
- `docs/development.md` — INSPECT→PLAN→CHANGE→TEST→VERIFY→REPORT workflow
- `docs/operations.md` — Bootstrap, doctor, verification, toolchain, Gate, network limits, P4 blocker
- `ops/security/privilege-policy.md` — 5 levels, allowlist, fail-closed, sudo distinction
- `ops/security/privilege-gate.sh` — Execution authority (Gate)

## 1. Separation of Concerns

### AI (Proposer)

Role: Proposes actions, reads, plans, writes safe workspace changes, runs tests (read-only first).

Allowed:
- READ_ONLY (CLASS-0): whoami, id, uname, cat /etc/os-release, command -v, git status, df, free, curl -Is
- SAFE_WORKSPACE (CLASS-1): mkdir -p ops/, write_file, edit_file in allowed paths
- BUILD_TEST (CLASS-2): bash -n, shellcheck, gcc smoke, run tests
- NETWORK_READ (CLASS-3): Official sources only, per network policy (github.com PASS, packages.microsoft.com BLOCKED in Arena)

Not allowed without Gate + explicit approval:
- PACKAGE_INSTALL (CLASS-4)
- PRIVILEGED_OPERATION (CLASS-5)
- DESTRUCTIVE_OPERATION (CLASS-6) → always DENY

### Policy / Authorization (Decider)

Role: Decides if proposed action is allowed, based on allowlist, validation, network policy, security rules.

Artifacts:
- `AGENTS.md` — constitution
- `ARENA.md` — Arena protocol
- `ops/security/privilege-policy.md` — privilege levels, allowlist, fail-closed
- `ops/security/policy-check.sh` — checks for forbidden patterns (eval executable, curl|bash executable, sudo sh -c executable, apt upgrade executable, /tmp inside repo, *.deb inside repo, credentials inside repo)
- `docs/security.md` — System vs Project
- `config/` — non-sensitive config only

Policy checks:
- Package name regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no forbidden tokens `; & | $ ` \ " ' < > ( ) { } * ? ! ~ #`, no `/` or `..`, no leading `-`
- Service name same strict
- Deb path must be `/tmp/linex-os-powershell/*.deb` pattern `^powershell(-lts)?_7\.[0-9]+\.[0-9]+.*\.deb$`, Package=powershell Arch=amd64
- Microsoft repo URL constructed internally, not arbitrary
- No secrets in repo (grep for credential patterns, exclude tests)
- No /tmp inside repo, no *.deb inside repo

### Execution Authority (Gate)

Role: Executes only allowlisted, validated actions, with DRY-RUN default, structured evidence.

Artifact: `ops/security/privilege-gate.sh`

Gate enforces:
- No `sudo <input>`, no `sudo bash/sh/env/-i/su`, no `bash -c "$INPUT"`, no `sh -c "$INPUT"`
- Allowlist check: P2 ca-certificates curl wget git jq tar gzip zip unzip bash coreutils findutils grep sed gawk; P3 +gcc g++ make pkg-config build-essential; P4 +powershell packages-microsoft-prod powershell_7.6.6-1.deb_amd64.deb pattern
- Validation: package name regex, forbidden tokens, deb validation via dpkg-deb --info
- DRY-RUN default: `WOULD EXECUTE` `NOT EXECUTED` with full structured evidence, only `--execute` explicit runs
- Fail-closed: UNKNOWN → BLOCKED, UNSUPPORTED → BLOCKED, MISSING_POLICY → BLOCKED, MISSING_EVIDENCE → BLOCKED, AMBIGUOUS_AUTHORIZATION → BLOCKED, INVALID_ARGUMENT → BLOCKED, NETWORK_UNVERIFIED → BLOCKED
- Structured evidence: ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE / EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY, reason if BLOCKED

Example:
```
./privilege-gate.sh package-install pkg-config
# → POLICY: PASS (allowlisted)
# → DECISION: DRY-RUN (default)
# → EXECUTION: NOT EXECUTED
# → EVIDENCE: WOULD EXECUTE: sudo apt-get install -y pkg-config

./privilege-gate.sh --execute package-install pkg-config
# → EXECUTION: EXECUTED
# → EXIT_CODE: 0 or non-zero
```

Example BLOCKED:
```
./privilege-gate.sh "sudo whoami"
# → UNKNOWN action → BLOCKED
# System outside Gate: sudo whoami → root (system allows, project does NOT)
```

### Verifier (Evidence Producer)

Role: Produces evidence, does not allow. Checks if tool exists, version, smoke test, test logs, no overclaim.

Artifacts:
- `ops/bootstrap/bootstrap.sh` — Phase 1
- `ops/verify/verify-environment.sh` — Phase 1 and overall
- `ops/verify/verify-environment.ps1` — PowerShell equivalent
- `ops/linux/doctor.sh` and `ops/powershell/doctor.ps1` — Aggregators
- `ops/security/policy-check.sh` — Forbidden patterns
- `ops/security/tests/privilege-policy.test.sh` — 28 tests
- `ops/linux/tests/toolchain.test.sh` — 44 tests
- `ops/powershell/tests/powershell-install.test.sh` — 18 tests
- `ops/security/tests/agent-contract.test.sh` — 15 tests (P6)

Verifier outputs:
- PASS / VERIFIED / NOT VERIFIED / BLOCKED / SKIPPED with evidence
- Never PASS without evidence
- No MOCK PASS → PRODUCTION PASS (Local DB REAL LOCAL TEST, Fake provider MOCK, Production API REAL PRODUCTION EVIDENCE)
- No production claims from local tests (deployed successfully, production healthy, DB updated unless evidence from production itself)

## 2. Workflow

Core workflow mandatory for every task:

```
INSPECT → PLAN → CHANGE → TEST → VERIFY → REPORT
```

- No CHANGE before INSPECT (read-only first: README.md, AGENTS.md, ARENA.md, relevant files, git status, branch, log, whoami, id, uname, /etc/os-release, command -v, sudo -n true, df, free, network)
- No REPORT PASS before VERIFY (run verification scripts, tests, bash -n, policy-check)
- TEST before VERIFY (run tests)
- PLAN before CHANGE (minimal plan, files only in allowed paths, security implications, testing strategy, evidence strategy, rollback plan)

## 3. Command Classification (AGENTS.md Section 5)

- CLASS-0 READ_ONLY → AUTO allowed
- CLASS-1 SAFE_WORKSPACE → AUTO allowed
- CLASS-2 BUILD_TEST → AUTO allowed
- CLASS-3 NETWORK_READ → AUTO allowed per network policy (BLOCKED must be documented with evidence)
- CLASS-4 PACKAGE_INSTALL → Gate + policy + DRY-RUN + EXPLICIT_APPROVAL + evidence
- CLASS-5 PRIVILEGED_OPERATION → explicit structured action + Gate + EXPLICIT_APPROVAL + evidence
- CLASS-6 DESTRUCTIVE_OPERATION → DENY always

## 4. Decision Matrix (AGENTS.md Section 6)

| Operation | Agent Action | Gate | User Approval | Evidence |
|-----------|--------------|------|---------------|----------|
| Read file | ALLOW | NO | NO | YES |
| Write safe file in repo | ALLOW | NO | NO | YES |
| Run test | ALLOW | NO | NO | YES |
| Install approved package | PLAN/DRY-RUN | YES | EXPLICIT | YES |
| Modify sudoers | DENY | N/A | EXPLICIT SYSTEM ADMIN ONLY | YES |
| Reboot | DENY | N/A | N/A | YES |
| Deploy production | BLOCKED unless separately authorized | YES | EXPLICIT | YES |
| Arbitrary sudo | DENY via Gate (system may allow outside) | YES (BLOCKED) | DENY | YES |

## 5. Sudo Boundary (AGENTS.md Section 7)

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
PROJECT_PRIVILEGE_POLICY: CONTROLLED BY LINEX.OS (Gate)
```

Even if `sudo NOPASSWD: ALL`, Agent policy does NOT allow same. Must be tested: `sudo whoami` outside Gate → root, `./privilege-gate.sh "sudo whoami"` → BLOCKED.

## 6. DRY-RUN

Any risk (package install, config, service, DB migration, permission change) → Agent not jump PLAN→EXECUTE, must DRY-RUN first.

Gate DRY-RUN default shows `WOULD EXECUTE`, `NOT EXECUTED` with full structured evidence.

## 7. Approval Levels (AGENTS.md Section 9)

- AUTO → READ_ONLY, SAFE_WORKSPACE, BUILD_TEST, NETWORK_READ (if network PASS)
- DRY_RUN → PACKAGE_INSTALL, PRIVILEGED_OPERATION (Gate dry-run first)
- EXPLICIT_APPROVAL → PACKAGE_INSTALL with --execute, PRIVILEGED_OPERATION with --execute, git commit, git push, production deploy
- DENY → DESTRUCTIVE_OPERATION, modify sudoers, bypass policy, secret exposure, untrusted source, production access without auth

## 8. Fail-Closed (AGENTS.md Section 10)

UNKNOWN, UNSUPPORTED, MISSING_POLICY, MISSING_EVIDENCE, AMBIGUOUS_AUTHORIZATION, INVALID_ARGUMENT, NETWORK_UNVERIFIED → BLOCKED not ASSUME ALLOW.

## 9. Evidence Model (AGENTS.md Section 11)

No PASS without Evidence. States: PASS, VERIFIED, NOT VERIFIED, BLOCKED, IMPLEMENTED, SKIPPED. No use of PASS to infer production.

- Mock vs Real: Local DB REAL LOCAL TEST, Fake provider MOCK, Production API REAL PRODUCTION EVIDENCE, no MOCK PASS→PRODUCTION PASS
- Production claims forbidden without production evidence
- Captured output: whoami, id, uname -a, /etc/os-release, command -v, --version, dpkg-query -W, pwsh --version, $PSVersionTable, curl -Is, test logs, Gate structured evidence

## 10. Git Policy (AGENTS.md Section 15)

READ/INSPECT/MODIFY WORKTREE → AUTO
Commit/push/merge/tag/release → EXPLICIT ACTION
No git push --force unless explicit very strong auth
Forbidden: reset --hard, clean -fd, branch deletion unless explicit

Current P1-P6 prompts: no commit, no push, no merge, no deployment — only git status --short and git diff --stat.

## 11. Secrets (AGENTS.md Section 12)

Forbidden: commit/print/log secrets, echo env credentials, copy API keys to docs, put tokens into tests.

Must use: env vars, secret manager, platform secrets, not log secret value.

Check: grep for credential patterns, exclude tests, ensure no secrets in evidence.

## 12. Dependencies (AGENTS.md Section 13)

New dependency must have: WHY, SOURCE, VERSION, LICENSE, RISK, ALTERNATIVES, REQUIRED_FOR.

No dependency for convenience, prefer existing capability.

P3 example: pkg-config required for build, official Debian package BLOCKED due to network, workaround via git clone https://github.com/pkgconf/pkgconf.git → built pkgconf-lite → pkg-config VERIFIED (documented as workaround, not ideal).

## 13. Network (AGENTS.md Section 14)

NETWORK_AVAILABLE, PARTIALLY_AVAILABLE, BLOCKED.

No auto redirect to random mirror, undocumented proxy, third-party download, untrusted binary.

When BLOCKED → BLOCKED with evidence, then official alternatives only.

Current Arena:
- github.com PASS, api.github.com PASS
- packages.microsoft.com BLOCKED, release-assets.githubusercontent.com BLOCKED, deb.debian.org BLOCKED

## 14. Production Distinction (AGENTS.md Section 17)

Production claims forbidden: deployed successfully, production healthy, verified, DB updated unless evidence from production itself. Local tests not enough.

Differentiate: Implemented, Tested, Verified, Deployed, Production Verified.

## 15. P4 Blocker Preservation

```
PowerShell 7: BLOCKED in current Arena

Evidence:
- packages.microsoft.com → BLOCKED (SSL_ERROR_SYSCALL 13.107.213.70:443)
- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL 185.199.111.133:443)
- github.com → PASS (200 via E2B proxy)
- api.github.com → PASS (200, v7.6.6)
- deb.debian.org → BLOCKED

Official: PowerShell 7.6.6 LTS, Debian 12 supported until 2028-06-30
Sources: packages.microsoft.com and github.com/PowerShell/PowerShell only
No third-party, no snap, no unofficial mirror, no build from source

No Agent may change to PASS without pwsh --version real execution + smoke test + verification
```

Must remain BLOCKED in README.md, docs/operations.md, ops/powershell/install-pwsh.sh, AGENTS.md, ARENA.md until network unblocked or manual .deb provision.

## 16. Agent MUST NOT

- list / modify sudoers, /etc/passwd, /etc/group, /etc/shadow
- bypass permissions / policy / authentication
- expose secrets
- execute arbitrary shell (eval, curl|bash, sudo sh -c executable)
- use arbitrary sudo outside Gate
- download unknown binaries, use untrusted mirrors, use third-party PowerShell source
- fake PASS, infer production state, auto deploy, force push, delete repo history, destroy data
- install Docker/K8s/SDKs in early phases (P0-P6)
- upgrade OS, modify boot, firewall, disk
- huge feature at once — use MILESTONE→SUBTASK→CHANGE→TEST→VERIFY→EVIDENCE

## 17. Architecture Boundary

Forbidden: UI→sudo, UI→OS command, LLM→arbitrary shell, Agent→production DB directly

Expected: UI→API→Runtime→Policy→Execution Authority→Verifier

## 18. Reporting Format

STATUS, RESULT, OBJECTIVE, INSPECT, PLAN, CHANGES, TESTS, VERIFICATION, EVIDENCE, BLOCKERS, SECURITY, GIT, NEXT, P<X> COMPLETE YES/NO

No overclaim: SUCCESS only with appropriate evidence, differentiate Implemented/Tested/Verified/Deployed/Production Verified.

## 19. Validation Checklist (AGENTS.md Section 20 and ARENA.md Section 18)

After AGENTS.md, ARENA.md:

- [ ] Required sections present: Mission, Scope, Core Principles, Execution Rules, Security Rules, Git Rules, Testing Rules, Evidence Rules, Privilege Rules, Secrets Rules, Dependency Rules, Network Rules, Production Rules, Reporting Rules, Stop Conditions (AGENTS.md)
- [ ] Arena Role, Workspace Boundaries, Repository Boundaries, Command Rules, Privilege Rules, Approval Rules, Network Rules, Git Rules, Testing Rules, Evidence, Stop Conditions, Operating Loop (ARENA.md)
- [ ] Security privilege fail-closed dry-run evidence git secret network production distinction
- [ ] P4 BLOCKED preserved (README.md, docs/operations.md, AGENTS.md, ARENA.md, install-pwsh.sh consistent)
- [ ] No secrets (grep credential patterns)
- [ ] No contradictory permissions (SYSTEM_SUDO_POLICY EXTERNAL vs PROJECT_POLICY CONTROLLED consistent across docs)
- [ ] No system changes (repository-only)
- [ ] Git status --short and diff --stat shown, no auto commit/push
- [ ] Tests: agent-contract.test.sh 15 tests PASS
- [ ] bash -n all scripts PASS
- [ ] policy-check.sh PASS (with self-match avoidance for /tests/ and log messages)

## 20. References

- Microsoft PowerShell Debian: https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian
- PowerShell 7.6.6: https://github.com/PowerShell/PowerShell/releases/tag/v7.6.6
- Debian 12 supported until 2028-06-30
- GitHub GITHUB_TOKEN least privilege: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token
- Arena Agent Mode: https://help.arena.ai/articles/5432423882-how-to-use-agent-mode
- AGENTS.md, ARENA.md, docs/security.md, docs/development.md, docs/operations.md, ops/security/privilege-policy.md
