#!/usr/bin/env bash
# W2: shared, Gate-mediated provisioning for the CI and CI Debug workflows.
# Repository tooling only. Default: dry-run. No direct privileged commands.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT_DIR/ops/security/privilege-gate.sh"

fail() {
  printf '::error title=W2 CI provisioning::%s\n' "$1" >&2
  exit "${2:-1}"
}

if (( $# < 1 || $# > 2 )); then
  fail 'Usage: provision-toolchain.sh <p3|debug> [--dry-run|--execute]' 2
fi
PROFILE="$1"
EXECUTE=false
case "${2:---dry-run}" in
  --dry-run) ;;
  --execute) EXECUTE=true ;;
  *) fail 'Unknown mode; use --dry-run or --execute' 2 ;;
esac

# Explicit command -> package mapping. '-' denotes a package-only prerequisite.
# The P3 package set is unchanged from ci.yml at 6ebda95 (including certificates).
case "$PROFILE" in
  p3)
    BASELINE=(
      find:findutils grep:grep sed:sed awk:gawk tar:tar gzip:gzip
      zip:zip unzip:unzip curl:curl wget:wget git:git jq:jq
      -:ca-certificates gcc:gcc g++:g++ make:make pkg-config:pkg-config python3:python3
    )
    ;;
  debug) BASELINE=(pkg-config:pkg-config zip:zip unzip:unzip) ;;
  *) fail 'Unknown profile; only p3 and debug are supported' 2 ;;
esac

[[ -f "$GATE" ]] || fail 'Privilege Gate is missing; no fallback is permitted' 3
command -v apt-get >/dev/null 2>&1 || fail 'CI provisioning requires an APT runner' 3

gate() {
  local rc
  if bash "$GATE" "$@"; then
    return 0
  else
    rc=$?
    fail "Gate action $1 refused or failed (exit $rc); stopping without fallback" "$rc"
  fi
}

present() {
  if [[ "$1" == '-' ]]; then
    # A certificate bundle is not a command; do not silently drop it from P3.
    command -v dpkg-query >/dev/null 2>&1 &&
      [[ "$(dpkg-query -W -f='${Status}' "$2" 2>/dev/null)" == 'install ok installed' ]]
  else
    command -v "$1" >/dev/null 2>&1
  fi
}

MISSING=()
for entry in "${BASELINE[@]}"; do
  tool="${entry%%:*}"
  package="${entry#*:}"
  # Preflight the entire fixed profile, even packages already present. A future
  # allowlist drift must fail before *any* privileged action, not only on a bare VM.
  gate package-install "$package"
  if ! present "$tool" "$package"; then
    MISSING+=("$package")
  fi
done

if (( ${#MISSING[@]} == 0 )); then
  printf 'PRESENT: %s baseline; no installation needed\n' "$PROFILE"
  exit 0
fi

printf 'MISSING packages (%s): %s\n' "$PROFILE" "${MISSING[*]}"
gate apt-update
if [[ "$EXECUTE" == false ]]; then
  printf 'DRY-RUN: plan only; no packages installed (use --execute explicitly)\n'
  exit 0
fi

gate apt-update --execute
for package in "${MISSING[@]}"; do
  gate package-install "$package" --execute
done

# A zero installer exit alone is not evidence that provisioning satisfied P3.
for entry in "${BASELINE[@]}"; do
  tool="${entry%%:*}"
  package="${entry#*:}"
  if ! present "$tool" "$package"; then
    fail "Required tool/package still missing after provisioning: $entry" 3
  fi
done
printf 'VERIFIED: %s baseline present after Gate-mediated provisioning\n' "$PROFILE"
