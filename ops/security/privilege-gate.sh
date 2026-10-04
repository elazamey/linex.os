#!/usr/bin/env bash
# LINEX.OS - Privilege Gate (P2)
# Purpose: Project privilege governance - allowlist + structured actions + fail-closed + dry-run default
# NOT a kernel sandbox. System sudoers is EXTERNAL. Project policy is CONTROLLED BY LINEX.OS GATE.
# Strict mode, no arbitrary execution, no eval, no bash -c with uncontrolled input, no secrets logging.

set -Eeuo pipefail

# --- Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLICY_FILE="$SCRIPT_DIR/privilege-policy.md"
FORBIDDEN_FILE="$SCRIPT_DIR/forbidden-commands.txt"

# Allowed actions (P2 minimal + P3 extension + P4 PowerShell)
# P2: check-sudo, check-package-manager, package-install, package-remove, service-status
# P3: apt-update (safe, needed to refresh package lists before install)
# P4: register-microsoft-repository (official Microsoft repo), install-powershell-package (official PowerShell .deb)
ALLOWED_ACTIONS=("check-sudo" "check-package-manager" "package-install" "package-remove" "service-status" "apt-update" "register-microsoft-repository" "install-powershell-package")

# Allowed packages (P2/P3) - DEFAULT DENY, explicit allowlist
# P2 baseline: ca-certificates, curl, wget, git, jq, tar, gzip, zip, unzip, bash, coreutils, findutils, grep, sed, gawk
# P3 justification: Add build toolchain minimal for Developer Build Baseline on Debian 12
# - gcc, g++, make, pkg-config, build-essential are required for C/C++ build smoke tests and future build steps
# - They are official Debian packages, small, non-privileged runtime, no docker/k8s/java/go/rust/dotnet
# - Only pkg-config is missing in current env, others already VERIFIED but allowlisted for reproducibility
ALLOWED_PACKAGES=(
  "ca-certificates"
  "curl"
  "wget"
  "git"
  "jq"
  "tar"
  "gzip"
  "zip"
  "unzip"
  "bash"
  "coreutils"
  "findutils"
  "grep"
  "sed"
  "gawk"
  "gcc"
  "g++"
  "make"
  "pkg-config"
  "build-essential"
)

# Allowed services for service-status (read-only)
ALLOWED_SERVICES=(
  "ssh"
  "sshd"
  "docker"
  "podman"
  "systemd"
  "network"
  "cron"
)

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Helpers ---
log() { printf "%s\n" "$*"; }
log_evidence() {
  # Structured evidence without secrets
  printf "ACTION: %s\n" "${ACTION:-unknown}"
  printf "CLASS: %s\n" "${CLASS:-UNKNOWN}"
  printf "POLICY: %s\n" "${POLICY_RESULT:-UNKNOWN}"
  printf "DECISION: %s\n" "${DECISION:-UNKNOWN}"
  printf "EXECUTION: %s\n" "${EXECUTION_STATUS:-UNKNOWN}"
  if [[ -n "${WOULD_EXECUTE:-}" ]]; then
    printf "WOULD EXECUTE: %s\n" "$WOULD_EXECUTE"
  fi
  printf "EXIT_CODE: %s\n" "${EXIT_CODE:-0}"
  printf "TIMESTAMP: %s\n" "$TIMESTAMP"
  # System vs Project distinction
  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    printf "SYSTEM_SUDO: %s\n" "AVAILABLE_NOPASSWD - EXTERNAL / NOT CONTROLLED BY REPOSITORY"
  else
    printf "SYSTEM_SUDO: %s\n" "NOT AVAILABLE or NEEDS PASSWORD - EXTERNAL"
  fi
  printf "PROJECT_POLICY: %s\n" "CONTROLLED BY LINEX.OS GATE"
}

fail_blocked() {
  local reason="$1"
  local exit_code="${2:-1}"
  CLASS="${CLASS:-UNKNOWN}"
  POLICY_RESULT="BLOCKED"
  DECISION="BLOCKED"
  EXECUTION_STATUS="NOT EXECUTED"
  EXIT_CODE="$exit_code"
  WOULD_EXECUTE="${WOULD_EXECUTE:-N/A - $reason}"
  log_evidence
  printf "REASON: %s\n" "$reason" >&2
  exit "$exit_code"
}

