# LINEX.OS — Slice 0: minimal governed user path

**Status:** demonstration slice · Bash only · decides no technology (ADR 0012) · not the product
**Path:** request → structured action → schema → policy → execution → verification → evidence → response

This directory exists to answer one question with running code instead of documents:

> Can a user make a request and get a response, through the governance frame, without the
> frame costing more than the feature?

It is deliberately small: four files, one allowed read capability, one allowed pure function.
It is **not** the P13 agent runtime, **not** the P11 policy engine, **not** the P10 execution
authority, and it decides **nothing** about P18 (implementation language stays DECISION PENDING).

## Run it

```bash
# allowed: workspace-scoped read (response on stdout, governance trace on stderr)
./userpath/request.sh --action read_file --path README.md

# allowed: bounded literal text (printed, never executed)
./userpath/request.sh --action echo_text --text 'hello $(whoami)'

# denied: traversal, absolute path, symlink escape, .git internals
./userpath/request.sh --action read_file --path ../../etc/passwd
./userpath/request.sh --action read_file --path /etc/passwd

# denied: capabilities with no executor in the slice
./userpath/request.sh --action run_command --text whoami
./userpath/request.sh --action install_package --text gcc
./userpath/request.sh --action network_fetch --text https://example.com

# approval path: nothing is executed
./userpath/request.sh --action write_file --path new.txt

# policy only, no execution
./userpath/request.sh --action read_file --path README.md --dry-run
```

Streams: **stdout = response payload only** (pipeable), **stderr = governance trace**.
Evidence: append-only JSONL at `${LINEX_EVIDENCE_DIR:-${TMPDIR:-/tmp}/linex-os-evidence}/requests.jsonl`.

## Exit-code contract

| Code | Meaning | Executed? |
|------|---------|-----------|
| 0 | `ALLOW` + execution `VERIFIED` (or `--dry-run`) | yes / no (dry-run) |
| 2 | `INVALID` request schema or usage | no |
| 3 | `DENY` (policy) | no |
| 4 | `REQUIRE_APPROVAL` — no approver channel in Slice 0 | no |
| 5 | execution failed | attempted |
| 6 | verification failed (digest mismatch) | yes, response withheld |

Fail-closed rules: unknown action → `DENY`; unmatched rule → `DENY`; missing required resource
→ invalid schema (2); anything privileged (`sudo`, package install, network) has **no executor**
here and must go through `ops/security/privilege-gate.sh` instead.

## Capability map (subset of `docs/contracts/capability.md`)

| Action | Capability | Decision | Executor |
|--------|-----------|----------|----------|
| `read_file` | `CAP_FS_READ` | ALLOW if workspace-scoped, regular file ≤ 64 KiB | `userpath/executor.sh` (`cat`, ARGV) |
| `echo_text` | `CAP_ECHO` | ALLOW if ≤ 4096 chars | `userpath/executor.sh` (`printf`, ARGV) |
| `write_file` | `CAP_FS_WRITE` | REQUIRE_APPROVAL (no approver in Slice 0) | none |
| `run_command` | `CAP_PROCESS_EXEC` | DENY | none |
| `install_package` | `CAP_PACKAGE_INSTALL` | DENY (use the Gate) | none |
| `network_fetch` | `CAP_NETWORK_CONNECT` | DENY | none |

## Security properties (asserted by `tests/user-path.test.sh`, 38 behavioural checks)

- User data is never evaluated: ARGV mode only, no `eval`, no `bash -c`, no command substitution.
- Containment is a real test, not a string test: `readlink -f` resolution plus prefix check, so
  symlink escape out of the workspace is denied.
- Evidence is **content-free**: only the sha256 digest of the response is stored, never its bytes.
- Evidence is **append-only**: existing lines are never rewritten (the suite hashes them).
- The response the user receives is the response evidence recorded: the digest is recomputed on
  the emitted payload, and exit 6 withholds the payload if it does not match.

## What this slice deliberately does NOT do

- No agent, no LLM, no planner, no MCP, no memory, no API/UI, no database, no sandbox levels 1–4.
- No new dependency and no new language: it reuses the repository's existing Bash baseline.
- No privileged path: privileged actions stay with `ops/security/privilege-gate.sh`.

See `docs/architecture/adr/0012-slice0-demonstration-path.md` for the decision record and
`docs/reports/triage-correction-and-system-integrity-a71643a.md` for the audit that motivated it.
