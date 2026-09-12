#!/bin/bash

# Fails if a script or guide pipes a download straight into a shell, or fetches
# this repository's files from the mutable main branch. Operators run these
# commands as root, so every download has to be pinned and checked first.
#
# Run from anywhere: bash .github/scripts/guard-remote-exec.sh

set -euo pipefail

cd "$(dirname "$0")/../.."

paths=(scripts sysop developer community-manager README.md)

# `curl ... | sh`, `wget ... | sudo -E bash -` and similar.
pipe_to_shell='(curl|wget)[^#]*\|[[:space:]]*(sudo[[:space:]]+(-[A-Za-z]+[[:space:]]+)*)?(ba|z|da)?sh([^[:alnum:]_]|$)'
# `bash <(curl ...)`
process_substitution='(ba|z|da)?sh[[:space:]]+<\([[:space:]]*(curl|wget)'
# Raw fetches from this repo's main branch.
raw_main='raw\.githubusercontent\.com/OpenVTC/vti-setup/(refs/heads/)?main/'

status=0
check() {
  local description="$1" pattern="$2"
  if grep -rnE -- "$pattern" "${paths[@]}"; then
    echo "::error::${description}" >&2
    status=1
  fi
}

check "download piped into a shell; download, verify, then run instead" "$pipe_to_shell"
check "download run through process substitution; download, verify, then run instead" "$process_substitution"
check "fetch from OpenVTC/vti-setup main; use a tagged release asset instead" "$raw_main"

if [ "$status" -eq 0 ]; then
  echo "No remote-exec patterns found."
fi
exit "$status"
