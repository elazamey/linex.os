#!/usr/bin/env bash
# LINEX.OS - Slice 0 executor (execution authority subset).
#
# This is the ONLY file in the slice that touches the world. Properties, all of
# which the slice's tests assert by running it:
#   - ARGV mode only: user data is passed as an argument, never evaluated.
#   - No eval, no bash -c, no sh -c, no command substitution over user data.
#   - No sudo, no network, no writes, no process spawn beyond cat/printf.
#   - Reads only paths the policy layer has already resolved and ALLOWed.
#
# Not the P10 execution authority: a slice-sized subset with no technology
# decision (ADR 0012).

# $1 = resolved absolute path already ALLOWed by the policy layer.
slice_exec_read_file() {
  local resolved="$1"
  cat -- "$resolved"
}

# $1 = bounded literal text.
slice_exec_echo_text() {
  printf '%s\n' "$1"
}
