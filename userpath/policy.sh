#!/usr/bin/env bash
# LINEX.OS - Slice 0 policy layer (decision engine subset).
#
# Scope: the decision vocabulary of docs/contracts/policy.md (ALLOW / DENY /
# REQUIRE_APPROVAL) applied to ONE narrow user path. DEFAULT DENY, fail-closed.
# This file NEVER executes anything and never touches the filesystem for writes.
#
# Explicitly NOT: the P11 policy engine, a technology choice (see ADR 0012), or
# a replacement for ops/security/privilege-gate.sh (which governs privileged
# package/service actions and stays the only channel for those).
#
# Contract used:
#   slice_policy_decide <action> <resource> <workspace> [dry_run]
#   -> sets POLICY_DECISION (ALLOW|DENY|REQUIRE_APPROVAL),
#           POLICY_REASON  (human-readable, evidence-safe, no secrets),
#           POLICY_CAPABILITY (CAP_* name from docs/contracts/capability.md)

# Decision constants
POLICY_DECISION="DENY"
POLICY_REASON="policy engine not invoked (fail-closed default)"
POLICY_CAPABILITY="NONE"

# Workspace containment check. Denies absolute paths, traversal, .git internals,
# symlink escapes, non-regular files and oversized files.
slice_validate_workspace_path() {
  local rel="$1" workspace="$2"
  local root resolved size

  if [[ -z "$rel" ]]; then
    POLICY_REASON="empty resource path"
    return 1
  fi
  if [[ "$rel" == /* ]]; then
    POLICY_REASON="absolute paths are out of scope: workspace-relative resources only"
    return 1
  fi
  if [[ "$rel" == *".."* ]]; then
    POLICY_REASON="path traversal ('..') denied"
    return 1
  fi
  if [[ "$rel" == ".git" || "$rel" == ".git/"* || "$rel" == "./.git" || "$rel" == "./.git/"* ]]; then
    POLICY_REASON=".git internals are not a user-facing resource"
    return 1
  fi

  if ! root="$(cd -- "$workspace" 2>/dev/null && pwd -P)"; then
    POLICY_REASON="workspace does not exist or is not a directory"
    return 1
  fi

  # readlink -f resolves symlinks; the prefix test below is therefore a real
  # containment test, not a string test.
  if ! resolved="$(readlink -f -- "$root/$rel" 2>/dev/null)"; then
    POLICY_REASON="resource path cannot be resolved"
    return 1
  fi

  case "$resolved" in
    "$root"/*) : ;;
    *)
      POLICY_REASON="resolved path escapes the workspace (symlink or traversal)"
      return 1
      ;;
  esac

  if [[ ! -f "$resolved" ]]; then
    POLICY_REASON="resource is not a regular file"
    return 1
  fi

  size="$(stat -c %s -- "$resolved" 2>/dev/null || echo 0)"
  if [[ ! "$size" =~ ^[0-9]+$ ]]; then
    POLICY_REASON="resource size is not measurable"
    return 1
  fi
  if [[ "$size" -gt 65536 ]]; then
    POLICY_REASON="resource exceeds the Slice 0 limit of 65536 bytes (${size} bytes)"
    return 1
  fi

  POLICY_DECISION="ALLOW"
  POLICY_REASON="CAP_FS_READ, workspace-scoped, regular file, ${size} bytes"
  return 0
}

slice_policy_decide() {
  local action="$1" resource="$2" workspace="$3"

  POLICY_DECISION="DENY"
  POLICY_CAPABILITY="NONE"
  POLICY_REASON="no rule matched: DEFAULT DENY (fail-closed)"

  case "$action" in
    read_file)
      POLICY_CAPABILITY="CAP_FS_READ"
      slice_validate_workspace_path "$resource" "$workspace" || return 0
      ;;
    echo_text)
      POLICY_CAPABILITY="CAP_ECHO"
      if [[ ${#resource} -gt 4096 ]]; then
        POLICY_REASON="literal text exceeds 4096 characters"
        return 0
      fi
      POLICY_DECISION="ALLOW"
      POLICY_REASON="CAP_ECHO is ALLOW for a bounded literal string (printed, never executed)"
      ;;
    write_file)
      POLICY_CAPABILITY="CAP_FS_WRITE"
      POLICY_DECISION="REQUIRE_APPROVAL"
      POLICY_REASON="writes require an approver; Slice 0 has no approver channel, so execution stays blocked"
      ;;
    run_command)
      POLICY_CAPABILITY="CAP_PROCESS_EXEC"
      POLICY_REASON="CAP_PROCESS_EXEC has no executor in Slice 0 (ARGV-mode process executor is a later phase)"
      ;;
    install_package)
      POLICY_CAPABILITY="CAP_PACKAGE_INSTALL"
      POLICY_REASON="privileged package actions belong to ops/security/privilege-gate.sh, not to this path"
      ;;
    network_fetch)
      POLICY_CAPABILITY="CAP_NETWORK_CONNECT"
      POLICY_REASON="CAP_NETWORK_CONNECT has no executor in Slice 0"
      ;;
    *)
      POLICY_CAPABILITY="NONE"
      POLICY_REASON="unknown action '${action}': DEFAULT DENY (fail-closed)"
      ;;
  esac
  return 0
}
