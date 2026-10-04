# LINEX.OS — Tests

## Test Levels

### 1. Unit

- Small, isolated tests for individual functions
- Example: `validate_name()` in privilege-gate.sh — test package name with `;`, `&&`, `$()`, backticks → BLOCKED
- No system changes, no network, no privileged operations

### 2. Static

- `bash -n` syntax check for all Bash scripts (mandatory)
- `shellcheck` if available, else SKIPPED (not FAILURE)
- PowerShell syntax validation only if pwsh available, else SKIPPED
- Check for dangerous patterns: no `eval` as executable, no `curl | bash` as executable, no `sudo sh -c` as executable, no `apt upgrade` as executable — with exclusions to avoid self-match on test files that intentionally test blocking
- Check for no secrets

### 3. Integration

- Tests that combine multiple components
- Example: `install-base.sh` → Gate dry-run → Gate --execute → verification
- Example: `install-pwsh.sh` → network checks → Gate dry-run → Gate execution → pwsh --version
- May require network (github.com PASS, deb.debian.org BLOCKED in Arena), so some integration tests may be BLOCKED with evidence, not fake PASS

### 4. Smoke

- Minimal build tests that prove toolchain works
- Example P3:
  - C: create temp `test.c` with `printf("LINEX.OS C SMOKE PASS")` → `gcc test.c -o test_c` → run → expected output → delete artifact
  - C++: same with `g++`
- Example P4:
  - PowerShell: `pwsh -NoLogo -NoProfile -Command '"LINEX.OS POWERSHELL SMOKE PASS"'` → expected output
- No production code used for smoke tests, only tiny temporary files

### 5. System

- Full system verification via `verify-environment.sh`, `doctor.sh`, `policy-check.sh`
- Checks Repository, Git, Linux shell, sudo, PowerShell, Package manager, Network, Required tools, Disk, Memory, Security
- Outputs VERIFIED / NOT VERIFIED / BLOCKED / PASS with evidence

### 6. Production Evidence

- Evidence that would be valid in production, not just local sandbox
- Example: `dpkg-query -W` for installed packages, `pwsh --version` with PSVersionTable, `git log --oneline` for branch, `df -h` and `free -h` for resources
- Local PASS in Arena sandbox proves logic, but Local PASS ≠ Production PASS — production needs actual deployment verification

## Important Principle

```
Local PASS ≠ Production PASS
```

- Tests in Arena sandbox (Debian 12 bookworm x86_64, 21G disk, 3.8Gi memory, github.com PASS, deb.debian.org BLOCKED) prove that logic is correct, fail-closed, allowlist enforced, no arbitrary execution
- Production PASS requires actual production environment verification (e.g., GitHub Actions runner, real Debian 12 host with network allowlist for packages.microsoft.com and release-assets.githubusercontent.com, real PowerShell installation)

## Current Tests (P5)

| Test File | Count | Status | Notes |
|-----------|-------|--------|-------|
| ops/security/tests/privilege-policy.test.sh | 28 | PASS | No real install/remove, dry-run only, tests blocking for ; && $() backticks | etc., fail-closed |
| ops/linux/tests/toolchain.test.sh | 44 | PASS | Required commands exist, version succeeds, package mapping valid, no arbitrary apt, no apt upgrade, no curl|bash, Gate invoked, smoke tests C/C++ PASS |
| ops/powershell/tests/powershell-install.test.sh | 18 | PASS (logic) / BLOCKED (install) | Debian detection, arch detection, source allowlist, third-party blocked, arbitrary URL blocked, arbitrary path blocked, curl|bash blocked, apt upgrade blocked, metadata validation, pwsh --version logic, smoke test logic, Gate P4 actions, no snap — install itself BLOCKED due to Arena network (packages.microsoft.com and release-assets blocked) |

**Total: 90 tests PASS (logic), with P4 install BLOCKED as known network restriction, documented as BLOCKED not fake PASS.**

## Running Tests

```bash
# All
./ops/security/tests/privilege-policy.test.sh
./ops/linux/tests/toolchain.test.sh
./ops/powershell/tests/powershell-install.test.sh

# Static
bash -n $(find ops scripts -name "*.sh" -type f)
# shellcheck if available
shellcheck ops/**/*.sh || echo "shellcheck SKIPPED"

# Verification
./ops/verify/verify-environment.sh
./scripts/doctor.sh
./ops/linux/doctor.sh
./ops/security/policy-check.sh
```

## CI

- `.github/workflows/ci.yml` runs static validation only (bash -n, dangerous pattern checks with exclusions)
- Runs P2, P3, P4 policy tests (P4 tests that require pwsh classified as NOT VERIFIED / CONDITIONAL if pwsh missing, not fake PASS)
- Uses `permissions: contents: read` (least privilege)
- No Docker, PowerShell, cloud credentials, secrets assumed
- If GitHub Actions local tool not available: SKIPPED — TOOL NOT AVAILABLE, don't claim GitHub-hosted runner succeeded

## No Secrets in Tests

- Tests must not contain API keys, tokens, passwords
- Tests may contain strings like "curl|bash" as test cases for blocking, but must be excluded from security checks that look for actual executable patterns (e.g., exclude /tests/ directories or check only lines starting with optional whitespace and then curl|bash as executable)

---

**Status:** P5 Tests foundation documented, 90 tests PASS (logic), P4 install BLOCKED as known network restriction, Local PASS ≠ Production PASS principle enforced.

**Next:** CI foundation, then P6 Agent Contract.
