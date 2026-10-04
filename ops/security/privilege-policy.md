# LINEX.OS - Privilege Policy (P2)

> **Principle:** System sudo ≠ Project policy. `sudo NOPASSWD: ALL` is external, project gate is allowlist + structured actions + fail-closed.

## 1. Architecture

```
AI proposes
   ↓
Policy validates
   ↓
Privilege Gate
   ↓
Execution
   ↓
Evidence / Result
```

The Privilege Gate is **not a general shell**. It does NOT allow:

```
sudo bash
sudo sh
sudo env
sudo -i
sudo su
sudo <arbitrary-command>
sudo "$USER_INPUT"
eval "$INPUT"
bash -c "$INPUT"
sh -c "$INPUT"
```

All execution is via **structured actions** with validated arguments.

## 2. Privilege Levels (literal)

### READ_ONLY
- Allowed without sudo
- Examples: check-package-manager, repository inspection, OS detection
- No system modification

### SAFE_USER_COMMAND
- Allowed if command is explicitly classified safe and defined in policy
- May use sudo only for read-only checks (sudo -n true, sudo -l, systemctl is-active)
- No modification

### PACKAGE_INSTALL
- **Denied by default** until passing through Gate
- Requires explicit allowlisted package name
- Requires --execute flag for real execution
- Default mode is DRY-RUN
- In P2 phase, real execution is implemented but NOT used in tests to keep REPOSITORY-ONLY

### PRIVILEGED_OPERATION
- **Denied by default** until action explicitly defined in Policy
- Example: service-status (read-only status of service)
- Requires validation, no arbitrary commands

### DESTRUCTIVE_OPERATION
- **Always denied in P2**
- Includes: rm -rf /, mkfs, dd, fdisk, shutdown, reboot, iptables -F, etc.
- See forbidden-commands.txt

## 3. Default Policy

| Level | Default |
|-------|---------|
| READ_ONLY | ALLOW |
| SAFE_USER_COMMAND | ALLOW IF explicitly safe |
| PACKAGE_INSTALL | DENY (requires Gate + allowlist) |
| PRIVILEGED_OPERATION | DENY (requires explicit action) |
| DESTRUCTIVE_OPERATION | DENY ALWAYS (P2) |

Unknown action, unknown package, invalid args, missing policy, malformed input, unexpected environment, forbidden token → **BLOCKED** with non-zero exit.

## 4. Allowed Actions (P2 - minimal set)

### check-sudo
- Class: READ_ONLY
- Description: Verify sudo availability via read-only checks
- Execution: sudo -n true, sudo -l
- Args: none
- Dry-run: shows would execute, --execute does real read-only check

### check-package-manager
- Class: READ_ONLY
- Description: Detect package manager (apt-get, apt, dnf, yum, pacman, apk, etc.)
- Execution: command -v checks
- Args: none

### package-install
- Class: PACKAGE_INSTALL
- Description: Install allowlisted package (dry-run default)
- Usage: privilege-gate.sh package-install <approved-package>
- Validation:
  - Package name must match regex: ^[a-z0-9][a-z0-9+._-]{0,63}$
  - No shell metacharacters: ; & | $ ` \ " ' < > ( ) { } * ? ! ~ # = % + (except + allowed in middle) etc.
  - No command substitution: $(), ``
  - No pipes, redirects, semicolon, &&, ||
  - No path traversal: no / or .. 
  - No options: must not start with -
  - Must be in ALLOWED_PACKAGES allowlist
  - No shell interpreter for value (direct exec, not bash -c)
- Execution (with --execute): sudo <pkg-manager> install -y <package> (apt-get example)
- In P2 tests: only dry-run used, no real install

### package-remove
- Class: PACKAGE_INSTALL (treated same as install for policy)
- Description: Remove allowlisted package (dry-run default)
- Same validation as package-install
- Execution (with --execute): sudo <pkg-manager> remove -y <package>
- In P2 tests: only dry-run

### service-status
- Class: SAFE_USER_COMMAND
- Description: Check status of allowlisted service (read-only)
- Usage: privilege-gate.sh service-status <service-name>
- Validation: same strict name validation as package, plus service must be in allowed list or match safe pattern
- Execution: systemctl is-active <service> or systemctl status <service> --no-pager (read-only)

## 5. Package Allowlist (P2)

**DEFAULT: DENY** - any package not in list → BLOCKED

```
ALLOWED_PACKAGES:
- ca-certificates
- curl
- wget
- git
- jq
- tar
- gzip
- zip
- unzip
- bash
- coreutils
- findutils
- grep
- sed
- gawk
```

This list is explicit and reviewable. No package outside this list is allowed in P2.
Future phases may extend list via policy change with justification.

For testing in P2, we use these known packages only in dry-run mode, no real install.

## 6. Forbidden Commands

See ops/security/forbidden-commands.txt

Design is **ALLOWLIST + structured actions + fail-closed**, NOT blacklist only. Forbidden list is defense-in-depth, not primary control.

Primary control:
- Unknown action → BLOCKED
- Unknown package → BLOCKED
- Invalid args → BLOCKED
- Missing policy → BLOCKED (fail-closed)

## 7. Sudo Policy

### SYSTEM_SUDO_POLICY
- Current environment: sudo NOPASSWD: ALL (user may run ALL commands as ALL without password)
- Evidence: sudo -n true → PASS, sudo -l → (ALL : ALL) ALL, (ALL) NOPASSWD: ALL
- Status: **EXTERNAL / NOT CONTROLLED BY REPOSITORY**
- P2 does NOT modify /etc/sudoers, /etc/sudoers.d/*, /etc/passwd, /etc/group
- P2 does NOT attempt to "fix" sudoers
- Documented as sensitive environmental condition

### PROJECT_PRIVILEGE_POLICY
- Controlled by LINEX.OS Gate (ops/security/privilege-gate.sh)
- Enforces allowlist, structured actions, fail-closed
- Default dry-run, explicit --execute required for real execution
- No arbitrary command execution
- No secrets in logs

**Important distinction:**
```
System privilege (sudoers NOPASSWD: ALL) ≠ Project policy (Gate)
System can do sudo <anything> outside Gate → YES (expected in current env)
Project via Gate allows sudo <anything> → NO (BLOCKED unless explicitly allowed action + allowlist)
Gate is governance layer, not kernel sandbox. Real isolation needs container/user isolation later.
```

## 8. Fail-Closed

Any of:
- unknown action
- unknown package
- invalid arguments
- missing policy file
- malformed input
- unexpected environment
- forbidden token (;, &&, ||, |, $, `, >, <, etc. in package name)
- empty input

