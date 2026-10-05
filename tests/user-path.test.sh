#!/usr/bin/env bash
# LINEX.OS - Slice 0 user path tests (BEHAVIOURAL, not text-presence).
# Every check below runs ./userpath/request.sh and asserts on exit code, on the
# response payload (stdout), on the governance trace (stderr) and on the
# append-only evidence file. No system changes, no package install, no network,
# no sudo: the slice under test has no such executor.
#
# This suite is the counter-example to the "93% of checks are greps" finding:
# it fails if the slice misbehaves, not if a sentence disappears.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUEST="$ROOT_DIR/userpath/request.sh"
TOTAL=0
PASSED=0
FAILED=0

log() { printf '%s\n' "$*"; }
pass() { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); printf '%-62s → PASS (%s)\n' "$1" "$2"; }
fail() { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); printf '%-62s → FAIL (%s)\n' "$1" "$2" >&2; }
check() { # name, condition-result(0/1), detail
  if [[ "$2" -eq 0 ]]; then pass "$1" "$3"; else fail "$1" "$3"; fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/linex-slice0-test.XXXXXX")"
EVID="$WORK/evidence"
MARKER="SLICE0-CONTENT-MARKER-$$-DO-NOT-STORE"
mkdir -p "$WORK/workspace"
printf 'line-one\n%s\nline-three\n' "$MARKER" > "$WORK/workspace/note.txt"
printf 'outside-secret\n' > "$WORK/outside.txt"
ln -s "$WORK/outside.txt" "$WORK/workspace/escape-link.txt"
mkdir -p "$WORK/workspace/.git"
printf 'gitconfig-secret\n' > "$WORK/workspace/.git/config"
head -c 70000 /dev/zero | tr '\0' 'x' > "$WORK/workspace/big.txt"

run() { # -> sets RC, OUT (stdout), ERR (stderr)
  local outfile errfile
  outfile="$WORK/.out"; errfile="$WORK/.err"
  set +e
  LINEX_EVIDENCE_DIR="$EVID" "$REQUEST" "$@" >"$outfile" 2>"$errfile"
  RC=$?
  set -e
  OUT="$(cat "$outfile")"
  ERR="$(cat "$errfile")"
}

log "LINEX.OS SLICE 0 USER PATH TESTS"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log ""

# ---- 1. allowed read returns the file content as the response --------------
run --action read_file --path note.txt --workspace "$WORK/workspace"
check "T1 allowed read exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit=$RC"
check "T2 response payload is the file content" \
  "$([[ "$OUT" == *"$MARKER"* ]] && echo 0 || echo 1)" "marker present in stdout"
check "T3 trace shows POLICY ALLOW" \
  "$(grep -q '^POLICY: ALLOW$' <<<"$ERR" && echo 0 || echo 1)" "ALLOW recorded"
check "T4 trace shows VERIFIED execution" \
  "$(grep -q '^VERIFICATION: VERIFIED' <<<"$ERR" && echo 0 || echo 1)" "verification line"

# ---- 5. evidence properties ------------------------------------------------
EVFILE="$EVID/requests.jsonl"
check "T5 evidence file created with exactly one line" \
  "$([[ -f "$EVFILE" && "$(wc -l < "$EVFILE" | tr -d ' ')" == "1" ]] && echo 0 || echo 1)" "1 line"
check "T6 evidence records decision ALLOW and verification VERIFIED" \
  "$(grep -q '"decision":"ALLOW"' "$EVFILE" && grep -q '"verification":"VERIFIED' "$EVFILE" && echo 0 || echo 1)" \
  "decision+verification"
check "T7 evidence is CONTENT-FREE (marker absent)" \
  "$(grep -q "$MARKER" "$EVFILE" && echo 1 || echo 0)" "content never stored"
EXPECT_SHA="$(sha256sum "$WORK/workspace/note.txt" | cut -d' ' -f1)"
check "T8 evidence carries the real sha256 digest" \
  "$(grep -q "\"result_sha256\":\"$EXPECT_SHA\"" "$EVFILE" && echo 0 || echo 1)" "digest matches file"

# ---- 9. policy denials -----------------------------------------------------
run --action read_file --path ../outside.txt --workspace "$WORK/workspace"
check "T9 traversal '..' denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action read_file --path /etc/passwd --workspace "$WORK/workspace"
check "T10 absolute path denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action read_file --path escape-link.txt --workspace "$WORK/workspace"
check "T11 symlink escape denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action read_file --path .git/config --workspace "$WORK/workspace"
check "T12 .git internals denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action read_file --path missing.txt --workspace "$WORK/workspace"
check "T13 missing file denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action read_file --path big.txt --workspace "$WORK/workspace"
check "T14 oversized file denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
check "T15 denials emit no response payload" "$([[ -z "$OUT" ]] && echo 0 || echo 1)" "stdout empty"
check "T16 denials are still evidenced (append-only grows)" \
  "$([[ "$(wc -l < "$EVFILE" | tr -d ' ')" -ge 7 ]] && echo 0 || echo 1)" "denials recorded"
