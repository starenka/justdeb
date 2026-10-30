#!/usr/bin/env bash
# Installs the built .debs in a clean container and runs each binary.
# Usage: scripts/test-debs.sh [ARCH] [IMAGE]   (defaults: host arch, debian:testing)
set -euo pipefail
cd "$(dirname "$0")/.."

arch=${1:-$(dpkg --print-architecture)}
image=${2:-debian:testing}

compgen -G "out/*_${arch}.deb" >/dev/null || { echo "no out/*_${arch}.deb; run 'just build'" >&2; exit 1; }

docker run --rm --platform "linux/$arch" -v "$PWD/out:/debs:ro" "$image" bash -euo pipefail -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq /debs/*_'"$arch"'.deb >/dev/null
  apt-get install -y -qq xvfb xauth libgl1-mesa-dri fonts-dejavu-core >/dev/null
  fail=0
  for cmd in "uv --version" "uvx --version" "bun --version" "bunx --version" "lazygit --version" \
             "lazydocker --version" "lazyjira --version" "just --version" "ruff --version" "deno --version" "prek --version" \
             "mitmproxy --version" "mitmdump --version" "mitmweb --version" \
             "kitty --version" "kitten --version"; do
    if out=$($cmd 2>&1 | head -n1); then printf "ok    %-22s %s\n" "$cmd" "$out"
    else printf "FAIL  %-22s %s\n" "$cmd" "$out"; fail=1; fi
  done
  # kitty GUI: open a window on a virtual X display (software GL), run a command, exit
  if LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a timeout 30 kitty --config NONE -o close_on_child_death=yes \
       sh -c "echo gui-ok > /tmp/kitty-out" >/dev/null 2>&1 && [ "$(cat /tmp/kitty-out)" = gui-ok ]; then
    printf "ok    %-22s %s\n" "kitty (xvfb window)" "ran command"
  else printf "FAIL  %-22s\n" "kitty (xvfb window)"; fail=1; fi
  exit $fail
'
