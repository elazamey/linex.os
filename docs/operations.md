# LINEX.OS — Operations (P5 Foundation)

## Overview

This document describes operational aspects: bootstrap, doctor, verification, toolchain, privilege gate, known network limitations, P4 blocker, and component status table.

## 1. Bootstrap

### ops/bootstrap/bootstrap.sh (P1)

- **Purpose:** Read-only environment discovery, no installation, fail-closed
- **Strict mode:** `set -Eeuo pipefail`
- **Detects:** OS_ID, OS_PRETTY, OS_VERSION, OS_CODENAME, ARCH, PACKAGE_MANAGER, USER, GROUPS, SHELL, PWD
- **Checks:** Required tools (bash, sh, git, curl, grep, sed, awk, find, tar) → FAIL-CLOSED if missing; Important tools (wget, jq, gzip, zip, unzip, python3, node, npm, ca-certificates) → NOT VERIFIED if missing; Optional (sudo, pwsh, docker, podman) → NOT VERIFIED expected
- **Security:** No privilege escalation wrapper, no curl|bash, no sudo sh -c, no system file modification, no secrets
- **Output:** VERIFIED / NOT VERIFIED / BLOCKED / PASS with evidence, plus VERSION DETAILS and SECURITY CHECKS
- **Extensibility:** Supports debian, ubuntu, rhel, fedora, centos, arch, alpine, linux, darwin via /etc/os-release and uname
- **Usage:**
  ```bash
  ./ops/bootstrap/bootstrap.sh
  ```

### ops/bootstrap/bootstrap.ps1 (P1)

- PowerShell 7 compatible, strict mode, detects OS via $IsLinux, $IsMacOS, $IsWindows, RuntimeInformation, package managers via Get-Command, same VERIFIED/NOT VERIFIED/BLOCKED/PASS output
- Usage:
  ```powershell
  pwsh ./ops/bootstrap/bootstrap.ps1
  ```

## 2. Doctor

### scripts/doctor.sh (P1 Aggregator)

- **Purpose:** Aggregates verification checks, no installation, read-only
- **Checks existence** of bootstrap.sh, bootstrap.ps1, verify-environment.sh, verify-environment.ps1, doctor.sh, doctor.ps1
- **Runs** bootstrap.sh and verify-environment.sh
- **Summary:** Repository, Git, Linux shell, sudo, PowerShell, Package manager, Network, Required tools, Disk, Memory → PASS / NOT VERIFIED / BLOCKED
- **Final:** P1 COMPLETE, PowerShell NOT VERIFIED expected, sudo AVAILABLE_NOPASSWD requires P2 policy, STATUS PASS
- **Usage:**
  ```bash
  ./scripts/doctor.sh
  ```

### scripts/doctor.ps1 (P1 Aggregator PowerShell)

- Same as doctor.sh but PowerShell version, runs bootstrap.ps1 and verify-environment.ps1
- Usage:
  ```powershell
  pwsh ./scripts/doctor.ps1
  ```

### ops/linux/doctor.sh (P3)

- Verifies Linux toolchain: Required baseline (bash, coreutils, find, grep, sed, awk, tar, gzip, zip, unzip, curl, wget, git, jq, ca-certificates), Developer Build Toolchain (gcc, g++, make, pkg-config, build-essential), Runtimes (python3, node, npm), plus Docker/Podman should be NOT INSTALLED, PowerShell should be NOT VERIFIED for P3
- Checks package mapping valid (no raw user input), no sudo sh -c, no apt upgrade, Gate usage
- Disk/Memory
- Final: STATUS PASS if all toolchain VERIFIED, else NOT VERIFIED
- Usage:
  ```bash
  ./ops/linux/doctor.sh
  ```

### ops/powershell/doctor.ps1 (P4)

- Verifies PowerShell: pwsh binary, pwsh --version, PSVersionTable (PSEdition, PSVersion, OS, Platform, Arch, GitCommitId), smoke test, network for official sources, security (official source, no arbitrary URL, no third-party)
- If pwsh NOT FOUND → NOT VERIFIED (BLOCKED network)
- If pwsh FOUND and smoke test PASS → P4 COMPLETE
- Usage:
  ```powershell
  pwsh ./ops/powershell/doctor.ps1
  ```

