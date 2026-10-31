# justdeb: upstream APT mirror

Latest upstream `uv`, `bun`, `lazygit`, `lazydocker`, `lazyjira`, `just`, `mitmproxy`, `ruff`, `deno`, `prek`, `nicotine+` as `.deb` (amd64, arm64), rebuilt daily and served from GitHub Pages. Binaries are static, so any Debian release works (`nicotine` is upstream's own `arch: all` package and pulls GTK from Debian).

## Setup (once)
1. `gpg --quick-gen-key "APT mirror" default default never` (no passphrase)
2. Add repo secret `GPG_PRIVATE_KEY` = output of `gpg --armor --export-secret-keys "APT mirror"`
3. Settings → Pages → Source: **GitHub Actions**
4. Run the `publish-apt` workflow.

## Client
```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://starenka.github.io/justdeb/key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/sta-justdeb.gpg
echo "deb [signed-by=/etc/apt/keyrings/sta-justdeb.gpg] https://starenka.github.io/justdeb stable main" | sudo tee /etc/apt/sources.list.d/sta-justdeb.list
sudo apt update && sudo apt install uv bun lazygit lazydocker lazyjira just mitmproxy ruff deno prek nicotine
```

Pin the mirrored tools to this repo, so Debian's own (older, or higher-sorting) packages never replace them:
```
sudo tee /etc/apt/preferences.d/sta-justdeb <<'EOF'
Package: uv bun lazygit lazydocker lazyjira just ruff deno prek nicotine
Pin: release o=sta-justdeb
Pin-Priority: 900
EOF
```
Add `mitmproxy` to the `Package:` line if you want those pinned too.

Only the latest version of each tool is kept. To add a tool, add a block in `scripts/build-debs.sh`.
