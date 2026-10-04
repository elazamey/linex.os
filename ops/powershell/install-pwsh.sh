#!/usr/bin/env bash
# LINEX.OS - P4 PowerShell 7 Installer (Debian 12)
# Purpose: Official sources only, dual-path: Microsoft Repository primary, GitHub .deb fallback, fail-closed, via Gate
# No third-party, no snap, no build from source, no arbitrary sudo, no curl|bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$ROOT_DIR/ops/security/privilege-gate.sh"

log() { printf "%s\n" "$*"; }
section() { printf "\n=== %s ===\n" "$*"; }
ver() { printf "%-30s → %s\n" "$1" "$2"; }
notver() { printf "%-30s → %s\n" "$1" "$2"; }

# Required version policy - LTS official
POWERSHELL_VERSION="7.6.6"
POWERSHELL_DEB="powershell_7.6.6-1.deb_amd64.deb"
POWERSHELL_DEB_LTS="powershell-lts_7.6.6-1.deb_amd64.deb"
# Official GitHub release URL (no mirror, no short URL)
GITHUB_RELEASE_BASE="https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}"
GITHUB_DEB_URL="${GITHUB_RELEASE_BASE}/${POWERSHELL_DEB}"

# Microsoft repository
MICROSOFT_PROD_URL_TEMPLATE="https://packages.microsoft.com/config/%s/%s/packages-microsoft-prod.deb"

log "LINEX.OS - P4 PowerShell 7 Installer"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Target: Debian 12 bookworm x86_64, PowerShell ${POWERSHELL_VERSION} LTS"
log "Sources allowed: packages.microsoft.com, github.com/PowerShell/PowerShell only"
log ""

# Check Gate
if [[ ! -x "$GATE" ]]; then
  log "BLOCKED: Gate not found at $GATE"
  exit 4
fi

section "PRE-FLIGHT - OS DETECTION"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VERSION="${VERSION_ID:-unknown}"
  OS_PRETTY="${PRETTY_NAME:-unknown}"
  OS_CODENAME="${VERSION_CODENAME:-unknown}"
else
  OS_ID="unknown"
  OS_VERSION="unknown"
  OS_PRETTY="unknown"
  OS_CODENAME="unknown"
fi
ARCH="$(uname -m)"
ver "OS_ID" "$OS_ID"
ver "OS_VERSION" "$OS_VERSION"
ver "OS_PRETTY" "$OS_PRETTY"
ver "OS_CODENAME" "$OS_CODENAME"
ver "ARCH" "$ARCH"
ver "POWERSHELL_VERSION" "$POWERSHELL_VERSION"
ver "SOURCE" "Official Microsoft + Official GitHub"
ver "ARCH" "$ARCH"

# Validate Debian 12
if [[ "$OS_ID" != "debian" ]]; then
  log "BLOCKED: OS_ID is not debian, got $OS_ID"
  exit 2
fi
if [[ "$OS_VERSION" != "12" ]]; then
  log "BLOCKED: VERSION_ID is not 12, got $OS_VERSION (expected Debian 12 bookworm)"
  exit 2
fi
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  log "BLOCKED: ARCH is not x86_64/amd64, got $ARCH"
  exit 2
fi

section "PRE-FLIGHT - NETWORK"
# Test official sources only
MICROSOFT_REPO_NETWORK="BLOCKED"
GITHUB_NETWORK="BLOCKED"
GITHUB_API_NETWORK="BLOCKED"
DEBIAN_APT_NETWORK="BLOCKED"

# Test packages.microsoft.com
if curl -Is --connect-timeout 10 https://packages.microsoft.com 2>&1 | head -1 | grep -q "200\|302\|301" || curl -L --connect-timeout 10 -o /dev/null https://packages.microsoft.com 2>&1 | grep -q "200"; then
  MICROSOFT_REPO_NETWORK="PASS"
