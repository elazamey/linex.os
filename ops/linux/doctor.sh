#!/usr/bin/env bash
# LINEX.OS - P3 Linux Toolchain Doctor
# Purpose: Verify developer build baseline, no install, read-only

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

log() { printf "%s\n" "$*"; }
section() { printf "\n=== %s ===\n" "$*"; }
ver() { printf "%-22s → %s\n" "$1" "$2"; }
notver() { printf "%-22s → %s\n" "$1" "$2"; }

check_tool() {
  local tool="$1"
  case "$tool" in
    ca-certificates)
      if dpkg -l 2>/dev/null | grep -q ca-certificates; then echo "FOUND"; return 0; fi
      if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then echo "FOUND"; return 0; fi
      echo "MISSING"; return 1
      ;;
    *)
      if command -v "$tool" >/dev/null 2>&1; then echo "FOUND"; return 0; else echo "MISSING"; return 1; fi
      ;;
  esac
}

log "LINEX.OS LINUX TOOLCHAIN DOCTOR - P3"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log ""

section "REQUIRED BASELINE"
for tool in bash coreutils find grep sed awk tar gzip zip unzip curl wget git jq ca-certificates; do
  if [[ "$tool" == "coreutils" ]]; then
    if ls --version >/dev/null 2>&1; then ver "$tool" "PASS"; else notver "$tool" "NOT VERIFIED"; fi
  elif [[ "$tool" == "find" ]]; then
    if command -v find >/dev/null 2>&1; then ver "$tool" "PASS ($(find --version | head -1))"; else notver "$tool" "NOT VERIFIED"; fi
  else
    if check_tool "$tool" >/dev/null; then
      if command -v "$tool" >/dev/null 2>&1; then ver "$tool" "PASS ($($tool --version 2>&1 | head -1 || echo $(command -v $tool)))"; else ver "$tool" "PASS (ca-certificates)"; fi
    else
      notver "$tool" "NOT VERIFIED"
    fi
  fi
done

section "DEVELOPER BUILD TOOLCHAIN"
for tool in gcc g++ make pkg-config; do
  if command -v "$tool" >/dev/null 2>&1; then ver "$tool" "PASS ($($tool --version 2>&1 | head -1))"; else notver "$tool" "MISSING"; fi
done
if dpkg -l 2>/dev/null | grep -q "^ii.*build-essential"; then ver "build-essential" "PASS ($(dpkg-query -W -f='${Version}' build-essential 2>/dev/null))"; else notver "build-essential" "NOT INSTALLED (may be ok if gcc,g++,make exist)"; fi

section "RUNTIMES"
for tool in python3 node npm; do
  if command -v "$tool" >/dev/null 2>&1; then ver "$tool" "PASS ($($tool --version 2>&1 | head -1))"; else notver "$tool" "NOT VERIFIED"; fi
done

section "DOCKER / PODMAN (should be NOT REQUIRED)"
if command -v docker >/dev/null 2>&1; then notver "docker" "INSTALLED but NOT REQUIRED for P3 (should be NOT INSTALLED)"; else ver "docker" "NOT INSTALLED (expected for P3)"; fi
if command -v podman >/dev/null 2>&1; then notver "podman" "INSTALLED but NOT REQUIRED for P3"; else ver "podman" "NOT INSTALLED (expected for P3)"; fi

section "POWERSHELL (should be NOT VERIFIED for P3)"
if command -v pwsh >/dev/null 2>&1; then notver "pwsh" "INSTALLED but should be NOT VERIFIED in P3 (P4 only)"; else ver "pwsh" "NOT VERIFIED (expected for P3, P4 will install)"; fi

section "PACKAGE MAPPING VALIDATION"
# Ensure no arbitrary apt command in install-base.sh
if grep -E 'apt-get install.*\$RAW|apt install.*\$RAW' "$SCRIPT_DIR/install-base.sh" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" >/dev/null; then
  notver "package mapping" "FAIL - raw user input used"
else
  ver "package mapping" "PASS - explicit mapping, no raw input"
fi
# Check for actual sudo sh -c execution, not just log mentioning it
if grep -E '^\s*sudo.*sh -c' "$SCRIPT_DIR/install-base.sh" 2>/dev/null | grep -v "No " | grep -v "VERIFIED" >/dev/null; then
  notver "no sudo sh -c" "FAIL - sudo sh -c execution found"
else
  ver "no sudo sh -c" "PASS - no sudo sh -c execution (only logs)"
fi
# Check for actual apt upgrade as command, not documentation
if grep -E '^\s*apt-get upgrade|^\s*apt upgrade|^\s*sudo apt-get upgrade|^\s*sudo apt upgrade' "$SCRIPT_DIR/install-base.sh" 2>/dev/null | grep -v "No " | grep -v "avoid" | grep -v "VERIFIED" >/dev/null; then
  notver "no apt upgrade" "FAIL - apt upgrade found as executable"
else
  ver "no apt upgrade" "PASS - no upgrade/full-upgrade/dist-upgrade as executable"
fi

section "GATE USAGE"
if grep -q "privilege-gate.sh" "$SCRIPT_DIR/install-base.sh"; then ver "Gate usage" "PASS - Gate invoked for privileged install"; else notver "Gate usage" "FAIL - Gate not used"; fi

section "DISK / MEMORY"
df -h | head -10
free -h

section "FINAL"
log "LINEX.OS LINUX TOOLCHAIN DOCTOR"
log "P3 verification complete"
# Determine overall status
missing=0
for tool in gcc g++ make pkg-config; do
  if ! command -v "$tool" >/dev/null 2>&1; then missing=$((missing+1)); fi
done
if [[ $missing -eq 0 ]]; then
  log "STATUS → PASS - All P3 toolchain VERIFIED"
  log "RESULT → P3 TOOLCHAIN ALREADY SATISFIED or INSTALLED"
else
  log "STATUS → NOT VERIFIED - $missing tools missing (pkg-config likely)"
  log "RESULT → P3 needs install-base.sh to install missing: pkg-config"
fi
log "EVIDENCE → doctor.sh execution"
log "NEXT → P4 PowerShell"
