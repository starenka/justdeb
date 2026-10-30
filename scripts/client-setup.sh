#!/usr/bin/env bash
# Sets up (or migrates) this machine to use the sta-justdeb apt repo.
# Run as your normal user; it uses sudo where needed.
set -euo pipefail

URL=https://starenka.github.io/justdeb
PKGS="uv bun lazygit lazydocker lazyjira just ruff deno prek kitty mitmproxy"

# 1. Remove old client config, whatever it was called
sudo rm -f /etc/apt/keyrings/{upstream-mirror,starenka-justdeb}.gpg \
           /etc/apt/sources.list.d/{upstream-mirror,starenka-justdeb}.list \
           /etc/apt/preferences.d/upstream-mirror

# 2. Key + source
sudo mkdir -p /etc/apt/keyrings
curl -fsSL "$URL/key.gpg" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/sta-justdeb.gpg
echo "deb [signed-by=/etc/apt/keyrings/sta-justdeb.gpg] $URL stable main" | sudo tee /etc/apt/sources.list.d/sta-justdeb.list >/dev/null

# 3. Pin to the mirror
sudo tee /etc/apt/preferences.d/sta-justdeb >/dev/null <<EOF
Package: $PKGS
Pin: release o=sta-justdeb
Pin-Priority: 900
EOF

# 4. Update (accepts the Origin change) and install
sudo apt update --allow-releaseinfo-change
# shellcheck disable=SC2086
sudo apt install -y $PKGS

# 5. Remove stray copies that shadow the packages
for t in ruff rust-just deno prek; do uv tool uninstall "$t" 2>/dev/null || true; done
sudo rm -f /usr/local/bin/bun /usr/local/bin/bunx "$HOME/.local/bin/uvx"

# 6. Check
for p in $PKGS uvx; do
  printf '%-12s %-24s %s\n' "$p" "$(command -v "$p" || echo MISSING)" "$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate/{print $2}')"
done
echo "open a new shell (or run: hash -r) so zsh forgets old paths"