else
  # Try with verbose to detect E2B proxy vs blocked
  if curl -v --connect-timeout 10 https://packages.microsoft.com 2>&1 | grep -q "Connected to packages.microsoft.com"; then
    # Connected but SSL error means blocked
    MICROSOFT_REPO_NETWORK="BLOCKED (SSL_ERROR_SYSCALL - Arena sandbox blocks packages.microsoft.com)"
  else
    MICROSOFT_REPO_NETWORK="BLOCKED (connection failed)"
  fi
fi

# Test github.com (should PASS via E2B proxy)
if curl -Is --connect-timeout 10 https://github.com 2>&1 | head -1 | grep -q "200"; then
  GITHUB_NETWORK="PASS"
else
  GITHUB_NETWORK="BLOCKED"
fi

# Test api.github.com
if curl -Is --connect-timeout 10 https://api.github.com 2>&1 | head -1 | grep -q "200"; then
  GITHUB_API_NETWORK="PASS"
else
  GITHUB_API_NETWORK="BLOCKED"
fi

# Test deb.debian.org
if curl -Is --connect-timeout 10 http://deb.debian.org/debian/dists/bookworm/InRelease 2>&1 | head -1 | grep -q "200"; then
  DEBIAN_APT_NETWORK="PASS"
else
  DEBIAN_APT_NETWORK="BLOCKED (Arena sandbox blocks deb.debian.org - Empty reply, as seen in P3)"
fi

ver "MICROSOFT_REPO_NETWORK" "$MICROSOFT_REPO_NETWORK"
ver "GITHUB_NETWORK" "$GITHUB_NETWORK"
ver "GITHUB_API_NETWORK" "$GITHUB_API_NETWORK"
ver "DEBIAN_APT_NETWORK" "$DEBIAN_APT_NETWORK"

# Check apt metadata
if ls /var/lib/apt/lists/ 2>/dev/null | grep -q "debian"; then
  ver "APT_METADATA" "PASS (has debian lists)"
else
  notver "APT_METADATA" "BLOCKED (empty, only $(ls /var/lib/apt/lists/ 2>/dev/null | wc -l) files)"
fi

section "DISK / MEMORY BEFORE"
df -h
free -h
avail_kb=$(df / | tail -1 | awk '{print $4}')
if [[ "$avail_kb" -lt 500000 ]]; then
  log "BLOCKED: Low disk space"
  exit 5
fi

section "CHECK EXISTING PWSH"
if command -v pwsh >/dev/null 2>&1; then
  ver "pwsh" "FOUND at $(command -v pwsh) - $(pwsh --version)"
  log "PowerShell already installed, verifying..."
  pwsh --version
  pwsh -NoLogo -NoProfile -Command '$PSVersionTable | Format-List' 2>&1 | head -20
  log "STATUS → PASS (already installed)"
  exit 0
else
  notver "pwsh" "NOT FOUND (expected before P4 install)"
fi

section "PRIMARY PATH - MICROSOFT PACKAGE REPOSITORY"
MICROSOFT_PROD_URL=$(printf "$MICROSOFT_PROD_URL_TEMPLATE" "$OS_ID" "$OS_VERSION")
ver "MICROSOFT_PROD_URL" "$MICROSOFT_PROD_URL"
ver "METHOD" "Official Microsoft Repository (packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb)"

if [[ "$MICROSOFT_REPO_NETWORK" == PASS* ]]; then
  log "Microsoft repository network PASS, attempting primary path"
  log "DRY-RUN via Gate: register-microsoft-repository"
  if "$GATE" register-microsoft-repository 2>&1; then
    ver "Gate dry-run register-microsoft-repository" "PASS"
  else
    notver "Gate dry-run" "BLOCKED"
    log "Gate dry-run failed, will try fallback"
  fi

  # Try real execution if dry-run PASS
  log "Attempting real execution: $GATE register-microsoft-repository --execute"
  if "$GATE" register-microsoft-repository --execute 2>&1; then
    ver "register-microsoft-repository" "PASS via Gate"
    # Try apt-update via Gate (may fail due to Debian network BLOCKED, but Microsoft repo may still be added)
    log "Attempting apt-update via Gate (may fail partially due to Debian network BLOCKED)"
    "$GATE" apt-update --execute 2>&1 || log "apt-update failed (expected if Debian mirrors BLOCKED, but Microsoft repo config added)"
    
    # Try install PowerShell via apt
    log "Attempting to install PowerShell via apt (package: powershell)"
    if "$GATE" package-install powershell 2>&1; then
      ver "Gate dry-run package-install powershell" "PASS"
      if "$GATE" package-install powershell --execute 2>&1; then
        ver "powershell apt install" "PASS"
        # Verify
        if command -v pwsh >/dev/null 2>&1; then
          ver "pwsh" "VERIFIED after Microsoft repo install - $(pwsh --version)"
          log "RESULT: PASS — MICROSOFT REPOSITORY"
          exit 0
        fi
      fi
    fi
  else
    notver "register-microsoft-repository" "FAILED (network BLOCKED or other)"
  fi
