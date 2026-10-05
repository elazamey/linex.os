#!/usr/bin/env bash
# LINEX.OS - Slice 0: minimal governed user path (request -> response).
#
# Usage:
#   ./userpath/request.sh --action read_file --path README.md [--workspace DIR]
#   ./userpath/request.sh --action echo_text --text "hello"
#   ./userpath/request.sh --action run_command --text "whoami"      # DENY
#   ./userpath/request.sh --action read_file --path X --dry-run     # policy only
#
# Streams:
#   stdout = the RESPONSE payload only (so it can be piped)
#   stderr = the GOVERNANCE TRACE (request, action, schema, policy, execution,
#            verification, evidence) - one field per line, no secrets
#
# Exit codes (documented contract, asserted by tests/user-path.test.sh):
#   0  ALLOW + execution VERIFIED
#   2  INVALID request schema / usage (fail-closed, nothing executed)
#   3  DENY (policy)
#   4  REQUIRE_APPROVAL - no approver channel in Slice 0, nothing executed
#   5  execution failed
#   6  VERIFICATION failed (response digest does not match evidence digest)
#
# This is a demonstration slice, not the product: no technology decision is
# made here and P18 remains the technology-selection gate (ADR 0012).

set -Eeuo pipefail

SLICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SLICE_DIR/policy.sh"
# shellcheck source=/dev/null
source "$SLICE_DIR/executor.sh"
# shellcheck source=/dev/null
source "$SLICE_DIR/evidence.sh"

ACTION=""
RESOURCE=""
WORKSPACE="${PWD}"
REQUEST_ID=""
DRY_RUN="false"
ACTOR="${LINEX_ACTOR:-local-user}"

trace() { printf '%s\n' "$*" >&2; }

usage() {
  trace "USAGE: request.sh --action <read_file|echo_text|write_file|run_command|install_package|network_fetch> [--path P | --text T] [--workspace DIR] [--request-id ID] [--dry-run]"
}

# ---- parse (structured request only; no free-form command string) -----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)     ACTION="${2:-}"; shift 2 ;;
    --path)       RESOURCE="${2:-}"; shift 2 ;;
    --text)       RESOURCE="${2:-}"; shift 2 ;;
    --workspace)  WORKSPACE="${2:-}"; shift 2 ;;
    --request-id) REQUEST_ID="${2:-}"; shift 2 ;;
    --dry-run)    DRY_RUN="true"; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            trace "SCHEMA: INVALID - unknown argument '$1'"; usage; exit 2 ;;
  esac
done

if [[ -z "$REQUEST_ID" ]]; then
  REQUEST_ID="req-$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi
if [[ ! "$REQUEST_ID" =~ ^[A-Za-z0-9._:-]{4,64}$ ]]; then
  trace "SCHEMA: INVALID - request-id must match [A-Za-z0-9._:-]{4,64}"
  exit 2
fi
if [[ -z "$ACTION" ]]; then
  trace "SCHEMA: INVALID - --action is required"
  usage
  exit 2
fi

trace "REQUEST: ${REQUEST_ID}"
trace "ACTOR: ${ACTOR}"
trace "SCOPE: workspace=${WORKSPACE} write=false network=false privilege=false"

case "$ACTION" in
  read_file)
    trace "ACTION: read_file"
    trace "CAPABILITY: CAP_FS_READ"
    trace "RESOURCE: ${RESOURCE}"
    trace "SCHEMA: VALID"
    ;;
  echo_text)
    trace "ACTION: echo_text"
    trace "CAPABILITY: CAP_ECHO"
    trace "RESOURCE: (literal text, ${#RESOURCE} chars)"
    trace "SCHEMA: VALID"
    ;;
  write_file|run_command|install_package|network_fetch)
    trace "ACTION: ${ACTION}"
    trace "SCHEMA: VALID"
    ;;
  *)
    trace "ACTION: ${ACTION}"
    trace "SCHEMA: INVALID - unknown action"
    ;;
esac

# Resource requirement is part of the schema, per action.
case "$ACTION" in
  read_file|write_file)
    if [[ -z "$RESOURCE" ]]; then
      trace "SCHEMA: INVALID - ${ACTION} requires --path"
      exit 2
    fi
    ;;
  echo_text)
    if [[ -z "$RESOURCE" ]]; then
      trace "SCHEMA: INVALID - echo_text requires --text"
      exit 2
    fi
    ;;
  run_command|install_package|network_fetch|'')
    : ;;  # denied by policy below; no extra schema requirement in Slice 0
  *)
    : ;;  # unknown action: denied by policy below
esac

