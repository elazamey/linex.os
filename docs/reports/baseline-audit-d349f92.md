# Baseline Audit — measured at `d349f92`

| | |
|---|---|
| **Measured commit** | `d349f92c9346061237e2d4bf3b0cdd17498f236c` (= `origin/main` at measurement time) |
| **Measured in** | Arena sandbox, Debian 12 bookworm x86_64, 2026-10-04 (UTC) |
| **Worktree** | clean, 0 commits ahead / 0 behind `origin/main` |
| **Clone depth** | 1 (`.git/shallow` present) — ancestry beyond `d349f92` is not inspectable here |
| **System changes made** | NONE. Every command below is read-only detection, grep, or a test suite that the repository itself ships for this purpose |

This report follows `docs/reports/README.md`. Every number carries the command that produced
it (R1). No number in this file measures this file (R2).

## 1. Result

```
STATUS   → PASS WITH ONE ENVIRONMENT BLOCKER
RESULT   → 255 of 256 shipped checks PASS. The single FAIL is pkg-config absence in this
           sandbox, which is not remediable here (apt mirror unreachable) and does not occur
           on the GitHub runner. Remote CI on main is green: 6 of 6 jobs success.
EVIDENCE → Sections 2-4 below, raw logs reproduced by the commands shown
NEXT     → Gaps G1-G9 in section 5; phase decision recorded in ADR 0011
```

## 2. Test suites — all nine, actually executed

Command form: `./<path>` from the repository root, output captured verbatim.

| Phase | Command | TOTAL | PASSED | FAILED | exit |
|---|---|---|---|---|---|
| P2 | `./ops/security/tests/privilege-policy.test.sh` | 28 | 28 | 0 | 0 |
| P3 | `./ops/linux/tests/toolchain.test.sh` | 44 | **43** | **1** | **1** |
| P4 | `./ops/powershell/tests/powershell-install.test.sh` | 18 | 18 | 0 | 0 |
| P6 | `./ops/security/tests/agent-contract.test.sh` | 15 | 15 | 0 | 0 |
| P8 | `./tests/architecture.test.sh` | 15 | 15 | 0 | 0 |
| P9 | `./tests/contracts.test.sh` | 15 | 15 | 0 | 0 |
| P10 | `./tests/execution-authority.test.sh` | 36 | 36 | 0 | 0 |
| P11 | `./tests/policy.test.sh` | 40 | 40 | 0 | 0 |
| P12 | `./tests/capability.test.sh` | 45 | 45 | 0 | 0 |
| | **sum** | **256** | **255** | **1** | |

The five contract suites alone (P8+P9+P10+P11+P12) sum to 15+15+36+40+45 = **151**.

### The one failure, verbatim

```
$ ./ops/linux/tests/toolchain.test.sh | grep -E '→ FAIL|^(TOTAL|PASSED|FAILED|STATUS)'
version succeeds: pkg-config                            → FAIL (MISSING)
TOTAL: 44
PASSED: 43
FAILED: 1
STATUS → FAIL
```

Root cause, measured — not assumed:

```
$ apt-cache policy pkg-config
(no output — no package index present)

$ apt-get -s install pkg-config        # -s = simulate, changes nothing
E: Unable to locate package pkg-config

$ curl -sSI http://deb.debian.org/debian/dists/bookworm/Release
curl: (52) Empty reply from server
```

Classification: **BLOCKED BY ENVIRONMENT** locally (apt mirror unreachable from Arena, and no
system changes are permitted here), and **PASS** in CI. Not a repository defect.

The CI mechanism matters and was verified rather than assumed: `ci.yml` Job 4 contains a step
named `Ensure P3 toolchain baseline (provision, then verify)` (labelled `CI-H4`) which installs
the P3 baseline — `pkg-config` included — *before* running `toolchain.test.sh`, on the explicit
reasoning that "the runner image is not part of the LINEX.OS contract". Its own comment records
the same observation made here: *"observed in the Arena sandbox: 43/44, only pkg-config
missing"*. So Job 4 is green because CI provisions the tool, not because the runner image ships
it — and the local FAIL is the identical condition CI was hardened against.

