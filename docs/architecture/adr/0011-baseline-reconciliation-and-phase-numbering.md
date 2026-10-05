# ADR 0011 — Baseline Reconciliation and Phase Numbering Authority

## Context

Phase P12 (Capability Registry Contract) is merged into `main` at `d349f92`, and a full audit
of that commit was performed in a fresh Arena sandbox (`docs/reports/baseline-audit-d349f92.md`).
255 of 256 shipped checks pass; remote CI on `main` is green (6 of 6 jobs, run `37233042304`).
The audit also found that the project's *status* documentation had drifted from its *merged*
state, in five distinct ways:

1. **Non-reproducible state recorded as verified.** `ops/linux/toolchain-manifest.txt` lists
   `pkg-config` as `VERIFIED | 3.0.0` on the strength of a source build performed in an earlier
   sandbox, outside the repository. In a fresh sandbox the tool is absent, the package mirror is
   unreachable (`apt-get -s install pkg-config` → `Unable to locate package`;
   `deb.debian.org` → `curl: (52) Empty reply`), and the P3 suite reports 43/44. The manifest's
   own header rule — *"Status is VERIFIED only after actual command execution, not assumed"* —
   had no way to express "executed once, in an environment that no longer exists".

2. **Committed evidence contradicting the commit it sits on.** `verification-summary.txt`
   names branch `arena/01a107fc-linex-os` and commit `768bf39`, claims `PASS=47 FAIL=0`, and
   claims `REMOTE CI: NOT VERIFIED (branch not pushed)`. At `d349f92` the measured counts are
   `PASS=45 FAIL=1 BLOCKED=2 NOT_VERIFIED=1` and remote CI is verified green. `README.md`
   repeats the pkg-config claim as present tense ("44 tests PASS").

3. **Phase labels with three incompatible meanings.** `roadmap.md` says `P13 → Agent Runtime`,
   `P14 → Tool Runtime`; ADR 0008, ADR 0009 and `docs/contracts/README.md` say
   `P13 Agent Runtime Contract`, `P14 Tool+Skill Contract`, and diverge from `roadmap.md`
   for every phase from P15 onward; and `.github/workflows/ci.yml` uses `P13 FIX` comments to
   label a set of CI repairs that are not a phase at all.

4. **Status tracking four phases behind reality.** `roadmap.md` declares
   `## Architecture (P8) — CURRENT` and `ci.yml` echoes `NEXT: P8 Architecture Design`, while
   ADRs 0007–0010 are `ACCEPTED` and the P8–P12 suites pass 151 checks.

5. **An unverifiable handoff was treated as completed work.** A report describing commit
   `59ded43`, a `control/` Python package, 181 pytest tests, a `configDigest` CLI and a git
   bundle was presented as executed and verified. The commit does not exist locally
   (`git cat-file -t` → not a valid object) or on GitHub (`gh api …/commits/59ded43` →
   `422 No commit found for SHA`); the branch it names is merged at `24752a2` with 4 changed
   files; the repository contains 0 Python files; `pytest` is absent; and no bundle or handoff
   file exists anywhere on the filesystem. Two of its environment observations were accurate
   (`bc` absent, toolchain 43/44 with pkg-config missing) and one number was real but
   misattributed (151 is the sum of the five *shell* contract suites). The remainder had no
   referent.

The common cause is not carelessness in any one document. It is that the project never defined
**what counts as evidence**, **what makes a status claim valid**, or **which document owns
phase identity** — so each sandbox supplied its own answers, and a claim could travel further
than the work behind it.

## Decision

**Baseline reconciled to merged git state; evidence and numbering authority fixed by rule — ACCEPTED**

### D1 — Evidence authority

Only two things are evidence:

- **Merged git state** reachable from the remote (`git ls-remote`, `gh api`, `gh run view`).
- **A command re-run in the current environment**, with its output and exit code.

Anything else — a chat report, a handoff file, a git bundle, a screenshot, a summary of a
previous sandbox — is a *claim*. A claim becomes evidence only when its commit is fetchable and
its measurements reproduce. Claims whose commits are absent from the remote are recorded as
`NOT EVIDENCE` and may not be used as a basis for status, planning, or further work.

Corollary: work that is not pushed does not exist. The `59ded43` handoff was lost precisely
because it lived only in a sandbox filesystem.

### D2 — Reproducibility rule for status claims

A status of `VERIFIED` / `PASS` / `COMPLETE` is valid only if it can be **re-derived from
repository contents alone, in a fresh sandbox**. A result that depends on state outside the
repository — an installed package, a locally built binary, a downloaded tool, a warm cache —
must be recorded as `ENVIRONMENT-DEPENDENT`, with the environment named.

`ENVIRONMENT-DEPENDENT` joins the status vocabulary alongside `PASS`, `FAIL`, `BLOCKED` and
`NOT VERIFIED`. It is not a softer `PASS`: it means "true somewhere, not re-derivable here".

