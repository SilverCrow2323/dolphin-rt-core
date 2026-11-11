#!/usr/bin/env bash
set -euo pipefail
INPUT=""
OUT="$PWD/dist"
BUILD_ID=local
while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --build-id) BUILD_ID="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$INPUT" ] || { echo "usage: $0 --input BUILD_DIR [--out DIR] [--build-id ID]" >&2; exit 2; }
[ -d "$INPUT" ] || { echo "build directory not found: $INPUT" >&2; exit 1; }
INPUT="$(cd "$INPUT" && pwd -P)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd -P)"
for tool in readelf ldd tar sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool" >&2; exit 1; }
done
TMP="$(mktemp -d "$OUT/.desktop-stage.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
validate_x86_64() {
  binary="$1"
  [ -s "$binary" ] && [ -x "$binary" ] || { echo "missing or non-executable binary: $binary" >&2; exit 1; }
  header="$(readelf -h "$binary" 2>/dev/null)" || { echo "cannot read ELF header: $binary" >&2; exit 1; }
  printf '%s\n' "$header" | grep -Eq 'Class:[[:space:]]+ELF64' || { echo "not ELF64: $binary" >&2; exit 1; }
  printf '%s\n' "$header" | grep -Eq 'Data:.*little endian' || { echo "not little-endian ELF: $binary" >&2; exit 1; }
  printf '%s\n' "$header" | grep -Eq 'Machine:.*(X86-64|x86-64)' || { echo "not an x86_64 executable: $binary" >&2; exit 1; }
  ldd "$binary" > "$TMP/$(basename "$binary").ldd" 2>&1 || {
    echo "ldd failed for $binary" >&2
    cat "$TMP/$(basename "$binary").ldd" >&2
    exit 1
  }
  if grep -Fq 'not found' "$TMP/$(basename "$binary").ldd"; then
    echo "unresolved runtime dependency in $binary:" >&2
    cat "$TMP/$(basename "$binary").ldd" >&2
    exit 1
  fi
}
for file in dolphin dolphin-gui; do
  [ -e "$INPUT/$file" ] || { echo "missing required desktop frontend: $INPUT/$file" >&2; exit 1; }
done
[ -s "$INPUT/BUILDINFO.txt" ] || { echo "missing BUILDINFO.txt" >&2; exit 1; }
for asset in GC/font_western.bin GC/font_japanese.bin GC/dsp_rom.bin GC/dsp_coef.bin Resources/OSD_Font.ttf; do
  [ -s "$INPUT/Sys/$asset" ] || { echo "missing Sys/$asset" >&2; exit 1; }
done
SOURCE_ARCHIVE="$(find "$INPUT" -maxdepth 1 -type f -name 'source-*.tar.xz' -print -quit)"
[ -n "$SOURCE_ARCHIVE" ] || { echo "missing matching source-*.tar.xz archive" >&2; exit 1; }
BUNDLE="Dolphin-RtCore-Desktop-x86_64"
STAGE="$TMP/$BUNDLE"
mkdir -p "$STAGE"
validate_x86_64 "$INPUT/dolphin"
validate_x86_64 "$INPUT/dolphin-gui"
install -m755 "$INPUT/dolphin" "$STAGE/dolphin"
install -m755 "$INPUT/dolphin-gui" "$STAGE/dolphin-gui"
if [ -s "$INPUT/dolphin-nogui" ]; then install -m755 "$INPUT/dolphin-nogui" "$STAGE/dolphin-nogui"; fi
cp -a "$INPUT/Sys" "$STAGE/Sys"
install -m644 "$INPUT/BUILDINFO.txt" "$STAGE/BUILDINFO.txt"
install -m644 "$SOURCE_ARCHIVE" "$STAGE/"
cat > "$STAGE/run-gui.sh" <<'RUNGUI'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -x "$HERE/dolphin-gui" ] || { echo "Dolphin Qt GUI binary is missing" >&2; exit 1; }
if [ -z "$QT_QPA_PLATFORM" ]; then export QT_QPA_PLATFORM=xcb; fi
exec "$HERE/dolphin-gui" "$@"
RUNGUI
cat > "$STAGE/run-nogui.sh" <<'RUNNOGUI'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -x "$HERE/dolphin" ] || { echo "Dolphin NoGUI binary is missing" >&2; exit 1; }
exec "$HERE/dolphin" "$@"
RUNNOGUI
cat > "$STAGE/install-desktop-entry.sh" <<'INSTALLENTRY'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/applications"
mkdir -p "$DEST"
cat > "$DEST/dolphin-rtcore.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Dolphin Rt:Core
Comment=GameCube and Wii emulator
Exec="$HERE/run-gui.sh" %U
Icon=applications-games
Terminal=false
Categories=Game;Emulator;
StartupNotify=true
EOF
chmod 644 "$DEST/dolphin-rtcore.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DEST" >/dev/null 2>&1 || true
echo "Installed XFCE application-menu entry: $DEST/dolphin-rtcore.desktop"
INSTALLENTRY
chmod 755 "$STAGE/run-gui.sh" "$STAGE/run-nogui.sh" "$STAGE/install-desktop-entry.sh"
for report in "$TMP"/dolphin.ldd "$TMP"/dolphin-gui.ldd; do
  [ -s "$report" ] || { echo "missing runtime dependency report: $report" >&2; exit 1; }
  install -m644 "$report" "$STAGE/RUNTIME-LIBRARIES-$(basename "$report" .ldd).txt"
