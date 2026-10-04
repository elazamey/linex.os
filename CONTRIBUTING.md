# CONTRIBUTING — LINEX.OS

## Principles

### Small and Safe

- Propose minimal changes, not "install everything" or "rewrite all"
- Each PR should be one phase (P1, P2, P3, etc.) with clear STATUS, RESULT, EVIDENCE
- No blind installation — detect OS, version, arch, package manager first via /etc/os-release and command -v
- No destructive commands by default (rm -rf /, mkfs, dd, shutdown, etc. always BLOCKED)

### Testable

- Every change must have tests or verification
- Run `bash -n` for all Bash scripts (mandatory)
- Run `shellcheck` if available, else SKIPPED (not FAILURE)
- Run relevant tests: P2 28 tests, P3 44 tests, P4 18 tests — all must PASS for phase to be COMPLETE, except known BLOCKED due to network (document as BLOCKED, not fake PASS)
- Include smoke tests for toolchain (C/C++ compile and run) that prove tools work, then delete artifacts
- Evidence mandatory: captured command outputs, version checks, test logs, dpkg-query, etc.

### No Secrets

- No API keys, tokens, passwords, private credentials, .env with secrets, credential material in repository
- No secrets in logs (evidence must not contain passwords, tokens)
- config/ is for non-sensitive config only
- .gitignore excludes .env, .env.*, secrets, credentials, logs, build artifacts, OS junk
- If you need to document secret patterns as what should NOT be logged, do it as comment in forbidden-commands.txt (e.g., # password=) not actual secret value

### No Privileged Changes Without Policy

- Any package installation must go via `ops/security/privilege-gate.sh` with DRY-RUN first, then --execute, with explicit allowlist
- No `sudo <arbitrary-command>` via Gate — only structured actions allowlisted: check-sudo, package-install <allowlisted-package>, apt-update, register-microsoft-repository, install-powershell-package, etc.
- No `sudo bash`, `sudo sh`, `sudo env`, `sudo -i`, `sudo su`
- No `eval`, no `bash -c "$INPUT"` with uncontrolled input
- No `curl | bash`, `curl | sh`, `wget | bash`, `wget | sh`
- Package name validation strict: regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no metacharacters, no path traversal
- Allowlist DEFAULT DENY — unknown package/action → BLOCKED non-zero exit
- Document justification for adding to allowlist in privilege-policy.md or toolchain-manifest.txt

### No Dependency Without Justification

- No addition of Docker, Kubernetes, Rust, Go, Java, .NET, Android SDK, CUDA, etc. unless architecture (P8) proves need
- No npm install, pip install, cargo add just to create CI or docs
- No application dependencies in P0-P5 (only system packages via Gate with allowlist)
- For PowerShell: only official sources `packages.microsoft.com` and `github.com/PowerShell/PowerShell`, no third-party, no snap, no unofficial mirror, no build from source

### Workflow: INSPECT → PLAN → CHANGE → TEST → VERIFY → REPORT

Mandatory for Arena and contributors:

1. **INSPECT**: Read-only discovery (whoami, id, uname -a, /etc/os-release, command -v, sudo -n true, network, git status)
2. **PLAN**: Propose minimal changes, files to create/modified only in allowed paths (ops/, docs/, config/, tests/, scripts/, .github/), security implications, testing strategy, evidence strategy, rollback plan
3. **CHANGE**: Create files only in repository, no /etc/sudoers modification, no secrets, strict mode, no destructive
4. **TEST**: bash -n, shellcheck if available, run relevant tests, no real install in tests (dry-run), check forbidden patterns with exclusions to avoid self-match
5. **VERIFY**: Run verification scripts (bootstrap.sh, verify-environment.sh, doctor.sh, policy-check.sh, toolchain tests), evidence VERIFIED/NOT VERIFIED/BLOCKED/PASS
6. **REPORT**: STATUS, RESULT, EVIDENCE, CHANGED FILES, TESTS, BLOCKERS, NEXT, P<X> COMPLETE YES/NO — no PASS without evidence

### Evidence Mandatory

- Every PASS must have evidence
- For Gate: ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY
- For toolchain: command -v, --version, dpkg-query -W, smoke test output
- For PowerShell: pwsh --version, PSVersionTable, smoke test, verify-environment.ps1 now VERIFIED
- For network: curl -Is or curl -v output showing PASS/BLOCKED

### No Production Claims from Local Tests

- Local PASS in Arena sandbox (Debian 12, 21G disk, 3.8Gi memory, github.com PASS, deb.debian.org BLOCKED) proves logic, not production deployment
- Document in tests/README.md: Local PASS ≠ Production PASS
- No claim "production ready", "fully complete", "cross-platform verified" unless actually verified with evidence in production

### No Auto Deployment

- No auto commit, push, merge, deployment in P1-P5
- Show git status --short and changed files only
- CI is static validation only, no deployment, permissions contents: read

### Security Invariants (P2)

Must be preserved:

- INVARIANT-1: No arbitrary command execution through Gate
- INVARIANT-2: Unknown actions are denied
- INVARIANT-3: Unknown packages are denied
- INVARIANT-4: Destructive operations are denied
- INVARIANT-5: Default mode is dry-run
- INVARIANT-6: Repository cannot modify system sudoers
- INVARIANT-7: No secrets are stored or logged
- INVARIANT-8: Policy failure causes non-zero exit status

Verified via policy-check.sh and privilege-policy.test.sh (28 tests PASS).

## How to Contribute

1. **Check current status:** Read README.md, docs/operations.md component table, and latest P<X> report
2. **Inspect current branch:** git branch, git status, git log --oneline
3. **Don't delete P1-P4 files:** If conflict, STOP REPORT, don't delete or restructure security files
4. **Follow phase order:** P0→P1→P2→P3→P4→P5→P6→P7→P8→P9+. Don't jump to Product Code before foundation PASS
5. **Create small PR:** One phase per PR, with clear description, evidence, tests
6. **Run tests locally:** bash -n, policy-check, toolchain tests, powershell tests, bootstrap, verify, doctor
7. **Update docs:** If you add tool or change policy, update toolchain-manifest.txt, privilege-policy.md, docs/ files, README status table
8. **Handle blockers:** If network BLOCKED (e.g., packages.microsoft.com, release-assets.githubusercontent.com, deb.debian.org blocked in Arena), document as BLOCKED with evidence (curl -v output), don't use third-party workaround, don't claim fake PASS

## Known Blockers (P5)

- PowerShell 7.6.6 LTS: BLOCKED in Arena network (packages.microsoft.com BLOCKED SSL_ERROR_SYSCALL, release-assets.githubusercontent.com BLOCKED, github.com PASS, api.github.com PASS) — requires network allowlist or manual .deb provision per Microsoft Learn (Debian 12 supported until 2028-06-30)
- Debian apt mirrors: BLOCKED (deb.debian.org Empty reply) — workaround via GitHub source build for pkg-config succeeded (pkgconf 3.0.0), but apt packages still blocked
- Branch arena/01a107fc-linex-os not on GitHub yet (only main at 768bf39), per no auto push decision

## Code Style

- Bash: `set -Eeuo pipefail`, strict mode, explicit package mapping, no raw user input, no `sudo "$USER_INPUT"`
- PowerShell: `Set-StrictMode -Version Latest`, `$ErrorActionPreference = "Stop"`, compatible with PowerShell 7
- Documentation: Markdown, clear sections, evidence-based, no invented data

## Reporting Security Issues

See SECURITY.md — no invented email, no secrets, document expectations for secret handling, privileged operations, unsafe commands, dependency security, supply-chain.

## License

LICENSE is currently PENDING OWNER DECISION (placeholder). Don't guess MIT/Apache/GPL. See LICENSE file.

---

**Status:** P5 Contributing rules documented, mandatory for all contributors and Arena.

**Next:** P6 Agent Contract (AGENTS.md, ARENA.md) will formalize when Arena inspects, proposes, requests permission, and stops.