Applied now to `ops/linux/toolchain-manifest.txt` (pkg-config row) and to `README.md`.

### D3 — Fail-closed aggregators are not weakened by classification

`scripts/doctor.sh` exits 3 (`FAIL`) because a required toolchain tool is missing. That is
**correct fail-closed behaviour and it is not changed by this ADR**: the P3 baseline declares
pkg-config required, the requirement is genuinely unmet in this environment, and the tool that
reports it must not soften. The classification introduced by D2 belongs in the *evidence layer*
(`docs/reports/`, this ADR, the manifest), not baked into the aggregator — a reason string
printed by doctor would itself become a non-reproducible claim unless doctor performed live
network probing, which would make it slower and flakier than the check it explains.

Gap G1 is therefore recorded with a defined remedy and deliberately **deferred**: any change to
doctor's exit semantics must arrive as its own scoped change, with its own test coverage, and
must not land in the same commit that audits it.

### D4 — Phase numbering authority

- **Phase identity and order** are owned by `docs/architecture/roadmap.md`, reconciled to the
  `ACCEPTED` ADR sequence (0007 → 0010). Where the P8-era roadmap sketch and the ADRs
  disagreed, the ADR sequence prevails, because it is what P9–P12 actually executed.
- **P13 = Agent Runtime Contract** (contracts only). **P14 = Tool + Skill Contract.** These are
  the next two phases, in that order. P12 is the last completed phase.
- The longer P15–P24 sketch in `roadmap.md` is **superseded from P15 onward** by the ADR
  sequence (P15 Memory/State/Event, P16 Verification/Eval, P17 MCP, P18 Technology Selection →
  implementation). Its remaining subjects are preserved as an explicit unordered backlog so that
  nothing is silently dropped by the renumbering.
- **`P13 FIX` labels are relabelled `CI-H1…CI-H6`** across `.github/workflows/ci.yml`,
  `.github/workflows/ci-debug.yml`, `ops/powershell/tests/powershell-install.test.sh` and
  `scripts/doctor.sh`. They were repairs to CI and to the doctor aggregator — self-matching
  grep checks, a dispatch-only debug runner, P4 annotations, provision-then-verify for the P3
  baseline, a distro-agnostic TEST-1, and a deterministic doctor report — not the P13 phase.
  The collision is removed rather than explained: a phase label that means three things cannot
  authorise work.
- **"P14 Control Plane MVP" is not a phase.** It appears in no authoritative document, matches
  neither planning source, and its deliverable does not exist. The name is retired.

### D5 — No implementation language before Technology Selection

The P8 freeze leaves the implementation language `DECISION PENDING` until the Technology
Selection phase, and states that any violation requires an ADR. A Python control plane
(`control/` package, `pytest`, `PyYAML`) would have decided that question four phases early,
under the cover of a phase name that did not exist. It is **rejected**, on two independent
grounds:

1. **Architectural** — it preempts a decision the freeze explicitly reserves, and would make
   Core depend on a runtime choice that ADR 0009 keeps open (Rust / Go / Python / Node).
2. **Evidential** — it cannot be verified in this environment at all: `pytest` is absent,
   `PyYAML` is absent, no venv exists, and no package index is reachable (gap G9). A deliverable
   whose tests cannot be run cannot produce evidence, and unevidenced work is `NOT VERIFIED`
   by definition.

Verification and gate tooling therefore stays inside the toolchain the repository already ships:
`bash`, `jq` 1.6 (whose `-cS` yields canonical sorted-key JSON), `sha256sum`, `git`. A
deterministic decision layer — canonical config → digest → deterministic evaluation →
`ALLOW / DENY / REQUIRE_APPROVAL / DRY_RUN / BLOCKED` → append-only evidence — is fully
expressible in those tools, and every step is executable and re-executable here.

Should the project later *want* a different implementation language, that is the Technology
Selection phase's decision, made with criteria, and it will need its own ADR.

### D6 — Evidence artefact discipline

`docs/reports/` is created as the home for measurement reports, governed by
`docs/reports/README.md`:

- **R1** every number carries the command that produced it;
- **R2** no self-referential measurements — a report never states its own size, or the
  file/insertion counts of a change that contains it;
- **R3** environment is part of the result, and `ARENA_*` stays distinct from `REMOTE_CI_*`;
- **R4** classify with the project vocabulary, never soften `FAIL`;
- **R5** no secrets, no credential-shaped strings;
- **R6** reports are append-only history — supersede by reference, never overwrite.

R2 exists because of an observed failure: a PR body describing its own branch claimed an
insertion count that its own edit invalidated, twice, and the only structural fix was to remove
the count. R3 exists because of D2. R6 exists because a corrected report that rewrites history
cannot be compared against the thing it corrects.

### D7 — Remote CI is verified at job granularity from Arena

`gh run view <id> --json jobs` is reachable and authoritative; `gh run view <id> --log` is not
(`results-receiver.actions.githubusercontent.com` → `EOF`), which is the same blocker `ci.yml`
already documents. Therefore:

- `REMOTE CI = VERIFIED` may be asserted from job conclusions (name + conclusion + head SHA).
- Any statement about **runner log contents** is `NOT VERIFIED` from Arena and must be labelled
  as such, even when the job is green.

## Alternatives

- **Alternative 1: Accept the handoff and rebuild `control/` to match its description.**
  Rejected: it would encode claims with no referent (a commit absent from the remote, a test
  count for a runner that does not exist, a digest from a CLI that was never written) into the
  repository, and would make the fiction permanently harder to distinguish from the record.

- **Alternative 2: Adopt `roadmap.md`'s P14 (Tool Runtime) as the next phase.** Rejected: both
  planning sources agree P13 (Agent Runtime) comes first, and P12 is the last completed phase.
  Skipping to P14 would repeat the exact defect this ADR corrects — selecting a phase by
  preference rather than by the authoritative sequence.

- **Alternative 3: Implement the Python control plane now, on the argument that a working gate
  is worth more than a clean phase ledger.** Rejected per D5: it violates the freeze, and its
  tests cannot run here, so it could only ever be delivered as `NOT VERIFIED` — the same defect
  as the handoff, with more code.

- **Alternative 4: Publish the audit only, and leave the stale status documents alone.**
  Rejected: `verification-summary.txt`, `toolchain-manifest.txt` and `README.md` are the
  mechanism by which a false claim reaches the next reader. An audit that documents drift
  without correcting it leaves two contradictory sources in the tree, and the stale one is the
  one people read first.

- **Alternative 5: Soften `scripts/doctor.sh` so the local run reports BLOCKED instead of
  FAIL.** Rejected per D3: it would weaken a fail-closed aggregator to make an audit look
  cleaner, and it would put an environment-specific explanation inside a tool that must stay
  environment-agnostic.

- **Alternative 6 (chosen): Audit → reconcile status documents to merged state → record the
  rules and the numbering authority in an ADR → name the next phase from the authoritative
  sequence, with no product code.** Accepted: it fixes the mechanism rather than the symptom,
  every claim it makes is re-derivable, and it changes no verification behaviour.

## Consequences

- Positive:
  - One authoritative answer to "what phase are we in" and "what comes next": P12 done, P13
    Agent Runtime Contract next, P14 Tool + Skill Contract after.
  - `P13` no longer means three things; CI hardening has its own label space (`CI-H*`).
  - Status claims become re-derivable or explicitly `ENVIRONMENT-DEPENDENT`; the pkg-config
    situation stops reading as a repository defect.
  - Committed evidence (`verification-summary.txt`) matches the commit it sits on, and separates
    Arena results from runner results.
  - Evidence artefacts have a home, a naming rule, and an explicit ban on self-referential
    numbers — the failure mode that produced both the stale summary and the lost handoff.
  - The implementation-language decision stays where the freeze put it.
- Negative:
  - Local doctor still exits 3 until pkg-config is present or the mirror is reachable; readers
    must consult the audit report to understand why (G1 deferred by D3).
  - `roadmap.md` had to be rewritten rather than appended to, so the P8-era sketch survives only
    as a backlog section; anyone who memorised the old P15–P24 numbering must re-read it.
  - Relabelling `ci.yml` comments touches the workflow file, which re-triggers CI — accepted,
    since that run is itself the evidence that the relabelling broke nothing.
- Neutral:
  - Still no product code. Every `COMPLETE` in this repository continues to mean "contract
    written, self-consistent and machine-checked", not "implemented" (gap G7). That is by design
    until Technology Selection.

## Status

ACCEPTED

## References

- `docs/reports/baseline-audit-d349f92.md` — the measurements this ADR is based on
- `docs/reports/README.md` — evidence report convention (R1–R6), created by D6
- `docs/architecture/roadmap.md` — reconciled phase status and authoritative sequence (D4)
- `docs/architecture/adr/0007-core-runtime-contracts.md` … `0010-capability-registry-contract.md` — the ACCEPTED sequence D4 adopts
- `docs/architecture/adr/0009-policy-engine-contract.md` — implementation language `DECISION PENDING` (D5)
- `docs/architecture/frozen-baseline.md` — architecture freeze, "any violation requires ADR"
- `docs/contracts/result.md` — Result/Evidence Contract, `SUCCEEDED ≠ VERIFIED`
- `ops/linux/toolchain-manifest.txt` — reclassified per D2
- `scripts/doctor.sh` — exit-code semantics preserved per D3
- `.github/workflows/ci.yml`, `ci-debug.yml`, `ops/powershell/tests/powershell-install.test.sh`,
  `scripts/doctor.sh` — `CI-H1…CI-H6` relabelling per D4; log-archive blocker per D7
- `AGENTS.md` — Dependency Rules, Tool selection least-tool priority, evidence model
  `STATUS / RESULT / EVIDENCE / NEXT`