→ Result: BLOCKED, non-zero exit code, evidence logged, no execution.

## 9. Dry-Run Default

privilege-gate.sh default mode is DRY-RUN:

```
ACTION: package-install
CLASS: PACKAGE_INSTALL
POLICY: ALLOW (allowlisted)
DECISION: DRY-RUN (would execute)
WOULD EXECUTE: sudo apt-get install -y curl
EXECUTION: NOT EXECUTED (dry-run)
EXIT_CODE: 0
TIMESTAMP: ...
```

Real execution requires explicit flag:

```
--execute
```

--execute is rejected unless Action is explicitly allowed and args validated. Even with --execute, unknown/invalid → BLOCKED.

## 10. Evidence Format

Every Gate invocation outputs structured evidence without secrets:

```
ACTION: <action>
CLASS: <level>
POLICY: <ALLOW|DENY|BLOCKED>
DECISION: <ALLOW|BLOCKED|DRY-RUN|EXECUTED>
EXECUTION: <NOT EXECUTED|EXECUTED|FAILED>
WOULD EXECUTE: <command that would be executed (sanitized)>
EXIT_CODE: <0|non-zero>
TIMESTAMP: <UTC ISO8601>
SYSTEM_SUDO: <AVAILABLE_NOPASSWD|etc>
PROJECT_POLICY: CONTROLLED BY LINEX.OS GATE
```

Must NOT log:
- passwords
- tokens
- API keys
- environment secrets
- credential material

## 11. Logging

- No permanent log with secrets inside repository
- Temporary safe output for testing allowed: /tmp/linex-os-privilege-test.log
- No secrets file inside repository

## 12. Security Invariants (P2)

INVARIANT-1: No arbitrary command execution through Gate.
INVARIANT-2: Unknown actions are denied.
INVARIANT-3: Unknown packages are denied.
INVARIANT-4: Destructive operations are denied.
INVARIANT-5: Default mode is dry-run.
INVARIANT-6: Repository cannot modify system sudoers.
INVARIANT-7: No secrets are stored or logged.
INVARIANT-8: Policy failure causes non-zero exit status.

## 13. P2 Scope

P2 is REPOSITORY-ONLY:

Allowed:
- Read-only checks: sudo -n true, sudo -l, command -v, cat /etc/os-release
- Policy file creation
- Gate script creation
- Tests in dry-run mode

Forbidden in P2 (system changes):
- apt install / apt remove / apt upgrade
- systemctl modification (enable, disable, start, stop) - only status/is-active allowed as read-only
- useradd, usermod, userdel, groupadd, groupdel
- sudoers modification
- reboot, shutdown, poweroff
- firewall modification (iptables -F, nft flush)
- disk modification (mkfs, fdisk, dd, wipefs, parted)
- network modification

## 14. References

- Microsoft PowerShell Debian 12 support: Debian 12 supported until 2028-06-30 (for P4)
- GitHub Actions GITHUB_TOKEN least privilege (for future CI)
- P1 Environment: Debian 12 bookworm x86_64, apt-get, sudo NOPASSWD: ALL, pwsh NOT VERIFIED

## 15. Next Phases

P3 Linux Toolchain will use Gate for package-install with allowlist.
P4 PowerShell will use Gate for official Microsoft repo installation via structured action (future: add pwsh-install action).
P2 establishes the governance layer so P3/P4 cannot do sudo <arbitrary>.
