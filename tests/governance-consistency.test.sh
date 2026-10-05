#!/usr/bin/env bash
# LINEX.OS - Governance consistency tests (W1 + W2 regression guard).
#
# These checks exist because two real drifts were measured in the triage audit
# (docs/reports/triage-audit-a71643a.md) and are re-checked here so they cannot
# come back silently:
#
#   W1  policy <-> code allowlist drift
#       ops/security/privilege-gate.sh allowed 20 packages while
#       ops/security/privilege-policy.md §5 documented 15, and neither list
#       covered python3/nodejs/npm although ops/linux/toolchain-manifest.txt
#       declares them Required=yes. install-base.sh could therefore detect a
#       missing runtime and then be BLOCKED by the Gate.
#
#   W2  CI bypassed the Gate
#       .github/workflows/ci.yml Job 4 provisioned the P3 baseline with raw
#       `sudo apt-get install`, outside ops/security/privilege-gate.sh - the only
#       install path the project claims. The provisioning must now be a Gate
#       decision (apt-update + package-install --execute).
#
# Every check is a set comparison or a source scan: none of them can pass by the
# wording of a sentence changing.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT_DIR/ops/security/privilege-gate.sh"
POLICY="$ROOT_DIR/ops/security/privilege-policy.md"
MANIFEST="$ROOT_DIR/ops/linux/toolchain-manifest.txt"
INSTALL_BASE="$ROOT_DIR/ops/linux/install-base.sh"
CI="$ROOT_DIR/.github/workflows/ci.yml"

TOTAL=0
PASSED=0
FAILED=0

log() { printf '%s\n' "$*"; }
pass() { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); printf '%-64s → PASS (%s)\n' "$1" "$2"; }
fail() { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); printf '%-64s → FAIL (%s)\n' "$1" "$2" >&2; }
check() { if [[ "$2" -eq 0 ]]; then pass "$1" "$3"; else fail "$1" "$3"; fi }

# Set helpers. NB: this shell's `comm` does not accept here-strings as operands,
# so every comparison goes through process substitution over a sorted stream.
count() { printf '%s\n' "$1" | grep -c . || true; }
only_in() { # only_in A B -> lines present in A and absent from B (both sorted)
  comm -23 <(printf '%s\n' "$1" | grep . | sort -u) <(printf '%s\n' "$2" | grep . | sort -u) || true
}
# Extract the VALUE side of every [tool]="package" pair in a file. Layout-agnostic:
# several pairs may share a line, and this shell's grep/awk bracket handling is not
# relied upon.
pkg_values() {
  # keys appear quoted (["gcc"]="gcc") and unquoted ([find]="findutils")
  { grep -oE '\["?[a-zA-Z0-9+._-]+"?\]="[a-zA-Z0-9+._-]+"' "$1" 2>/dev/null || true; } \
    | sed -E 's/.*="([^"]+)"$/\1/' | sort -u
}

log "LINEX.OS GOVERNANCE CONSISTENCY TESTS (W1/W2 guard)"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log ""

# ---- extract the Gate allowlist (source of truth) --------------------------
GATE_PKGS="$(
  awk '/^ALLOWED_PACKAGES=\(/{f=1;next} f&&/^\)/{f=0} f{gsub(/[",[:space:]]/,""); if(length($0)>0) print}' "$GATE" \
  | sort -u
)"