# ---- policy ----------------------------------------------------------------
slice_policy_decide "$ACTION" "$RESOURCE" "$WORKSPACE"
trace "POLICY: ${POLICY_DECISION}"
trace "POLICY_CAPABILITY: ${POLICY_CAPABILITY}"
trace "POLICY_REASON: ${POLICY_REASON}"

finish() { # $1 exit code, $2 execution_status, $3 bytes, $4 digest, $5 verification
  slice_evidence_append \
    "event_id=evt-${REQUEST_ID}" \
    "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "request_id=${REQUEST_ID}" \
    "actor=${ACTOR}" \
    "action=${ACTION:-none}" \
    "capability=${POLICY_CAPABILITY}" \
    "resource=${RESOURCE}" \
    "scope=workspace:${WORKSPACE}" \
    "decision=${POLICY_DECISION}" \
    "reason=${POLICY_REASON}" \
    "executor=$([[ "$2" == "NOT EXECUTED"* ]] && echo none || echo slice0)" \
    "execution_status=$2" \
    "bytes=$3" \
    "result_sha256=$4" \
    "verification=$5" \
    "exit_code=$1" \
    "slice_version=${SLICE_VERSION}"
  trace "EVIDENCE: $(slice_evidence_file) (append-only, content-free)"
  trace "EXIT: $1"
  exit "$1"
}

if [[ "$POLICY_DECISION" != "ALLOW" ]]; then
  trace "EXECUTION: NOT EXECUTED (policy: ${POLICY_DECISION})"
  if [[ "$POLICY_DECISION" == "REQUIRE_APPROVAL" ]]; then
    finish 4 "NOT EXECUTED (approval required)" 0 "-" "NOT APPLICABLE"
  fi
  finish 3 "NOT EXECUTED (denied)" 0 "-" "NOT APPLICABLE"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  trace "EXECUTION: NOT EXECUTED (dry-run)"
  finish 0 "NOT EXECUTED (dry-run)" 0 "-" "NOT APPLICABLE"
fi

# ---- execute + respond -----------------------------------------------------
trap 'trace "EXECUTION: FAILED (unexpected error)"; finish 5 "FAILED" 0 "-" "UNVERIFIED"' ERR

RESPONSE_TMP="$(mktemp "${TMPDIR:-/tmp}/linex-slice0-response.XXXXXX")"
EMIT_TMP="$(mktemp "${TMPDIR:-/tmp}/linex-slice0-emitted.XXXXXX")"
cleanup() { rm -f -- "$RESPONSE_TMP" "$EMIT_TMP"; }
trap 'cleanup' EXIT

case "$ACTION" in
  read_file)
    # Re-resolve exactly what the policy layer validated (both against the same
    # workspace root) and hand it to the executor in ARGV position.
    ROOT="$(cd -- "$WORKSPACE" && pwd -P)"
    RESOLVED="$(readlink -f -- "$ROOT/$RESOURCE")"
    trace "EXECUTOR: slice0/read_file (ARGV mode, no shell evaluation)"
    if ! slice_exec_read_file "$RESOLVED" > "$RESPONSE_TMP"; then
      trace "EXECUTION: FAILED"
      finish 5 "FAILED" 0 "-" "UNVERIFIED"
    fi
    ;;
  echo_text)
    trace "EXECUTOR: slice0/echo_text (literal, no shell evaluation)"
    slice_exec_echo_text "$RESOURCE" > "$RESPONSE_TMP"
    ;;
esac

# ---- verification + response ----------------------------------------------
# The payload is emitted exactly once, through `tee`, so what the user receives
# and what gets hashed are the same bytes (no shell trailing-newline stripping).
DIGEST_SRC="$(sha256sum -- "$RESPONSE_TMP" | cut -d' ' -f1)"
cat -- "$RESPONSE_TMP" | tee -- "$EMIT_TMP"
BYTES="$(wc -c < "$EMIT_TMP" | tr -d ' ')"
DIGEST="$(sha256sum -- "$EMIT_TMP" | cut -d' ' -f1)"

trace "EXECUTION: EXECUTED"
if [[ "$DIGEST_SRC" == "$DIGEST" ]]; then
  trace "VERIFICATION: VERIFIED (bytes=${BYTES}, sha256=${DIGEST:0:16}...)"
  finish 0 "EXECUTED" "$BYTES" "$DIGEST" "VERIFIED (sha256 matches the emitted response)"
fi

trace "VERIFICATION: UNVERIFIED (emitted digest differs from executor output)"
finish 6 "EXECUTED" "$BYTES" "$DIGEST" "UNVERIFIED (digest mismatch)"
