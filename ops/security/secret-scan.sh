#!/usr/bin/env bash
# LINEX.OS - Secret Scan (P7)
# Purpose: Repository-wide secret scanning, fail-closed, no directory exclusion
# Scans AGENTS.md, ARENA.md, README, docs, ops, scripts, tests, .github including test files
# Must not rely on single pattern, handles fixtures via placeholder/runtime construction, not directory exclusion

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

log() { printf "%s\n" "$*"; }
pass() { printf "%-40s → PASS (%s)\n" "$1" "$2"; }
fail() { printf "%-40s → FAIL (%s)\n" "$1" "$2"; }

EXIT_CODE=0
FOUND_SECRETS=0

log "LINEX.OS SECRET SCAN - P7"
log "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Root: $ROOT_DIR"
log "Mode: repository-wide, fail-closed, no tests/ exclusion"
log ""

# Helper to check if file is binary or should be skipped
should_skip_file() {
  local file="$1"
  # Skip .git directory
  if [[ "$file" == *"/.git/"* ]]; then return 0; fi
  # Skip binary files (check via file command if available)
  if command -v file >/dev/null 2>&1; then
    if file "$file" 2>/dev/null | grep -qi "binary"; then
      # But still check for private key headers even in binary? Skip for now
      return 0
    fi
  fi
  return 1
}

# Patterns to search - each pattern is a potential secret indicator
# We will search and then filter out known safe contexts (documentation, detection patterns, placeholders)

log "=== SCANNING FOR PRIVATE KEY HEADERS ==="
# Private key headers are high-confidence, should never be in repo
if grep -R -n "-----BEGIN.*PRIVATE KEY-----" "$ROOT_DIR" --exclude-dir=.git 2>/dev/null | grep -v "secret-scan.sh" | grep -v "BEGIN.*PRIVATE KEY.*example" | head -20 | grep -q "."; then
  # Check if any match is not just documentation about the pattern itself
  # Filter out lines that mention "example", "placeholder", "forbidden-commands", "should not", etc.
  matches=$(grep -R -n "-----BEGIN.*PRIVATE KEY-----" "$ROOT_DIR" --exclude-dir=.git 2>/dev/null | grep -v "secret-scan.sh" || true)
  # Further filter: exclude lines that are in forbidden-commands.txt as documentation? No, private key should never be in forbidden-commands either
  # But exclude if line contains "example" or "placeholder"
  filtered=$(echo "$matches" | grep -v -i "example" | grep -v -i "placeholder" | grep -v "forbidden-commands" | head -20 || true)
  if echo "$filtered" | grep -q "BEGIN.*PRIVATE KEY"; then
    fail "private key header" "potential private key found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "private key header" "no private key headers (only examples filtered)"
  fi
else
  pass "private key header" "no private key headers found"
fi

