#!/bin/bash

# Fails if the release pinned in the explore guide cannot be verified.
#
# The guide has operators download `setup-explore.sh` from a tagged release and
# check it against a SHA-256 pinned on the page, because they then run it as
# root. Two things can go wrong without anything noticing, and this guard
# covers both:
#
#   drift     the pin no longer describes the script in the tree, so the guide
#             tells operators to reject the current release
#   missing   the pinned release was never published, so the download 404s and
#             the explore stream stops at its first command
#
# The drift check always runs. The published check runs only when
# CHECK_PUBLISHED=1, because RELEASING.md deliberately pins the version and
# hash in a merged pull request *before* the tag that creates the release
# exists; demanding the release on every pull request would deadlock that
# order. CI runs the published check on main and on a schedule instead, so a
# tag that never gets pushed surfaces within a day.
#
# Run from anywhere:
#   bash .github/scripts/guard-release-pin.sh
#   CHECK_PUBLISHED=1 bash .github/scripts/guard-release-pin.sh

set -euo pipefail

cd "$(dirname "$0")/../.."

guide=sysop/explore/01-server-setup.md
script=scripts/setup-explore.sh

fail() {
  echo "::error::$1" >&2
  exit 1
}

# Read the guide with any CR stripped, so a checkout made with
# core.autocrlf=true parses the same way the Linux runner does.
guide_text=$(tr -d '\r' <"$guide")

ver=$(printf '%s\n' "$guide_text" | sed -n 's/^VER=\(.*\)$/\1/p' | head -n 1)
pinned=$(printf '%s\n' "$guide_text" | sed -n 's/^SHA256=\([0-9a-f]\{64\}\)$/\1/p' | head -n 1)

[ -n "$ver" ] || fail "no VER= pin found in ${guide}"
[ -n "$pinned" ] || fail "no SHA256= pin (64 lowercase hex) found in ${guide}"

# The pin must describe the script this commit ships. `release.yml` hashes the
# file as it stands in the tree, so this hashes the same bytes. A Windows
# checkout made with core.autocrlf=true will disagree here; the Linux runner is
# what the pin is for.
actual=$(sha256sum "$script" | cut -d ' ' -f 1)
if [ "$actual" != "$pinned" ]; then
  fail "${guide} pins SHA256=${pinned}, but ${script} hashes to ${actual}; re-pin the guide or revert the script (RELEASING.md)"
fi
echo "Pin matches ${script}: ${pinned}"

if [ "${CHECK_PUBLISHED:-0}" != "1" ]; then
  echo "Skipping the published-release check; set CHECK_PUBLISHED=1 to run it."
  exit 0
fi

# Take the download location from the guide itself, so this checks the URL
# operators are actually told to fetch rather than one written twice.
url_template=$(printf '%s\n' "$guide_text" |
  sed -n 's#^curl -fsSLO "\(https://github.com/[^"]*\)/setup-explore\.sh"$#\1#p' |
  head -n 1)
[ -n "$url_template" ] || fail "could not read the release download URL out of ${guide}"
base=${url_template//\$\{VER\}/$ver}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

for asset in setup-explore.sh SHA256SUMS; do
  if ! curl -fsSL --retry 3 -o "${workdir}/${asset}" "${base}/${asset}"; then
    fail "${base}/${asset} could not be downloaded; ${guide} pins release ${ver}, so either push the ${ver} tag (RELEASING.md) or re-pin the guide to a release that exists"
  fi
done

published=$(sha256sum "${workdir}/setup-explore.sh" | cut -d ' ' -f 1)
if [ "$published" != "$pinned" ]; then
  fail "release ${ver} ships setup-explore.sh with SHA256 ${published}, but ${guide} pins ${pinned}"
fi

if ! (cd "$workdir" && sha256sum -c SHA256SUMS >/dev/null); then
  fail "release ${ver} SHA256SUMS does not verify against the assets published beside it"
fi

echo "Release ${ver} is published and its setup-explore.sh matches the pin."
