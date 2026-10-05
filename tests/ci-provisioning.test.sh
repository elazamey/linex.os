#!/usr/bin/env bash
# W2 regression tests: real Gate dry-runs + isolated provisioning with a fake Gate.
# No real privileged execution, package installation, or network access.
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT_DIR/ops/ci/provision-toolchain.sh"
GATE="$ROOT_DIR/ops/security/privilege-gate.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/linex-os-w2-test.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
TOTAL=0 FAILED=0 CASE_ID=0

check() {
  local name="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@"; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s\n' "$name"
    FAILED=$((FAILED + 1))
  fi
}

# Conservative literal provisioning-command guard, not a shell parser or a sandbox.
# It scans both workflows for package-manager + mutating operation (not prose such
# as "apt mirror unreachable"). Quoted command examples fail; comments do not.
no_raw_package_commands() {
  local file
  (( $# > 0 )) || return 1
  for file in "$@"; do [[ -f "$file" && -r "$file" ]] || return 1; done
  awk '
    !/^[[:space:]]*#/ && /(^|[^[:alnum:]_-])(apt-get|apt|dpkg)[[:space:]]+(-[-[:alnum:]=]+[[:space:]]+)*(install|update|remove|purge|upgrade|full-upgrade|dist-upgrade|-i|--install|--configure)([[:space:]]|$)/ {
      printf "%s:%d: direct package-manager reference: %s\n", FILENAME, FNR, $0
      bad=1
    }
    END { exit bad }
  ' "$@"
}

# These particular steps deliberately have only a name and a literal run block.
# Compare the whole non-comment step, so a skipped/softened step cannot pass just
# because its expected command is still somewhere in the YAML text.
step_is() {
  local file="$1" name="$2" command="$3" actual expected
  actual=$(awk -v name="$name" '
    /^      - name:/ { active = ($0 == "      - name: " name) }
    active && NF && $0 !~ /^[[:space:]]*#/ { print }
  ' "$file")
  printf -v expected '      - name: %s\n        run: |\n          %s' "$name" "$command"
  [[ "$actual" == "$expected" ]]
}

shopt -s nullglob
WORKFLOWS=("$ROOT_DIR/.github/workflows/"*.yml "$ROOT_DIR/.github/workflows/"*.yaml)
check 'all workflows prohibit literal direct package-manager calls' no_raw_package_commands "${WORKFLOWS[@]}"
check 'main provisioning step calls the shared helper, without softening' step_is \
  "$ROOT_DIR/.github/workflows/ci.yml" 'Ensure P3 toolchain baseline (provision, then verify)' \
  'bash ops/ci/provision-toolchain.sh p3 --execute'
check 'debug provisioning step calls the shared helper, without softening' step_is \
  "$ROOT_DIR/.github/workflows/ci-debug.yml" 'Ensure debug toolchain baseline through Gate (W2)' \
  'bash ops/ci/provision-toolchain.sh debug --execute'
for workflow in ci.yml ci-debug.yml; do
  check "$workflow runs this regression suite without softening" step_is \
    "$ROOT_DIR/.github/workflows/$workflow" 'CI provisioning regression tests (W2)' \
    'bash tests/ci-provisioning.test.sh'
done

# A plain (unquoted) `name:` scalar containing ": " is invalid YAML. GitHub then
# reports "This run likely failed because of a workflow file issue" with zero jobs:
# the run never starts, no job-level check can see it, and no shell linter catches it.
# Not hypothetical - it happened to a parallel W2 PR (run 37274775844). Quoted name
# values may contain ": " legitimately; anything else must not.
name_scalars_are_valid() {
  local file
  (( $# > 0 )) || return 1
  for file in "$@"; do [[ -f "$file" && -r "$file" ]] || return 1; done
  awk -v q="'" '
    /^[[:space:]]*(-[[:space:]]+)?name:[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*(-[[:space:]]+)?name:[[:space:]]+/, "", line)
      first = substr(line, 1, 1)
      if (first == "\"" || first == q) next
      if (index(line, ": ") > 0) {
        printf "%s:%d: unquoted \": \" in a name scalar: %s\n", FILENAME, FNR, $0
        bad = 1
      }
    }
    END { exit bad }
  ' "$@"
}
check 'all workflow name scalars are valid YAML' name_scalars_are_valid "${WORKFLOWS[@]}"
cp "$ROOT_DIR/.github/workflows/ci.yml" "$WORK/mutated-name.yml"
printf '      - name: %s\n' 'zzz: yyy' >> "$WORK/mutated-name.yml"
if name_scalars_are_valid "$WORK/mutated-name.yml" > "$WORK/mutation-output" 2>&1; then
  check 'YAML name-scalar guard rejects an unquoted ": " (mutation)' false
else
  check 'YAML name-scalar guard rejects an unquoted ": " (mutation)' true
fi
cp "$ROOT_DIR/.github/workflows/ci.yml" "$WORK/mutated-name.yml"
printf '      - name: %s\n' '"zzz: yyy"' >> "$WORK/mutated-name.yml"
if name_scalars_are_valid "$WORK/mutated-name.yml" > "$WORK/mutation-output" 2>&1; then
  check 'quoted name scalars may still contain ": " (positive control)' true
else
  check 'quoted name scalars may still contain ": " (positive control)' false
fi

# Mutation probes never execute the injected text. They prove the same guard
# rejects a reintroduced bypass in either workflow, including the old inline form.
for workflow in ci.yml ci-debug.yml; do
  for injection in 'sudo apt-get install -y zip' \
    'command -v zip || sudo apt-get install -y zip' \
    'sudo dpkg -i example.deb' 'apt-get update'; do
    cp "$ROOT_DIR/.github/workflows/$workflow" "$WORK/mutated.yml"
    printf '          %s\n' "$injection" >> "$WORK/mutated.yml"
    if no_raw_package_commands "$WORK/mutated.yml" > "$WORK/mutation-output" 2>&1; then
      check "$workflow rejects injected bypass: $injection" false
    else
      check "$workflow rejects injected bypass: $injection" true
    fi
  done
done
cp "$ROOT_DIR/.github/workflows/ci.yml" "$WORK/mutated.yml"
sed -i '/- name: Ensure P3 toolchain baseline/a\        continue-on-error: true' "$WORK/mutated.yml"
if step_is "$WORK/mutated.yml" 'Ensure P3 toolchain baseline (provision, then verify)' \
  'bash ops/ci/provision-toolchain.sh p3 --execute'; then
  check 'softening a provisioning step is rejected' false
else
  check 'softening a provisioning step is rejected' true
fi

P3_PACKAGES=(findutils grep sed gawk tar gzip zip unzip curl wget git jq ca-certificates gcc g++ make pkg-config python3)
TOOLS=(find grep sed awk tar gzip zip unzip curl wget git jq gcc g++ make pkg-config python3)
real_gate_dry_run() {
  local output
  output=$(bash "$GATE" package-install "$1" 2>&1) || { printf '%s\n' "$output"; return 1; }
  [[ "$output" == *'DECISION: DRY-RUN'* && "$output" == *'EXECUTION: NOT EXECUTED (dry-run)'* ]]
}
for package in "${P3_PACKAGES[@]}"; do
  check "real Gate permits existing CI prerequisite $package in dry-run" real_gate_dry_run "$package"
done
for package in find awk nodejs npm; do
  if bash "$GATE" package-install "$package" > "$WORK/denial" 2>&1; then
    check "real Gate still rejects $package" false
  else
    check "real Gate still rejects $package" grep -q 'POLICY: BLOCKED' "$WORK/denial"
  fi
done

# Compare explicit package lists, not a claim that the entire policy is semantic.
awk '/^ALLOWED_PACKAGES=\(/ { list=1; next } list && /^\)/ { exit }
  list && /"/ { gsub(/["[:space:]]/, ""); print }' "$GATE" | sort > "$WORK/gate-packages"
