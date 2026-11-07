#!/usr/bin/env bash
# Builds dist/spdw-stream-portal_<version>_all.deb from the repository sources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OUT="${1:-$ROOT/dist}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

LIB="$STAGE/usr/lib/spdw-stream-portal"
SHARE="$STAGE/usr/share/spdw-stream-portal"
install -d "$STAGE/DEBIAN" "$STAGE/usr/bin" "$LIB" "$SHARE/assets" "$SHARE/dolphin-profiles" \
  "$STAGE/usr/share/applications" "$STAGE/usr/share/pixmaps" "$STAGE/usr/share/doc/spdw-stream-portal"

install -m755 "$ROOT"/pc/portal/*.py "$ROOT"/pc/portal/*.sh "$LIB/"
cp -r "$ROOT"/pc/profiles/. "$SHARE/dolphin-profiles/"
cp "$ROOT"/pc/assets/* "$SHARE/assets/"
install -m755 "$ROOT"/pc/packaging/debian/bin/* "$STAGE/usr/bin/"
install -m644 "$ROOT/pc/packaging/debian/spdw-stream-portal.desktop" "$STAGE/usr/share/applications/"
install -m644 "$ROOT/pc/packaging/debian/icons/pixmap.png" "$STAGE/usr/share/pixmaps/spdw-stream-portal.png"
for s in 16 24 32 48 64 128 256; do
  install -d "$STAGE/usr/share/icons/hicolor/${s}x${s}/apps"
  install -m644 "$ROOT/pc/packaging/debian/icons/$s.png" "$STAGE/usr/share/icons/hicolor/${s}x${s}/apps/spdw-stream-portal.png"
done
install -m644 "$ROOT/pc/packaging/debian/doc/copyright" "$STAGE/usr/share/doc/spdw-stream-portal/copyright"
install -m644 "$ROOT/README.md" "$STAGE/usr/share/doc/spdw-stream-portal/README.md"
install -m644 "$ROOT/CHANGELOG.md" "$STAGE/usr/share/doc/spdw-stream-portal/changelog"
install -m755 "$ROOT/pc/packaging/debian/postinst" "$ROOT/pc/packaging/debian/prerm" "$STAGE/DEBIAN/"
sed "s/@VERSION@/$VERSION/" "$ROOT/pc/packaging/debian/control.in" > "$STAGE/DEBIAN/control"
find "$STAGE" -name __pycache__ -prune -exec rm -rf {} +

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT/spdw-stream-portal_${VERSION}_all.deb"
echo "built $OUT/spdw-stream-portal_${VERSION}_all.deb"
