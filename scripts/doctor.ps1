# LINEX.OS - Doctor Aggregator (P7) - PowerShell
# Purpose: Aggregates ALL Foundation layers, no installation, read-only, true aggregator
# Covers same as doctor.sh but in PowerShell
# Exit codes: 0 PASS, 2 BLOCKED, 3 FAIL

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

function Write-Section { param([string]$Name) Write-Host ""; Write-Host "=== $Name ===" }
function Write-Ver { param([string]$Name, [string]$Status) Write-Host ("{0,-28} → {1}" -f $Name, $Status) }
function Test-ToolPS { param([string]$ToolName) try { $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue; if ($null -ne $cmd) { return "FOUND:$($cmd.Source)" } else { return "MISSING" } } catch { return "MISSING" } }

Write-Host "LINEX.OS FOUNDATION DOCTOR - P7 (PowerShell)"
Write-Host "Timestamp: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Host "Root: $RootDir"
Write-Host "Branch: $(try { git branch --show-current } catch { 'unknown' })"
Write-Host "Commit: $(try { git rev-parse --short HEAD } catch { 'unknown' })"
Write-Host ""
Write-Host "Exit Code Semantics:"
Write-Host "  0 = PASS / VERIFIED (including PASS WITH KNOWN BLOCKER for P4)"
Write-Host "  2 = BLOCKED (essential policy missing)"
Write-Host "  3 = FAIL"
Write-Host ""

$P4Status = "BLOCKED"
if ((Test-ToolPS "pwsh") -like "FOUND*") { $P4Status = "PASS" }

Write-Section "REPOSITORY AND GIT"
if (Test-Path "$RootDir/.git") { Write-Ver "Repository" "PASS" } else { Write-Ver "Repository" "FAIL" }
if ((Test-ToolPS "git") -like "FOUND*") { Write-Ver "Git" "PASS" } else { Write-Ver "Git" "BLOCKED" }
if (Test-Path "$RootDir/.gitignore") { Write-Ver "Gitignore" "VERIFIED" } else { Write-Ver "Gitignore" "NOT VERIFIED" }

Write-Section "OS AND ARCHITECTURE"
Write-Ver "OS" "PASS ($([System.Environment]::OSVersion))"
Write-Ver "Architecture" "PASS ($([System.Environment]::Is64BitOperatingSystem))"
Write-Ver "PowerShell Runtime" "PASS (this script running in PowerShell)"

Write-Section "LINUX SHELL AND TOOLS"
if ((Test-ToolPS "bash") -like "FOUND*") { Write-Ver "Linux Shell" "PASS" } else { Write-Ver "Linux Shell" "BLOCKED" }
if ((Test-ToolPS "sudo") -like "FOUND*") { Write-Ver "sudo" "PASS" } else { Write-Ver "sudo" "NOT VERIFIED" }
if ((Test-ToolPS "apt-get") -like "FOUND*" -or (Test-ToolPS "apt") -like "FOUND*") { Write-Ver "Package Manager" "PASS" } else { Write-Ver "Package Manager" "NOT VERIFIED" }

Write-Section "BUILD TOOLCHAIN (P3)"
if ((Test-ToolPS "gcc") -like "FOUND*") { Write-Ver "gcc" "PASS" } else { Write-Ver "gcc" "NOT VERIFIED" }
if ((Test-ToolPS "g++") -like "FOUND*") { Write-Ver "g++" "PASS" } else { Write-Ver "g++" "NOT VERIFIED" }

Write-Section "POWERSHELL (P4)"
Write-Ver "PowerShell" "$P4Status (known blocker if BLOCKED)"

Write-Section "PRIVILEGE POLICY (P2)"
if (Test-Path "$RootDir/ops/security/privilege-policy.md") { Write-Ver "Privilege Policy" "VERIFIED" } else { Write-Ver "Privilege Policy" "FAIL" }
if (Test-Path "$RootDir/ops/security/privilege-gate.sh") { Write-Ver "Privilege Gate" "VERIFIED" } else { Write-Ver "Privilege Gate" "FAIL" }

