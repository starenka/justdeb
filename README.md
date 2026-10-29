# justdeb: upstream APT mirror

Latest upstream `uv`, `bun`, `lazygit`, `lazydocker`, `lazyjira`, `just`, `kitty`, `mitmproxy`, `ruff` as `.deb` (amd64, arm64), rebuilt daily and served from GitHub Pages. Binaries are static, so any Debian release works.

## Setup (once)
1. `gpg --quick-gen-key "APT mirror" default default never` (no passphrase)
2. Add repo secret `GPG_PRIVATE_KEY` = output of `gpg --armor --export-secret-keys "APT mirror"`
3. Settings → Pages → Source: **GitHub Actions**
4. Run the `publish-apt` workflow.

## Client
```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://USER.github.io/REPO/key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/upstream-mirror.gpg
echo "deb [signed-by=/etc/apt/keyrings/upstream-mirror.gpg] https://USER.github.io/REPO stable main" | sudo tee /etc/apt/sources.list.d/upstream-mirror.list
sudo apt update && sudo apt install uv bun lazygit lazydocker lazyjira just kitty mitmproxy ruff
```

Only the latest version of each tool is kept. To add a tool, add a block in `scripts/build-debs.sh`.