Two grep artefacts were checked and are *not* failures: `privilege-policy.test.sh` emits
`→ FAIL` twice inside the *name* of TEST 10 (`missing policy → FAIL-CLOSED → PASS`), and
`toolchain.test.sh` emits a second `→ FAIL` as the `STATUS → FAIL` summary line. The real
failing check count is 1.

## 3. Security, verification and doctor layers

| Command | exit | Verdict line emitted |
|---|---|---|
| `bash -n` over all 24 `*.sh` in `ops/ scripts/ tests/` | 0 | all 24 parse clean |
| `./ops/security/policy-check.sh` | 0 | `STATUS → PASS` |
| `./ops/security/secret-scan.sh` | 0 | `STATUS → PASS` |
| `./ops/security/static-security-check.sh` | 0 | `STATUS → PASS` |
| `./ops/verify/verify-architecture.sh` | 0 | 37 `→ PASS`, 0 `→ FAIL` |
| `./ops/verify/verify-contracts.sh` | 0 | 46 `→ PASS`, 0 `→ FAIL` |
| `./ops/verify/verify-execution-authority.sh` | 0 | 67 `→ PASS`, 0 `→ FAIL` |
| `./ops/verify/verify-policy.sh` | 0 | 104 `→ PASS`, 0 `→ FAIL` |
| `./ops/verify/verify-capability.sh` | 0 | 87 `→ PASS`, 0 `→ FAIL` |
| `./ops/verify/verify-environment.sh` | 0 | `STATUS → PASS (with PowerShell NOT VERIFIED expected)` |
| `./ops/bootstrap/bootstrap.sh` | 0 | `STATUS → PASS`, no installation performed |
| `./ops/linux/doctor.sh` | 0 | `STATUS → NOT VERIFIED - 1 tools missing (pkg-config likely)` |
| `./scripts/doctor.sh` | **3** | `FOUNDATION STATUS: FAIL` — see below |

`scripts/doctor.sh` exit-code semantics are its own: `0 = PASS`, `2 = BLOCKED`, `3 = FAIL`.

```
$ ./scripts/doctor.sh | tail -20
P1 Environment          PASS
P2 Privilege            PASS
P3 Toolchain            FAIL
P4 PowerShell           BLOCKED
P5 Repository           PASS
P6 Agent Contract       PASS
P7 Verification         PASS

Security                PASS
Secrets                 PASS
Policy                  PASS
Tests                   FAIL
Git Hygiene             PASS
System Changes          NONE (repository-only)

Counts: PASS=45 FAIL=1 BLOCKED=2 NOT_VERIFIED=1
EXIT CODE: 3 (FAIL)
```

The cascade is single-rooted: `pkg-config` absent → P3 suite exit 1 → doctor's "P3 Toolchain
Tests" FAIL → doctor's "Tests" FAIL → exit 3. Nothing else in the repository contributes to
the FAIL. Note that doctor already has the right instinct for P4 (`PowerShell BLOCKED as known
external Arena blocker does NOT cause overall FAIL`) but has no equivalent treatment for an
environment-dependent *toolchain* gap — that asymmetry is gap G1.

## 4. Remote CI — measured from GitHub, not from a sandbox

```
$ gh run list --branch main --limit 10
completed  success  Merge pull request #2 ...  CI  main  push  37233042304  2m37s

$ gh run view 37233042304 --json conclusion,headSha,headBranch,event,jobs
conclusion = success
headSha    = d349f92c9346061237e2d4bf3b0cdd17498f236c
headBranch = main
event      = push
jobs       = Job 1: Repository / Static Validation      success
             Job 2: Security Validation                 success
             Job 3: Policy Tests (P2)                   success
             Job 4: Toolchain Tests (P3)                success
             Job 5: Contract Tests (P4, P6)             success
             Job 6: Doctor / Final Verification (P7)    success
```