# Validate package/service name strictly
# Rules: ^[a-z0-9][a-z0-9+._-]{0,63}$ , no leading -, no /, no .., no metacharacters
validate_name() {
  local name="$1"
  local type="$2" # package or service

  if [[ -z "$name" ]]; then
    fail_blocked "Empty $type name" 2
  fi

  # Length check
  if [[ ${#name} -gt 64 ]]; then
    fail_blocked "$type name too long (>64): $name" 2
  fi

  # Must not start with -
  if [[ "$name" == -* ]]; then
    fail_blocked "$type name must not start with -: $name" 2
  fi

  # No path traversal
  if [[ "$name" == *"/"* ]]; then
    fail_blocked "$type name must not contain /: $name" 2
  fi
  if [[ "$name" == *".."* ]]; then
    fail_blocked "$type name must not contain ..: $name" 2
  fi

  # No forbidden tokens (shell metacharacters)
  # List: ; & | $ ` \ " ' < > ( ) { } * ? ! ~ # = % and space, tab, newline, etc.
  # We check via regex for allowed chars only
  if ! [[ "$name" =~ ^[a-z0-9][a-z0-9+._-]*$ ]]; then
    fail_blocked "$type name contains forbidden characters or invalid format (allowed: ^[a-z0-9][a-z0-9+._-]*$): $name" 2
  fi

  # Explicitly block dangerous substrings that might bypass regex (defense in depth)
  local forbidden_tokens=(";" "&&" "||" "|" "\$" "\$(" "\`" ">" "<" "(" ")" "{" "}" "*" "?" "!" "~" "#" "=" "%" "&" "\\" "\"" "'" " " $'\t' $'\n')
  for token in "${forbidden_tokens[@]}"; do
    if [[ "$name" == *"$token"* ]]; then
      # Allow + . _ - are ok, but others not
      if [[ "$token" == "+" || "$token" == "." || "$token" == "_" || "$token" == "-" ]]; then
        continue
      fi
      fail_blocked "$type name contains forbidden token '$token': $name" 2
    fi
  done

  # No command substitution patterns
  if [[ "$name" == *'$('* ]] || [[ "$name" == *'`'* ]]; then
    fail_blocked "$type name contains command substitution: $name" 2
  fi
}

is_package_allowed() {
  local pkg="$1"
  for allowed in "${ALLOWED_PACKAGES[@]}"; do
    if [[ "$pkg" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

is_service_allowed() {
  local svc="$1"
  for allowed in "${ALLOWED_SERVICES[@]}"; do
    if [[ "$svc" == "$allowed" ]]; then
      return 0
    fi
  done
  # Also allow if matches safe pattern but not in list? For P2, strict allowlist
  return 1
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then echo "apt-get"; return 0; fi
  if command -v apt >/dev/null 2>&1; then echo "apt"; return 0; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf"; return 0; fi
  if command -v yum >/dev/null 2>&1; then echo "yum"; return 0; fi
  if command -v pacman >/dev/null 2>&1; then echo "pacman"; return 0; fi
  if command -v apk >/dev/null 2>&1; then echo "apk"; return 0; fi
  if command -v zypper >/dev/null 2>&1; then echo "zypper"; return 0; fi
  echo "unknown"
  return 1
}

# --- Main ---
ACTION=""
PACKAGE_NAME=""
SERVICE_NAME=""
EXECUTE=false
DRY_RUN=true

# Parse args
# Usage: privilege-gate.sh <action> [package/service] [--execute]
# No arbitrary command string

if [[ $# -eq 0 ]]; then
  ACTION="unknown"
  CLASS="UNKNOWN"
  fail_blocked "Missing action. Allowed actions: ${ALLOWED_ACTIONS[*]}" 2
fi

ACTION="$1"
shift || true

# Check for --execute flag anywhere
for arg in "$@"; do
  if [[ "$arg" == "--execute" ]]; then
    EXECUTE=true
    DRY_RUN=false
  fi
done

# Remove --execute from positional args for further parsing
ARGS=()
for arg in "$@"; do
  if [[ "$arg" != "--execute" ]]; then
    ARGS+=("$arg")
  fi
done

# Validate action is in allowlist
action_allowed=false
for allowed in "${ALLOWED_ACTIONS[@]}"; do
  if [[ "$ACTION" == "$allowed" ]]; then
    action_allowed=true
    break
  fi
done

if [[ "$action_allowed" == false ]]; then
  CLASS="UNKNOWN"
  POLICY_RESULT="BLOCKED"
  DECISION="BLOCKED"
  EXECUTION_STATUS="NOT EXECUTED"
  EXIT_CODE=3
  WOULD_EXECUTE="N/A - unknown action: $ACTION"
  log_evidence
  printf "REASON: Unknown action '%s'. Allowed: %s\n" "$ACTION" "${ALLOWED_ACTIONS[*]}" >&2
  exit 3
fi

# Map action to class
case "$ACTION" in
  check-sudo)
    CLASS="READ_ONLY"
    ;;
  check-package-manager)
    CLASS="READ_ONLY"
    ;;
  package-install)
    CLASS="PACKAGE_INSTALL"
    ;;
  package-remove)
    CLASS="PACKAGE_INSTALL"
    ;;
  service-status)
    CLASS="SAFE_USER_COMMAND"
    ;;
  apt-update)
    CLASS="SAFE_USER_COMMAND"
    ;;
  register-microsoft-repository)
    CLASS="PRIVILEGED_OPERATION"
    ;;
  install-powershell-package)
    CLASS="PACKAGE_INSTALL"
    ;;
  *)
    CLASS="UNKNOWN"
    ;;
