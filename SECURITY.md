# SECURITY — LINEX.OS

## Security Reporting Expectations

- **Do NOT put secrets in issues, PRs, or repository files** — no API keys, tokens, passwords, private credentials, .env with secrets
- **Document security concerns with evidence**, not claims — include command outputs, version checks, test logs, but without secrets
- **Use responsible disclosure for real vulnerabilities** — if you find a vulnerability that allows arbitrary command execution through Gate, or secrets leakage, or privilege escalation outside policy, report it via GitHub Security Advisories (if enabled) or via documented contact method (do NOT put invented email here)
- **No invented contact email** — this file does not contain `security@example.com` or similar invented address. Owner should configure GitHub Security policy or provide real contact via repository settings

## Secret Handling

- **No secrets in repository:** No API keys, tokens, passwords, private credentials, .env files with secrets, credential material, SSH private keys, certificates private keys
- **No secrets in logs:** Evidence from Gate, doctor, verification must NOT contain passwords, tokens, API keys, environment secrets
- **Allowed documentation:** Mentioning "No secrets" or "passwords" as what should NOT be logged is allowed (e.g., in privilege-policy.md, forbidden-commands.txt as example `# password=`), but not actual secret values
- **Config:** `config/` directory is for non-sensitive config only — no secrets (documented in config/README.md)
- **.gitignore:** Excludes `.env`, `.env.*`, `secrets`, `credentials`, `*.key`, `*.pem`, logs, build artifacts, OS junk
- **Verification:** `ops/security/policy-check.sh` checks for secret patterns like `password\s*=\s*[^\s]{8,}` etc., excluding `forbidden-commands.txt` which documents patterns as examples, and excluding documentation lines

## Privileged Operations

### System vs Project

```
SYSTEM_SUDO_POLICY: EXTERNAL / NOT CONTROLLED BY REPOSITORY
  - Measured in the P0 audit (`a71643a`): sudo NOPASSWD: ALL (environment-specific; recheck live)
  - Evidence: sudo -n true PASS, sudo -l shows (ALL : ALL) ALL
  - System can do sudo <arbitrary> outside Gate → YES (expected)

LINEX_OS_PROJECT_POLICY: CONTROLLED BY PROJECT GATE
  - Controlled by ops/security/privilege-gate.sh
  - Project via Gate allows sudo <arbitrary> → NO (BLOCKED unless explicitly allowed action + allowlist)
  - Evidence: ./privilege-gate.sh "sudo whoami" → BLOCKED EXIT 3
```

- Gate is governance layer, NOT kernel-level sandbox — real isolation needs container/user isolation later

### Privilege Levels

- READ_ONLY: allowed without sudo
- SAFE_USER_COMMAND: allowed if explicitly safe (e.g., service-status ssh read-only)
- PACKAGE_INSTALL: DENY by default, requires Gate + allowlist + --execute
- PRIVILEGED_OPERATION: DENY by default, requires explicit action (e.g., register-microsoft-repository)
- DESTRUCTIVE_OPERATION: DENY always in P2-P5 (rm -rf /, mkfs, dd, shutdown, etc.)

### Structured Actions

Allowed (P2-P4):
```
check-sudo, check-package-manager, package-install, package-remove, service-status, apt-update, register-microsoft-repository, install-powershell-package
```

Not allowed (must be BLOCKED):
```
sudo bash, sudo sh, sudo env, sudo -i, sudo su, sudo <arbitrary-command>, sudo "$USER_INPUT", eval "$INPUT", bash -c "$INPUT", sh -c "$INPUT"
```

- Package name validation: regex `^[a-z0-9][a-z0-9+._-]{0,63}$`, no metacharacters `; & | $ ` \ " ' < > ( ) { } * ? ! ~ #`, no path traversal `/` or `..`, no leading `-`
- Deb path for PowerShell: restricted to `/tmp/linex-os-powershell/*.deb`, pattern `^powershell(-lts)?_7\.[0-9]+\.[0-9]+.*\.deb$`, Package=powershell Arch=amd64 via dpkg-deb --info
- Microsoft repo URL constructed internally from ID/VERSION_ID `https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb`, no arbitrary URL

### Dry-Run Default

- Gate default DRY-RUN, shows WOULD EXECUTE but NOT EXECUTED
- Real execution requires explicit `--execute`
- Even with --execute, unknown/invalid → BLOCKED non-zero exit

### Fail-Closed

Unknown action/package/invalid args/missing policy/malformed input → BLOCKED non-zero exit, no `sudo <input>`.

## Unsafe Commands

See `ops/security/forbidden-commands.txt` — defense-in-depth, not primary control (primary is allowlist).

Includes at least:

