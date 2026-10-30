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
mkdeb() {
  local name=$1 ver=$2 arch=$3 desc=$4 home=$5; shift 5
  local root=$WORK/pkg-$name-$arch
  rm -rf "$root"
  mkdir -p "$root/DEBIAN" "$root/usr/bin"
  for b in "$@"; do install -m755 "$b" "$root/usr/bin/"; done
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
    *.txz) tar -xJf "$dest/archive" -C "$dest" ;;
    *) tar -xzf "$dest/archive" -C "$dest" ;;
  esac
  rm "$dest/archive"
}

# mkdeb_kitty VERSION ARCH SRCDIR  (bundle goes to /opt/kitty, symlinked into /usr/bin)
mkdeb_kitty() {
  local ver=$1 arch=$2 src=$3
  local root=$WORK/pkg-kitty-$arch
  rm -rf "$root"
  mkdir -p "$root/DEBIAN" "$root/opt" "$root/usr/bin" "$root/usr/share"
  cp -a "$src" "$root/opt/kitty"
  ln -s ../../opt/kitty/bin/kitty "$root/usr/bin/kitty"
  ln -s ../../opt/kitty/bin/kitten "$root/usr/bin/kitten"
  cp -a "$src/share/applications" "$src/share/icons" "$root/usr/share/"
  cat > "$root/DEBIAN/control" <<EOF
Package: kitty
Version: $ver
Architecture: $arch
Section: utils
Priority: optional
Maintainer: ${MAINTAINER:-APT mirror <starenka0@gmail.com>}
Depends: libx11-6, libx11-xcb1, libxcursor1, libxrandr2, libxi6, libxinerama1, libxkbcommon0, libxkbcommon-x11-0, libwayland-client0, libdbus-1-3, libgl1, libfontconfig1
Homepage: https://sw.kovidgoyal.net/kitty/
Description: Fast, feature-rich, GPU based terminal emulator
EOF
  dpkg-deb --root-owner-group --build "$root" "$OUT/kitty_${ver}_${arch}.deb" >/dev/null
  echo "built kitty_${ver}_${arch}.deb"
}

findbin() { find "$1" -type f -name "$2" | head -n1; }

declare -A UV=([amd64]=x86_64 [arm64]=aarch64)
declare -A BUN=([amd64]=x64 [arm64]=aarch64)
declare -A LG=([amd64]=x86_64 [arm64]=arm64)
declare -A JUST=([amd64]=x86_64 [arm64]=aarch64)
declare -A RUFF=([amd64]=x86_64 [arm64]=aarch64)
declare -A MITM=([amd64]=x86_64 [arm64]=aarch64)
declare -A KITTY=([amd64]=x86_64 [arm64]=arm64)
declare -A LJ=([amd64]=amd64 [arm64]=arm64)
declare -A DENO=([amd64]=x86_64 [arm64]=aarch64)
declare -A PREK=([amd64]=x86_64 [arm64]=aarch64)

uvt=$(latest astral-sh/uv); buntag=$(latest oven-sh/bun)
lgt=$(latest jesseduffield/lazygit); ldt=$(latest jesseduffield/lazydocker)
justt=$(latest casey/just); ruffv=$(latest astral-sh/ruff); mitmt=$(latest mitmproxy/mitmproxy)
kitt=$(latest kovidgoyal/kitty); ljt=$(latest textfuel/lazyjira)
denot=$(latest denoland/deno); prekt=$(latest j178/prek)

if [[ ${1:-} == --versions ]]; then
  printf '%s\n' "uv $uvt" "bun ${buntag#bun-v}" "lazygit ${lgt#v}" "lazydocker ${ldt#v}" \
    "lazyjira ${ljt#v}" "just $justt" "ruff $ruffv" "deno ${denot#v}" "prek ${prekt#v}" \
    "mitmproxy ${mitmt#v}" "kitty ${kitt#v}" | sort
  exit 0
fi

for arch in amd64 arm64; do
  d=$WORK/uv-$arch
  fetch "https://github.com/astral-sh/uv/releases/download/$uvt/uv-${UV[$arch]}-unknown-linux-musl.tar.gz" "$d"
  mkdeb uv "$uvt" "$arch" "Extremely fast Python package and project manager" \
    https://github.com/astral-sh/uv "$(findbin "$d" uv)" "$(findbin "$d" uvx)"

  d=$WORK/bun-$arch
  fetch "https://github.com/oven-sh/bun/releases/download/$buntag/bun-linux-${BUN[$arch]}.zip" "$d"
  mkdeb bun "${buntag#bun-v}" "$arch" "Fast all-in-one JavaScript runtime and toolkit" \
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

  d=$WORK/kitty-$arch
  fetch "https://github.com/kovidgoyal/kitty/releases/download/$kitt/kitty-${kitt#v}-${KITTY[$arch]}.txz" "$d"
  mkdeb_kitty "${kitt#v}" "$arch" "$d"

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
