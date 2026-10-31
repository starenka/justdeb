#!/usr/bin/env bash
# Builds .deb files for the latest upstream releases into ./out
# With --versions, only prints "PACKAGE VERSION" lines for what would be built.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$PWD/out
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

latest() { gh release view -R "$1" --json tagName -q .tagName; }

# mkdeb NAME VERSION ARCH DESCRIPTION HOMEPAGE BINARY...
# Optional SYMLINKS="alias=target ..." in the environment adds /usr/bin symlinks.
mkdeb() {
  local name=$1 ver=$2 arch=$3 desc=$4 home=$5; shift 5
  local root=$WORK/pkg-$name-$arch
  rm -rf "$root"
  mkdir -p "$root/DEBIAN" "$root/usr/bin"
  for b in "$@"; do install -m755 "$b" "$root/usr/bin/"; done
  for l in ${SYMLINKS:-}; do ln -s "${l#*=}" "$root/usr/bin/${l%%=*}"; done
  cat > "$root/DEBIAN/control" <<EOF
Package: $name
Version: $ver
Architecture: $arch
Section: utils
Priority: optional
Maintainer: ${MAINTAINER:-APT mirror <starenka0@gmail.com>}
Homepage: $home
Description: $desc
EOF
  dpkg-deb --root-owner-group --build "$root" "$OUT/${name}_${ver}_${arch}.deb" >/dev/null
  echo "built ${name}_${ver}_${arch}.deb"
}

# fetch URL DESTDIR  (extracts tar.gz or zip)
fetch() {
  local url=$1 dest=$2
  mkdir -p "$dest"
  curl -fsSL "$url" -o "$dest/archive"
  case $url in
    *.zip) unzip -q "$dest/archive" -d "$dest" ;;
    *) tar -xzf "$dest/archive" -C "$dest" ;;
  esac
  rm "$dest/archive"
}

findbin() { find "$1" -type f -name "$2" | head -n1; }

declare -A UV=([amd64]=x86_64 [arm64]=aarch64)
declare -A BUN=([amd64]=x64 [arm64]=aarch64)
declare -A LG=([amd64]=x86_64 [arm64]=arm64)
declare -A JUST=([amd64]=x86_64 [arm64]=aarch64)
declare -A RUFF=([amd64]=x86_64 [arm64]=aarch64)
declare -A MITM=([amd64]=x86_64 [arm64]=aarch64)
declare -A LJ=([amd64]=amd64 [arm64]=arm64)
declare -A DENO=([amd64]=x86_64 [arm64]=aarch64)
declare -A PREK=([amd64]=x86_64 [arm64]=aarch64)

uvt=$(latest astral-sh/uv); buntag=$(latest oven-sh/bun)
lgt=$(latest jesseduffield/lazygit); ldt=$(latest jesseduffield/lazydocker)
justt=$(latest casey/just); ruffv=$(latest astral-sh/ruff); mitmt=$(latest mitmproxy/mitmproxy)
ljt=$(latest textfuel/lazyjira)
denot=$(latest denoland/deno); prekt=$(latest j178/prek)
nict=$(latest nicotine-plus/nicotine-plus)

if [[ ${1:-} == --versions ]]; then
  printf '%s\n' "uv $uvt" "bun ${buntag#bun-v}" "lazygit ${lgt#v}" "lazydocker ${ldt#v}" \
    "lazyjira ${ljt#v}" "just $justt" "ruff $ruffv" "deno ${denot#v}" "prek ${prekt#v}" \
    "mitmproxy ${mitmt#v}" "nicotine ${nict#v}-1" | sort
  exit 0
fi