awk '/^## 5\./ { list=1; next } list && /^## 6\./ { exit }
  list && /^- [a-z0-9][a-z0-9+._-]*$/ { print substr($0, 3) }' \
  "$ROOT_DIR/ops/security/privilege-policy.md" | sort > "$WORK/policy-packages"
check 'documented package allowlist matches the Gate' diff -u "$WORK/policy-packages" "$WORK/gate-packages"

# Fake Gate: installed commands and package state live only below WORK.
# Injection controls belong exclusively to this fixture, never the shipped helper.
cat > "$WORK/fake-gate" <<'MOCK'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$FIXTURE_DIR/calls"
[[ "$*" != "$REJECT_CALL" ]] || exit 19
if [[ "$1" == apt-update ]]; then exit 0; fi
[[ "$1" == package-install && $# -ge 2 ]] || exit 91
if [[ "${3:-}" != --execute ]]; then exit 0; fi
[[ "$2" != "$OMIT_INSTALL" ]] || exit 0
case "$2" in
  findutils) tool=find ;;
  gawk) tool=awk ;;
  ca-certificates) : > "$FIXTURE_DIR/ca-certificates"; exit 0 ;;
  *) tool="$2" ;;
esac
/bin/ln -sf /bin/true "$FIXTURE_DIR/bin/$tool"
MOCK

