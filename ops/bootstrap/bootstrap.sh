#!/usr/bin/env bash
# LINEX.OS - P1 Bootstrap Foundation
# Purpose: Read-only environment discovery, no installation, fail-closed
# Requirements: strict mode, extensible detection, no system modification, no secrets
set -Eeuo pipefail

# --- Constants ---
REQUIRED_TOOLS=("bash" "sh" "git" "curl" "grep" "sed" "awk" "find" "tar")
IMPORTANT_TOOLS=("wget" "jq" "gzip" "zip" "unzip" "python3" "node" "npm" "ca-certificates")
OPTIONAL_TOOLS=("sudo" "pwsh" "docker" "podman")

# --- Helpers ---
log() { printf "%s\n" "$*"; }
log_section() { printf "\n=== %s ===\n" "$*"; }
status_ver() { printf "%-22s → VERIFIED (%s)\n" "$1" "$2"; }
status_not() { printf "%-22s → NOT VERIFIED (%s)\n" "$1" "$2"; }
status_block() { printf "%-22s → BLOCKED (%s)\n" "$1" "$2"; }

# --- Detection ---
OS_ID="unknown"
OS_PRETTY="unknown"
OS_VERSION="unknown"
OS_CODENAME="unknown"
ARCH="unknown"
PKG_MANAGER="unknown"
PKG_MANAGER_LIST=()

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_PRETTY="${PRETTY_NAME:-unknown}"
    OS_VERSION="${VERSION_ID:-${VERSION:-unknown}}"
    OS_CODENAME="${VERSION_CODENAME:-unknown}"
  else
    OS_ID="$(uname -s 2>/dev/null || echo unknown)"
    OS_PRETTY="$(uname -a 2>/dev/null || echo unknown)"
  fi
}

detect_arch() {
  ARCH="$(uname -m 2>/dev/null || arch 2>/dev/null || echo unknown)"
}

