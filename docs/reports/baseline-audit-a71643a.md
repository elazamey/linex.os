# Baseline Audit — measured at `a71643a`

| | |
|---|---|
| **Measured repository commit** | `a71643aba21202a75021b45757d774ca2cc27aaa` (`a71643a`) |
| **Initial Arena measurement time** | UNRESOLVED: prior records conflict and no contemporaneous output was recoverable, so no initial time is asserted. Explicit GitHub and network recheck times are listed below. |
| **Environment** | Arena sandbox, Debian 12 bookworm, `x86_64` (`cat /etc/os-release`; `uname -m`) |
| **System package changes** | NONE. The audit-only `pkgconf-lite` build and binary were kept under `/tmp`; no system package was installed. |
| **GitHub state rechecked** | `2026-10-05T00:54:15Z`, from `date -u +%Y-%m-%dT%H:%M:%SZ` |
| **Network rechecked** | `2026-10-05T00:34:28Z`, from `date -u +%Y-%m-%dT%H:%M:%SZ` |

This report follows `docs/reports/README.md`. It records the baseline at the merged commit; it does
not measure its own contents, line count, or the diff that adds it (R2). The earlier audit at
`d349f92` remains historical evidence in `baseline-audit-d349f92.md` and is not overwritten (R6).

## 1. Independent Results

These are three separate measurements, not one blended status:

```
REPOSITORY_STATUS: PASS
  Repository-owned security and contract verifiers pass. The default-PATH suite set is
  255/256 because the P3 test correctly detects the missing required `pkg-config` tool;
  with the audit-only temporary binary on PATH, the suites are 256/256. This is an
  environment-caused check failure, not evidence that the repository's contracts are defective.

ENVIRONMENT_STATUS: BLOCKED
  `pkg-config` is absent from the default PATH and the approved Debian package mirror is
  unreachable. P3 is 43/44 and `scripts/doctor.sh` correctly retains its FAIL / exit 3.
  P4 PowerShell is also BLOCKED by Arena network restrictions. Do not soften doctor or
  change the test expectation to make this environment look READY.

REMOTE_CI_STATUS: VERIFIED
  GitHub Actions run `37246010719` on `main`, head `a71643a`, succeeded in all six jobs.
  This remote result does not change the local doctor result or environment status.
```

Phase position is independent of the environment verdict. The table below preserves the original
suite labels for traceability; they are not the active phase sequence. The approved active sequence
is P0 Baseline Reconciliation → P1 MVP Definition + ADRs → P2 P9 Runtime Core → P3 P11/P12 Policy
+ Capability → P4 P10 Execution Authority → P5 P13/P14 Vertical Slice → P6 CI + Security + Release.
P1 must establish language, storage, isolation boundary, execution model, evidence model, and failure
semantics by ADR before Runtime implementation. See the active plan in `docs/architecture/roadmap.md`;
ADR 0011 and earlier numbering remain unchanged historical records until explicitly reconciled by ADR.

## 2. Shipped Test Suites — Default Arena PATH

Each command below was run from the repository root. The rows are the source of the aggregate
counts; no unqualified suite result is implied.

| Phase | Exact command | TOTAL | PASSED | FAILED | exit |
|---|---|---:|---:|---:|---:|
| P2 | `./ops/security/tests/privilege-policy.test.sh` | 28 | 28 | 0 | 0 |
| P3 | `./ops/linux/tests/toolchain.test.sh` | 44 | **43** | **1** | **1** |
| P4 | `./ops/powershell/tests/powershell-install.test.sh` | 18 | 18 | 0 | 0 |
| P6 | `./ops/security/tests/agent-contract.test.sh` | 15 | 15 | 0 | 0 |
| P8 | `./tests/architecture.test.sh` | 15 | 15 | 0 | 0 |
| P9 | `./tests/contracts.test.sh` | 15 | 15 | 0 | 0 |
| P10 | `./tests/execution-authority.test.sh` | 36 | 36 | 0 | 0 |
| P11 | `./tests/policy.test.sh` | 40 | 40 | 0 | 0 |
| P12 | `./tests/capability.test.sh` | 45 | 45 | 0 | 0 |
| **Sum of the nine rows above** | The exact commands in this table | **256** | **255** | **1** | — |

The single P3 failure is `version succeeds: pkg-config → FAIL (MISSING)`, emitted by
`./ops/linux/tests/toolchain.test.sh`. Running that suite with the temporary binary on PATH:

```bash
PATH="/tmp/linex-os-pkgconf-p0/bin:$PATH" ./ops/linux/tests/toolchain.test.sh
```

