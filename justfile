set shell := ["bash", "-euo", "pipefail", "-c"]

# list targets
default:
    @just --list

# build all .debs into ./out
build:
    scripts/build-debs.sh

# list built packages with version, arch and size
ls:
    @for f in out/*.deb; do dpkg-deb -f "$f" Package Version Architecture | paste -sd' ' | tr -d '\n'; echo "  $(du -h "$f" | cut -f1)"; done

# show contents of one package, e.g. `just inspect kitty`
inspect name:
    @for f in out/{{name}}_*.deb; do echo "== $f"; dpkg-deb -I "$f"; dpkg-deb -c "$f"; done

# build the signed apt repo into ./site (needs reprepro + a gpg key)
repo: build
    rm -rf site
    mkdir -p site
    reprepro -b site --confdir "$PWD/conf" includedeb stable out/*.deb
    rm -rf site/conf site/db
    gpg --export > site/key.gpg
    touch site/.nojekyll

# serve ./site locally on :8000
serve port="8000": repo
    python3 -m http.server -d site {{port}}

# shellcheck + bash syntax check of the build script
lint:
    bash -n scripts/build-debs.sh
    shellcheck scripts/build-debs.sh

# trigger the publish-apt workflow on GitHub and follow it
publish:
    gh workflow run publish-apt
    sleep 3
    gh run watch "$(gh run list -w publish-apt -L1 --json databaseId -q '.[0].databaseId')"

# show latest upstream version of every tracked tool
versions:
    @for r in astral-sh/uv oven-sh/bun jesseduffield/lazygit jesseduffield/lazydocker textfuel/lazyjira casey/just kovidgoyal/kitty mitmproxy/mitmproxy astral-sh/ruff denoland/deno j178/prek; do printf '%-28s %s\n' "$r" "$(gh release view -R "$r" --json tagName -q .tagName)"; done

# remove build output
clean:
    rm -rf out site

# install the built debs in a clean container and run each binary (default: debian testing, host arch)
test arch=`dpkg --print-architecture` image="debian:testing": build
    scripts/test-debs.sh {{arch}} {{image}}
