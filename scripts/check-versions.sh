#!/usr/bin/env bash
# Compares upstream versions with what the published repo serves.
# Prints "changed=true" or "changed=false" (suitable for $GITHUB_OUTPUT).
# Any failure to read the published repo counts as changed.
set -uo pipefail
cd "$(dirname "$0")/.."

URL=${1:-https://starenka.github.io/justdeb}

want=$(scripts/build-debs.sh --versions) || { echo "changed=true"; exit 0; }

for arch in amd64 arm64; do
  have=$(curl -fsSL "$URL/dists/stable/main/binary-$arch/Packages" 2>/dev/null |
    awk '/^Package:/{p=$2} /^Version:/{print p, $2}' | sort)
  if [[ $have != "$want" ]]; then
    echo "published $arch differs from upstream:" >&2
    diff <(echo "$have") <(echo "$want") >&2 || true
    echo "changed=true"; exit 0
  fi
done
echo "changed=false"
