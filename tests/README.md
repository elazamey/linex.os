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

## Foundation Test Inventory (P1-P7)

The table below records the original P5 foundation suites; later contract suites are listed separately.

| Test File | Count | Status | Notes |
|-----------|-------|--------|-------|
| ops/security/tests/privilege-policy.test.sh | 28 | PASS | No real install/remove, dry-run only, tests blocking for ; && $() backticks | etc., fail-closed |
| ops/linux/tests/toolchain.test.sh | 44 | 43/44 locally; CI PASS after provisioning | `pkg-config` is absent in a fresh Arena sandbox and apt mirrors are blocked; all other checks, including C/C++ smoke, pass |
| ops/powershell/tests/powershell-install.test.sh | 18 | PASS (logic) / BLOCKED (install) | Debian detection, arch detection, source allowlist, third-party blocked, arbitrary URL blocked, arbitrary path blocked, curl|bash blocked, apt upgrade blocked, metadata validation, pwsh --version logic, smoke test logic, Gate P4 actions, no snap — install itself BLOCKED due to Arena network (packages.microsoft.com and release-assets blocked) |

**Foundation baseline in Arena:** 90 tests across P2-P4; 89 pass and 1 P3 check fails because `pkg-config` is unavailable locally. P2 28/28 and P4 logic 18/18 pass; P4 installation remains BLOCKED by the known network restriction. CI provisions the P3 baseline before checking it.

## P13 Agent Runtime Contract Checks

| Test File | Count | Status | Notes |
|-----------|-------|--------|-------|
| `tests/agent-runtime.test.sh` | 28 | PASS locally | Contract and eight structured acceptance vectors only; no Agent Runtime simulation |
| `ops/verify/verify-agent-runtime.sh` | 11 | PASS locally | Read-only contract verification; acceptance YAML 1.2 JSON subset parsed with existing `jq` |

The P13 scenarios cover a valid typed proposal, ambiguity, capability/scope denial, approval,
verified completion, rejection audit, fail-closed unknowns, and untrusted context. Every vector
has one primary assertion. This is contract evidence, not runtime, immutability, or production
evidence. CI Job 5 is configured to run both P13 checks; remote CI for the current session-branch
changes is pending.

## Running Tests

```bash
# Foundation suites
./ops/security/tests/privilege-policy.test.sh
./ops/linux/tests/toolchain.test.sh
./ops/powershell/tests/powershell-install.test.sh

# P13 contract-only checks
./tests/agent-runtime.test.sh
./ops/verify/verify-agent-runtime.sh

# Static
find ops scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
# shellcheck if available
shellcheck ops/**/*.sh || echo "shellcheck SKIPPED"

# Verification
./ops/verify/verify-environment.sh
./scripts/doctor.sh
./ops/linux/doctor.sh
./ops/security/policy-check.sh
```

## CI

- `.github/workflows/ci.yml` runs static/security validation, P2-P4/P6 foundation tests, and the P13 contract test plus verifier in Job 5
- P4 tests that require `pwsh` are classified as NOT VERIFIED / CONDITIONAL if it is missing, not fake PASS
- P13 vectors are parsed with the existing `jq`; CI does not install an additional YAML or runtime dependency
- Uses `permissions: contents: read` (least privilege)
- No Docker, PowerShell, cloud credentials, secrets assumed
- If GitHub Actions local tool not available: SKIPPED — TOOL NOT AVAILABLE, don't claim GitHub-hosted runner succeeded

## No Secrets in Tests

- Tests must not contain API keys, tokens, passwords
- Tests may contain strings like "curl|bash" as test cases for blocking, but must be excluded from security checks that look for actual executable patterns (e.g., exclude /tests/ directories or check only lines starting with optional whitespace and then curl|bash as executable)

---

**Status:** Foundation test inventory preserved; P13 contract checks are 28/28 locally and verifier checks 11/11. P3/P4 environment blockers remain explicitly distinct from contract-test results; Local PASS ≠ Production PASS.

**Next:** P14 Tool + Skill Contract.