produced `TOTAL: 44`, `PASSED: 44`, `FAILED: 0`, exit `0`. Replacing only that P3 result in the
nine-suite table yields 256/256 for the temporary-PATH audit run; this does not mean the default
PATH was repaired.

## 3. Environment Evidence and Temporary Source Build

P0 classification (without changing test or doctor semantics):

- If `pkg-config` is present, run the P3 suite and classify the environment from the result.
- If it is missing and an approved package source is reachable, remediate only with explicit
  authorization through the privilege Gate, then rerun P3 and doctor.
- If it is missing and approved installation is blocked, classify `ENVIRONMENT_STATUS: BLOCKED`.
  Keep the required-tool test failure and doctor exit 3 visible; do not force an installation,
  bypass the Gate, or change the test expectation.
- The temporary `/tmp` source build in this audit verifies the suite only; it does not make the
  default Arena environment READY.

The commands below were used to distinguish a missing tool from an installed system package:

| Exact command | Observed result |
|---|---|
| `command -v pkg-config` | No path; exit `1` |
| `apt-cache policy pkg-config` | No candidate/output; exit `0` |
| `apt-get -s install pkg-config` | `E: Unable to locate package pkg-config`; exit `100` (simulation only) |
| `curl -sSI --max-time 10 http://deb.debian.org/debian/dists/bookworm/Release` | `curl: (52) Empty reply from server`; exit `52` |

Official source provenance and temporary binary checks:

| Exact command | Observed result |
|---|---|
| `git -C /tmp/linex-os-pkgconf-p0 rev-parse HEAD` | `d908d63634c13b9a4f88d2fe4578d95048a6b13c` |
| `/tmp/linex-os-pkgconf-p0/bin/pkg-config --version` | `3.0.0` |
| `sha256sum /tmp/linex-os-pkgconf-p0/bin/pkg-config` | `38607c477319301da2b25c00e7aff69ea033c4a5ee75c070342483465bcd4fab` |
| `make -C /tmp/linex-os-pkgconf-p0 -f Makefile.lite SYSTEM_LIBDIR=/usr/lib SYSTEM_INCLUDEDIR=/usr/include PKG_DEFAULT_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig check` | exit `0` |

The source was built from the official `pkgconf/pkgconf` repository at the pinned commit above,
then used only from `/tmp` to re-run verification. It was not installed system-wide. Therefore the
manifest classification remains `ENVIRONMENT-DEPENDENT`, the default PATH remains missing
`pkg-config`, and no package-install workaround is claimed.

Network recheck at `2026-10-05T00:34:28Z` (timestamp from `date -u +%Y-%m-%dT%H:%M:%SZ`):

| Exact command | Result |
|---|---|
| `curl -IsS --max-time 8 https://github.com` | HTTP/2 200; exit `0` |
| `curl -IsS --max-time 8 https://api.github.com` | HTTP/2 200; exit `0` |
| `curl -IsS --max-time 8 https://packages.microsoft.com` | `SSL_ERROR_SYSCALL`; exit `35` |
| `curl -IsS --max-time 8 https://release-assets.githubusercontent.com` | `SSL_ERROR_SYSCALL`; exit `35` |
| `curl -IsS --max-time 8 http://deb.debian.org/debian/dists/bookworm/Release` | `Empty reply from server`; exit `52` |

`packages.microsoft.com` and GitHub release assets were BLOCKED; `github.com` and `api.github.com`
were reachable. P4 remains BLOCKED, and no third-party PowerShell source was used.

## 4. Doctor Semantics — Preserved Fail-Closed

Default PATH command:

```bash
./scripts/doctor.sh
```

Observed result: `P3 Toolchain FAIL`, `Tests FAIL`, `Counts: PASS=45 FAIL=1 BLOCKED=2 NOT_VERIFIED=1`,
`FOUNDATION STATUS: FAIL`, exit `3`. The single essential failure is the P3 toolchain suite
because `pkg-config` is missing. P4 PowerShell is separately reported as the known network blocker;
it does not explain away the P3 failure.

With the temporary binary on PATH, the command

```bash
PATH="/tmp/linex-os-pkgconf-p0/bin:$PATH" ./scripts/doctor.sh
```

returned `P3 Toolchain Tests → PASS (44/44)`, `Counts: PASS=47 FAIL=0 BLOCKED=2 NOT_VERIFIED=0`,
and `PASS WITH KNOWN BLOCKER` for P4, exit `0`. That result applies only to the temporary PATH.
ADR 0011 D3's doctor semantics are unchanged: the default-PATH missing required tool stays FAIL / exit 3.