**REMOTE CI at `d349f92` = VERIFIED, 6 of 6 jobs success.** Job 4 (Toolchain, P3) succeeding
while the same suite fails here is the direct proof that the pkg-config FAIL is
environment-specific — and section 2 records *why* Job 4 passes: it provisions the baseline
first (`CI-H4`) instead of trusting the runner image.

Runner log bodies are **NOT RETRIEVABLE from this sandbox**:

```
$ gh run view 37233042304 --log
failed to get run log: Get "https://results-receiver.actions.githubusercontent.com/...": EOF
```

This is the blocker already documented inside `ci.yml` itself (its P4 step emits annotations
precisely because the log archive is unreachable from Arena). So remote evidence is available
at **job-conclusion granularity only**. Any claim about runner log contents is
`NOT VERIFIED` from here and must be labelled as such.

## 5. Gap register

Severity is about *evidence integrity*, not about product risk — the repository is
documentation and gates, so a wrong claim is the defect.

### G1 — Doctor cannot express "environment-dependent", so it reports FAIL

`scripts/doctor.sh` has a documented exemption for the known P4 blocker but none for a
toolchain gap caused by an unreachable package mirror. Result: the aggregator's headline is
`FOUNDATION STATUS: FAIL` / exit 3 for a condition that is not a repository defect and that
does not occur in CI. A reader who runs only doctor concludes the project is broken.

### G2 — `ops/linux/toolchain-manifest.txt` records non-reproducible state as VERIFIED

The manifest's own header says *"Status is VERIFIED only after actual command execution, not
assumed"*. The pkg-config row reads:

```
pkg-config | pkg-config | pkg-config | yes | VERIFIED | 3.0.0 | pkgconf 3.0.0 built from
  GitHub pkgconf/pkgconf via make -f Makefile.lite (Arena sandbox apt mirror blocked,
  workaround via GitHub source)
```

That execution happened — in a previous sandbox, from a source build that lived outside the
repository and is gone. The row is honest about *how* but wrong about *status*: it is not
re-derivable from repository contents, so by R3 it is `ENVIRONMENT-DEPENDENT`. The manifest
has no such status value, which is why the false `VERIFIED` was the only option available.

### G3 — Committed `verification-summary.txt` is stale and contradicted by measurement

The file at `d349f92` asserts:

```
Branch: arena/01a107fc-linex-os      ← not the branch this commit is on
Commit: 768bf39                      ← not this commit
P3: TOTAL: 44 / STATUS → PASS        ← measured here as 43/44, STATUS → FAIL
Counts: PASS=47 FAIL=0 NOT_VERIFIED=0 ← measured here as PASS=45 FAIL=1 NOT_VERIFIED=1
REMOTE CI: NOT VERIFIED (branch not pushed, per P7 spec)  ← false: 6/6 jobs success on main
```

Nothing parses this file (it is referenced only as an *example* evidence artefact in
`docs/architecture.md`, `docs/architecture/data-model.md` and ADR 0005), so it is pure
evidence — and it is wrong evidence, committed to the branch it misdescribes.

### G4 — `README.md` repeats the G2 claim as a present-tense fact

> `P3 Linux Toolchain | ✅ COMPLETE | gcc 12.2.0, g++ 12.2.0, make 4.3, pkg-config 3.0.0
> (built from GitHub pkgconf), python3, node, npm — 44 tests PASS`

Unqualified "44 tests PASS" is true on the runner and false in Arena. The README is the most
read file in the repository, so this is where the misclassification does most damage.

### G5 — Three incompatible meanings of "P13", and P14+ numbering diverges between sources

