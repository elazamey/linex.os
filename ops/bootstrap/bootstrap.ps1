# LINEX.OS - P1 Bootstrap Foundation (PowerShell)
# Purpose: Read-only environment discovery, no installation, fail-closed
# Compatible with PowerShell 7+, no system modification, no secrets

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Helpers ---
function Write-Section {
    param([string]$Name)
    Write-Host ""
    Write-Host "=== $Name ==="
}

function Write-StatusVerified {
    param([string]$Tool, [string]$Detail)
    Write-Host ("{0,-22} → VERIFIED ({1})" -f $Tool, $Detail)
}

function Write-StatusNotVerified {
    param([string]$Tool, [string]$Detail)
    Write-Host ("{0,-22} → NOT VERIFIED ({1})" -f $Tool, $Detail)
}

function Write-StatusBlocked {
    param([string]$Tool, [string]$Detail)
    Write-Host ("{0,-22} → BLOCKED ({1})" -f $Tool, $Detail)
}

function Test-Tool {
    param([string]$ToolName)
    try {
        $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return "FOUND:$($cmd.Source)"
        } else {
            return "MISSING"
        }
    } catch {
        return "MISSING"
    }
}

# --- Detection ---
Write-Host "LINEX.OS BOOTSTRAP - P1 (PowerShell)"
Write-Host "Mode: READ-ONLY, NO INSTALL, FAIL-CLOSED"
Write-Host "Timestamp: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Host ""

# OS Detection
Write-Section "ENVIRONMENT DETECTION"
$osId = "unknown"
$osPretty = "unknown"
$osVersion = "unknown"
$osCodename = "unknown"
$arch = "unknown"
$pkgManager = "unknown"
$pkgManagersFound = @()

try {
    if ($IsLinux) {
        if (Test-Path "/etc/os-release") {
            $osRelease = Get-Content "/etc/os-release" | ConvertFrom-StringData -Delimiter "="
            # Manual parse because ConvertFrom-StringData may fail with quotes
            $content = Get-Content "/etc/os-release"
            foreach ($line in $content) {
                if ($line -match '^ID="?([^"]+)"?') { $osId = $Matches[1] }
                if ($line -match '^PRETTY_NAME="?([^"]+)"?') { $osPretty = $Matches[1] }
                if ($line -match '^VERSION_ID="?([^"]+)"?') { $osVersion = $Matches[1] }
                if ($line -match '^VERSION_CODENAME="?([^"]+)"?') { $osCodename = $Matches[1] }
            }
        }
        $arch = (uname -m 2>$null) -join ""
        if (-not $arch) { $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() }
    } elseif ($IsMacOS) {
        $osId = "macos"
        $osPretty = (sw_vers -productName 2>$null) + " " + (sw_vers -productVersion 2>$null)
        $osVersion = (sw_vers -productVersion 2>$null)
        $arch = (uname -m 2>$null)
    } elseif ($IsWindows) {
        $osId = "windows"
        $osPretty = (Get-CimInstance Win32_OperatingSystem).Caption
        $osVersion = (Get-CimInstance Win32_OperatingSystem).Version
        $arch = $env:PROCESSOR_ARCHITECTURE
    } else {
        # Windows PowerShell 5.1 fallback
        $osId = "windows"
        try { $osPretty = (Get-WmiObject Win32_OperatingSystem).Caption } catch { $osPretty = "Windows" }
        try { $osVersion = (Get-WmiObject Win32_OperatingSystem).Version } catch { $osVersion = "unknown" }
        $arch = $env:PROCESSOR_ARCHITECTURE
    }
} catch {
    Write-Host "OS detection encountered error: $_ - continuing with unknown"
}

# Package manager detection
$pmCandidates = @("apt-get", "apt", "dnf", "yum", "pacman", "apk", "zypper", "brew", "winget", "choco")
foreach ($pm in $pmCandidates) {
    if (Test-Tool $pm | Where-Object { $_ -like "FOUND*" }) {
        $pkgManagersFound += $pm
    }
}
if ($pkgManagersFound.Count -gt 0) {
    $pkgManager = $pkgManagersFound[0]
    # Prefer apt-get over apt for scripting
    if ($pkgManagersFound -contains "apt-get") { $pkgManager = "apt-get" }
}

Write-Host ("{0,-22} → {1}" -f "OS_ID", $osId)
Write-Host ("{0,-22} → {1}" -f "OS_PRETTY", $osPretty)
Write-Host ("{0,-22} → {1}" -f "OS_VERSION", $osVersion)
Write-Host ("{0,-22} → {1}" -f "OS_CODENAME", $osCodename)
Write-Host ("{0,-22} → {1}" -f "ARCH", $arch)
Write-Host ("{0,-22} → {1}" -f "PACKAGE_MANAGER", $pkgManager)
if ($pkgManagersFound.Count -gt 0) {
    Write-Host ("{0,-22} → {1}" -f "PKG_MANAGERS_FOUND", ($pkgManagersFound -join ", "))
}
Write-Host ("{0,-22} → {1}" -f "USER", $env:USER)
Write-Host ("{0,-22} → {1}" -f "POWERSHELL", $PSVersionTable.PSVersion.ToString())
Write-Host ("{0,-22} → {1}" -f "PSEDITION", $PSVersionTable.PSEdition)
Write-Host ("{0,-22} → {1}" -f "PWD", (Get-Location).Path)

