#!/bin/bash
# Dolphin Rt:Core K - online installer (single file)
#   curl -fsSL https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/knulli/get.sh | bash
#   ... | bash -s -- --dest /userdata/emulators/dolphin-rtcore-k --ref v0.2.0
# Downloads the release from the repo, unpacks it and runs install.sh. Safe to run again: it then updates.
REPO="${RTCORE_REPO:-SilverCrow2323/dolphin-rt-core}"
REF="${RTCORE_REF:-main}"
SUBDIR="${RTCORE_SUBDIR-knulli}"
URL="${RTCORE_URL:-}"
DEST=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest)   DEST="$2"; shift 2;;
    --repo)   REPO="$2"; shift 2;;
    --ref)    REF="$2"; shift 2;;
    --subdir) SUBDIR="$2"; shift 2;;
    --url)    URL="$2"; shift 2;;
    *)        ARGS+=("$1"); shift;;
  esac
done
say() { echo "[rtcore-k] $*"; }
die() { echo "[rtcore-k] ERROR: $*" >&2; exit 1; }

if [ -z "$DEST" ]; then
  if [ -d /userdata ]; then DEST=/userdata/emulators/dolphin-rtcore-k; else DEST="$PWD/dolphin-rtcore-k"; fi
fi
SRCARGS=(--repo "$REPO" --ref "$REF" --subdir "$SUBDIR")
[ -n "$URL" ] && SRCARGS+=(--url "$URL")

if [ -f "$DEST/install.sh" ]; then
  say "Found an existing install in $DEST: updating it"
  exec bash "$DEST/install.sh" --update "${SRCARGS[@]}" "${ARGS[@]}"
fi

command -v tar >/dev/null 2>&1 || die "tar is required"
url="${URL:-https://codeload.github.com/$REPO/tar.gz/$REF}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/rtcore.XXXXXX")" || die "cannot create a temporary folder"
trap 'rm -rf "$tmp"' EXIT
say "Downloading $url"
if   command -v curl >/dev/null 2>&1; then curl -fL $([ -t 2 ] && echo -# || echo -sS) --retry 3 --connect-timeout 20 -o "$tmp/src.tar.gz" "$url" || die "download failed"
elif command -v wget >/dev/null 2>&1; then wget -q -O "$tmp/src.tar.gz" "$url" || die "download failed"
else die "neither curl nor wget is available"; fi
mkdir -p "$tmp/x" && tar -xzof "$tmp/src.tar.gz" -C "$tmp/x" || die "the download is not a valid archive"
top="$(ls -1 "$tmp/x" | head -n1)"
src="$tmp/x/$top"; [ -n "$SUBDIR" ] && src="$src/$SUBDIR"
[ -f "$src/install.sh" ] && [ -f "$src/core/dolphin" ] || die "no release found in the download (expected '${SUBDIR:+$SUBDIR/}install.sh')"
mkdir -p "$DEST" || die "cannot create $DEST"
(cd "$src" && tar -cf - .) | (cd "$DEST" && tar -xof -)
say "Unpacked into $DEST"
exec bash "$DEST/install.sh" --offline "${ARGS[@]}"
