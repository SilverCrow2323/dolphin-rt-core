#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGER="$ROOT/dolphin-build/package-desktop.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
INPUT="$TMP/input"
OUT="$TMP/out"
mkdir -p "$INPUT/Sys/GC" "$INPUT/Sys/Resources" "$OUT"
cat > "$TMP/probe.c" <<'C'
int main(void) { return 0; }
C
cc "$TMP/probe.c" -o "$INPUT/dolphin"
cp "$INPUT/dolphin" "$INPUT/dolphin-gui"
cp "$INPUT/dolphin" "$INPUT/dolphin-nogui"
chmod 755 "$INPUT"/dolphin*
printf 'western font fixture\n' > "$INPUT/Sys/GC/font_western.bin"
printf 'Japanese font fixture\n' > "$INPUT/Sys/GC/font_japanese.bin"
printf 'DSP ROM fixture\n' > "$INPUT/Sys/GC/dsp_rom.bin"
printf 'DSP coefficient fixture\n' > "$INPUT/Sys/GC/dsp_coef.bin"
printf 'OSD font fixture\n' > "$INPUT/Sys/Resources/OSD_Font.ttf"
printf 'desktop packaging test\n' > "$INPUT/BUILDINFO.txt"
mkdir -p "$TMP/source"
printf 'matching Dolphin source fixture\n' > "$TMP/source/README"
tar -cJf "$INPUT/source-test.tar.xz" -C "$TMP/source" .
bash "$PACKAGER" --input "$INPUT" --out "$OUT" --build-id test-build
ARCHIVE="$OUT/Dolphin-RtCore-Desktop-x86_64-test-build.tar.gz"
[ -s "$ARCHIVE" ]
[ -s "$ARCHIVE.sha256" ]
tar -tzf "$ARCHIVE" > "$TMP/archive-list.txt"
grep -Fxq 'Dolphin-RtCore-Desktop-x86_64/dolphin' "$TMP/archive-list.txt"
grep -Fxq 'Dolphin-RtCore-Desktop-x86_64/dolphin-gui' "$TMP/archive-list.txt"
grep -Fxq 'Dolphin-RtCore-Desktop-x86_64/Sys/GC/font_western.bin' "$TMP/archive-list.txt"
grep -Fxq 'Dolphin-RtCore-Desktop-x86_64/README-MX-XFCE.md' "$TMP/archive-list.txt"
grep -Fxq 'Dolphin-RtCore-Desktop-x86_64/RUNTIME-LIBRARIES-dolphin-gui.txt' "$TMP/archive-list.txt"
mkdir -p "$TMP/extracted"
tar -xzf "$ARCHIVE" -C "$TMP/extracted"
BUNDLE="$TMP/extracted/Dolphin-RtCore-Desktop-x86_64"
HOME="$TMP/home" "$BUNDLE/install-desktop-entry.sh"
grep -Fq 'Dolphin Rt:Core' "$TMP/home/.local/share/applications/dolphin-rtcore.desktop"
grep -Fq "$BUNDLE/run-gui.sh" "$TMP/home/.local/share/applications/dolphin-rtcore.desktop"
(
  cd "$BUNDLE"
  sha256sum -c SHA256SUMS >/dev/null
)
echo "[OK] x86_64 desktop bundle contains GUI/NoGUI, matching Sys, runtime reports and source"
echo "[OK] XFCE desktop entry installer and bundle SHA256 manifest work"