## 3. Verification

### ops/verify/verify-environment.sh (P1)

- Comprehensive verification, read-only, no installation
- Sections: Repository (.git exists), Git (version), Linux shell (bash, sh), Sudo (AVAILABLE_NOPASSWD), PowerShell (MISSING expected), Package manager (apt-get), Network (github.com 200, ping 8.8.8.8), Required tools (bash, sh, git, curl, wget, jq, tar, gzip, grep, sed, awk, find, ca-certificates), Optional tools (python3, node, npm, zip, unzip, docker, podman), Disk (df -h, avail >1GB), Memory (free -h, >500MB), OS details (/etc/os-release, uname -a, arch), Security (no privilege escalation wrapper, no system file modification, no secrets, no forbidden patterns)
- Security check excludes test files to avoid false positives on test cases that intentionally test blocking
- Result: STATUS PASS with PowerShell NOT VERIFIED expected
- Usage:
  ```bash
  ./ops/verify/verify-environment.sh
  ```

### ops/verify/verify-environment.ps1 (P1)

- PowerShell version of verify-environment.sh, same sections but PowerShell style
- Usage:
  ```powershell
  pwsh ./ops/verify/verify-environment.ps1
  ```

## 4. Toolchain (P3)

### ops/linux/install-base.sh (default DRY-RUN since 2026-10-05)

**Execution mode:** `--dry-run` is the default and performs no system change (detect, plan, and
ask the Gate for a decision). Real installation requires an explicit `--execute`, mirroring the
Gate's own convention (W8 fix; see
`docs/reports/triage-correction-and-system-integrity-a71643a.md`).

```
./ops/linux/install-base.sh              # PLAN ONLY, no privileged command
./ops/linux/install-base.sh --execute    # install allowlisted packages through the Gate
```


- **Workflow:** DETECT → VERIFY → PLAN MISSING → DRY-RUN → GATE → INSTALL ONLY APPROVED → VERIFY
- **Detects:** Required baseline, Developer Build Toolchain (gcc, g++, make, pkg-config), Runtimes, build-essential via dpkg, disk/memory before (fail-closed if <500MB disk or <300MB memory)
- **Plans:** MISSING_PACKAGES list, deduplicated, explicit package mapping TOOL_TO_PACKAGE (tool → package, e.g., gcc→gcc, pkg-config→pkg-config), no raw user input
- **Gate DRY-RUN:** For each missing package, calls `privilege-gate.sh package-install <pkg>` dry-run, must PASS (allowlisted) else BLOCKED
- **Gate EXECUTION:** Only if missing, detects package manager, then for each missing: `apt-update --execute` via Gate (to refresh lists, may fail due to Debian network BLOCKED), then `package-install <pkg> --execute` via Gate
- **Verification after:** gcc --version, g++ --version, make --version, pkg-config --version, git/curl/wget/jq/python3/node/npm versions, dpkg-query -W for installed packages, disk/memory after, security checks (no apt upgrade, no curl|bash, no docker/pwsh install, no sudoers modification, Gate used)
- **Result:** If no missing → P3 TOOLCHAIN ALREADY SATISFIED, no installation; else P3 TOOLCHAIN INSTALLED
- **Current status in Arena:** gcc/g++/make/build-essential already VERIFIED via dpkg (base image), pkg-config was MISSING before P3, built from GitHub pkgconf/pkgconf via make -f Makefile.lite due to apt network block (github.com allowed, deb.debian.org blocked), now VERIFIED 3.0.0
- **Usage:**
  ```bash
  ./ops/linux/install-base.sh
  ```

### ops/linux/toolchain-manifest.txt

- Format: Tool | Command | Package | Required | Status | Version | Notes
- Only VERIFIED after actual command execution
- Lists baseline, dev toolchain, runtimes, and explicitly NOT REQUIRED (docker, podman, pwsh, java, go, rust, dotnet, cuda)
- Example: `gcc | gcc | gcc | yes | VERIFIED | 12.2.0 | Debian 12.2.0-14+deb12u1`
- `pkg-config | pkg-config | pkg-config | yes | VERIFIED | 3.0.0 | pkgconf 3.0.0 built from GitHub due to apt mirror blocked`
- `pwsh | pwsh | powershell | P4 | NOT VERIFIED | N/A | P4 will install via Microsoft repo (Debian 12 supported until 2028-06-30)`

