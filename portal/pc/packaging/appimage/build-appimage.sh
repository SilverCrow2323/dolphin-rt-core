#!/usr/bin/env bash
# Builds the self-installing AppImage (x86_64). Needs a Debian/Ubuntu host with network access.
# Why self-installing: the portal writes commands with absolute paths into Sunshine's apps.json and into
# autostart entries; an AppImage mounts at a different temporary path on every run (and root cannot read a
# user's FUSE mount), so AppRun unpacks the payload once into ~/.local/share/spdw-stream-portal/<version>.
# Why Ubuntu's Python/Tk: the python-build-standalone Tk crashed (xcb assertion) with this threaded GUI.
set -euo pipefail
ROOT="$1"; DIST="$2"; VERSION="$3"; HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
APPDIR="$W/AppDir"; R="$APPDIR/python-runtime"
mkdir -p "$W/debs" "$W/x" "$R/bin" "$R/lib/x86_64-linux-gnu" "$R/share" "$APPDIR/usr"
( cd "$W/debs" && apt-get download python3.12-minimal libpython3.12-minimal libpython3.12-stdlib python3-tk libtk8.6 libtcl8.6 >/dev/null )
for f in "$W"/debs/*.deb; do dpkg-deb -x "$f" "$W/x"; done
cp "$W/x/usr/bin/python3.12" "$R/bin/"; ln -s python3.12 "$R/bin/python3"
cp -a "$W/x/usr/lib/python3.12" "$R/lib/"
cp -a "$W"/x/usr/lib/x86_64-linux-gnu/libtcl8.6.so* "$W"/x/usr/lib/x86_64-linux-gnu/libtk8.6.so* "$R/lib/x86_64-linux-gnu/"
cp -a "$W/x/usr/share/tcltk" "$R/share/"
for d in tcl8.6 tk8.6; do [ -d "$W/x/usr/lib/$d" ] && cp -a "$W/x/usr/lib/$d" "$R/lib/" || true; done
rm -rf "$R"/lib/python3.12/{test,idlelib,turtledemo,ensurepip,lib2to3}
pip download -q --only-binary=:all: --platform manylinux_2_28_x86_64 --python-version 3.12 --implementation cp -d "$W/wh" pillow
mkdir -p "$R/lib/python3/dist-packages"   # Debian's Python reads dist-packages, not site-packages
unzip -q -o "$W"/wh/pillow*.whl -d "$R/lib/python3/dist-packages"
find "$R" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
# portal payload (same staging as the deb/rpm)
STG="$W/stage"; bash -c "source <(sed -n '/^stage_usr()/,/^}/p' '$ROOT/tools/build-packages.sh'); ROOT='$ROOT'; PK='$ROOT/pc/packaging'; stage_usr '$STG'"
cp -a "$STG/usr/lib" "$STG/usr/share" "$APPDIR/usr/"
echo "$VERSION" > "$APPDIR/VERSION"
cp "$ROOT/pc/packaging/debian/icons/256.png" "$APPDIR/spdw-stream-portal.png"
sed 's|^Exec=.*|Exec=spdw-stream-portal|' "$ROOT/pc/packaging/debian/spdw-stream-portal.desktop" > "$APPDIR/spdw-stream-portal.desktop"
cp "$HERE/AppRun" "$APPDIR/AppRun"; chmod 755 "$APPDIR/AppRun"
curl -sL -o "$W/appimagetool" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"; chmod +x "$W/appimagetool"
ARCH=x86_64 "$W/appimagetool" --appimage-extract-and-run "$APPDIR" "$DIST/SPDW_Stream_Portal-$VERSION-x86_64.AppImage" >/dev/null 2>&1
echo "built $DIST/SPDW_Stream_Portal-$VERSION-x86_64.AppImage"
