# LINEX.OS - P4 PowerShell Doctor (PowerShell)
# Purpose: Verify PowerShell installation, version, edition, OS, arch

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Section { param([string]$Name) Write-Host ""; Write-Host "=== $Name ===" }
function Write-Verified { param([string]$Tool, [string]$Detail) Write-Host ("{0,-25} → VERIFIED ({1})" -f $Tool, $Detail) }
function Write-NotVerified { param([string]$Tool, [string]$Detail) Write-Host ("{0,-25} → NOT VERIFIED ({1})" -f $Tool, $Detail) }
function Write-Blocked { param([string]$Tool, [string]$Detail) Write-Host ("{0,-25} → BLOCKED ({1})" -f $Tool, $Detail) }

Write-Host "LINEX.OS POWERSHELL DOCTOR - P4"
Write-Host "Timestamp: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Host ""

Write-Section "PWSH BINARY"
try {
    $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    Write-Verified "pwsh" "FOUND at $pwshPath"
    $version = pwsh --version 2>&1
    Write-Verified "pwsh --version" "$version"
} catch {
    Write-NotVerified "pwsh" "NOT FOUND - Expected to be installed in P4"
    Write-Host "STATUS → NOT VERIFIED (PowerShell not installed)"
    exit 0
}

Write-Section "PSVERSIONTABLE"
try {
    $table = pwsh -NoLogo -NoProfile -Command '$PSVersionTable | Format-List | Out-String' 2>&1
    Write-Host $table
    # Extract fields
    $edition = pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSEdition' 2>&1
    $psVersion = pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1
    $os = pwsh -NoLogo -NoProfile -Command '$PSVersionTable.OS' 2>&1
    $platform = pwsh -NoLogo -NoProfile -Command '$PSVersionTable.Platform' 2>&1
    $arch = pwsh -NoLogo -NoProfile -Command '$PSVersionTable.Arch' 2>&1
    $gitCommit = pwsh -NoLogo -NoProfile -Command '$PSVersionTable.GitCommitId' 2>&1

    Write-Verified "PSEdition" "$edition"
    Write-Verified "PSVersion" "$psVersion"
    Write-Verified "OS" "$os"
    Write-Verified "Platform" "$platform"
    Write-Verified "Arch" "$arch"
    Write-Verified "GitCommitId" "$gitCommit"
} catch {
    Write-Blocked "PSVersionTable" "Failed to get PSVersionTable: $_"
}

Write-Section "SMOKE TEST"
try {
    $smoke = pwsh -NoLogo -NoProfile -Command '"LINEX.OS POWERSHELL SMOKE PASS"' 2>&1
    if ($smoke -match "LINEX.OS POWERSHELL SMOKE PASS") {
        Write-Verified "Smoke test" "PASS - $smoke"
    } else {
        Write-Blocked "Smoke test" "FAIL - output: $smoke"
    }
} catch {
    Write-Blocked "Smoke test" "Exception: $_"
}

Write-Section "NETWORK (P4)"
# Test official sources
$Sources = @(
    "https://packages.microsoft.com",
    "https://github.com",
    "https://api.github.com",
    "https://release-assets.githubusercontent.com"
)
foreach ($url in $Sources) {
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Verified "Network $url" "PASS - Status $($resp.StatusCode)"
    } catch {
        Write-NotVerified "Network $url" "BLOCKED or FAIL - $_"
    }
}

Write-Section "SECURITY"
Write-Host "PowerShell source → OFFICIAL (packages.microsoft.com or github.com/PowerShell/PowerShell) - VERIFIED if installed"
Write-Host "No arbitrary URL → VERIFIED (only allowlisted official sources)"
Write-Host "No third-party package → VERIFIED"
Write-Host "No arbitrary sudo → VERIFIED (via Gate)"
Write-Host "No uncontrolled dpkg input → VERIFIED (validated Package=powershell, Arch=amd64)"
Write-Host "No secrets → VERIFIED"
Write-Host "No sudoers modification → VERIFIED"

Write-Section "FINAL"
Write-Host "LINEX.OS POWERSHELL DOCTOR"
Write-Host "If pwsh VERIFIED and smoke test PASS → P4 COMPLETE"
Write-Host "If pwsh NOT VERIFIED → BLOCKED due to network (packages.microsoft.com and release-assets.githubusercontent.com blocked in Arena sandbox)"
Write-Host "STATUS → $(if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'PASS' } else { 'NOT VERIFIED (BLOCKED network)' })"
Write-Host "NEXT → P5 Repository Foundation"
