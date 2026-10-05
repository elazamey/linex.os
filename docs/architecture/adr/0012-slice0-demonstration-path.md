# ADR 0012 — Slice 0: a minimal governed user path (demonstration), and the W1/W2/W8 remediation

- **Status:** ACCEPTED (owner-directed, 2026-10-05)
- **Phase:** not a phase. Recorded as a **demonstration slice** so the ledger stays truthful.
- **Supersedes:** nothing. **Amends:** nothing in the P8 freeze.
- **Related:** ADR 0001 (scope), ADR 0008 (execution authority), ADR 0009 (policy engine),
  ADR 0010 (capability registry), ADR 0011 (status/evidence authority)

## Context

The triage audit of `a71643a` (`docs/reports/triage-audit-a71643a.md`) measured a repository with
a mature governance frame and **no user-visible path at all**: 0 lines of product code, no request
that a user can issue, no response they can receive. The owner's assessment was blunt and correct:
the audit measured *document consistency*, not *system completeness*, and the cost of the frame
was beginning to exceed its return.

Two defects found in that audit were load-bearing, not cosmetic:

- **W1 — allowlist drift.** `privilege-gate.sh` allowed 20 packages; `privilege-policy.md` §5
  documented 15; and `python3`, `nodejs`, `npm` were declared `Required=yes` in
  `ops/linux/toolchain-manifest.txt` while being **not installable through the Gate**. Worse:
  `install-base.sh` detected missing runtimes and never added them to its install plan, so the
  declared baseline was unreachable by design.
- **W2 — CI bypassed the Gate.** `ci.yml` Job 4 provisioned the P3 baseline with raw
  `sudo apt-get install`. The bypass was not a shortcut: routing that step through the Gate as
  written would have been **BLOCKED for 3 of 18 entries** (`python3` not allowlisted; `find` and
  `awk` are tool names, not package names). The project's claim that the Gate is the only install
  path was therefore not implementable.

## Decision

1. **Fix W1, W2 and W8 before adding any surface.** The frame must be true before it is extended:
   - Gate allowlist aligned to the manifest (23 packages: 15 P2 + 5 P3 build + 3 P3 runtimes).
   - `privilege-policy.md` §5 restructured into three code blocks that mirror the code exactly.
   - `install-base.sh` plans missing runtimes (so `Required=yes` means installable).
   - `ci.yml` provisions through the Gate (`apt-update --execute`, `package-install --execute`)
     with a fail-closed annotation, and uses an explicit tool→package map.
   - `install-base.sh` defaults to **DRY-RUN**; real installation requires `--execute` (W8).
   - A new checker, `tests/governance-consistency.test.sh`, enforces all of the above as set
     comparisons, and was verified to **fail** on four reintroduced regressions.
2. **Add Slice 0: the smallest governed user path**, in `userpath/`, as running Bash:
   request → structured action → schema → policy → execution → verification → evidence → response.
3. **Slice 0 decides no technology.** It introduces no new language, dependency, framework, or
   provider, so ADR 0011 D5 and the P8 freeze remain intact. The repository's own freeze guards
   (`tests/contracts.test.sh` TEST 10, `tests/capability.test.sh` TEST-44,
   `tests/execution-authority.test.sh` TEST-35, which forbid `*.py|*.js|*.ts|*.go|*.rs` and the
   directories `src/ app/ api/ ui/`) still pass **unchanged**, and that is the evidence that the
   slice does not pre-empt P18.
4. **Slice 0 is explicitly throwaway.** It is a demonstration and a regression surface, not the
   product. When P18 selects the implementation language, this directory is expected to be
   rewritten (or deleted) and its behavioural test kept as the acceptance criterion.

## Consequences

**Positive**
- The frame's central claim ("privileged installs only through the Gate") is now true in the
  repository's own pipeline, and a checker keeps it true.
- There is a user-visible path to talk about: `./userpath/request.sh --action read_file --path X`
  returns a response, a governance trace, and an append-only evidence line whose digest matches
  the response the user received.
- 38 behavioural checks (exit codes, containment, denial of privileged capabilities, content-free
  and append-only evidence) counter the "93% of checks are greps" finding with executable proof.
- The slice demonstrates two capabilities (`CAP_FS_READ`, `CAP_ECHO`) and **denies four** it cannot
  honour (`CAP_FS_WRITE` needs an approver, `CAP_PROCESS_EXEC`, `CAP_PACKAGE_INSTALL`,
  `CAP_NETWORK_CONNECT` have no executor). Denial is part of the demonstration.

**Negative / accepted**
- A new implementation-ish surface now exists in a repository whose README claimed none. The
  README and roadmap are updated in the same change so the ledger stays truthful.
- The slice's policy layer is a subset of the P11 contract; it is not the policy engine and must
  not be extended into one (that is P11/implementation work).
- The slice adds no production hardening: no sandbox level 1+, no resource limits beyond size
  caps, no approver channel.

**Rejected alternatives**
- *Do nothing until P18.* Rejected: it leaves the frame unverifiable in practice and the W1/W2
  defects live.
- *Pick an implementation language now to build the slice properly.* Rejected: that is P18's
  decision, and pre-empting it would violate the freeze without an owner decision that says so.
- *Keep the Gate bypass in CI and document it as an exception.* Rejected: the drift that made the
  Gate unable to install the declared baseline is a bug, not a policy choice; documenting it would
  have frozen the bug in place.

## Verification

- `tests/governance-consistency.test.sh` → 8/8 PASS at baseline; demonstrably FAILS when W1 code
  drift, W1 doc drift, W1 installability gap, or W2 raw-install is reintroduced.
- `tests/user-path.test.sh` → 38/38 PASS.
- `ci.yml` contains no `sudo apt|dpkg` line and is Gate-mediated (guard G5/G6/G7).
- No system change: see `docs/reports/triage-correction-and-system-integrity-a71643a.md`
  §System integrity.
