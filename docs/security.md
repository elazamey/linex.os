# LINEX.OS — Security Model

## Overview

LINEX.OS security is built on explicit separation between **System privilege** (external, not controlled) and **Project policy** (controlled by Gate), with allowlist, fail-closed, structured actions, dry-run default, and no secrets.

This document consolidates security decisions recorded under the original foundation milestones P1–P5; those labels are historical and are not the active P0–P6 sequence.

## 1. System vs Project Privilege

### SYSTEM_SUDO_POLICY

```
Status: EXTERNAL / NOT CONTROLLED BY REPOSITORY
Measured in the P0 audit at `a71643a`: sudo NOPASSWD: ALL (environment-specific; recheck live)
Evidence:
  - sudo -n true → PASS
  - sudo -l → (ALL : ALL) ALL, (ALL : ALL) NOPASSWD: ALL, (ALL) NOPASSWD: ALL, (ALL : ALL) NOPASSWD: ALL
  - User: user (uid 1001, groups sudo)
  - System can do sudo <arbitrary> outside Gate → YES (expected in Arena sandbox)
  - Example: sudo whoami → root (outside Gate, system allows)

No modification in P2-P5:
  - /etc/sudoers NOT modified
  - /etc/sudoers.d/* NOT modified
  - /etc/passwd, /etc/group NOT modified
  - Verified via policy-check.sh: no sudoers modification
```

### LINEX_OS_PROJECT_POLICY

```
Status: CONTROLLED BY PROJECT GATE
Controlled by: ops/security/privilege-gate.sh
Enforces:
  - Allowlist (DEFAULT DENY)
  - Structured actions (no arbitrary command string)
  - Fail-closed (unknown → BLOCKED non-zero exit)
  - Dry-run default (real execution needs --execute explicit)
  - No arbitrary sudo (no sudo $ACTION, sudo $ARGS, sudo "$USER_INPUT")
  - No eval, no bash -c with uncontrolled input
  - Evidence without secrets

Project via Gate allows sudo <arbitrary> → NO
Evidence:
  - ./privilege-gate.sh "sudo whoami" → BLOCKED EXIT 3 (unknown action)
  - ./privilege-gate.sh "rm -rf /" → BLOCKED EXIT 3
  - ./privilege-gate.sh package-install "curl;rm -rf /" → BLOCKED EXIT 2 (forbidden ; and /)
  - ./privilege-gate.sh package-install "curl|bash" → BLOCKED EXIT 2
  - ./privilege-gate.sh package-install "nonexistent-pkg" → BLOCKED EXIT 3 (not in allowlist)

Gate is governance layer, NOT kernel-level sandbox. Real isolation needs container/user isolation or actual sudoers policy later.
```

**Critical Test (from P2 prompt):**
```
Question: هل يستطيع Arena تشغيل sudo <arbitrary-command> من خارج الـGate؟
Answer: نعم على الأرجح لأن sudoers الحالية NOPASSWD: ALL
This is NOT failure of P2; it proves difference between System privilege ≠ Project policy
```

## 2. Privilege Levels (Literal)

Defined in `ops/security/privilege-policy.md`:

- **READ_ONLY**: Allowed without sudo (e.g., check-package-manager, OS detection, command -v)
- **SAFE_USER_COMMAND**: Allowed if explicitly safe and defined (e.g., service-status ssh read-only via systemctl is-active)
- **PACKAGE_INSTALL**: Denied by default until passing Gate + allowlist + --execute (e.g., package-install curl)
- **PRIVILEGED_OPERATION**: Denied by default until action explicitly defined (e.g., register-microsoft-repository)
- **DESTRUCTIVE_OPERATION**: Denied always in P2/P3/P4 (e.g., rm -rf /, mkfs, dd, shutdown, reboot, iptables -F)

Default: DENY for unknown.

## 3. Allowlist (DEFAULT DENY)

**P2 Baseline:**
```
ca-certificates, curl, wget, git, jq, tar, gzip, zip, unzip, bash, coreutils, findutils, grep, sed, gawk
```

**P3 Extension (justified: Developer Build Baseline minimal for Debian 12, official Debian packages, no docker/k8s/java/go/rust/dotnet):**
```
+ gcc, g++, make, pkg-config, build-essential
```

At the P0 audit, `pkg-config` was missing from the default Arena PATH and Debian mirrors were blocked. The official `pkgconf/pkgconf` source at commit `d908d63634c13b9a4f88d2fe4578d95048a6b13c` was built under `/tmp` for verification only. No system package was installed, so the default PATH remained without `pkg-config`; see `docs/reports/baseline-audit-a71643a.md`.

**P4 Extension (official PowerShell only):**
```
+ powershell, packages-microsoft-prod (for Microsoft repository)
+ powershell_7.6.6-1.deb_amd64.deb pattern (official GitHub release)
- Only from packages.microsoft.com and github.com/PowerShell/PowerShell, no third-party
```

**Enforcement:**
- `is_package_allowed()` checks exact match against allowlist
- Unknown package → BLOCKED EXIT 3
- Example: `package-install nonexistent-package-xyz` → BLOCKED

