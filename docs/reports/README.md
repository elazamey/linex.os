# Evidence Reports — Convention

This directory holds **measurement reports**: files whose only job is to record what was
actually observed when a verification command was run, where, and when.

It exists because the project has two distinct kinds of document and was conflating them:

| Kind | Answers | Lives in | May it change behaviour? |
|---|---|---|---|
| Contract / architecture | "What must be true?" | `docs/contracts/`, `docs/architecture/` | Yes — it is the spec |
| Evidence report | "What was observed?" | `docs/reports/` | No — it is a record |

A contract that goes stale is a bug in the spec. An evidence report that goes stale is
**normal and expected** — it is a photograph. It must therefore never be written as if it
were a live claim about the present.

## Rules

### R1 — Every number must carry its derivation

A count, hash, exit code or status may appear only next to the exact command that produced
it. If a reader cannot re-run the command and get the number, the number must not be in the
file.

```
WRONG:  181 tests passed
RIGHT:  ./tests/policy.test.sh → TOTAL: 40 PASSED: 40 FAILED: 0 (exit 0)
```

### R2 — No self-referential measurements

A report must never state a measurement of itself or of the change that contains it:
not its own line count, not "N files changed" for a diff that includes the report, not
"N insertions" for a commit the report is part of. Editing such a number invalidates it,
and the only fix is to delete it. Measure the thing under test, never the measurement.

### R3 — Environment is part of the result

Every report states the environment it was measured in, and separates it from other
environments. `PASS` in one sandbox is not `PASS` in another. Use the project's existing
distinction (`ARENA_*` vs `REMOTE_CI_*`) rather than a single unqualified verdict.

A result whose truth depends on state **outside** the repository (an installed package, a
built binary, a downloaded tool) is `ENVIRONMENT-DEPENDENT`, never `VERIFIED`. See ADR 0011.

### R4 — Classify with the project vocabulary

`PASS` · `FAIL` · `BLOCKED` · `NOT VERIFIED` · `ENVIRONMENT-DEPENDENT`

`BLOCKED` means an external condition prevents measurement. `NOT VERIFIED` means the check
was not run or does not apply. Neither may be reported as `PASS`, and `FAIL` may not be
softened into either without naming the reason.

### R5 — No secrets, no credential-shaped strings

`ops/security/secret-scan.sh` scans this directory (it scans the whole repository). Reports
must not contain private key blocks, token-shaped literals, or `key = value` credential
patterns — not even as examples of what was scanned for. Describe the pattern, do not
reproduce it.

### R6 — Reports are append-only history

Do not edit a published report to reflect new measurements. Write a new report named for the
commit it measures. A corrected report supersedes the old one by reference, not by overwrite.

## Naming

```
docs/reports/<subject>-<measured-commit>.md
```

The commit in the filename is the commit **being measured** (an immutable ancestor), not the
commit that adds the file. That keeps the name stable and the scope unambiguous.

## References

- `docs/architecture/adr/0011-baseline-reconciliation-and-phase-numbering.md` — why this convention exists
- `docs/architecture/data-model.md` — Evidence Artifact class (owner, scope, hash, provenance, retention, no secrets)
- `docs/contracts/result.md` — Result/Evidence Contract, `SUCCEEDED ≠ VERIFIED`
- `ops/security/secret-scan.sh` — the scanner R5 refers to
