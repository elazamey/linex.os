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

- The P0 audit snapshot for this Arena environment is recorded in `docs/reports/baseline-audit-a71643a.md`; network and resource values are measurements, not live claims.
- Local tests prove logic and contracts, not production readiness. GitHub Actions provides REMOTE CI evidence, not production evidence; production PASS requires verification in the actual production environment.

## Shipped Test Suites (legacy P2–P4 labels)

These original suite labels identify the test artifacts; they are not the active P0–P6 phase sequence.

| Command (run from repository root) | Count | P0 audit result | Notes |
|------------------------------------|-------|-----------------|-------|
| `./ops/security/tests/privilege-policy.test.sh` | 28 | 28/28 PASS | No real install/remove; dry-run and fail-closed behavior |
| `./ops/linux/tests/toolchain.test.sh` | 44 | Default PATH: 43/44 (single `pkg-config` failure); temporary official-source PATH: 44/44 | Also validates package mapping, Gate use, C/C++ smoke tests, and forbidden install patterns |
| `./ops/powershell/tests/powershell-install.test.sh` | 18 | 18/18 PASS (logic); PowerShell runtime/install BLOCKED | Policy and install logic only; no claim that `pwsh` is installed or verified |

The three suites contain 90 checks in total (`28 + 44 + 18`). In the P0 default-path run,
89/90 passed and the one failure was the required-but-missing `pkg-config` check. The temporary
source-built binary under `/tmp` made the P3 suite 44/44 for verification only; no system package
was installed and the default environment remained unchanged. See `docs/reports/baseline-audit-a71643a.md`.

## Running Tests

```bash
# P2/P3/P4 suites; default Arena may fail P3 if pkg-config is absent.
# scripts/doctor.sh must retain exit 3 for this required-tool failure.
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

- `.github/workflows/ci.yml` runs six repository/static, security, policy, toolchain, contract, and doctor jobs; it does not deploy.
- The P0 audit verified GitHub Actions run `37246010719` on `main` at `a71643a`: all six job conclusions were `success` (`gh run view 37246010719 --json conclusion,headSha,headBranch,event,jobs`).
- Uses `permissions: contents: read` (least privilege); no Docker installation, cloud credentials, or production services are assumed.
- Runner log bodies were not retrievable from Arena (`gh run view 37246010719 --log` returned EOF); claim only job-conclusion granularity.
- A local GitHub Actions tool is not a substitute for a real GitHub-hosted run.

## No Secrets in Tests

- Tests must not contain API keys, tokens, passwords
- Tests may contain strings like "curl|bash" as test cases for blocking, but must be excluded from security checks that look for actual executable patterns (e.g., exclude /tests/ directories or check only lines starting with optional whitespace and then curl|bash as executable)

---

**Status:** Test categories and shipped suites are documented. At baseline commit `a71643a`, `REPOSITORY_STATUS: PASS` for repository-owned security/contract verifiers, `ENVIRONMENT_STATUS: BLOCKED` (`pkg-config` missing; doctor FAIL/exit 3), and `REMOTE_CI_STATUS: VERIFIED` (6/6 jobs) are separate; see `docs/reports/baseline-audit-a71643a.md`.

**Next:** P1 MVP Definition + ADRs per `docs/architecture/roadmap.md`. No Runtime implementation before P1 decisions are accepted.