## 4. Fail-Closed

Any of:
- unknown action
- unknown package
- invalid arguments (e.g., package name with `;`, `&&`, `||`, `|`, `$`, `` ` ``, `>`, `<`, `/`, `..`, leading `-`)
- missing policy file (privilege-policy.md, forbidden-commands.txt)
- malformed input
- unexpected environment
- forbidden token

→ Result: BLOCKED, non-zero exit (2,3,4,5,6), evidence logged, no execution, no `sudo <input>`.

**Evidence format:**
```
ACTION: <action>
CLASS: <level>
POLICY: BLOCKED
DECISION: BLOCKED
EXECUTION: NOT EXECUTED
WOULD EXECUTE: N/A - reason
EXIT_CODE: non-zero
TIMESTAMP: UTC ISO8601
SYSTEM_SUDO: EXTERNAL / NOT CONTROLLED
PROJECT_POLICY: CONTROLLED BY LINEX.OS GATE
REASON: ...
```

## 5. Structured Actions (No Arbitrary Execution)

**Allowed actions (P2-P4):**
```
check-sudo, check-package-manager, package-install, package-remove, service-status, apt-update, register-microsoft-repository, install-powershell-package
```

**Not allowed (must be BLOCKED):**
```
sudo bash, sudo sh, sudo env, sudo -i, sudo su, sudo <arbitrary-command>, sudo "$USER_INPUT", eval "$INPUT", bash -c "$INPUT", sh -c "$INPUT"
```

**Implementation:**
- No `eval` in Gate (verified via policy-check.sh)
- No `bash -c "$var"` with uncontrolled input
- No `sh -c "$var"`
- Package name validation: regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no metacharacters, no path traversal, no leading `-`
- Service name same strict validation
- Deb path for PowerShell: must be in `/tmp/linex-os-powershell/*.deb`, must match `^powershell(-lts)?_7\.[0-9]+\.[0-9]+.*\.deb$`, must have Package=powershell Arch=amd64 via dpkg-deb --info
- Microsoft repository URL constructed internally from ID/VERSION_ID (`https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb`), not from user input → prevents arbitrary URL

## 6. Dry-Run Default

- `privilege-gate.sh` default `DRY_RUN=true`, `EXECUTE=false`
- Shows `WOULD EXECUTE` but `NOT EXECUTED (dry-run)`
- Real execution requires explicit `--execute` flag
- Even with `--execute`, unknown/invalid → BLOCKED
- Example: `package-install curl` → DRY-RUN PASS, `package-install curl --execute` → EXECUTED (would do sudo apt-get install -y curl)

**P2-P3 tests use dry-run only to keep REPOSITORY-ONLY (no real apt install/remove in tests).**

## 7. Forbidden Commands (Defense-in-Depth)

See `ops/security/forbidden-commands.txt` — not primary control, but defense-in-depth. Primary is allowlist.

Includes at least:
```
rm -rf /, mkfs, mkfs.*, fdisk, parted, wipefs, dd, shutdown, reboot, poweroff, halt, init, systemctl poweroff, systemctl reboot, iptables -F, nft flush ruleset, userdel, groupdel, sudo bash, sudo sh, sudo env, curl | sh, curl | bash, wget | sh, wget | bash, eval, bash -c, sh -c, mount, systemctl enable/disable/start/stop, etc.
```

But design is **ALLOWLIST + structured actions + fail-closed**, NOT blacklist only.

## 8. Secrets Policy

- **No secrets in repository:** No API keys, tokens, passwords, private credentials, .env files with secrets, credential material
- **No secrets in logs:** Evidence must NOT log passwords, tokens, API keys, environment secrets
- **Allowed:** Documentation mentioning "No secrets" or "passwords" as what should NOT be logged (e.g., in privilege-policy.md, forbidden-commands.txt as example of what should never be logged)
- **Verification:** `policy-check.sh` checks for `password\s*=\s*[^\s]{8,}` etc., excluding forbidden-commands.txt which documents patterns as examples, and excluding documentation lines
- **Config:** `config/` is for non-sensitive config only, no secrets (documented in config/README.md)
- **.gitignore:** Excludes .env, .env.*, secrets, credentials, logs, build artifacts, OS junk

## 9. Audit / Evidence

Every Gate invocation outputs structured evidence without secrets:

```
ACTION: package-install
CLASS: PACKAGE_INSTALL
POLICY: ALLOW (allowlisted)
DECISION: DRY-RUN or EXECUTED or BLOCKED
EXECUTION: NOT EXECUTED (dry-run) or EXECUTED or FAILED or NOT EXECUTED
WOULD EXECUTE: sudo apt-get install -y curl (sanitized, validated)
EXIT_CODE: 0 or non-zero
TIMESTAMP: 2026-10-04T17:45:01Z
SYSTEM_SUDO: AVAILABLE_NOPASSWD - EXTERNAL / NOT CONTROLLED BY REPOSITORY
PROJECT_POLICY: CONTROLLED BY LINEX.OS GATE
```

- Temporary safe output for testing allowed: `/tmp/linex-os-privilege-test.log`, `/tmp/linex-os-powershell/`, but no secrets inside repo
- No `/tmp` inside repository, no runtime logs, no downloaded .deb inside repo (per repository rules)

## 10. Network and Supply-Chain Security

**Official sources only (P4):**

- SOURCE-1: `packages.microsoft.com` (Microsoft Package Repository)
- SOURCE-2: `github.com/PowerShell/PowerShell` (official PowerShell releases)

Any other source → BLOCKED.

**Arena network measured in the P0 audit (`a71643a`; see the audit report):**
- `github.com` → PASS (200 via E2B proxy)
- `api.github.com` → PASS (200)
- `packages.microsoft.com` → BLOCKED (SSL_ERROR_SYSCALL, 13.107.213.70:443)
- `release-assets.githubusercontent.com` → BLOCKED (SSL_ERROR_SYSCALL, where GitHub release binaries hosted)
- `deb.debian.org` → BLOCKED (Empty reply, 151.101.66.132:80)
- `google.com` → BLOCKED (SSL_ERROR_SYSCALL)

Therefore:
- P3 default environment: `pkg-config` is missing and P3 is 43/44; the P0 audit built pinned official pkgconf source temporarily under `/tmp` to rerun P3 at 44/44. This was test-only, not a system install or a persistent fix; `scripts/doctor.sh` still exits 3 on the default PATH by design.
- P4: both the Microsoft repository and official GitHub release-asset paths were BLOCKED during the P0 audit, so PowerShell remained NOT VERIFIED (no third-party source).

**Supply-chain:**
- No third-party PowerShell source, no snap, no unofficial mirror, no binary from untrusted source
- Package integrity checks: HTTP status, Content-Type, file size >0, dpkg-deb --info Package=powershell Arch=amd64 Version contains 7.6.6, checksum from official hashes.sha256 if available (not invented)
- If metadata incompatible → BLOCKED, no install

## 11. Security Invariants (P2)

Verified via tests:

- INVARIANT-1: No arbitrary command execution through Gate → VERIFIED (no sudo $ACTION, only validated names)
- INVARIANT-2: Unknown actions are denied → VERIFIED (unknown-action → BLOCKED EXIT 3)
- INVARIANT-3: Unknown packages are denied → VERIFIED (nonexistent-package → BLOCKED)
- INVARIANT-4: Destructive operations are denied → VERIFIED (rm -rf / → BLOCKED, DESTRUCTIVE_OPERATION always DENIED)
- INVARIANT-5: Default mode is dry-run → VERIFIED (DRY_RUN=true default)
- INVARIANT-6: Repository cannot modify system sudoers → VERIFIED (no /etc/sudoers modification, policy-check PASS)
- INVARIANT-7: No secrets are stored or logged → VERIFIED (policy-check PASS, tests PASS)
- INVARIANT-8: Policy failure causes non-zero exit status → VERIFIED (all BLOCKED cases non-zero)

## 12. What Gate Is NOT

- Gate is **NOT** kernel-level sandbox
- Gate is **NOT** replacement for sudoers (SYSTEM_SUDO_POLICY remains EXTERNAL)
- Gate is **NOT** container isolation
- Gate is governance layer inside repository that enforces allowlist + structured actions + evidence

Real isolation needs container/user isolation or actual sudoers policy later (future phases).

## 13. CI Security

- `.github/workflows/ci.yml` uses `permissions: contents: read` (least privilege, per GitHub Docs for GITHUB_TOKEN)
- No `write-all`, no GitHub token with write unless proven need
- CI performs repository validation, security checks, tests, and doctor using least-privilege permissions; it does not deploy.
- No Docker installation, cloud credentials, secrets, or production services are assumed in CI. PowerShell tests validate install logic; the Arena runtime remains blocked separately.
- P4 tests that require pwsh classified as NOT VERIFIED / CONDITIONAL, not fake PASS

## 14. Reporting

- Do NOT claim system is absolutely secure
- Say precisely:
  - `LINEX.OS PROJECT PRIVILEGE POLICY → VERIFIED`
  - `SYSTEM sudoers SECURITY → EXTERNAL / NOT CONTROLLED BY REPOSITORY`
- Document BLOCKED cases with evidence, not hidden

---

**Status:** This guide describes the repository's security boundaries and controls. At audit commit `a71643a`, `REPOSITORY_STATUS` was PASS for repository-owned security checks, `ENVIRONMENT_STATUS` was BLOCKED (`pkg-config` absent; doctor FAIL/exit 3; PowerShell network-blocked), and `REMOTE_CI_STATUS` was independently VERIFIED. See `docs/reports/baseline-audit-a71643a.md`; none of these classifications alters the fail-closed doctor result.

**Next:** Complete P0 reconciliation, then P1 MVP Definition + ADRs per `docs/architecture/roadmap.md`. The proposed MVP is not frozen; no Runtime implementation before P1 decisions are accepted.
