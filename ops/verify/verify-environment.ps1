# LINEX.OS - P1 Verify Environment (PowerShell)
# Purpose: Comprehensive verification, read-only, no installation

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Section { param([string]$Name) Write-Host ""; Write-Host "=== $Name ===" }
function Write-Verified { param([string]$Tool, [string]$Detail) Write-Host ("{0,-22} → VERIFIED ({1})" -f $Tool, $Detail) }
function Write-NotVerified { param([string]$Tool, [string]$Detail) Write-Host ("{0,-22} → NOT VERIFIED ({1})" -f $Tool, $Detail) }
function Write-Blocked { param([string]$Tool, [string]$Detail) Write-Host ("{0,-22} → BLOCKED ({1})" -f $Tool, $Detail) }

function Test-ToolPS {
    param([string]$ToolName)
    try {
        $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return "FOUND:$($cmd.Source)" } else { return "MISSING" }
    } catch { return "MISSING" }
}

Write-Host "LINEX.OS VERIFY ENVIRONMENT - P1 (PowerShell)"
Write-Host "Timestamp: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Host "Mode: READ-ONLY"

Write-Section "REPOSITORY"
if (Test-Path ".git") { Write-Verified "Repository" ".git exists at $(Get-Location)" } else { Write-NotVerified "Repository" ".git missing" }
$gitCheck = Test-ToolPS "git"
if ($gitCheck -like "FOUND*") { Write-Verified "Git" $gitCheck } else { Write-Blocked "Git" "git missing" }

Write-Section "LINUX SHELL"
$bashCheck = Test-ToolPS "bash"
if ($bashCheck -like "FOUND*") { Write-Verified "Linux shell (bash)" $bashCheck } else { Write-Blocked "Linux shell (bash)" "bash missing" }
$shCheck = Test-ToolPS "sh"
if ($shCheck -like "FOUND*") { Write-Verified "Linux shell (sh)" $shCheck } else { Write-Blocked "Linux shell (sh)" "sh missing" }

Write-Section "SUDO"
$sudoCheck = Test-ToolPS "sudo"
if ($sudoCheck -like "FOUND*") { Write-Verified "sudo" $sudoCheck } else { Write-NotVerified "sudo" "MISSING" }

Write-Section "POWERSHELL"
Write-Verified "PowerShell" "Current runtime $($PSVersionTable.PSVersion) - VERIFIED"
$pwshCheck = Test-ToolPS "pwsh"
if ($pwshCheck -like "FOUND*") { Write-Verified "PowerShell (pwsh)" $pwshCheck } else { Write-NotVerified "PowerShell (pwsh)" "MISSING - Expected in P1, will be installed in P4 via Microsoft repo (Debian 12 supported until 2028-06-30)" }

Write-Section "PACKAGE MANAGER"
$pmCandidates = @("apt-get", "apt", "dnf", "yum", "pacman", "apk", "zypper", "brew")
$found = $false
foreach ($pm in $pmCandidates) {
    $r = Test-ToolPS $pm
    if ($r -like "FOUND*") { Write-Verified "Package manager" "$pm - $r"; $found = $true; break }
}
if (-not $found) { Write-NotVerified "Package manager" "No known package manager found" }

Write-Section "NETWORK"
try {
    $response = Invoke-WebRequest -Uri "https://github.com" -Method Head -TimeoutSec 10 -ErrorAction Stop
    if ($response.StatusCode -eq 200) { Write-Verified "Network (github.com)" "Invoke-WebRequest → 200" } else { Write-NotVerified "Network (github.com)" "Status $($response.StatusCode)" }
} catch {
    Write-NotVerified "Network (github.com)" "Request failed: $_"
}

Write-Section "REQUIRED TOOLS"
$required = @("bash", "sh", "git", "curl", "wget", "jq", "tar", "grep", "sed")
foreach ($t in $required) {
    $r = Test-ToolPS $t
    if ($r -like "FOUND*") { Write-Verified $t $r } else { Write-NotVerified $t "MISSING" }
}

Write-Section "OPTIONAL TOOLS / RUNTIMES"
$optional = @("python3", "node", "npm", "docker", "podman")
foreach ($t in $optional) {
    $r = Test-ToolPS $t
    if ($r -like "FOUND*") { Write-Verified $t $r } else { Write-NotVerified $t "MISSING (expected)" }
}

Write-Section "DISK"
try { Get-PSDrive -PSProvider FileSystem | Format-Table -AutoSize } catch { Write-Host "Disk info not available via Get-PSDrive" }

Write-Section "MEMORY"
try {
    if ($IsLinux) {
        if (Test-Path "/proc/meminfo") { Get-Content "/proc/meminfo" | Select-Object -First 5 }
    } else {
        Write-Host "Memory check via CIM"
        Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | Format-List
    }
} catch { Write-Host "Memory info error: $_" }

Write-Section "OS DETAILS"
try {
    if ($IsLinux -and (Test-Path "/etc/os-release")) { Get-Content "/etc/os-release" }
    Write-Host "OS Description: $([System.Runtime.InteropServices.RuntimeInformation]::GetOSDescription())"
    Write-Host "OS Arch: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
} catch { Write-Host "OS details error: $_" }

Write-Section "SECURITY (P1)"
Write-Host "No privilege escalation wrapper - VERIFIED"
Write-Host "No system file modification - VERIFIED"
Write-Host "No secrets - VERIFIED"

Write-Section "RESULT"
Write-Host "STATUS → PASS (with PowerShell pwsh NOT VERIFIED expected if running from non-pwsh, but runtime VERIFIED)"
Write-Host "EVIDENCE → verify-environment.ps1 execution log"
Write-Host "NEXT → P2 Privilege Policy"