```
Destructive filesystem: rm -rf /, mkfs, mkfs.*, fdisk, parted, wipefs, dd, shred
System power: shutdown, reboot, poweroff, halt, init, systemctl poweroff, systemctl reboot
Firewall destructive: iptables -F, nft flush ruleset
User/group destructive: userdel, groupdel
Privilege escalation wrappers: sudo bash, sudo sh, sudo env, sudo -i, sudo su
Shell escape tokens: ; && || | $ $() `` > < >> << ` \ " ' ( ) { } * ? ! ~ # % &
Path traversal: ../, /etc/, /
Curl piped to shell: curl | sh, curl | bash, wget | sh, wget | bash, curl | sudo bash
Eval and shell -c: eval, bash -c, sh -c
Dangerous mounts: mount, umount, systemctl enable/disable/start/stop
Package manager dangerous: apt upgrade, full-upgrade, dist-upgrade, autoremove (only allow apt-get install -y <specific> via Gate)
Container escape: docker run --privileged, podman run --privileged
```

But design is **ALLOWLIST + structured actions + fail-closed**, NOT blacklist only. Unknown is BLOCKED by default.

## Dependency Security

- No Runtime implementation or implementation dependencies before the required P1 MVP ADR decisions are accepted; no npm install, pip install, or cargo add just to create CI
- Only system packages via Gate with allowlist and justification
- For PowerShell: only official sources `packages.microsoft.com` and `github.com/PowerShell/PowerShell`, no third-party, no snap, no unofficial mirror, no build from source
- Package integrity: HTTP status, Content-Type, file size >0, dpkg-deb --info Package=powershell Arch=amd64 Version contains 7.6.6, checksum from official hashes.sha256 if available (not invented), BLOCKED if metadata incompatible
- No `apt upgrade`, `full-upgrade`, `dist-upgrade` — only `apt-get install -y <specific-allowlisted-package>` via Gate
- No `apt autoremove`

## Supply-Chain Considerations

- **Official sources only (P4):**
  - SOURCE-1: `packages.microsoft.com` (Microsoft Package Repository)
  - SOURCE-2: `github.com/PowerShell/PowerShell` (official PowerShell releases)
  - Any other source → BLOCKED
- **Arena network measured in the P0 audit (`a71643a`; recheck before treating as current):**
  - `github.com` → PASS (200 via E2B proxy)
  - `api.github.com` → PASS (200)
  - `packages.microsoft.com` → BLOCKED (SSL_ERROR_SYSCALL)
  - `release-assets.githubusercontent.com` → BLOCKED (where GitHub release binaries hosted)
  - `deb.debian.org` → BLOCKED (Empty reply)
- P3 environment evidence: Debian mirrors are BLOCKED, while the official `pkgconf/pkgconf` GitHub repository is reachable. During the P0 audit, commit `d908d63634c13b9a4f88d2fe4578d95048a6b13c` was built under `/tmp` for test execution only; no system package was installed and the default PATH remains without `pkg-config`. See `docs/reports/baseline-audit-a71643a.md`.
- P4 both primary and fallback BLOCKED due to release-assets and packages.microsoft.com blocked, so RESULT BLOCKED per spec, no third-party
- No third-party PowerShell source, no snap, no unofficial mirror, no binary from untrusted source
- If both official paths BLOCKED, result is BLOCKED (not fake PASS) — requires network allowlist for packages.microsoft.com and release-assets.githubusercontent.com or manual .deb provision into /tmp/linex-os-powershell/ per official Microsoft Learn (Debian 12 supported until 2028-06-30)

## CI Security

- `.github/workflows/ci.yml` uses `permissions: contents: read` (least privilege per GitHub Docs for GITHUB_TOKEN)
- No `write-all`, no GitHub token with write unless proven need
- CI runs repository validation, security checks, tests, and doctor, with `contents: read`; it does not deploy.
- No Docker installation, cloud credentials, secrets, or production services are assumed in CI. PowerShell logic tests do not establish the Arena runtime's availability.
- P4 tests that require pwsh classified as NOT VERIFIED / CONDITIONAL if pwsh missing, not fake PASS

## Security Invariants (P2)

- INVARIANT-1: No arbitrary command execution through Gate
- INVARIANT-2: Unknown actions are denied
- INVARIANT-3: Unknown packages are denied
- INVARIANT-4: Destructive operations are denied
- INVARIANT-5: Default mode is dry-run
- INVARIANT-6: Repository cannot modify system sudoers
- INVARIANT-7: No secrets are stored or logged
- INVARIANT-8: Policy failure causes non-zero exit status

Verified via `policy-check.sh` and `privilege-policy.test.sh` (28 tests PASS).

## What Gate Is NOT

- NOT kernel-level sandbox
- NOT replacement for sudoers (SYSTEM_SUDO_POLICY remains EXTERNAL)
- NOT container isolation
- Governance layer inside repository

Real isolation needs container/user isolation or actual sudoers policy later.

## Reporting

- Do NOT claim system is absolutely secure
- Say precisely:
  - `LINEX.OS PROJECT PRIVILEGE POLICY → VERIFIED`
  - `SYSTEM sudoers SECURITY → EXTERNAL / NOT CONTROLLED BY REPOSITORY`
- Document BLOCKED cases with evidence

---

**Status:** This document describes repository security policy. At audit commit `a71643a`, `REPOSITORY_STATUS` was PASS for repository security checks, `ENVIRONMENT_STATUS` was BLOCKED (`pkg-config` absent; doctor FAIL/exit 3; P4 network-blocked), and `REMOTE_CI_STATUS` was independently VERIFIED (6/6 jobs). See `docs/reports/baseline-audit-a71643a.md`; these states do not alter the fail-closed doctor result.

**References:**
- Microsoft PowerShell Debian: https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian
- GitHub GITHUB_TOKEN least privilege: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token