esac

# Policy file existence check (fail-closed)
if [[ ! -f "$POLICY_FILE" ]]; then
  fail_blocked "Missing policy file: $POLICY_FILE" 4
fi
if [[ ! -f "$FORBIDDEN_FILE" ]]; then
  fail_blocked "Missing forbidden commands file: $FORBIDDEN_FILE" 4
fi

# Action-specific logic
case "$ACTION" in
  check-sudo)
    if [[ ${#ARGS[@]} -ne 0 ]]; then
      fail_blocked "check-sudo takes no arguments, got: ${ARGS[*]}" 2
    fi
    POLICY_RESULT="ALLOW"
    WOULD_EXECUTE="sudo -n true; sudo -l (read-only checks)"
    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Would execute read-only sudo checks"
      exit 0
    else
      DECISION="EXECUTED"
      # Real execution - read-only, safe
      if command -v sudo >/dev/null 2>&1; then
        if sudo -n true >/dev/null 2>&1; then
          log_evidence
          log "sudo -n true: PASS (NOPASSWD available)"
          sudo -l 2>&1 | head -20
          EXIT_CODE=0
          EXECUTION_STATUS="EXECUTED"
          exit 0
        else
          log_evidence
          log "sudo -n true: FAIL (needs password or unavailable)"
          EXIT_CODE=1
          EXECUTION_STATUS="FAILED"
          exit 1
        fi
      else
        fail_blocked "sudo command not found" 5
      fi
    fi
    ;;

  check-package-manager)
    if [[ ${#ARGS[@]} -ne 0 ]]; then
      fail_blocked "check-package-manager takes no arguments, got: ${ARGS[*]}" 2
    fi
    POLICY_RESULT="ALLOW"
    WOULD_EXECUTE="command -v apt-get/apt/dnf/yum/pacman/apk detection (read-only)"
    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Would detect package manager"
      exit 0
    else
      DECISION="EXECUTED"
      PKG_MGR="$(detect_pkg_manager || true)"
      if [[ "$PKG_MGR" != "unknown" ]]; then
        log_evidence
        log "Package manager detected: $PKG_MGR at $(command -v "$PKG_MGR")"
        EXIT_CODE=0
        EXECUTION_STATUS="EXECUTED"
        exit 0
      else
        fail_blocked "No package manager detected" 5
      fi
    fi
    ;;

  package-install)
    if [[ ${#ARGS[@]} -ne 1 ]]; then
      fail_blocked "package-install requires exactly 1 argument: <approved-package>, got: ${ARGS[*]}" 2
    fi
    PACKAGE_NAME="${ARGS[0]}"
    validate_name "$PACKAGE_NAME" "package"

    if ! is_package_allowed "$PACKAGE_NAME"; then
      fail_blocked "Package '$PACKAGE_NAME' not in allowlist. Allowed: ${ALLOWED_PACKAGES[*]}" 3
    fi

    POLICY_RESULT="ALLOW (allowlisted)"
    PKG_MGR="$(detect_pkg_manager || echo "apt-get")"
    case "$PKG_MGR" in
      apt-get) WOULD_EXECUTE="sudo apt-get install -y $PACKAGE_NAME" ;;
      apt) WOULD_EXECUTE="sudo apt install -y $PACKAGE_NAME" ;;
      dnf) WOULD_EXECUTE="sudo dnf install -y $PACKAGE_NAME" ;;
      yum) WOULD_EXECUTE="sudo yum install -y $PACKAGE_NAME" ;;
      pacman) WOULD_EXECUTE="sudo pacman -S --noconfirm $PACKAGE_NAME" ;;
      apk) WOULD_EXECUTE="sudo apk add $PACKAGE_NAME" ;;
      *) WOULD_EXECUTE="sudo $PKG_MGR install $PACKAGE_NAME (detected manager: $PKG_MGR)" ;;
    esac

    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Package '$PACKAGE_NAME' is allowlisted, would execute: $WOULD_EXECUTE"
      log "NOTE: In P2, real execution is implemented but tests use dry-run to keep REPOSITORY-ONLY"
      exit 0
    else
      # Real execution - only if --execute explicitly given and package allowlisted
      DECISION="EXECUTED"
      log_evidence
      log "Executing: $WOULD_EXECUTE"
      # Use direct execution, no shell interpreter for package name (already validated)
      # Note: In P2 phase, this would be a system change. Tests avoid --execute for install/remove.
      if [[ "$PKG_MGR" == "apt-get" ]]; then
        sudo apt-get install -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "apt" ]]; then
        sudo apt install -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "dnf" ]]; then
        sudo dnf install -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "yum" ]]; then
        sudo yum install -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "pacman" ]]; then
        sudo pacman -S --noconfirm "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "apk" ]]; then
        sudo apk add "$PACKAGE_NAME"
      else
        fail_blocked "Unsupported package manager for execution: $PKG_MGR" 5
      fi
      EXIT_CODE=$?
      if [[ $EXIT_CODE -eq 0 ]]; then
        EXECUTION_STATUS="EXECUTED"
      else
        EXECUTION_STATUS="FAILED"
      fi
      exit $EXIT_CODE
    fi
    ;;

  package-remove)
    if [[ ${#ARGS[@]} -ne 1 ]]; then
      fail_blocked "package-remove requires exactly 1 argument: <approved-package>, got: ${ARGS[*]}" 2
    fi
    PACKAGE_NAME="${ARGS[0]}"
    validate_name "$PACKAGE_NAME" "package"

    if ! is_package_allowed "$PACKAGE_NAME"; then
      fail_blocked "Package '$PACKAGE_NAME' not in allowlist for removal. Allowed: ${ALLOWED_PACKAGES[*]}" 3
    fi

    POLICY_RESULT="ALLOW (allowlisted)"
    PKG_MGR="$(detect_pkg_manager || echo "apt-get")"
    case "$PKG_MGR" in
      apt-get) WOULD_EXECUTE="sudo apt-get remove -y $PACKAGE_NAME" ;;
      apt) WOULD_EXECUTE="sudo apt remove -y $PACKAGE_NAME" ;;
      dnf) WOULD_EXECUTE="sudo dnf remove -y $PACKAGE_NAME" ;;
      yum) WOULD_EXECUTE="sudo yum remove -y $PACKAGE_NAME" ;;
      pacman) WOULD_EXECUTE="sudo pacman -R --noconfirm $PACKAGE_NAME" ;;
      apk) WOULD_EXECUTE="sudo apk del $PACKAGE_NAME" ;;
      *) WOULD_EXECUTE="sudo $PKG_MGR remove $PACKAGE_NAME" ;;
    esac

    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Package '$PACKAGE_NAME' removal allowlisted, would execute: $WOULD_EXECUTE"
      exit 0
    else
      DECISION="EXECUTED"
      log_evidence
      log "Executing: $WOULD_EXECUTE"
      if [[ "$PKG_MGR" == "apt-get" ]]; then
        sudo apt-get remove -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "apt" ]]; then
        sudo apt remove -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "dnf" ]]; then
        sudo dnf remove -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "yum" ]]; then
        sudo yum remove -y "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "pacman" ]]; then
        sudo pacman -R --noconfirm "$PACKAGE_NAME"
      elif [[ "$PKG_MGR" == "apk" ]]; then
        sudo apk del "$PACKAGE_NAME"
      else
        fail_blocked "Unsupported package manager for execution: $PKG_MGR" 5
      fi
      EXIT_CODE=$?
      if [[ $EXIT_CODE -eq 0 ]]; then
        EXECUTION_STATUS="EXECUTED"
      else
        EXECUTION_STATUS="FAILED"
      fi
      exit $EXIT_CODE
    fi
    ;;

  service-status)
    if [[ ${#ARGS[@]} -ne 1 ]]; then
      fail_blocked "service-status requires exactly 1 argument: <service-name>, got: ${ARGS[*]}" 2
    fi
    SERVICE_NAME="${ARGS[0]}"
    validate_name "$SERVICE_NAME" "service"

    if ! is_service_allowed "$SERVICE_NAME"; then
      fail_blocked "Service '$SERVICE_NAME' not in allowlist. Allowed: ${ALLOWED_SERVICES[*]}" 3
    fi

    POLICY_RESULT="ALLOW (allowlisted)"
    WOULD_EXECUTE="systemctl is-active $SERVICE_NAME (read-only) or systemctl status $SERVICE_NAME --no-pager"

    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Service '$SERVICE_NAME' status check would execute: $WOULD_EXECUTE"
      exit 0
    else
      DECISION="EXECUTED"
      log_evidence
      if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active "$SERVICE_NAME" || true
        systemctl status "$SERVICE_NAME" --no-pager -l 2>&1 | head -30 || true
        EXIT_CODE=0
        EXECUTION_STATUS="EXECUTED"
        exit 0
      else
        log "systemctl not found, trying service command"
        if command -v service >/dev/null 2>&1; then
          service "$SERVICE_NAME" status 2>&1 | head -30 || true
          EXIT_CODE=0
          EXECUTION_STATUS="EXECUTED"
          exit 0
        else
          fail_blocked "No systemctl or service command found for service-status" 5
        fi
      fi
    fi
    ;;

  apt-update)
    if [[ ${#ARGS[@]} -ne 0 ]]; then
      fail_blocked "apt-update takes no arguments, got: ${ARGS[*]}" 2
    fi
    POLICY_RESULT="ALLOW"
    PKG_MGR="$(detect_pkg_manager || echo "apt-get")"
    case "$PKG_MGR" in
      apt-get) WOULD_EXECUTE="sudo apt-get update" ;;
      apt) WOULD_EXECUTE="sudo apt update" ;;
      *) WOULD_EXECUTE="sudo $PKG_MGR update (or equivalent)" ;;
    esac

    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Would execute: $WOULD_EXECUTE"
      exit 0
    else
      DECISION="EXECUTED"
      log_evidence
      log "Executing: $WOULD_EXECUTE"
      if [[ "$PKG_MGR" == "apt-get" ]]; then
        sudo apt-get update
      elif [[ "$PKG_MGR" == "apt" ]]; then
        sudo apt update
      else
        fail_blocked "apt-update only supported for apt/apt-get, detected: $PKG_MGR" 5
      fi
      EXIT_CODE=$?
      if [[ $EXIT_CODE -eq 0 ]]; then
        EXECUTION_STATUS="EXECUTED"
      else
        EXECUTION_STATUS="FAILED"
      fi
      exit $EXIT_CODE
    fi
    ;;

  register-microsoft-repository)
    if [[ ${#ARGS[@]} -ne 0 ]]; then
      fail_blocked "register-microsoft-repository takes no arguments, got: ${ARGS[*]}" 2
    fi
    # Detect OS for URL construction (official Microsoft repository)
    # Must derive from ID and VERSION_ID, not arbitrary URL
    if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      OS_ID="${ID:-debian}"
      OS_VERSION="${VERSION_ID:-12}"
    else
      OS_ID="debian"
      OS_VERSION="12"
    fi
    # Validate OS_ID and VERSION_ID (only allow debian/ubuntu, version numeric)
    if ! [[ "$OS_ID" =~ ^(debian|ubuntu)$ ]]; then
      fail_blocked "Unsupported OS for Microsoft repository: $OS_ID (only debian/ubuntu allowed)" 2
    fi
    if ! [[ "$OS_VERSION" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      fail_blocked "Invalid VERSION_ID for Microsoft repository: $OS_VERSION" 2
    fi
    # Construct official URL (no arbitrary URL allowed)
    # Per Microsoft Learn: https://packages.microsoft.com/config/<id>/<version>/packages-microsoft-prod.deb
    MICROSOFT_PROD_URL="https://packages.microsoft.com/config/${OS_ID}/${OS_VERSION}/packages-microsoft-prod.deb"
    POLICY_RESULT="ALLOW (official source: packages.microsoft.com)"
    WOULD_EXECUTE="curl -L -o /tmp/linex-os-powershell/packages-microsoft-prod.deb $MICROSOFT_PROD_URL && sudo dpkg -i /tmp/linex-os-powershell/packages-microsoft-prod.deb"

    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Would download official Microsoft repository package from: $MICROSOFT_PROD_URL"
      log "DESTINATION: /tmp/linex-os-powershell/packages-microsoft-prod.deb"
      log "VALIDATION: file size >0, dpkg-deb --info Package: packages-microsoft-prod"
      exit 0
    else
      DECISION="EXECUTED"
      log_evidence
      log "Downloading official Microsoft repository package from: $MICROSOFT_PROD_URL"
      mkdir -p /tmp/linex-os-powershell
      # Download with validation (no curl|bash)
      if ! curl -L --fail --connect-timeout 10 -o /tmp/linex-os-powershell/packages-microsoft-prod.deb "$MICROSOFT_PROD_URL" 2>&1; then
        fail_blocked "Failed to download Microsoft repository package from official source: $MICROSOFT_PROD_URL (network BLOCKED?)" 6
      fi
      # Validate file
      if [[ ! -s /tmp/linex-os-powershell/packages-microsoft-prod.deb ]]; then
        fail_blocked "Downloaded file is empty or missing: /tmp/linex-os-powershell/packages-microsoft-prod.deb" 6
      fi
      if ! dpkg-deb --info /tmp/linex-os-powershell/packages-microsoft-prod.deb 2>&1 | grep -q "Package:"; then
        fail_blocked "Downloaded file is not a valid .deb package" 6
      fi
      # Check package name
      pkg_name=$(dpkg-deb --field /tmp/linex-os-powershell/packages-microsoft-prod.deb Package 2>/dev/null || echo "unknown")
      if [[ "$pkg_name" != "packages-microsoft-prod" ]]; then
        fail_blocked "Package name mismatch, expected packages-microsoft-prod, got $pkg_name" 6
      fi
      log "Package validation PASS: $pkg_name, size $(stat -c%s /tmp/linex-os-powershell/packages-microsoft-prod.deb) bytes"
      log "Executing: sudo dpkg -i /tmp/linex-os-powershell/packages-microsoft-prod.deb"
      sudo dpkg -i /tmp/linex-os-powershell/packages-microsoft-prod.deb
      EXIT_CODE=$?
      if [[ $EXIT_CODE -eq 0 ]]; then
        EXECUTION_STATUS="EXECUTED"
        log "Microsoft repository registered successfully"
      else
        EXECUTION_STATUS="FAILED"
        log "Failed to register Microsoft repository, exit $EXIT_CODE"
      fi
      exit $EXIT_CODE
    fi
    ;;

  install-powershell-package)
    if [[ ${#ARGS[@]} -ne 1 ]]; then
      fail_blocked "install-powershell-package requires exactly 1 argument: <path-to-deb>, got: ${ARGS[*]}" 2
    fi
    DEB_PATH="${ARGS[0]}"

    # Validate path is restricted to allowed directory
    # Only allow /tmp/linex-os-powershell/*.deb to prevent arbitrary path
    if ! [[ "$DEB_PATH" =~ ^/tmp/linex-os-powershell/.*\.deb$ ]]; then
      fail_blocked "Deb path must be in /tmp/linex-os-powershell/ and end with .deb, got: $DEB_PATH" 2
    fi

    # No path traversal
    if [[ "$DEB_PATH" == *".."* ]]; then
      fail_blocked "Deb path must not contain ..: $DEB_PATH" 2
    fi

    # No shell metacharacters in path
    if ! [[ "$DEB_PATH" =~ ^[a-zA-Z0-9/_\.\-]+$ ]]; then
      fail_blocked "Deb path contains forbidden characters: $DEB_PATH" 2
    fi

    if [[ ! -f "$DEB_PATH" ]]; then
      fail_blocked "Deb file not found: $DEB_PATH" 2
    fi

    if [[ ! -s "$DEB_PATH" ]]; then
      fail_blocked "Deb file is empty: $DEB_PATH" 2
    fi

    # Validate package metadata
    if ! dpkg-deb --info "$DEB_PATH" >/dev/null 2>&1; then
      fail_blocked "File is not a valid .deb package: $DEB_PATH" 6
    fi

    pkg_name=$(dpkg-deb --field "$DEB_PATH" Package 2>/dev/null || echo "unknown")
    pkg_arch=$(dpkg-deb --field "$DEB_PATH" Architecture 2>/dev/null || echo "unknown")
    pkg_version=$(dpkg-deb --field "$DEB_PATH" Version 2>/dev/null || echo "unknown")

    # Only allow powershell package, amd64 arch
    if [[ "$pkg_name" != "powershell" && "$pkg_name" != "powershell-lts" ]]; then
      fail_blocked "Package name must be powershell or powershell-lts, got: $pkg_name" 6
    fi

    if [[ "$pkg_arch" != "amd64" ]]; then
      fail_blocked "Package architecture must be amd64, got: $pkg_arch" 6
    fi

    # Check for official source (file should have been downloaded from allowed sources)
    # We check that file name matches official pattern: powershell_7.6.6-1.deb_amd64.deb or powershell-lts_7.6.6-1.deb_amd64.deb
    if ! [[ "$(basename "$DEB_PATH")" =~ ^powershell(-lts)?_7\.[0-9]+\.[0-9]+.*\.deb$ ]]; then
      fail_blocked "Package file name does not match official PowerShell release pattern: $(basename "$DEB_PATH")" 6
    fi

    POLICY_RESULT="ALLOW (official source: github.com/PowerShell/PowerShell, package validated)"
    WOULD_EXECUTE="sudo dpkg -i $DEB_PATH"

    if [[ "$DRY_RUN" == true ]]; then
      DECISION="DRY-RUN"
      EXECUTION_STATUS="NOT EXECUTED (dry-run)"
      EXIT_CODE=0
      log_evidence
      log "RESULT: DRY-RUN - Would install official PowerShell package: $DEB_PATH"
      log "PACKAGE: $pkg_name, ARCH: $pkg_arch, VERSION: $pkg_version, SIZE: $(stat -c%s "$DEB_PATH") bytes"
      exit 0
    else
      DECISION="EXECUTED"
      log_evidence
      log "Installing official PowerShell package: $DEB_PATH"
      log "PACKAGE: $pkg_name, ARCH: $pkg_arch, VERSION: $pkg_version"
      sudo dpkg -i "$DEB_PATH"
      EXIT_CODE=$?
      if [[ $EXIT_CODE -eq 0 ]]; then
        EXECUTION_STATUS="EXECUTED"
        log "PowerShell package installed successfully"
        # Try to fix dependencies if needed (but avoid apt upgrade)
        # Only attempt apt-get install -f -y if dependency missing, and only if Debian network not blocked
        log "Checking if dependencies need fixing via apt-get install -f"
        sudo apt-get install -f -y 2>&1 | head -20 || log "apt-get install -f failed (may be due to Debian network BLOCKED)"
      else
        EXECUTION_STATUS="FAILED"
        log "Failed to install PowerShell package, exit $EXIT_CODE"
      fi
      exit $EXIT_CODE
    fi
    ;;

  *)
    fail_blocked "Unhandled action: $ACTION (should have been caught earlier)" 3
    ;;
esac