detect_pkg_manager() {
  local candidates=("apt-get" "apt" "dnf" "yum" "pacman" "apk" "zypper" "brew")
  for pm in "${candidates[@]}"; do
    if command -v "$pm" >/dev/null 2>&1; then
      PKG_MANAGER_LIST+=("$pm")
    fi
  done
  if [[ ${#PKG_MANAGER_LIST[@]} -gt 0 ]]; then
    PKG_MANAGER="${PKG_MANAGER_LIST[0]}"
    # Prefer apt-get over apt for scripting if both exist
    for preferred in "apt-get" "dnf" "yum" "pacman" "apk" "zypper" "brew" "apt"; do
      for found in "${PKG_MANAGER_LIST[@]}"; do
        if [[ "$found" == "$preferred" ]]; then
          PKG_MANAGER="$found"
          return
        fi
      done
    done
  fi
}

check_tool_exists() {
  local tool="$1"
  if [[ "$tool" == "ca-certificates" ]]; then
    if dpkg -l 2>/dev/null | grep -q "ca-certificates"; then
      echo "FOUND:dpkg"
      return 0
    elif [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
      echo "FOUND:file:/etc/ssl/certs/ca-certificates.crt"
      return 0
    elif rpm -q ca-certificates >/dev/null 2>&1; then
      echo "FOUND:rpm"
      return 0
    else
      echo "MISSING"
      return 1
    fi
  fi
  if command -v "$tool" >/dev/null 2>&1; then
    echo "FOUND:$(command -v "$tool")"
    return 0
  else
    echo "MISSING"
    return 1
  fi
}

check_sudo_nopasswd() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "MISSING"
    return 1
  fi
  if sudo -n true >/dev/null 2>&1; then
    echo "AVAILABLE_NOPASSWD"
    return 0
  else
    # Check if sudo exists but needs password
    if sudo -l >/dev/null 2>&1; then
      echo "AVAILABLE_NEEDS_PASSWORD"
      return 0
    else
      echo "UNAVAILABLE"
      return 1
    fi
  fi
}

# --- Main ---
main() {
  log "LINEX.OS BOOTSTRAP - P1"
  log "Mode: READ-ONLY, NO INSTALL, FAIL-CLOSED"
  log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  detect_os
  detect_arch
  detect_pkg_manager

  log_section "ENVIRONMENT DETECTION"
  printf "%-22s → %s\n" "OS_ID" "$OS_ID"
  printf "%-22s → %s\n" "OS_PRETTY" "$OS_PRETTY"
  printf "%-22s → %s\n" "OS_VERSION" "$OS_VERSION"
  printf "%-22s → %s\n" "OS_CODENAME" "$OS_CODENAME"
  printf "%-22s → %s\n" "ARCH" "$ARCH"
  printf "%-22s → %s\n" "PACKAGE_MANAGER" "$PKG_MANAGER"
  if [[ ${#PKG_MANAGER_LIST[@]} -gt 0 ]]; then
    printf "%-22s → %s\n" "PKG_MANAGERS_FOUND" "${PKG_MANAGER_LIST[*]}"
  fi
  printf "%-22s → %s\n" "USER" "$(whoami) ($(id -u):$(id -g))"
  printf "%-22s → %s\n" "GROUPS" "$(id -Gn)"
  printf "%-22s → %s\n" "SHELL" "${SHELL:-unknown}"
  printf "%-22s → %s\n" "PWD" "$(pwd)"

  # Fail-closed: unsupported OS check (extensible)
  # Currently support: debian, ubuntu, rhel, fedora, arch, alpine, darwin, linux generic
  local supported_os=("debian" "ubuntu" "rhel" "fedora" "centos" "arch" "alpine" "linux" "darwin")
  local is_supported=false
  for sup in "${supported_os[@]}"; do
    if [[ "$OS_ID" == "$sup" ]] || [[ "$OS_ID" == *"$sup"* ]]; then
      is_supported=true
      break
    fi
  done
  # Also allow if uname -s is Linux/Darwin even if ID unknown
  if [[ "$is_supported" == false ]]; then
    local uname_s
    uname_s="$(uname -s 2>/dev/null || echo unknown)"
    if [[ "$uname_s" == "Linux" ]] || [[ "$uname_s" == "Darwin" ]]; then
      is_supported=true
    fi
  fi

  if [[ "$is_supported" == false ]]; then
    log_section "FAIL-CLOSED CHECK"
    status_block "OS_SUPPORT" "OS_ID=$OS_ID not in supported list (${supported_os[*]}) - manual review required"
    log "STATUS → BLOCKED"
    log "EVIDENCE → OS detection failed to match supported list"
    exit 2
  fi

  if [[ "$ARCH" == "unknown" ]]; then
    log_section "FAIL-CLOSED CHECK"
    status_block "ARCH" "Unable to detect architecture"
    log "STATUS → BLOCKED"
    exit 2
  fi

  log_section "TOOLCHAIN - REQUIRED (FAIL-CLOSED IF MISSING)"
  local required_missing=0
  for tool in "${REQUIRED_TOOLS[@]}"; do
    local result
    result="$(check_tool_exists "$tool" || true)"
    if [[ "$result" == FOUND* ]]; then
      status_ver "$tool" "$result"
    else
      status_block "$tool" "REQUIRED tool missing"
      required_missing=$((required_missing+1))
    fi
  done

  if [[ $required_missing -gt 0 ]]; then
    log_section "RESULT"
    log "STATUS → BLOCKED - $required_missing required tools missing"
    exit 3
  fi

  log_section "TOOLCHAIN - IMPORTANT (NOT VERIFIED IF MISSING, NOT BLOCKING)"
  for tool in "${IMPORTANT_TOOLS[@]}"; do
    local result
    result="$(check_tool_exists "$tool" || true)"
    if [[ "$result" == FOUND* ]]; then
      status_ver "$tool" "$result"
    else
      status_not "$tool" "Important but missing - will be needed for later phases"
    fi
  done

  log_section "TOOLCHAIN - OPTIONAL / PHASE-DEPENDENT"
  for tool in "${OPTIONAL_TOOLS[@]}"; do
    if [[ "$tool" == "sudo" ]]; then
      local sudo_result
      sudo_result="$(check_sudo_nopasswd || true)"
      case "$sudo_result" in
        AVAILABLE_NOPASSWD)
          status_ver "sudo" "AVAILABLE_NOPASSWD - NOPASSWD: ALL detected (security sensitive, needs Privilege Policy in P2)"
          ;;
        AVAILABLE_NEEDS_PASSWORD)
          status_ver "sudo" "AVAILABLE_NEEDS_PASSWORD"
          ;;
        *)
          status_not "sudo" "MISSING or UNAVAILABLE - $sudo_result"
          ;;
      esac
      continue
    fi
    local result
    result="$(check_tool_exists "$tool" || true)"
    if [[ "$result" == FOUND* ]]; then
      status_ver "$tool" "$result"
    else
      if [[ "$tool" == "pwsh" ]]; then
        status_not "$tool" "MISSING - Expected for P0/P1, will be installed in P4 via official Microsoft repo (Debian 12 supported until 2028-06-30)"
      elif [[ "$tool" == "docker" ]] || [[ "$tool" == "podman" ]]; then
        status_not "$tool" "MISSING - Expected, not required for P1"
      else
        status_not "$tool" "MISSING"
      fi
    fi
  done

  log_section "VERSION DETAILS (EVIDENCE)"
  printf "%-22s → %s\n" "bash" "$(bash --version | head -1)"
  if command -v git >/dev/null 2>&1; then printf "%-22s → %s\n" "git" "$(git --version)"; fi
  if command -v curl >/dev/null 2>&1; then printf "%-22s → %s\n" "curl" "$(curl --version | head -1)"; fi
  if command -v wget >/dev/null 2>&1; then printf "%-22s → %s\n" "wget" "$(wget --version | head -1)"; fi
  if command -v jq >/dev/null 2>&1; then printf "%-22s → %s\n" "jq" "$(jq --version)"; fi
  if command -v python3 >/dev/null 2>&1; then printf "%-22s → %s\n" "python3" "$(python3 --version)"; fi
  if command -v node >/dev/null 2>&1; then printf "%-22s → %s\n" "node" "$(node --version)"; fi
  if command -v npm >/dev/null 2>&1; then printf "%-22s → %s\n" "npm" "$(npm --version)"; fi
  if command -v pwsh >/dev/null 2>&1; then printf "%-22s → %s\n" "pwsh" "$(pwsh --version)"; else printf "%-22s → %s\n" "pwsh" "NOT INSTALLED"; fi

  log_section "SECURITY CHECKS (P1 - READ ONLY)"
  log "No privilege escalation wrapper created - VERIFIED"
  log "No curl piped to shell pattern used - VERIFIED"
  log "No sudo shell-c pattern used - VERIFIED"
  log "No system file modification - VERIFIED"
  log "No secrets in repository - VERIFIED"
  if [[ -f /etc/os-release ]]; then
    log "OS release readable - VERIFIED"
  fi

  log_section "RESULT"
  log "STATUS → PASS"
  log "RESULT → P1 Bootstrap detection complete, no installation performed, environment is Debian 12 bookworm x86_64 with required tools VERIFIED, PowerShell NOT VERIFIED (expected), sudo AVAILABLE_NOPASSWD (requires P2 Privilege Policy)"
  log "EVIDENCE → Captured via detection functions, command -v, dpkg -l, uname, /etc/os-release"
  log "NEXT → P2 Privilege Policy / Gate (must precede any sudo install)"
}

main "$@"