done
cat > "$STAGE/README-MX-XFCE.md" <<'MXREADME'
# Dolphin Rt:Core // Linux Desktop x86_64

This is the native x86_64 Linux desktop build. It is separate from the AArch64/H700 handheld binaries.

## Runtime baseline

- x86_64 Linux
- glibc 2.35 or newer (build baseline: Ubuntu 22.04)
- Qt 6 runtime libraries and Qt XCB platform plugin
- X11 desktop session (the default launcher is configured for MX XFCE)

MX Linux editions based on Debian 12 or newer are the intended starting point. Older MX releases may not provide a new enough glibc/Qt 6 runtime; check BUILDINFO.txt and the dependency reports before use.

## Install runtime dependencies

Run in an MX XFCE terminal:

    sudo apt update
    sudo apt install libsdl2-2.0-0 libevdev2 libudev1 libusb-1.0-0 libpulse0 libasound2 libcurl4 liblzo2-2 libzstd1 liblzma5 libpng16-16 zlib1g libbz2-1.0 libegl1 libgles2 libgl1 libdrm2 libbluetooth3 libhidapi-hidraw0 libxi6 libx11-6 libxrandr2 libxinerama1 libxcursor1 libxext6 libwayland-client0 libxkbcommon0 libdecor-0-0 libqt6core6 libqt6gui6 libqt6widgets6 libqt6opengl6 libqt6svg6 qt6-qpa-plugins

Some names vary by MX/Debian release. RUNTIME-LIBRARIES-*.txt lists the exact SONAMEs checked on the build host. If APT cannot find a package, check the matching MX repository name rather than mixing packages from another distribution.

## Start Dolphin

Extract the archive, open a terminal in the extracted folder, and run:

    ./run-gui.sh

The GUI launcher selects Qt's xcb platform plugin by default, appropriate for a normal XFCE/X11 session. Add Dolphin to the current user's XFCE application menu with:

    ./install-desktop-entry.sh

The NoGUI frontend is also included for scripts and command-line use:

    ./run-nogui.sh --help

## Included files

- dolphin-gui — Qt desktop frontend
- dolphin / dolphin-nogui — NoGUI frontend
- Sys/ — exact resource tree from this same Dolphin source build
- BUILDINFO.txt — upstream revision, compiler, flags and GLIBC requirement
- RUNTIME-LIBRARIES-*.txt — resolved runtime dependency reports
- source-*.tar.xz — corresponding source archive
- launch helpers and per-user XFCE desktop-entry installer

A successful CI build proves that the binaries link in the build environment and that the resource bundle is complete. It does not certify every MX release or every game. Test video, audio, controller input and clean shutdown on the target PC.
MXREADME
(
  cd "$STAGE"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
SAFE_ID="$(printf '%s' "$BUILD_ID" | tr -cd '[:alnum:]._-')"
[ -n "$SAFE_ID" ] || SAFE_ID=local
SAFE_ID="$(printf '%s' "$SAFE_ID" | cut -c1-12)"
ARCHIVE="$OUT/Dolphin-RtCore-Desktop-x86_64-$SAFE_ID.tar.gz"
tar -C "$TMP" -czf "$ARCHIVE" "$BUNDLE"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
echo "built $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
echo "sha256: $(cut -d' ' -f1 "$ARCHIVE.sha256")"