The narrower `./ops/linux/doctor.sh` reported
`STATUS → NOT VERIFIED - 1 tools missing (pkg-config likely)`, exit `0`; it is not the aggregate
`scripts/doctor.sh` and does not override its exit code.

## 5. Repository Security and Contract Verification

These commands were run independently of the aggregate doctor:

| Exact command | Result |
|---|---|
| `mapfile -d '' files < <(find ops scripts tests -type f -name '*.sh' -print0); for f in "${files[@]}"; do bash -n "$f"; done` | 24 shell files parsed; exit `0` |
| `./ops/security/policy-check.sh` | `STATUS → PASS`; exit `0` |
| `./ops/security/secret-scan.sh` | `STATUS → PASS`; exit `0` |
| `./ops/security/static-security-check.sh` | `STATUS → PASS`; exit `0` |
| `./ops/verify/verify-architecture.sh` | `STATUS → PASS`; exit `0` |
| `./ops/verify/verify-contracts.sh` | `STATUS → PASS`; exit `0` |
| `./ops/verify/verify-execution-authority.sh` | `STATUS → PASS`; exit `0` |
| `./ops/verify/verify-policy.sh` | `STATUS → PASS`; exit `0` |
| `./ops/verify/verify-capability.sh` | `STATUS → PASS`; exit `0` |
| `./ops/verify/verify-environment.sh` | `STATUS → PASS (with PowerShell NOT VERIFIED expected)`; exit `0` |
| `./ops/bootstrap/bootstrap.sh` | `STATUS → PASS`; exit `0`; no installation performed |

The shell-file count is a syntax-check scope, not a test-pass count. Repository security and
contract checks passing does not convert the environment-dependent P3 failure into PASS.

## 6. GitHub and Remote CI Cross-Check

The local session branch and remote refs were rechecked at `2026-10-05T00:54:15Z`:

| Exact command | Observed result |
|---|---|
| `git branch --show-current` | `arena/01a1095e-linex-os` |
| `git rev-parse HEAD` | `a71643aba21202a75021b45757d774ca2cc27aaa` |
| `git ls-remote --heads origin main` | `a71643aba21202a75021b45757d774ca2cc27aaa refs/heads/main` |
| `git ls-remote --heads origin arena/01a1095e-linex-os` | No matching remote head returned |
| `gh pr view 3 --repo elazamey/linex.os --json number,title,state,mergedAt,mergeCommit,url` | PR #3 `MERGED`, merged `2026-10-05T00:04:00Z`, merge commit `a71643aba21202a75021b45757d774ca2cc27aaa` |

PR #3's merged title is “Baseline reconciliation: audited d349f92, ADR 0011 (evidence +
phase-numbering authority), roadmap/status corrected.” Its merged result is the baseline inspected
here; the earlier `baseline-audit-d349f92.md` remains historical evidence.

Remote run metadata was checked with:

```bash
gh run view 37246010719 --repo elazamey/linex.os \
  --json conclusion,headSha,headBranch,event,jobs,createdAt,updatedAt,url
```

Observed `conclusion=success`, `headBranch=main`, `headSha=a71643aba21202a75021b45757d774ca2cc27aaa`,
event `push`; all six job conclusions were `success`:

- Job 1: Repository / Static Validation
- Job 2: Security Validation
- Job 3: Policy Tests (P2)
- Job 4: Toolchain Tests (P3)
- Job 5: Contract Tests (P4, P6)
- Job 6: Doctor / Final Verification (P7)

The runner log archive was not retrievable from Arena:

```bash
gh run view 37246010719 --repo elazamey/linex.os --log
```

returned EOF from `results-receiver.actions.githubusercontent.com`. Remote CI is therefore
`VERIFIED` at job-conclusion granularity only; runner log contents are `NOT VERIFIED` from this
sandbox (ADR 0011 D7).

## 7. Scope and Follow-Up

This report is a baseline snapshot. The P0 changes that consume it are documentation-only: they do
not implement Runtime, change doctor behavior, install a system package, or rewrite ADR 0011 or
other historical ADRs. The active P0–P6 plan is recorded in `docs/architecture/roadmap.md`; P1 must
explicitly reconcile or reaffirm earlier ADR decisions before any P2 Runtime work. The proposed MVP
scope remains a proposal until those P1 ADRs are accepted. The default Arena doctor FAIL and remote
CI VERIFIED result remain separate.