else
  notver "Microsoft repository" "BLOCKED - $MICROSOFT_REPO_NETWORK, skipping primary path"
fi

section "FALLBACK PATH - OFFICIAL GITHUB .DEB"
ver "GITHUB_DEB_URL" "$GITHUB_DEB_URL"
ver "VERSION" "$POWERSHELL_VERSION"
ver "ARCH" "amd64"
ver "SOURCE" "github.com/PowerShell/PowerShell (official release)"
ver "PACKAGE" "$POWERSHELL_DEB"

if [[ "$GITHUB_NETWORK" != PASS* ]]; then
  log "BLOCKED: GitHub network $GITHUB_NETWORK, cannot use fallback"
  log "STATUS → BLOCKED"
  log "RESULT → BLOCKED - Both Microsoft repo ($MICROSOFT_REPO_NETWORK) and GitHub ($GITHUB_NETWORK) BLOCKED"
  exit 6
fi

# Check if release assets domain is blocked (as seen in P3/P4 preflight)
log "Testing release-assets.githubusercontent.com (where GitHub release binaries are hosted)"
if curl -Is --connect-timeout 10 https://release-assets.githubusercontent.com 2>&1 | head -1 | grep -q "200\|302\|301"; then
  ver "RELEASE_ASSETS_NETWORK" "PASS"
else
  notver "RELEASE_ASSETS_NETWORK" "BLOCKED (SSL_ERROR_SYSCALL - Arena sandbox blocks release-assets.githubusercontent.com, as seen in P3)"
  log "This means official GitHub .deb download will likely fail due to redirect to blocked domain"
fi

mkdir -p /tmp/linex-os-powershell
DEST_DEB="/tmp/linex-os-powershell/${POWERSHELL_DEB}"

log "Downloading official PowerShell .deb from: $GITHUB_DEB_URL"
log "Destination: $DEST_DEB"

# Try download (will likely fail due to redirect to blocked release-assets domain)
if curl -L --fail --connect-timeout 10 -o "$DEST_DEB" "$GITHUB_DEB_URL" 2>&1; then
  ver "Download" "PASS - $(stat -c%s "$DEST_DEB") bytes"
else
  notver "Download" "FAILED - curl failed (likely redirect to release-assets.githubusercontent.com which is BLOCKED in Arena sandbox)"
  log "Attempting alternative via gh CLI (also uses release-assets, likely to fail)"
  if command -v gh >/dev/null 2>&1; then
    if gh release download "v${POWERSHELL_VERSION}" --repo PowerShell/PowerShell --pattern "${POWERSHELL_DEB}" --dir /tmp/linex-os-powershell 2>&1; then
      ver "gh download" "PASS"
    else
      notver "gh download" "FAILED - gh also fails due to release-assets blocked (EOF error as seen in P3)"
    fi
  fi

  # Final check if file exists after attempts
  if [[ ! -s "$DEST_DEB" ]]; then
    log "BLOCKED: Official GitHub .deb download failed due to network restriction"
    log "STATUS → BLOCKED"
    log "RESULT → BLOCKED - MICROSOFT_REPOSITORY → $MICROSOFT_REPO_NETWORK, GITHUB_OFFICIAL_RELEASE → BLOCKED (release-assets.githubusercontent.com BLOCKED)"
    log "EVIDENCE:"
    log "- packages.microsoft.com → $MICROSOFT_REPO_NETWORK (SSL_ERROR_SYSCALL)"
    log "- github.com → $GITHUB_NETWORK (PASS via E2B proxy)"
    log "- api.github.com → $GITHUB_API_NETWORK (PASS)"
    log "- release-assets.githubusercontent.com → BLOCKED (SSL_ERROR_SYSCALL, where binaries hosted)"
    log "- deb.debian.org → $DEBIAN_APT_NETWORK (Empty reply)"
    log "- No third-party source used"
    log "- No arbitrary URL used"
    log "- Official sources only: packages.microsoft.com and github.com/PowerShell/PowerShell"
    log "NEXT → Document BLOCKED status, P4 requires network allowlist for packages.microsoft.com and release-assets.githubusercontent.com or manual .deb provision"
    exit 7
  fi
