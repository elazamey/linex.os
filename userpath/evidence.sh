#!/usr/bin/env bash
# LINEX.OS - Slice 0 evidence writer.
#
# Append-only JSONL evidence store. One line per decision, never rewritten.
# Contract properties (asserted by tests/user-path.test.sh):
#   - append-only: existing lines are never edited (the tests hash them)
#   - content-free: resource CONTENT is never stored, only its sha256 digest
#   - secret-free: only the fields below are written, all from fixed sources
#   - local by default: ${LINEX_EVIDENCE_DIR:-${TMPDIR:-/tmp}/linex-os-evidence}
#
# Fields recorded (docs/architecture/event-model.md, docs/contracts/result.md):
#   event_id timestamp request_id actor action capability resource scope
#   decision reason executor execution_status bytes result_sha256
#   verification exit_code slice_version

SLICE_VERSION="slice0-1"

slice_evidence_dir() {
  printf '%s\n' "${LINEX_EVIDENCE_DIR:-${TMPDIR:-/tmp}/linex-os-evidence}"
}

slice_evidence_file() {
  printf '%s/requests.jsonl\n' "$(slice_evidence_dir)"
}

# JSON string escaping without any external JSON dependency.
slice_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# slice_evidence_append key=value [key=value ...]
# Appends exactly one JSON object line. Values are always written as strings.
slice_evidence_append() {
  local dir file pair key value line=""
  dir="$(slice_evidence_dir)"
  mkdir -p -- "$dir" || return 1
  file="$dir/requests.jsonl"

  for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    line="${line}\"$(slice_json_escape "$key")\":\"$(slice_json_escape "$value")\","
  done
  line="{${line%,}}"

  printf '%s\n' "$line" >> "$file"
}

slice_evidence_count() {
  local file
  file="$(slice_evidence_file)"
  [[ -f "$file" ]] || { printf '0\n'; return 0; }
  wc -l < "$file" | tr -d ' '
}

slice_sha256() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

slice_file_sha256() {
  sha256sum -- "$1" | cut -d' ' -f1
}
