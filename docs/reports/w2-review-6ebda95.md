# W2-only review and proposed remediation — baseline `6ebda95`

- **Baseline measured:** `6ebda957e36b17d058ddad481ab7e1486782f47e` (merged PR #5).
- **Environment:** Arena, Debian 12, 2026-10-05 UTC.
- **Remediation evidence:** the W2-only working tree based on that commit; use the
  commit containing this report to reproduce the proposed scripts.
- **Approval:** awaiting owner review. No merge authorized or performed by this change.
- **Historical correction:** supplements, does not rewrite, the triage audit/register
  and merge message. Neither `COMPLETE_VERIFIED` nor green CI means W2 is resolved in main.

## 1. What was verified at the baseline

```text
$ gh pr view 5 --json state,mergedAt
{"mergedAt":"2026-10-05T06:24:27Z","state":"MERGED"}
$ gh pr view 6 --json state,mergedAt
{"mergedAt":null,"state":"OPEN"}
$ gh pr view 5 --json reviews
{"reviews":[]}
```

The merge message claims W2 was reviewed. The empty reviews array establishes only
that no GitHub review is recorded; it cannot establish whether an external review
occurred or whether the owner's condition was met.

Both baseline workflows contain direct privileged provisioning:

```bash
git show 6ebda95:.github/workflows/ci.yml | grep -n 'sudo apt-get'
git show 6ebda95:.github/workflows/ci-debug.yml | grep -n 'sudo apt-get'
```

The actual package gap is **one of eighteen: `python3`**, not three. `findutils` and
`gawk` are already package names in `P3_PKGS`; `find` and `awk` belong to the separate
command-presence loop. Derivation (read-only, not sourcing workflow code):

```bash
ref=6ebda95
ci_packages=$(git show "$ref:.github/workflows/ci.yml" |
  sed -n 's/^[[:space:]]*P3_PKGS="\([^"]*\)"/\1/p')
gate_packages=$(git show "$ref:ops/security/privilege-gate.sh" |
  awk '/^ALLOWED_PACKAGES=\(/ { list=1; next }
       list && /^\)/ { exit }
       list && /"/ { gsub(/["[:space:]]/, ""); print }')
read -r -a packages <<< "$ci_packages"
printf 'P3_PKGS: %s\n' "${#packages[@]}"
for package in "${packages[@]}"; do
  if ! grep -Fxq -- "$package" <<< "$gate_packages"; then
    printf 'Not allowlisted: %s\n' "$package"
  fi
done
# P3_PKGS: 18
# Not allowlisted: python3
```

## 2. Scope of the proposed fix

- Both workflows call `ops/ci/provision-toolchain.sh`, with fixed `p3` and `debug`
  profiles. The existing P3 package set and debug prerequisites are retained.
- The helper defaults to dry-run. Every profile package is preflighted through the
  real Gate before any execution, including packages already present. Tool/package
  mapping is explicit; the certificate bundle is checked as a package, not a command.
- Explicit `--execute` performs a Gate-mediated index refresh and installs only
  missing packages, one Gate action at a time. Refusal/failure stops without a fallback;
  a final presence check rejects a successful installer exit with an unmet prerequisite.
- The only new Gate package is `python3`, justified in policy section 5.1. Existing
  build allowances are documented there too. No `nodejs`/`npm` expansion.
- **Review consequence:** this Gate shares its package list between install and
  remove actions. Adding `python3` also permits the existing explicitly authorized
  removal action. CI does not invoke removal. This is not an install-only permission.
- A new regression suite runs in CI's Security job (before provisioning) and in CI
  Debug. No existing checker, expectation, exclusion, or fail-closed exit is weakened.

**Excluded:** `userpath/`, ADR 0012, product code, provider/hosting selection,
P18 changes, the `install-base.sh` default-mode fix, and the other PR #6 changes.
PR #6's branch is not modified by this split; its combined change still needs a
separate owner decision and must not be treated as approved by this W2-only proposal.

## 3. Verification of the proposal (local, not a real installation)

### Focused regression suite

```text
$ bash tests/ci-provisioning.test.sh
TOTAL: 53
PASSED: 53
FAILED: 0
Evidence scope: real Gate DRY-RUN + mocked provisioning; no real installs.
```

This is a mixed suite, not a claim of real installation coverage: it checks workflow
wiring and explicit policy lists, invokes the real Gate in dry-run, exercises the
helper against an isolated fake Gate, and probes the workflow guards with mutations.
The fake installation/state files exist only in temporary directories.

Cases include default/explicit dry-run; already-present tools; missing Gate;
unsupported runner; rejected arguments; preflight denial even for a present package;
update refusal/failure; install failure preventing subsequent installs; unmet
postconditions; command-to-package mapping; and certificate preservation.

Full-suite negative re-runs in temporary copies, never in the working tree:

| Mutation before `bash tests/ci-provisioning.test.sh` | Observed result |
|---|---|
| Delete the `"python3"` row from the copied Gate | exit 1; Python preflight and policy-list comparison FAIL |
| Append a direct install line to the copied `ci.yml` | exit 1; workflow guard FAIL |
| Append the old inline install form to the copied `ci-debug.yml` | exit 1; workflow guard FAIL |

The suite itself also contains executable mutation probes for both workflows and
for a softened provisioning step. The literal-command scanner is **not a shell
parser, sandbox, or proof against arbitrary indirect/obfuscated execution**.

Real helper defaults in this sandbox:

```text
$ bash ops/ci/provision-toolchain.sh p3
MISSING packages (p3): pkg-config
DRY-RUN: plan only; no packages installed (use --execute explicitly)
$ bash ops/ci/provision-toolchain.sh debug
MISSING packages (debug): pkg-config
DRY-RUN: plan only; no packages installed (use --execute explicitly)
```

### Existing checks and the local no-install guard

**Important pre-existing defect, not repaired here:** P2 TEST 13c invokes
`package-install curl --execute` even though its comment says no real install. To
avoid installing locally, legacy suites and doctor were run with temporary PATH
wrappers: `sudo -n true`, `sudo -l`, and `sudo --version` delegate to the real
read-only command; other sudo and direct APT calls are refused with exit 97.
No repository test or assertion is changed by this instrumentation. These results
are therefore **guarded local runs**, not uninstrumented executions.

| Command (under that guard) | Result |
|---|---|
| `bash ops/security/tests/privilege-policy.test.sh` | 28/28, exit 0 |
| `bash ops/linux/tests/toolchain.test.sh` | 43/44, exit 1: only `pkg-config` MISSING |
| `bash ops/powershell/tests/powershell-install.test.sh` | 18/18, exit 0 (logic, not a PowerShell installation) |
| `bash ops/security/tests/agent-contract.test.sh` | 15/15, exit 0 |
| `bash tests/architecture.test.sh` | 15/15, exit 0 |
| `bash tests/contracts.test.sh` | 15/15, exit 0 |
| `bash tests/execution-authority.test.sh` | 36/36, exit 0 |
| `bash tests/policy.test.sh` | 40/40, exit 0 |
| `bash tests/capability.test.sh` | 45/45, exit 0 |
| `bash scripts/doctor.sh` | exit 3; `PASS=45 FAIL=1 BLOCKED=2 NOT_VERIFIED=1` |

The guard recorded refused `curl` installation calls from the legacy test. The
existing P3 failure and doctor exit are preserved, not converted to PASS.

Other checks:

- `for name in policy-check secret-scan static-security-check; do bash "ops/security/$name.sh"; done`:
  each exits 0; also re-run without the guard.
- `for name in architecture contracts execution-authority policy capability; do bash "ops/verify/verify-$name.sh"; done`:
  each exits 0. `bash ops/verify/verify-environment.sh` exits 0 with PowerShell
  NOT VERIFIED. These are the existing checkers, not semantic product verification.
- `find ops scripts tests -type f -name '*.sh'`: each result checked with `bash -n`,
  no syntax failures. Every literal `run: |` block in both workflows was also
  extracted and syntax-checked; existing CI Configuration and Security patterns
  steps were re-run successfully.
- `git diff --check`: exit 0. `shellcheck`, `actionlint`, `yamllint`: unavailable;
  no package was installed to add them.

Package database and installation-log hashes were captured before and after with
`sha256sum /var/lib/dpkg/status /var/log/dpkg.log /var/log/apt/history.log`, then
compared with `diff -u`: identical. This supports **no local package installation**;
it is not a claim that no temporary file or unrelated background state changed.

## 4. Remaining verification and approval boundary

- Real package installation by the new helper: **NOT VERIFIED locally**. Simulated
  failure/success paths and real dry-runs are not production installation evidence.
- Remote CI at this report's writing: **NOT VERIFIED**. Record subsequent run URLs
  and conclusions in the PR, separately from this append-only snapshot.
- The legacy P2 test's real installation attempt remains outside this W2-only fix.
- Main still contains W2 until an independently reviewed fix is merged. Opening a
  PR or passing tests does not approve a policy change or authorize a merge.