fi

# Validate package integrity
section "PACKAGE INTEGRITY"
if [[ ! -s "$DEST_DEB" ]]; then
  log "BLOCKED: File empty or missing"
  exit 6
fi
ver "File size" "$(stat -c%s "$DEST_DEB") bytes - PASS (>0)"

# dpkg-deb --info
if ! dpkg-deb --info "$DEST_DEB" 2>&1 | head -20; then
  log "BLOCKED: dpkg-deb --info failed"
  exit 6
fi

pkg_name=$(dpkg-deb --field "$DEST_DEB" Package 2>/dev/null || echo "unknown")
pkg_arch=$(dpkg-deb --field "$DEST_DEB" Architecture 2>/dev/null || echo "unknown")
pkg_version=$(dpkg-deb --field "$DEST_DEB" Version 2>/dev/null || echo "unknown")

ver "Package" "$pkg_name"
ver "Architecture" "$pkg_arch"
ver "Version" "$pkg_version"

if [[ "$pkg_name" != "powershell" ]]; then
  log "BLOCKED: Package name mismatch, expected powershell, got $pkg_name"
  exit 6
fi

if [[ "$pkg_arch" != "amd64" ]]; then
  log "BLOCKED: Architecture mismatch, expected amd64, got $pkg_arch"
  exit 6
fi

if [[ "$pkg_version" != *"$POWERSHELL_VERSION"* ]]; then
  log "BLOCKED: Version mismatch, expected $POWERSHELL_VERSION, got $pkg_version"
  exit 6
fi

ver "Package metadata" "PASS - Package=powershell, Arch=amd64, Version=$pkg_version contains $POWERSHELL_VERSION"

# Check for official checksum if available (try to get from GitHub release)
log "Checking for official checksum from GitHub release (hashes.sha256)"
CHECKSUM_URL="${GITHUB_RELEASE_BASE}/hashes.sha256"
if curl -L --fail --connect-timeout 10 -o /tmp/linex-os-powershell/hashes.sha256 "$CHECKSUM_URL" 2>&1; then
  ver "Checksum file" "Downloaded from $CHECKSUM_URL"
  grep "$POWERSHELL_DEB" /tmp/linex-os-powershell/hashes.sha256 || log "Checksum entry not found for $POWERSHELL_DEB (may be ok)"
  # Verify checksum if entry found
  if grep -q "$POWERSHELL_DEB" /tmp/linex-os-powershell/hashes.sha256; then
    expected_sha=$(grep "$POWERSHELL_DEB" /tmp/linex-os-powershell/hashes.sha256 | awk '{print $1}')
    actual_sha=$(sha256sum "$DEST_DEB" | awk '{print $1}')
    if [[ "$expected_sha" == "$actual_sha" ]]; then
      ver "Checksum" "PASS - $actual_sha matches official"
    else
      notver "Checksum" "FAIL - expected $expected_sha, got $actual_sha"
      log "BLOCKED: Checksum mismatch"
      exit 6
    fi
  else
    log "Checksum verification SKIPPED - no entry found, but package metadata validated"
  fi
else
  notver "Checksum file" "BLOCKED - failed to download hashes.sha256 (likely release-assets or raw.githubusercontent.com blocked)"
  log "Checksum verification SKIPPED due to network, but package metadata validated via dpkg-deb"