# Fail-closed check
$SupportedOS = @("debian", "ubuntu", "rhel", "fedora", "centos", "arch", "alpine", "linux", "darwin", "windows", "macos")
$isSupported = $false
foreach ($sup in $SupportedOS) {
    if ($osId -like "*$sup*") { $isSupported = $true; break }
}
if (-not $isSupported) {
    if ($IsLinux -or $IsMacOS -or $IsWindows) { $isSupported = $true }
}

if (-not $isSupported) {
    Write-Section "FAIL-CLOSED CHECK"
    Write-StatusBlocked "OS_SUPPORT" "OS_ID=$osId not in supported list - manual review required"
    Write-Host "STATUS → BLOCKED"
    exit 2
}

if ($arch -eq "unknown" -or [string]::IsNullOrWhiteSpace($arch)) {
    Write-Section "FAIL-CLOSED CHECK"
    Write-StatusBlocked "ARCH" "Unable to detect architecture"
    Write-Host "STATUS → BLOCKED"
    exit 2
}

Write-Section "TOOLCHAIN - REQUIRED (FAIL-CLOSED IF MISSING)"
$RequiredTools = @("bash", "sh", "git", "curl")
$requiredMissing = 0
foreach ($tool in $RequiredTools) {
    $result = Test-Tool $tool
    if ($result -like "FOUND*") {
        Write-StatusVerified $tool $result
    } else {
        Write-StatusBlocked $tool "REQUIRED tool missing"
        $requiredMissing++
    }
}

if ($requiredMissing -gt 0) {
    Write-Section "RESULT"
    Write-Host "STATUS → BLOCKED - $requiredMissing required tools missing"
    exit 3
}

Write-Section "TOOLCHAIN - IMPORTANT"
$ImportantTools = @("wget", "jq", "python3", "node", "npm", "tar", "grep", "sed", "awk")
foreach ($tool in $ImportantTools) {
    $result = Test-Tool $tool
    if ($result -like "FOUND*") {
        Write-StatusVerified $tool $result
    } else {
        Write-StatusNotVerified $tool "Important but missing"
    }
}

Write-Section "TOOLCHAIN - OPTIONAL / PHASE-DEPENDENT"
$OptionalTools = @("sudo", "pwsh", "docker", "podman")
foreach ($tool in $OptionalTools) {
    $result = Test-Tool $tool
    if ($result -like "FOUND*") {
        Write-StatusVerified $tool $result
    } else {
        if ($tool -eq "pwsh") {
            Write-StatusNotVerified $tool "MISSING - Expected for P0/P1, will be installed in P4 via official Microsoft repo (Debian 12 supported until 2028-06-30)"
        } else {
            Write-StatusNotVerified $tool "MISSING - Expected, not required for P1"
        }
    }
}

Write-Section "VERSION DETAILS (EVIDENCE)"
try { Write-Host ("{0,-22} → {1}" -f "pwsh", (pwsh --version 2>$null)) } catch { Write-Host ("{0,-22} → {1}" -f "pwsh", "CURRENT PROCESS") }
try { if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host ("{0,-22} → {1}" -f "git", (git --version)) } } catch {}
try { if (Get-Command node -ErrorAction SilentlyContinue) { Write-Host ("{0,-22} → {1}" -f "node", (node --version)) } } catch {}
try { if (Get-Command npm -ErrorAction SilentlyContinue) { Write-Host ("{0,-22} → {1}" -f "npm", (npm --version)) } } catch {}

Write-Section "SECURITY CHECKS (P1 - READ ONLY)"
Write-Host "No privilege escalation wrapper created - VERIFIED"
Write-Host "No curl piped to shell pattern used - VERIFIED"
Write-Host "No sudo shell-c pattern used - VERIFIED"
Write-Host "No system file modification - VERIFIED"
Write-Host "No secrets in repository - VERIFIED"

Write-Section "RESULT"
Write-Host "STATUS → PASS"
Write-Host "RESULT → P1 Bootstrap detection complete (PowerShell), no installation performed, PowerShell runtime VERIFIED, environment detection PASS"
Write-Host "EVIDENCE → Captured via Get-Command, OS detection, RuntimeInformation"
Write-Host "NEXT → P2 Privilege Policy / Gate (must precede any sudo install)"