# ---- extract the documented allowlist (§5.1 + §5.2 + §5.3 code blocks) -----
DOC_PKGS="$(
  awk '
    /^## 5\./{in5=1; next}
    in5 && /^## 6\./{in5=0}
    in5 && /^```/{code=!code; next}
    in5 && code && /^- /{sub(/^- /,""); gsub(/[[:space:]]/,""); if(length($0)>0) print}
  ' "$POLICY" | sort -u
)"

# ---- extract manifest packages declared Required=yes ----------------------
MANIFEST_PKGS="$(
  grep -E '^[a-z0-9+._-]+[[:space:]]*\|' "$MANIFEST" \
  | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); gsub(/^[ \t]+|[ \t]+$/,"",$4); if(tolower($4)=="yes") print $3}' \
  | sort -u
)"

# ---- extract packages install-base.sh can ask the Gate for ----------------
INSTALLBASE_PKGS="$(pkg_values "$INSTALL_BASE")"

# ---- extract packages named in ci.yml provisioning map --------------------
CI_PKGS="$(pkg_values "$CI")"

log "--- extracted sets ---"
log "Gate ALLOWED_PACKAGES ($(count "$GATE_PKGS")): $(printf '%s\n' "$GATE_PKGS" | tr '\n' ' ')"
log "Documented §5 ($(count "$DOC_PKGS")): $(printf '%s\n' "$DOC_PKGS" | tr '\n' ' ')"
log "Manifest Required=yes ($(count "$MANIFEST_PKGS")): $(printf '%s\n' "$MANIFEST_PKGS" | tr '\n' ' ')"
log "install-base TOOL_TO_PACKAGE ($(count "$INSTALLBASE_PKGS"))"
log "ci.yml TO_PKG ($(count "$CI_PKGS"))"
log ""

# ---- G1: documented allowlist == Gate allowlist ----------------------------
if [[ "$DOC_PKGS" == "$GATE_PKGS" ]]; then
  check "G1 policy §5 set == gate ALLOWED_PACKAGES set" 0 "identical, $(count "$GATE_PKGS") packages"
else
  check "G1 policy §5 set == gate ALLOWED_PACKAGES set" 1 \
    "drift: only-in-doc=[$(only_in "$DOC_PKGS" "$GATE_PKGS" | tr '\n' ' ')] only-in-code=[$(only_in "$GATE_PKGS" "$DOC_PKGS" | tr '\n' ' ')]"
fi

# ---- G2: every Required=yes manifest package is installable through Gate ---
MISSING_IN_GATE="$(only_in "$MANIFEST_PKGS" "$GATE_PKGS")"
if [[ -z "$MISSING_IN_GATE" ]]; then
  check "G2 every manifest Required=yes package is gate-installable" 0 "no gap"
else
  check "G2 every manifest Required=yes package is gate-installable" 1 "not allowlisted: $(tr '\n' ' ' <<<"$MISSING_IN_GATE")"
fi

# ---- G3: install-base.sh cannot ask the Gate for something it denies ------
MISSING_INSTALLBASE="$(only_in "$INSTALLBASE_PKGS" "$GATE_PKGS")"
if [[ -z "$MISSING_INSTALLBASE" ]]; then
  check "G3 install-base TOOL_TO_PACKAGE ⊆ gate allowlist" 0 "no BLOCKED-at-runtime package"
else
  check "G3 install-base TOOL_TO_PACKAGE ⊆ gate allowlist" 1 "would be BLOCKED: $(tr '\n' ' ' <<<"$MISSING_INSTALLBASE")"
fi

# ---- G4: ci.yml provisioning map ⊆ gate allowlist -------------------------
if [[ -z "$CI_PKGS" ]]; then
  check "G4 ci.yml provisioning map ⊆ gate allowlist" 1 "could not parse TO_PKG map in ci.yml"
else
  MISSING_CI="$(only_in "$CI_PKGS" "$GATE_PKGS")"
  if [[ -z "$MISSING_CI" ]]; then
    check "G4 ci.yml provisioning map ⊆ gate allowlist" 0 "$(count "$CI_PKGS") packages"
  else
    check "G4 ci.yml provisioning map ⊆ gate allowlist" 1 "would be BLOCKED: $(tr '\n' ' ' <<<"$MISSING_CI")"
  fi
fi

# ---- G5: CI performs no raw privileged package operation -----------------
# Only `sudo` usage that must not exist: raw apt/apt-get install|update|upgrade.
RAW_SUDO="$(grep -nE '^[[:space:]]*sudo[[:space:]]+(apt-get|apt|dpkg)[[:space:]]' "$CI" || true)"
if [[ -z "$RAW_SUDO" ]]; then
  check "G5 ci.yml has no raw 'sudo apt/dpkg' provisioning" 0 "no bypass path"
else
  check "G5 ci.yml has no raw 'sudo apt/dpkg' provisioning" 1 "found: $(head -1 <<<"$RAW_SUDO")"
fi

# ---- G6: CI mediates provisioning through the Gate ------------------------
if grep -q 'privilege-gate\.sh' "$CI" \
   && grep -q 'apt-update --execute' "$CI" \
   && grep -q 'package-install "\$pkg" --execute' "$CI"; then
  check "G6 ci.yml provision is Gate-mediated" 0 "gate reference + apt-update --execute + package-install --execute"
else
  check "G6 ci.yml provision is Gate-mediated" 1 "missing gate invocation (need path, apt-update --execute, package-install --execute)"
fi

# ---- G7: the W2 defect shape (install-then-verify tautology) stays visible -
# The provisioning step must ask the Gate for a decision (dry-run) and must
# fail closed with an annotation if the Gate denies a package.
if grep -q 'package-install "\$pkg"' "$CI" && grep -q 'title=Gate blocked' "$CI"; then
  check "G7 CI fails closed with an annotation when the Gate denies" 0 "fail-closed annotation present"
else
  check "G7 CI fails closed with an annotation when the Gate denies" 1 "no fail-closed annotation"
fi

# ---- G8: the slice introduces no new language and no privileged primitive --
if find "$ROOT_DIR/userpath" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' \) | grep -q .; then
  check "G8 slice adds no new language (Bash only)" 1 "non-Bash file found"
else
  check "G8 slice adds no new language (Bash only)" 0 "Bash only"
fi

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