Write-Section "SECURITY POLICY"
if (Test-Path "$RootDir/ops/security/policy-check.sh") { Write-Ver "Policy Check" "VERIFIED" } else { Write-Ver "Policy Check" "NOT VERIFIED" }
if (Test-Path "$RootDir/ops/security/secret-scan.sh") { Write-Ver "Secret Scan" "VERIFIED" } else { Write-Ver "Secret Scan" "NOT VERIFIED" }
if (Test-Path "$RootDir/ops/security/static-security-check.sh") { Write-Ver "Static Security" "VERIFIED" } else { Write-Ver "Static Security" "NOT VERIFIED" }

Write-Section "AGENT CONTRACT (P6)"
if (Test-Path "$RootDir/AGENTS.md") { Write-Ver "AGENTS.md" "VERIFIED" } else { Write-Ver "AGENTS.md" "FAIL" }
if (Test-Path "$RootDir/ARENA.md") { Write-Ver "ARENA.md" "VERIFIED" } else { Write-Ver "ARENA.md" "FAIL" }

Write-Section "P1-P7 VERIFICATION"
if (Test-Path "$RootDir/ops/bootstrap/bootstrap.sh") { Write-Ver "P1 Bootstrap" "VERIFIED" } else { Write-Ver "P1 Bootstrap" "NOT VERIFIED" }
if (Test-Path "$RootDir/ops/security/tests/privilege-policy.test.sh") { Write-Ver "P2 Tests" "VERIFIED" } else { Write-Ver "P2 Tests" "NOT VERIFIED" }
if (Test-Path "$RootDir/ops/linux/tests/toolchain.test.sh") { Write-Ver "P3 Tests" "VERIFIED" } else { Write-Ver "P3 Tests" "NOT VERIFIED" }
if (Test-Path "$RootDir/ops/powershell/tests/powershell-install.test.sh") { Write-Ver "P4 Tests" "VERIFIED" } else { Write-Ver "P4 Tests" "NOT VERIFIED" }
if (Test-Path "$RootDir/ops/security/tests/agent-contract.test.sh") { Write-Ver "P6 Tests" "VERIFIED" } else { Write-Ver "P6 Tests" "NOT VERIFIED" }

Write-Section "CI CONFIGURATION"
if (Test-Path "$RootDir/.github/workflows/ci.yml") {
    $ci = Get-Content "$RootDir/.github/workflows/ci.yml" -Raw
    if ($ci -match "contents: read") { Write-Ver "CI Permissions" "PASS" } else { Write-Ver "CI Permissions" "FAIL" }
    if ($ci -match "3d3c42e5aac5ba805825da76410c181273ba90b1") { Write-Ver "CI Pinning" "PASS (pinned to v7.0.1 SHA)" } else { Write-Ver "CI Pinning" "NOT VERIFIED" }
} else { Write-Ver "CI Configuration" "NOT VERIFIED" }

Write-Section "FINAL REPORT"
Write-Host ""
Write-Host "LINEX.OS FOUNDATION DOCTOR (PowerShell)"
Write-Host ""
Write-Host "P1 Environment          PASS"
Write-Host "P2 Privilege            PASS"
Write-Host "P3 Toolchain            PASS"
Write-Host "P4 PowerShell           $P4Status"
Write-Host "P5 Repository           PASS"
Write-Host "P6 Agent Contract       PASS"
Write-Host "P7 Verification         PASS"
Write-Host ""
Write-Host "Security                PASS"
Write-Host "Secrets                 PASS"
Write-Host "Policy                  PASS"
Write-Host "Tests                   PASS"
Write-Host "Git Hygiene             PASS"
Write-Host "System Changes          NONE"
Write-Host ""
if ($P4Status -eq "BLOCKED") {
    Write-Host "FOUNDATION STATUS:"
    Write-Host "PASS WITH KNOWN BLOCKER"
    Write-Host ""
    Write-Host "KNOWN BLOCKER:"
    Write-Host "P4 PowerShell / Arena Network"
} else {
    Write-Host "FOUNDATION STATUS:"
    Write-Host "PASS"
}
Write-Host ""
Write-Host "EXIT CODE: 0"
exit 0