### ops/linux/tests/toolchain.test.sh

- 44 tests: required command exists (12), version succeeds (18 including pkg-config), package mapping valid, no arbitrary apt, no apt upgrade, no curl|bash, no wget|bash, no sudo sh -c, Gate invoked, missing package fail-closed, C compiler smoke test (gcc), C++ smoke test (g++), no docker install, no pwsh install, toolchain-manifest exists
- Smoke tests: create temp C source → gcc → executable → run → expected output LINEX.OS C SMOKE PASS → delete artifact
- Usage:
  ```bash
  ./ops/linux/tests/toolchain.test.sh
  ```

## 5. Privilege Gate (P2/P3/P4)

### ops/security/privilege-policy.md

- Defines 5 levels, default policy, allowed actions, allowlist, forbidden commands, sudo policy distinction, fail-closed, dry-run default, evidence format, invariants, P2 scope REPOSITORY-ONLY

### ops/security/forbidden-commands.txt

- Defense-in-depth list: rm -rf /, mkfs, fdisk, dd, shutdown, reboot, iptables -F, etc., plus shell escape tokens, curl|sh patterns, eval, bash -c, etc.

### ops/security/privilege-gate.sh

- **Purpose:** Project privilege governance, allowlist + structured actions + fail-closed + dry-run default, NOT kernel sandbox
- **Allowed actions:** check-sudo, check-package-manager, package-install, package-remove, service-status, apt-update (P3), register-microsoft-repository (P4), install-powershell-package (P4)
- **Allowlist:** DEFAULT DENY, explicit list P2 baseline + P3 gcc/g++/make/pkg-config/build-essential + P4 powershell/packages-microsoft-prod
- **Validation:** Package/service name regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no metacharacters, no path traversal, no leading -, no command substitution, deb path restricted to /tmp/linex-os-powershell/*.deb with pattern `^powershell(-lts)?_7\.[0-9]+\.[0-9]+.*\.deb$`, Package=powershell Arch=amd64 via dpkg-deb --info, Microsoft repo URL constructed internally from ID/VERSION_ID `https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb`, no arbitrary URL
- **Execution:** Direct exec, no shell interpreter for validated value, no eval, no bash -c with uncontrolled input, no sudo $ACTION
- **Evidence:** ACTION, CLASS, POLICY, DECISION, EXECUTION, WOULD EXECUTE, EXIT_CODE, TIMESTAMP, SYSTEM_SUDO, PROJECT_POLICY — no secrets
- **Usage:**
  ```bash
  ./ops/security/privilege-gate.sh package-install curl          # DRY-RUN
  ./ops/security/privilege-gate.sh package-install curl --execute # REAL (needs allowlist)
  ./ops/security/privilege-gate.sh check-sudo
  ./ops/security/privilege-gate.sh apt-update --execute
  ./ops/security/privilege-gate.sh register-microsoft-repository --execute
  ./ops/security/privilege-gate.sh install-powershell-package /tmp/linex-os-powershell/powershell_7.6.6-1.deb_amd64.deb --execute
  ```

### ops/security/policy-check.sh

- Verifies files existence, executable, no dangerous constructions (no eval, no bash -c uncontrolled, no arbitrary sudo, no curl|bash execution, no auto install outside Gate), fail-closed and dry-run defaults, policy content (5 levels, sudo distinction, default deny, forbidden required entries), no secrets (excluding forbidden-commands.txt which documents patterns), no sudoers modification, bash -n syntax
- Usage:
  ```bash
  ./ops/security/policy-check.sh
  ```

### ops/security/tests/privilege-policy.test.sh

- 28 tests: check-sudo dry-run ALLOW, check-sudo --execute PASS, unknown-action BLOCKED, unknown-package BLOCKED, package with ; BLOCKED, && BLOCKED, $() BLOCKED, backticks BLOCKED, destructive action BLOCKED, path traversal BLOCKED, default dry-run, missing policy FAIL-CLOSED, no eval, no arbitrary sudo, --execute rejected unless allowed, pipe/redirect blocked, leading - blocked, service-status, package-remove, check-package-manager, evidence format, no secrets
- No real package install/remove
- Usage:
  ```bash
  ./ops/security/tests/privilege-policy.test.sh
  ```

## 6. PowerShell (P4)

### ops/powershell/install-pwsh.sh

- **Goal:** Install PowerShell 7.6.6 LTS on Debian 12 x86_64, official sources only
- **Version policy:** LTS official, no preview/daily/nightly/community, record POWERSHELL_VERSION, SOURCE, ARCH, INSTALL_METHOD
- **Pre-flight network:** Test packages.microsoft.com, github.com, api.github.com, deb.debian.org, apt metadata → PASS/BLOCKED
- **Primary path:** Microsoft Package Repository via packages-microsoft-prod.deb from https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb (derived from ID=debian VERSION_ID=12, not hardcoded Ubuntu) — only if packages.microsoft.com PASS
- **Repository config:** DRY-RUN first, check destination path, file size>0, dpkg-deb --info, package metadata, source, arch, then registration via Gate register-microsoft-repository (structured, no arbitrary URL, no curl|bash)
- **Apt network failure path:** If apt-get update fails due to Debian network BLOCKED (as seen in P3: deb.debian.org Empty reply), no retry loop, no random mirror change, no unofficial sources, no undocumented proxy, no auto modification of /etc/apt/sources.list — go to GitHub fallback
- **GitHub fallback:** Official PowerShell releases from https://github.com/PowerShell/PowerShell/releases, Linux x64 Debian universal .deb stable/LTS, specific version 7.6.6, file powershell_7.6.6-1.deb_amd64.deb from github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell_7.6.6-1.deb_amd64.deb, no mirror
- **Integrity:** HTTP status, Content-Type, file size, dpkg-deb --info Package=powershell Arch=amd64 Version, checksum from official hashes.sha256 if available (not invented), BLOCKED if metadata incompatible
- **Gate:** Must go via Gate install-powershell-package with validation (path restricted to /tmp/linex-os-powershell/*.deb, Package=powershell Arch=amd64, filename pattern)
- **Source policy:** Only packages.microsoft.com and github.com/PowerShell/PowerShell allowed, others BLOCKED
- **System changes:** Only adding Microsoft repo config if primary path, installing PowerShell itself — no apt upgrade/full-upgrade/dist-upgrade, no Docker/Podman/.NET SDK/Java/Go/Rust, no /etc/sudoers modification
- **Dependencies:** Check dependencies, no apt autoremove/upgrade, if dependency missing record explicitly, if dependency requires Debian repo which is BLOCKED → BLOCKED — DEPENDENCY NETWORK
- **Verify:** command -v pwsh, pwsh --version, pwsh -NoLogo -NoProfile -Command '$PSVersionTable | Format-List' (Edition, Version, OS, Platform, Arch), smoke test pwsh -NoLogo -NoProfile -Command '"LINEX.OS POWERSHELL SMOKE PASS"'
- **Cross-shell:** ./ops/verify/verify-environment.sh and pwsh ./ops/verify/verify-environment.ps1 → PowerShell should become VERIFIED from NOT VERIFIED
- **Current Arena status:** Both primary and fallback BLOCKED due to network — packages.microsoft.com BLOCKED (SSL_ERROR_SYSCALL), release-assets.githubusercontent.com BLOCKED (where GitHub binaries hosted, SSL_ERROR_SYSCALL), github.com PASS, api.github.com PASS, deb.debian.org BLOCKED — so RESULT BLOCKED per spec, no third-party
- **Usage:**
  ```bash
  ./ops/powershell/install-pwsh.sh
  ```

## 7. Known Network Limitations

**Arena Sandbox Network (P3/P4 evidence):**

| Domain | Status | Evidence | Impact |
|--------|--------|----------|--------|
| github.com | PASS | curl -Is https://github.com → HTTP/2 200, via E2B proxy O=E2B; CN=github.com | Git clone, API work |
| api.github.com | PASS | curl -Is https://api.github.com → 200, returns v7.6.6 | Release info works |
| packages.microsoft.com | BLOCKED | curl -v https://packages.microsoft.com → SSL_ERROR_SYSCALL (13.107.213.70:443) | Microsoft repo primary path BLOCKED |
| release-assets.githubusercontent.com | BLOCKED | curl -v https://release-assets.githubusercontent.com → SSL_ERROR_SYSCALL (185.199.111.133:443) | GitHub release binaries BLOCKED (redirect from github.com) |
| objects.githubusercontent.com | BLOCKED | SSL_ERROR_SYSCALL | GitHub objects BLOCKED |
| deb.debian.org | BLOCKED | curl http://deb.debian.org/debian/dists/bookworm/InRelease → Empty reply (151.101.66.132:80), HTTPS → SSL_ERROR_SYSCALL | Debian apt mirrors BLOCKED, /var/lib/apt/lists empty |
| ftp.de.debian.org, mirror.hetzner.com, etc. | BLOCKED | Empty reply or SSL_ERROR_SYSCALL | All Debian mirrors blocked |
| google.com | BLOCKED | SSL_ERROR_SYSCALL | General internet not fully allowed |

**Implications:**
- P3: apt-get update fails, but workaround via git clone https://github.com/pkgconf/pkgconf.git → PASS, built pkgconf-lite → pkg-config VERIFIED
- P4: Both Microsoft repo and GitHub .deb fallback BLOCKED due to release-assets and packages.microsoft.com blocked, so P4 installation BLOCKED, but Gate and logic PASS, no third-party used — correct per spec

## 8. P4 PowerShell Blocker

**Official LTS:** PowerShell 7.6.6 LTS, Debian 12 supported until 2028-06-30 per Microsoft Learn

**Primary:**
- URL: https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
- Network: BLOCKED (SSL_ERROR_SYSCALL)
- Result: MICROSOFT_REPOSITORY → BLOCKED

**Fallback:**
- URL: https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell_7.6.6-1.deb_amd64.deb
- Network: github.com PASS, but redirect to release-assets.githubusercontent.com → BLOCKED
- gh CLI also fails: Get "https://release-assets.githubusercontent.com/..." EOF
- Result: GITHUB_OFFICIAL_RELEASE → BLOCKED

**Overall P4:**
- RESULT: BLOCKED — Both official paths blocked by Arena network, no third-party
- POWERSHELL INSTALLED: NO
- POWERSHELL VERIFIED: NO (remains NOT VERIFIED)
- Security: No arbitrary URL, no third-party, official sources only → VERIFIED
- Tests: 18/18 PASS (logic PASS, install BLOCKED documented)
- Next: Requires network allowlist for packages.microsoft.com and release-assets.githubusercontent.com or manual .deb provision into /tmp/linex-os-powershell/ per official Microsoft Learn

## 9. Component Status Table (P5)

| Component | Status | Evidence | Notes |
|-----------|--------|----------|-------|
| Repository | PASS | .git exists, git branch arena/01a107fc-linex-os, git log 768bf39 | Branch not yet on GitHub (only main on remote), per no auto push |
| Git | PASS | git version 2.39.5 | VERIFIED |
| Linux shell (bash) | PASS | GNU bash 5.2.15 | VERIFIED |
| sudo | PASS | AVAILABLE_NOPASSWD, sudo -n true PASS, sudo -l shows NOPASSWD ALL | Requires P2 policy, SYSTEM_SUDO_POLICY EXTERNAL |
| PowerShell | BLOCKED / NOT VERIFIED | command -v pwsh MISSING, install-pwsh.sh shows MICROSOFT_REPO_NETWORK BLOCKED, RELEASE_ASSETS_NETWORK BLOCKED, GITHUB_NETWORK PASS | Known blocker, P4 network restriction, no third-party |
| Package manager | PASS | apt-get at /usr/bin/apt-get | VERIFIED, but apt lists empty due to Debian mirrors BLOCKED |
| Network | PASS (partial) | github.com PASS, api.github.com PASS, deb.debian.org BLOCKED, packages.microsoft.com BLOCKED, release-assets BLOCKED | Documented as known limitations |
| Required tools | PASS | bash, git, curl, wget, jq, tar, gzip, zip, unzip, grep, sed, awk, find, ca-certificates all VERIFIED | P1 |
| Build toolchain | PASS | gcc 12.2.0, g++ 12.2.0, make 4.3, pkg-config 3.0.0 (built from GitHub), build-essential 12.9 VERIFIED via dpkg | P3, 44 tests PASS, smoke tests PASS |
| Runtimes | PASS | python3 3.11.2, node 22.22.3, npm 10.9.8 VERIFIED | P3 |
| Docker/Podman | NOT INSTALLED | command -v docker MISSING (expected) | NOT REQUIRED for P3, per spec |
| Disk | PASS | 21G total, 20G avail (5% used) | No pressure |
| Memory | PASS | 3.8Gi total, 3.6Gi available | No pressure |
| Security policy | PASS | privilege-policy.md exists, 5 levels, allowlist, fail-closed, Gate with 28 tests PASS | P2 |
| Tests | PASS | P2 28/28, P3 44/44, P4 18/18 logic PASS, P1 bootstrap/verify PASS | P4 install BLOCKED but logic PASS |
| CI | IMPLEMENTED | .github/workflows/ci.yml exists, static validation only, permissions contents: read | P5, no Docker/PowerShell assumed |
| Documentation | IMPLEMENTED | docs/vision.md, architecture.md, security.md, development.md, operations.md (this file) | P5 |
| Config | IMPLEMENTED | config/README.md exists, non-sensitive only | P5 |
| Tests foundation | IMPLEMENTED | tests/README.md exists, levels documented | P5 |
| Repository foundation | IMPLEMENTED | README.md, CONTRIBUTING.md, SECURITY.md, LICENSE, .gitignore | P5 |

## 10. Operations Commands

```bash
# Bootstrap
./ops/bootstrap/bootstrap.sh

# Verification
./ops/verify/verify-environment.sh
pwsh ./ops/verify/verify-environment.ps1  # if pwsh available, else NOT VERIFIED expected

# Doctor aggregators
./scripts/doctor.sh
./ops/linux/doctor.sh
pwsh ./ops/powershell/doctor.ps1

# Security
./ops/security/policy-check.sh
./ops/security/tests/privilege-policy.test.sh

# Toolchain
./ops/linux/install-base.sh
./ops/linux/tests/toolchain.test.sh

# PowerShell (will be BLOCKED in Arena due to network, but logic PASS)
./ops/powershell/install-pwsh.sh
./ops/powershell/tests/powershell-install.test.sh

# CI local validation
bash -n $(find ops scripts .github -name "*.sh" -type f)
```

## 11. Troubleshooting

**If apt-get update fails with Empty reply / SSL_ERROR_SYSCALL:**
- This is Arena sandbox network restriction (deb.debian.org blocked)
- Don't retry loop, don't add random mirrors, don't use unofficial proxy
- For P3, workaround via GitHub source build (e.g., pkgconf) is allowed because github.com PASS
- Document as BLOCKED with evidence

**If PowerShell install fails with release-assets blocked:**
- This is same network restriction (release-assets.githubusercontent.com blocked)
- Don't use third-party mirror, snap, or build from source (per P4 spec)
- Document as BLOCKED with evidence: MICROSOFT_REPOSITORY BLOCKED, GITHUB_OFFICIAL_RELEASE BLOCKED
- Requires network allowlist or manual .deb provision

**If Security check shows BLOCKED due to test files:**
- Ensure verify-environment.sh excludes /tests/ directories to avoid false positives on test cases that intentionally test blocking (e.g., "curl|bash" as argument to test BLOCKED)

---

**Status:** P5 Operations documented, P1-P3 PASS, P4 BLOCKED as known network restriction with dual-path design and no third-party, Gate extended for P3/P4 with justification.

**Next:** P6 Agent Contract (AGENTS.md, ARENA.md).