for arch in amd64 arm64; do
  d=$WORK/uv-$arch
  fetch "https://github.com/astral-sh/uv/releases/download/$uvt/uv-${UV[$arch]}-unknown-linux-musl.tar.gz" "$d"
  mkdeb uv "$uvt" "$arch" "Extremely fast Python package and project manager" \
    https://github.com/astral-sh/uv "$(findbin "$d" uv)" "$(findbin "$d" uvx)"

  d=$WORK/bun-$arch
  fetch "https://github.com/oven-sh/bun/releases/download/$buntag/bun-linux-${BUN[$arch]}.zip" "$d"
  SYMLINKS="bunx=bun" mkdeb bun "${buntag#bun-v}" "$arch" "Fast all-in-one JavaScript runtime and toolkit" \
    https://bun.sh "$(findbin "$d" bun)"

  d=$WORK/lazygit-$arch
  fetch "https://github.com/jesseduffield/lazygit/releases/download/$lgt/lazygit_${lgt#v}_Linux_${LG[$arch]}.tar.gz" "$d"
  mkdeb lazygit "${lgt#v}" "$arch" "Simple terminal UI for git commands" \
    https://github.com/jesseduffield/lazygit "$(findbin "$d" lazygit)"

  d=$WORK/lazydocker-$arch
  fetch "https://github.com/jesseduffield/lazydocker/releases/download/$ldt/lazydocker_${ldt#v}_Linux_${LG[$arch]}.tar.gz" "$d"
  mkdeb lazydocker "${ldt#v}" "$arch" "Simple terminal UI for docker and docker-compose" \
    https://github.com/jesseduffield/lazydocker "$(findbin "$d" lazydocker)"

  d=$WORK/just-$arch
  fetch "https://github.com/casey/just/releases/download/$justt/just-$justt-${JUST[$arch]}-unknown-linux-musl.tar.gz" "$d"
  mkdeb just "$justt" "$arch" "Handy way to save and run project-specific commands" \
    https://github.com/casey/just "$(findbin "$d" just)"

  d=$WORK/ruff-$arch
  fetch "https://github.com/astral-sh/ruff/releases/download/$ruffv/ruff-${RUFF[$arch]}-unknown-linux-musl.tar.gz" "$d"
  mkdeb ruff "$ruffv" "$arch" "Extremely fast Python linter and code formatter" \
    https://github.com/astral-sh/ruff "$(findbin "$d" ruff)"

  d=$WORK/mitmproxy-$arch
  fetch "https://downloads.mitmproxy.org/${mitmt#v}/mitmproxy-${mitmt#v}-linux-${MITM[$arch]}.tar.gz" "$d"
  mkdeb mitmproxy "${mitmt#v}" "$arch" "Interactive TLS-capable intercepting HTTP proxy" \
    https://mitmproxy.org "$(findbin "$d" mitmproxy)" "$(findbin "$d" mitmdump)" "$(findbin "$d" mitmweb)"

  d=$WORK/lazyjira-$arch
  fetch "https://github.com/textfuel/lazyjira/releases/download/$ljt/lazyjira_linux_${LJ[$arch]}.tar.gz" "$d"
  mkdeb lazyjira "${ljt#v}" "$arch" "Terminal UI for Jira" \
    https://github.com/textfuel/lazyjira "$(findbin "$d" lazyjira)"

  d=$WORK/deno-$arch
  fetch "https://github.com/denoland/deno/releases/download/$denot/deno-${DENO[$arch]}-unknown-linux-gnu.zip" "$d"
  mkdeb deno "${denot#v}" "$arch" "Secure runtime for JavaScript and TypeScript" \
    https://deno.com "$(findbin "$d" deno)"

  d=$WORK/prek-$arch
  fetch "https://github.com/j178/prek/releases/download/$prekt/prek-${PREK[$arch]}-unknown-linux-musl.tar.gz" "$d"
  mkdeb prek "${prekt#v}" "$arch" "Fast, drop-in pre-commit replacement written in Rust" \
    https://github.com/j178/prek "$(findbin "$d" prek)"
done

# nicotine+: upstream ships an arch:all .deb inside debian-package.zip; republish it as-is
d=$WORK/nicotine
fetch "https://github.com/nicotine-plus/nicotine-plus/releases/download/$nict/debian-package.zip" "$d"
deb=$(findbin "$d" 'nicotine_*_all.deb')
cp "$deb" "$OUT/"
echo "copied $(basename "$deb")"