new_fixture() {
  CASE_ID=$((CASE_ID + 1))
  FIXTURE_DIR="$WORK/case-$CASE_ID"
  BIN="$FIXTURE_DIR/bin"
  CALLS="$FIXTURE_DIR/calls"
  REJECT_CALL='' OMIT_INSTALL=''
  mkdir -p "$BIN" "$FIXTURE_DIR/ops/ci" "$FIXTURE_DIR/ops/security"
  cp "$HELPER" "$FIXTURE_DIR/ops/ci/provision-toolchain.sh"
  cp "$WORK/fake-gate" "$FIXTURE_DIR/ops/security/privilege-gate.sh"
  ln -s "$(command -v bash)" "$BIN/bash"
  ln -s "$(command -v dirname)" "$BIN/dirname"
  for tool in "${TOOLS[@]}"; do ln -s /bin/true "$BIN/$tool"; done
  for tool in "$@"; do rm -f -- "$BIN/$tool"; done
  : > "$CALLS"
  : > "$FIXTURE_DIR/ca-certificates"
  cat > "$BIN/dpkg-query" <<'MOCK'
#!/bin/bash
[[ -f "$FIXTURE_DIR/ca-certificates" ]] || exit 1
printf 'install ok installed'
MOCK
  # The helper may detect APT but must never execute it (or sudo) directly.
  cat > "$BIN/apt-get" <<'MOCK'
#!/bin/bash
printf 'unexpected direct call\n' >> "$FIXTURE_DIR/raw-calls"
exit 97
MOCK
  cp "$BIN/apt-get" "$BIN/sudo"
  chmod +x "$BIN/dpkg-query" "$BIN/apt-get" "$BIN/sudo"
}

run_fixture() {
  if OUTPUT=$(FIXTURE_DIR="$FIXTURE_DIR" REJECT_CALL="$REJECT_CALL" OMIT_INSTALL="$OMIT_INSTALL" \
    PATH="$BIN" "$BIN/bash" "$FIXTURE_DIR/ops/ci/provision-toolchain.sh" "$@" 2>&1); then
    RC=0
  else
    RC=$?
  fi
}

result_is() {
  if [[ "$RC" == "$1" && "$OUTPUT" == *"$2"* && "$(cat "$CALLS")" == "$3" &&
    ! -s "$FIXTURE_DIR/raw-calls" ]]; then
    return 0
  fi
  printf 'exit=%s\n%s\nGate trace:\n' "$RC" "$OUTPUT"
  cat "$CALLS"
  return 1
}

