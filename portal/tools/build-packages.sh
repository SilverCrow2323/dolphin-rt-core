#!/usr/bin/env bash
# Builds the PC portal for non-Debian systems from the repository sources.
#   tools/build-packages.sh rpm        -> dist/spdw-stream-portal-<v>-1.noarch.rpm     (Fedora/RHEL, needs rpmbuild)
#   tools/build-packages.sh arch       -> dist/arch/{PKGBUILD,*.install,*.tar.gz}      (makepkg -si inside dist/arch)
#   tools/build-packages.sh appimage   -> dist/SPDW_Stream_Portal-<v>-x86_64.AppImage  (Debian/Ubuntu host, needs network)
#   tools/build-packages.sh all
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="${DIST:-$ROOT/dist}"; mkdir -p "$DIST"
PK="$ROOT/pc/packaging"

# same payload as tools/build-deb.sh: <stage>/usr/...
stage_usr() {
  local S="$1"; local LIB="$S/usr/lib/spdw-stream-portal" SHARE="$S/usr/share/spdw-stream-portal"
  install -d "$S/usr/bin" "$LIB" "$SHARE/assets" "$SHARE/dolphin-profiles" "$S/usr/share/applications" "$S/usr/share/pixmaps"
  install -m755 "$ROOT"/pc/portal/*.py "$ROOT"/pc/portal/*.sh "$LIB/"
  cp -r "$ROOT"/pc/profiles/. "$SHARE/dolphin-profiles/"; cp "$ROOT"/pc/assets/* "$SHARE/assets/"
  install -m755 "$PK"/debian/bin/* "$S/usr/bin/"
  install -m644 "$PK/debian/spdw-stream-portal.desktop" "$S/usr/share/applications/"
  install -m644 "$PK/debian/icons/pixmap.png" "$S/usr/share/pixmaps/spdw-stream-portal.png"
  for s in 16 24 32 48 64 128 256; do
    install -d "$S/usr/share/icons/hicolor/${s}x${s}/apps"
    install -m644 "$PK/debian/icons/$s.png" "$S/usr/share/icons/hicolor/${s}x${s}/apps/spdw-stream-portal.png"
  done
  find "$S" -name __pycache__ -prune -exec rm -rf {} +
}

source_tarball() {   # -> $1/spdw-stream-portal-<v>.tar.gz (usr/ + LICENSE)
  local W="$1"; local D="$W/spdw-stream-portal-$VERSION"; mkdir -p "$D"
  stage_usr "$D"; cp "$ROOT/LICENSE" "$D/LICENSE"
  tar -C "$W" -czf "$W/spdw-stream-portal-$VERSION.tar.gz" "spdw-stream-portal-$VERSION"
}

build_rpm() {
  command -v rpmbuild >/dev/null || { echo "rpmbuild not found (apt install rpm / dnf install rpm-build)"; exit 1; }
  local W; W="$(mktemp -d)"; trap 'rm -rf "$W"' RETURN
  mkdir -p "$W"/{SOURCES,SPECS,BUILD,RPMS,SRPMS,BUILDROOT}
  local T; T="$(mktemp -d)"; source_tarball "$T"; cp "$T/spdw-stream-portal-$VERSION.tar.gz" "$W/SOURCES/"; rm -rf "$T"
  sed "s/@VERSION@/$VERSION/" "$PK/rpm/spdw-stream-portal.spec.in" > "$W/SPECS/spdw-stream-portal.spec"
  rpmbuild --define "_topdir $W" -bb "$W/SPECS/spdw-stream-portal.spec" >/dev/null
  cp "$W"/RPMS/noarch/*.rpm "$DIST/"; echo "built $(ls "$DIST"/spdw-stream-portal-*.rpm)"
}

build_arch() {
  local A="$DIST/arch"; rm -rf "$A"; mkdir -p "$A"
  source_tarball "$A"
  rm -rf "$A/spdw-stream-portal-$VERSION"   # keep only what makepkg needs
  local SUM; SUM="$(sha256sum "$A/spdw-stream-portal-$VERSION.tar.gz" | cut -d' ' -f1)"
  sed -e "s/@VERSION@/$VERSION/" -e "s/@SHA256@/$SUM/" "$PK/arch/PKGBUILD.in" > "$A/PKGBUILD"
  cp "$PK/arch/spdw-stream-portal.install" "$A/"; echo "built $A (cd there and run: makepkg -si)"
}

build_appimage() { bash "$PK/appimage/build-appimage.sh" "$ROOT" "$DIST" "$VERSION"; }

case "${1:-all}" in
  rpm) build_rpm ;; arch) build_arch ;; appimage) build_appimage ;;
  all) build_rpm; build_arch; build_appimage ;;
  *) echo "usage: $0 rpm|arch|appimage|all"; exit 2 ;;
esac