| Source | P13 | P14 | P15–P18 |
|---|---|---|---|
| `docs/architecture/roadmap.md` | Agent Runtime | Tool Runtime | Skill Runtime, MCP Gateway, Services Layer, Memory Service (…P24) |
| ADR 0008 + ADR 0009 + `docs/contracts/README.md` | Agent Runtime Contract | Tool+Skill Contract | Memory/State/Event, Verification/Eval, MCP, **Technology Selection → implementation** |
| `ci.yml`, `ci-debug.yml`, `powershell-install.test.sh`, `scripts/doctor.sh` comments | "P13 FIX" = six distinct CI/doctor repairs | — | — |

The two planning sources agree that P13 is Agent Runtime and disagree from P14 onward — one
has 12 more phases before implementation, the other has 4 and then an explicit technology
decision. The third usage is not a phase at all: it labels six separate repairs made across
four files — self-matching grep checks in two `ci.yml` steps, a dispatch-only debug runner, P4
failures surfaced as annotations, provision-then-verify for the P3 baseline, a distro-agnostic
PowerShell TEST-1, and a deterministic doctor report. A phase label that means three things
cannot be used to authorise work.

This is the gap that made an unverifiable "P14 Control Plane MVP" handoff plausible: there
was no single authoritative answer to "what is P14?".

### G6 — Roadmap status is four phases behind the repository

`docs/architecture/roadmap.md` says `## Architecture (P8) — CURRENT` and
`REMOTE CI: NOT VERIFIED — branch arena/01a107fc-linex-os not pushed, main at 768bf39`, and
`ci.yml`'s final status step still echoes `NEXT: P8 Architecture Design (after Foundation)`.
Meanwhile ADRs 0007–0010 are `ACCEPTED`, suites P8–P12 pass (151 checks), and CI carries
post-P12 hardening. The document that defines "what phase are we in" is the one document
nobody re-measured.

### G7 — There is no product code, so no "COMPLETE" so far means "working"

Census **of `d349f92` itself** — that is, before the correction commit that carries this report.
Re-running the command on a later commit gives different counts, because this report and its ADR
are themselves Markdown files. The counts are scoped to the measured commit on purpose (R1, R6);
they are not a live claim about the present tree.

```
$ git ls-tree -r --name-only d349f92 | sed 's/.*\.//' | sort | uniq -c | sort -rn
     58 md
     24 sh
      4 ps1
      3 txt
      2 yml
      1 gitignore
      1 LICENSE
```

93 files in total at `d349f92` (`git ls-tree -r --name-only d349f92 | wc -l`).

Zero `.py`, `.c`, `.ts`, `.go`, `.rs`. 16,087 lines of Markdown against 7,260 lines of shell,
and all of that shell is gates, doctor and tests — no runtime. All nine suites assert
*documentation properties* (file existence plus required strings and invariants); their own
headers say "no implementation". This is deliberate and correct per ADR 0009 (implementation
language is `DECISION PENDING` until Technology Selection), but it must be stated plainly
because it redefines every success claim: **"P12 COMPLETE" means "the capability contract is
written, self-consistent and machine-checked", never "a capability system exists".** Any
report describing a functioning gate, ledger or approval flow is describing something that is
not in this repository.

### G8 — Evidence artefacts had no home, no naming rule and no anti-staleness rule

`docs/architecture/data-model.md` defines an Evidence Artifact class (owner, scope, SHA256,
provenance, retention, no secrets) but the repository contained no `docs/reports/`, no naming
convention, and no rule against self-referential or environment-free measurements. Each
sandbox therefore invented its own handoff format — which is how a git bundle plus a
handoff file plus a PR body full of counts-of-itself came to be treated as evidence.
`docs/reports/README.md` (added with this audit) is the fix; R2 and R3 exist specifically to
close this failure mode structurally rather than by convention.

### G9 — Python-based verification is impossible in this sandbox

```
$ command -v pytest || echo ABSENT     → ABSENT
$ python3 -c "import yaml"             → ModuleNotFoundError: No module named 'yaml'
$ python3 -V                           → Python 3.11.2
```