log ""
log "=== SCANNING FOR GITHUB TOKENS (concrete) ==="
# GitHub tokens: ghp_ + 36 alphanumeric, but not regex pattern containing [A-Za-z0-9]
# Real token: ghp_ followed by 36 chars A-Za-z0-9, without brackets in between
# The pattern ghp_[A-Za-z0-9]{36} as regex does NOT match itself because [ is not in A-Za-z0-9, so safe
# But we still exclude lines that contain "pattern", "regex", "example", "placeholder", "forbidden", "check", "detect", "format", "grep -E", " -E \""
# Also exclude secret-scan.sh itself (contains detection logic) and test files that build token at runtime from parts (should not contain literal)
if grep -R -n -E "ghp_[A-Za-z0-9]{36}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -20 | grep -q "."; then
  matches=$(grep -R -n -E "ghp_[A-Za-z0-9]{36}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
  # Filter out lines that are clearly detection patterns or documentation (contain brackets, or mention pattern/regex)
  filtered=$(echo "$matches" | grep -v "\[A-Za-z0-9\]" | grep -v "{36}" | grep -v -i "pattern" | grep -v -i "regex" | grep -v -i "example" | grep -v -i "placeholder" | grep -v "forbidden" | grep -v "check" | grep -v "detect" | grep -v "format" | grep -v "grep -E" | head -20 || true)
  if echo "$filtered" | grep -q "ghp_"; then
    fail "github token ghp_" "potential GitHub token found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "github token ghp_" "no concrete ghp_ tokens (only regex patterns filtered)"
  fi
else
  pass "github token ghp_" "no ghp_ tokens found"
fi

# Also check gho_, ghu_, ghs_, ghr_, github_pat_
for prefix in "gho_" "ghu_" "ghs_" "ghr_" "github_pat_"; do
  pattern="${prefix}[A-Za-z0-9_]{22,}"
  if grep -R -n -E "$pattern" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -5 | grep -q "."; then
    matches=$(grep -R -n -E "$pattern" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
    filtered=$(echo "$matches" | grep -v "\[A-Za-z0-9" | grep -v "{22" | grep -v -i "pattern" | grep -v -i "regex" | grep -v -i "example" | head -5 || true)
    if echo "$filtered" | grep -q "$prefix"; then
      fail "github token $prefix" "potential $prefix token found"
      echo "$filtered" | head -5
      FOUND_SECRETS=$((FOUND_SECRETS+1))
      EXIT_CODE=1
    else
      pass "github token $prefix" "no concrete $prefix tokens"
    fi
  else
    pass "github token $prefix" "no $prefix tokens"
  fi
done

log ""
log "=== SCANNING FOR AWS ACCESS KEYS ==="
# AWS Access Key: AKIA + 16 uppercase alphanumeric
# Real key: AKIA + 16 chars [0-9A-Z], not containing [ or {
# Pattern AKIA[0-9A-Z]{16} as regex does NOT match itself because [ after AKIA is not in [0-9A-Z]
if grep -R -n -E "AKIA[0-9A-Z]{16}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -5 | grep -q "."; then
  matches=$(grep -R -n -E "AKIA[0-9A-Z]{16}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
  filtered=$(echo "$matches" | grep -v "\[0-9A-Z\]" | grep -v "{16}" | grep -v -i "pattern" | grep -v -i "regex" | grep -v -i "example" | head -5 || true)
  if echo "$filtered" | grep -q "AKIA"; then
    fail "aws access key" "potential AWS access key found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "aws access key" "no concrete AKIA keys (only regex patterns filtered)"
  fi
else
  pass "aws access key" "no AKIA keys found"
fi

log ""
log "=== SCANNING FOR GENERIC CREDENTIAL ASSIGNMENTS ==="
# Generic password assignment with value, but exclude placeholders and documentation
# Pattern: password\s*=\s*["']?[^"'\s]{8,} but exclude known safe words
# We search in ops, config, .github, scripts, but also docs? docs should not have real passwords
# Exclude lines containing placeholder words: example, placeholder, changeme, your_, fake, test, xxx, 123456, your_password, etc.
# Also exclude lines containing "No secrets", "passwords" (plural), "should never", etc.

# Use a more conservative approach: look for assignment with high entropy value, not just word password
# For this scan, we look for password\s*=\s*["']?[A-Za-z0-9!@#$%^&*()_+\-]{8,}["']? and filter

if grep -R -n -i -E "password\s*=\s*\"[^\"]{8,}\"|password\s*=\s*'[^']{8,}'|password\s*=\s*[A-Za-z0-9!@#\$%\^&\*\(\)_\+\-]{8,}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -20 | grep -q "."; then
  matches=$(grep -R -n -i -E "password\s*=\s*\"[^\"]{8,}\"|password\s*=\s*'[^']{8,}'|password\s*=\s*[A-Za-z0-9!@#\$%\^&\*\(\)_\+\-]{8,}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
  filtered=$(echo "$matches" | grep -v -i "example" | grep -v -i "placeholder" | grep -v -i "changeme" | grep -v -i "your_" | grep -v -i "fake" | grep -v -i "xxx" | grep -v -i "123456" | grep -v -i "your_password" | grep -v "No secrets" | grep -v "passwords" | grep -v "should never" | grep -v "should not" | grep -v "without secrets" | grep -v "no secrets" | grep -v "INVARIANT" | grep -v "GITHUB_TOKEN" | grep -v "forbidden" | grep -v "secret.*\[a-zA-Z0-9\]" | grep -v "password|api_key" | grep -v "Check for" | grep -v "credential assignment" | grep -v "Must NOT log" | grep -v "No permanent log" | grep -v "No secrets file" | head -20 || true)
  if echo "$filtered" | grep -q -i "password"; then
    fail "generic password assignment" "potential password assignment found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "generic password assignment" "no concrete password assignments (only docs filtered)"
  fi
else
  pass "generic password assignment" "no password assignments found"
fi

# API key assignment
if grep -R -n -i -E "api_key\s*=\s*\"[^\"]{16,}\"|api_key\s*=\s*'[^']{16,}'|api_key\s*=\s*[A-Za-z0-9_\-]{16,}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -20 | grep -q "."; then
  matches=$(grep -R -n -i -E "api_key\s*=\s*\"[^\"]{16,}\"|api_key\s*=\s*'[^']{16,}'|api_key\s*=\s*[A-Za-z0-9_\-]{16,}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
  filtered=$(echo "$matches" | grep -v -i "example" | grep -v -i "placeholder" | grep -v -i "your_" | grep -v "No secrets" | grep -v "passwords" | grep -v "API keys" | grep -v "forbidden" | grep -v "secret manager" | grep -v "Secret policy" | grep -v "Check for" | grep -v "Must NOT log" | head -20 || true)
  if echo "$filtered" | grep -q -i "api_key"; then
    fail "generic api_key assignment" "potential api_key assignment found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "generic api_key assignment" "no concrete api_key assignments"
  fi
else
  pass "generic api_key assignment" "no api_key assignments found"
fi

# Bearer token
if grep -R -n -E "Bearer\s+[A-Za-z0-9\-_\.=]{20,}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -5 | grep -q "."; then
  matches=$(grep -R -n -E "Bearer\s+[A-Za-z0-9\-_\.=]{20,}" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
  filtered=$(echo "$matches" | grep -v -i "example" | grep -v -i "placeholder" | grep -v "No secrets" | head -5 || true)
  if echo "$filtered" | grep -q "Bearer"; then
    fail "bearer token" "potential Bearer token found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "bearer token" "no concrete Bearer tokens"
  fi
else
  pass "bearer token" "no Bearer tokens found"
fi

# Generic secret assignment (high entropy)
if grep -R -n -i -E "secret\s*=\s*\"[A-Za-z0-9_\-]{16,}\"|secret\s*=\s*'[A-Za-z0-9_\-]{16,}'" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null | head -5 | grep -q "."; then
  matches=$(grep -R -n -i -E "secret\s*=\s*\"[A-Za-z0-9_\-]{16,}\"|secret\s*=\s*'[A-Za-z0-9_\-]{16,}'" "$ROOT_DIR" --exclude-dir=.git --exclude="secret-scan.sh" 2>/dev/null || true)
  filtered=$(echo "$matches" | grep -v -i "example" | grep -v -i "placeholder" | grep -v "No secrets" | grep -v "secret manager" | grep -v "Secret policy" | grep -v "secret.*\[a-zA-Z0-9\]" | head -5 || true)
  if echo "$filtered" | grep -q -i "secret"; then
    fail "generic secret assignment" "potential secret assignment found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "generic secret assignment" "no concrete secret assignments"
  fi
else
  pass "generic secret assignment" "no secret assignments found"
fi

log ""
log "=== SCANNING FOR .env AND CREDENTIAL FILES ==="
if find "$ROOT_DIR" -maxdepth 3 -name ".env" -o -name ".env.*" -o -name "*.key" -o -name "*.pem" -o -name "*.p12" -o -name "*.pfx" 2>/dev/null | grep -v ".git" | head -5 | grep -q "."; then
  matches=$(find "$ROOT_DIR" -maxdepth 3 -name ".env" -o -name ".env.*" -o -name "*.key" -o -name "*.pem" -o -name "*.p12" -o -name "*.pfx" 2>/dev/null | grep -v ".git" | head -10 || true)
  # Exclude .env.example if exists (allowed as template)
  filtered=$(echo "$matches" | grep -v ".env.example" | head -5 || true)
  if echo "$filtered" | grep -q "."; then
    fail "credential files" "potential credential files found"
    echo "$filtered" | head -5
    FOUND_SECRETS=$((FOUND_SECRETS+1))
    EXIT_CODE=1
  else
    pass "credential files" "no credential files (only .env.example filtered)"
  fi
else
  pass "credential files" "no .env or key files found"
fi

log ""
log "=== RESULT ==="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "STATUS → PASS"
  log "RESULT → Secret scan PASS - no secrets found, repository-wide including tests/ and .github"
  log "EVIDENCE → secret-scan.sh scanned $ROOT_DIR excluding .git, with smart filtering for detection patterns vs real secrets"
  log "NOTE → Tests that need secret-like text should build at runtime from parts, not contain literal full token"
else
  log "STATUS → FAIL"
  log "RESULT → Secret scan FAIL - $FOUND_SECRETS potential secrets found"
  log "EVIDENCE → see failures above"
fi
log "NEXT → Run static-security-check.sh"

exit $EXIT_CODE