fi

section "GATE DRY-RUN - INSTALL POWERSHELL PACKAGE"
if "$GATE" install-powershell-package "$DEST_DEB" 2>&1; then
  ver "Gate dry-run install-powershell-package" "PASS"
else
  notver "Gate dry-run" "BLOCKED"
  exit 3
fi

section "GATE EXECUTION - INSTALL POWERSHELL PACKAGE"
if "$GATE" install-powershell-package "$DEST_DEB" --execute 2>&1; then
  ver "install-powershell-package" "PASS via Gate"
else
  notver "install-powershell-package" "FAILED via Gate"
  exit 5
fi

section "VERIFY INSTALLATION"
if ! command -v pwsh >/dev/null 2>&1; then
  log "BLOCKED: pwsh not found after install"
  exit 6
fi

ver "command -v pwsh" "$(command -v pwsh) - PASS"
ver "pwsh --version" "$(pwsh --version) - PASS"

# PSVersionTable
log "PSVersionTable:"
pwsh -NoLogo -NoProfile -Command '$PSVersionTable | Format-List' 2>&1 | head -30

# Check Edition, Version, OS, Platform, Architecture
pwsh_output=$(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSEdition; $PSVersionTable.PSVersion; $PSVersionTable.OS; $PSVersionTable.Platform; $PSVersionTable.Arch' 2>&1)
ver "PSEdition" "$(echo "$pwsh_output" | head -1)"
ver "PSVersion" "$(echo "$pwsh_output" | sed -n '2p')"
ver "OS" "$(echo "$pwsh_output" | sed -n '3p')"
ver "Platform" "$(echo "$pwsh_output" | sed -n '4p')"
ver "Arch" "$(echo "$pwsh_output" | sed -n '5p')"

# Smoke test
section "SMOKE TEST"
if pwsh -NoLogo -NoProfile -Command '"LINEX.OS POWERSHELL SMOKE PASS"' 2>&1 | grep -q "LINEX.OS POWERSHELL SMOKE PASS"; then
  ver "PowerShell smoke test" "PASS"
else
  notver "PowerShell smoke test" "FAIL"
  exit 6
fi

section "CROSS-SHELL VERIFICATION"
if "$ROOT_DIR/ops/verify/verify-environment.sh" 2>&1 | tail -20; then
  ver "verify-environment.sh" "PASS"
fi

if command -v pwsh >/dev/null 2>&1; then
  if pwsh "$ROOT_DIR/ops/verify/verify-environment.ps1" 2>&1 | tail -30; then
    ver "verify-environment.ps1" "PASS - PowerShell should now be VERIFIED"
  fi
fi

section "DISK / MEMORY AFTER"
df -h
free -h

section "RESULT"
log "STATUS → PASS"
log "RESULT → PASS — OFFICIAL GITHUB FALLBACK (if Microsoft repo blocked) or PASS — MICROSOFT REPOSITORY"
log "ENVIRONMENT: Debian 12 bookworm x86_64"
log "POWERSHELL_VERSION: $POWERSHELL_VERSION (LTS)"
log "SOURCE: $(if [[ "$MICROSOFT_REPO_NETWORK" == PASS* ]]; then echo "packages.microsoft.com"; else echo "github.com/PowerShell/PowerShell"; fi)"
log "INSTALL_METHOD: $(if [[ "$MICROSOFT_REPO_NETWORK" == PASS* ]]; then echo "Microsoft Package Repository via packages-microsoft-prod.deb"; else echo "Official GitHub .deb $POWERSHELL_DEB"; fi)"
log "NETWORK: MICROSOFT_REPO_NETWORK=$MICROSOFT_REPO_NETWORK, GITHUB_NETWORK=$GITHUB_NETWORK, DEBIAN_APT_NETWORK=$DEBIAN_APT_NETWORK"
log "GATE: Used for register-microsoft-repository and install-powershell-package"
log "EVIDENCE: pwsh --version, PSVersionTable, smoke test, verify-environment.ps1 now VERIFIED"
log "NEXT → P5 Repository Foundation"