DEBUG_PREFLIGHT=$'package-install pkg-config\npackage-install zip\npackage-install unzip'
DEBUG_PLAN="$DEBUG_PREFLIGHT"$'\napt-update'
DEBUG_EXEC="$DEBUG_PLAN"$'\napt-update --execute\npackage-install pkg-config --execute'

new_fixture pkg-config
run_fixture debug
check 'default is dry-run: all preflights, no privileged execution' result_is 0 'DRY-RUN: plan only' "$DEBUG_PLAN"
run_fixture debug --dry-run
check 'explicit dry-run also performs no privileged execution' result_is 0 'DRY-RUN: plan only' "$DEBUG_PLAN"$'\n'"$DEBUG_PLAN"

new_fixture pkg-config
run_fixture debug --execute
check 'execute installs only the missing debug package via Gate, after dry-runs' result_is 0 'VERIFIED: debug' "$DEBUG_EXEC"

new_fixture
run_fixture debug --execute
check 'complete baseline performs preflights but no update or install' result_is 0 'PRESENT: debug' "$DEBUG_PREFLIGHT"

for args in 'unknown' 'debug --unknown' 'debug --execute extra'; do
  new_fixture
  # Intentional word splitting of fixed test data, not user-controlled input.
  read -r -a argv <<< "$args"
  run_fixture "${argv[@]}"
  check "invalid invocation fails before reaching Gate: $args" result_is 2 '::error' ''
done
new_fixture
run_fixture
check 'missing profile fails before reaching Gate' result_is 2 'Usage:' ''

new_fixture pkg-config
rm "$FIXTURE_DIR/ops/security/privilege-gate.sh"
run_fixture debug --execute
check 'missing Gate stops without a fallback' result_is 3 'Privilege Gate is missing' ''

new_fixture pkg-config
rm "$BIN/apt-get"
run_fixture debug --execute
check 'unsupported runner stops before reaching Gate' result_is 3 'requires an APT runner' ''

new_fixture pkg-config
REJECT_CALL='package-install unzip'
run_fixture debug --execute
check 'denied present package stops the whole plan before any execute' result_is 19 '::error' "$DEBUG_PREFLIGHT"

new_fixture pkg-config
REJECT_CALL='apt-update'
run_fixture debug --execute
check 'update preflight refusal prevents execution' result_is 19 '::error' "$DEBUG_PLAN"

new_fixture pkg-config
REJECT_CALL='apt-update --execute'
run_fixture debug --execute
check 'update failure prevents package installation' result_is 19 '::error' "$DEBUG_PLAN"$'\napt-update --execute'

new_fixture pkg-config zip
REJECT_CALL='package-install pkg-config --execute'
run_fixture debug --execute
check 'install failure stops before attempting the next missing package' result_is 19 '::error' "$DEBUG_EXEC"

new_fixture pkg-config
OMIT_INSTALL='pkg-config'
run_fixture debug --execute
check 'successful Gate exit cannot hide a missing postcondition' result_is 3 'still missing' "$DEBUG_EXEC"

new_fixture find awk python3
rm "$FIXTURE_DIR/ca-certificates"
run_fixture p3 --execute
P3_PREFLIGHT=$(printf 'package-install %s\n' "${P3_PACKAGES[@]}")
check 'P3 maps find/awk to packages, preserves certificates, and installs python3 via Gate' result_is 0 \
  'VERIFIED: p3' "$P3_PREFLIGHT"$'\napt-update\napt-update --execute\npackage-install findutils --execute\npackage-install gawk --execute\npackage-install ca-certificates --execute\npackage-install python3 --execute'

printf '\nTOTAL: %s\nPASSED: %s\nFAILED: %s\n' "$TOTAL" "$((TOTAL - FAILED))" "$FAILED"
printf 'Evidence scope: real Gate DRY-RUN + mocked provisioning; no real installs.\n'
(( FAILED == 0 ))