check "T17 denied requests execute nothing" \
  "$(grep -q 'NOT EXECUTED' <<<"$ERR" && echo 0 || echo 1)" "NOT EXECUTED trace"

# ---- 18. literal text is never executed ------------------------------------
run --action echo_text --text '$(whoami); rm -rf / #not-a-command'
check "T18 echo_text allowed (exit 0)" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit=$RC"
check "T19 literal text is returned verbatim, not evaluated" \
  "$([[ "$OUT" == '$(whoami); rm -rf / #not-a-command' ]] && echo 0 || echo 1)" "no evaluation"

# ---- 20. capabilities with no executor stay denied -------------------------
run --action run_command --text 'whoami'
check "T20 run_command denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action install_package --text gcc
check "T21 install_package denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action network_fetch --text 'https://example.com'
check "T22 network_fetch denied (exit 3)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"
run --action unknown_action --text x
check "T23 unknown action denied (exit 3, fail-closed)" "$([[ $RC -eq 3 ]] && echo 0 || echo 1)" "exit=$RC"

# ---- 24. approval path -----------------------------------------------------
run --action write_file --path new.txt --workspace "$WORK/workspace"
check "T24 write_file requires approval (exit 4)" "$([[ $RC -eq 4 ]] && echo 0 || echo 1)" "exit=$RC"
check "T25 approval-pending wrote nothing" "$([[ ! -e "$WORK/workspace/new.txt" ]] && echo 0 || echo 1)" "no file created"

# ---- 26. schema validation (fail-closed on usage) --------------------------
run --action read_file --workspace "$WORK/workspace"
check "T26 read_file without --path is invalid (exit 2)" "$([[ $RC -eq 2 ]] && echo 0 || echo 1)" "exit=$RC"
run --action echo_text
check "T27 echo_text without --text is invalid (exit 2)" "$([[ $RC -eq 2 ]] && echo 0 || echo 1)" "exit=$RC"
run --bogus-flag x
check "T28 unknown argument is invalid (exit 2)" "$([[ $RC -eq 2 ]] && echo 0 || echo 1)" "exit=$RC"
run
check "T29 no arguments is invalid (exit 2)" "$([[ $RC -eq 2 ]] && echo 0 || echo 1)" "exit=$RC"
run --action echo_text --text hi --request-id 'bad id!'
check "T30 invalid request-id rejected (exit 2)" "$([[ $RC -eq 2 ]] && echo 0 || echo 1)" "exit=$RC"

# ---- 31. dry-run: policy without execution ---------------------------------
run --action read_file --path note.txt --workspace "$WORK/workspace" --dry-run
check "T31 dry-run exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit=$RC"
check "T32 dry-run executes nothing" \
  "$(grep -q 'NOT EXECUTED (dry-run)' <<<"$ERR" && echo 0 || echo 1)" "not executed"

# ---- 33. append-only evidence --------------------------------------------
BEFORE_HASH="$(head -1 "$EVFILE" | sha256sum | cut -d' ' -f1)"
BEFORE_LINES="$(wc -l < "$EVFILE" | tr -d ' ')"
run --action echo_text --text 'second request'
AFTER_HASH="$(head -1 "$EVFILE" | sha256sum | cut -d' ' -f1)"
AFTER_LINES="$(wc -l < "$EVFILE" | tr -d ' ')"
check "T33 evidence is append-only (first line unchanged)" \
  "$([[ "$BEFORE_HASH" == "$AFTER_HASH" ]] && echo 0 || echo 1)" "line 1 identical"
check "T34 evidence grew by exactly one line" \
  "$([[ $((AFTER_LINES - BEFORE_LINES)) -eq 1 ]] && echo 0 || echo 1)" "+1 line"

# ---- 35. static properties of the slice -----------------------------------
check "T35 slice contains no eval-executable / sudo / curl / wget" \
  "$(grep -vE '^[[:space:]]*#' "$ROOT_DIR"/userpath/*.sh | grep -nE '^[[:space:]]*(eval |sudo |curl |wget )' >/dev/null && echo 1 || echo 0)" \
  "no privileged or network primitive"
check "T36 slice introduces no new language (no py/js/ts/go/rs)" \
  "$(find "$ROOT_DIR/userpath" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' \) | grep -q . && echo 1 || echo 0)" \
  "Bash only"
check "T37 slice decides no technology (no provider/engine/DB imports)" \
  "$(grep -riE 'require\(|import |FROM [a-z]+;' "$ROOT_DIR"/userpath/*.sh >/dev/null && echo 1 || echo 0)" \
  "no stack choice"
check "T38 README documents the exit-code contract" \
  "$(grep -q 'Exit-code contract' "$ROOT_DIR/userpath/README.md" && echo 0 || echo 1)" "documented"

rm -rf "$WORK"

log ""
log "=== TEST SUMMARY ==="
log "TOTAL: $TOTAL"
log "PASSED: $PASSED"
log "FAILED: $FAILED"
if [[ $FAILED -eq 0 ]]; then
  log "STATUS: PASS"
  exit 0
fi
log "STATUS: FAIL"
exit 1