No venv exists and no package index is reachable (section 2). Also absent: `shellcheck`,
`yamllint`, `bc`. Present and usable for a deterministic shell control layer: `jq` 1.6
(`jq -cS` produces canonical sorted-key JSON, verified), `sha256sum`, `openssl`, `git`,
`node` v22.22.3, `npm` 10.9.8. Any verification design that requires PyYAML or pytest cannot
be executed here, so it cannot be evidenced here — which is itself an argument for keeping the
verification layer in the tools the repository already ships.

## 6. Cross-check of the prior "P14 Control Plane MVP" handoff

A handoff report describing commit `59ded43`, a `control/` package, 181 pytest tests and a
`linex-control-59ded43-full.bundle` was presented as completed work. Checked against this
environment and against GitHub:

| Claim | Check run | Result |
|---|---|---|
| `HEAD = 59ded43` | `git rev-parse HEAD`; `git cat-file -t 59ded43` | `d349f92…`; `fatal: Not a valid object name` — **absent locally** |
| `59ded43` exists upstream | `gh api repos/elazamey/linex.os/commits/59ded43` | **422 "No commit found for SHA"** — absent on GitHub |
| Branch `arena/01a10858-linex-os` 11 ahead, 59 files | `git ls-remote origin`; `gh pr list --state all` | head = `24752a2`, PR #2 **MERGED**, 4 files / +395 / −76 |
| `control/` package, `control.cli digest`, `configDigest` | `ls control`; `find . -name '*.py'` | no such directory; **0 Python files** |
| 181 pytest tests in `control/tests` | `command -v pytest` | **ABSENT** — no referent exists |
| 151 numbered across 5 suites | section 2 | number is **real**, but it is the five *shell* contract suites (15+15+36+40+45), not pytest |
| 8 CI jobs | `awk` over `jobs:` in both workflows | `ci.yml` declares **6**; `ci-debug.yml` declares 1 |
| `cli validate` exit 0, `cli doctor` exit 0 | no such CLI exists | the repository's real doctor exits **3** |
| `docs/reports/P14-pr-body.md`, `HANDOFF.md`, `*.bundle` | `find / -xdev \( -name '*.bundle' -o -name HANDOFF.md -o -name 'P14*' \)` | **empty** — none exist anywhere on the filesystem |
| `REMOTE CI: NOT VERIFIED` | `gh run list --branch main` | **contradicted** — 6/6 jobs success at `d349f92` |
| `bc` absent, `pkg-config` absent | `command -v` | **CONFIRMED** — both absent |
| toolchain 43/44, 1 failed, left failing | section 2 | **CONFIRMED exactly** |

Verdict: the handoff mixed two genuinely accurate environment observations with a body of
work that does not exist in any reachable location. It is **not evidence** and was not used as
a basis for anything in this audit. Everything asserted here was re-measured from `d349f92`.

## 7. Reproducing this audit

```bash
git rev-parse HEAD                      # expect d349f92c9346061237e2d4bf3b0cdd17498f236c
for s in tests/*.test.sh ops/*/tests/*.test.sh ops/security/tests/*.test.sh; do
  printf '%s: ' "$s"; "./$s" >/tmp/o 2>&1; echo "exit=$? $(grep -aE '^(TOTAL|PASSED|FAILED):' /tmp/o | tr '\n' ' ')"
done
./ops/security/policy-check.sh;          echo "exit=$?"
./ops/security/secret-scan.sh;           echo "exit=$?"
./ops/security/static-security-check.sh; echo "exit=$?"
for v in ops/verify/*.sh; do "$v" >/dev/null 2>&1; echo "$v exit=$?"; done
./scripts/doctor.sh;                     echo "exit=$?"   # 3 = FAIL, driven only by pkg-config
gh run list --branch main --limit 5
```

Expected in a **fresh Arena sandbox**: one FAIL (P3, pkg-config) and doctor exit 3.
Expected on the **GitHub runner**: all green, as recorded in section 4.
If a future sandbox has a reachable package mirror, install `pkg-config` through
`ops/security/privilege-gate.sh` (it is already allowlisted) and both become green locally.
