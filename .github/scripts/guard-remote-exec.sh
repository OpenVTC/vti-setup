#!/bin/bash

# Fails if a script or guide pipes a download straight into a shell. Operators
# run these commands as root, so every download goes to a file they can read
# before running it.
#
# Run from anywhere: bash .github/scripts/guard-remote-exec.sh

set -euo pipefail

cd "$(dirname "$0")/../.."

paths=(scripts sysop developer community-manager README.md)

# `curl ... | sh`, `wget ... | sudo -E bash -` and similar.
pipe_to_shell='(curl|wget)[^#]*\|[[:space:]]*(sudo[[:space:]]+(-[A-Za-z]+[[:space:]]+)*)?(ba|z|da)?sh([^[:alnum:]_]|$)'
# `bash <(curl ...)`
process_substitution='(ba|z|da)?sh[[:space:]]+<\([[:space:]]*(curl|wget)'

status=0
check() {
  local description="$1" pattern="$2"
  if grep -rnE -- "$pattern" "${paths[@]}"; then
    echo "::error::${description}" >&2
    status=1
  fi
}

check "download piped into a shell; download to a file, read it, then run it instead" "$pipe_to_shell"
check "download run through process substitution; download to a file, read it, then run it instead" "$process_substitution"

if [ "$status" -eq 0 ]; then
  echo "No remote-exec patterns found."
fi
exit "$status"
