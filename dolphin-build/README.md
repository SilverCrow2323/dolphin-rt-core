# dolphin-build — reproducible ARM64 builds

This directory builds the upstream Dolphin revision pinned in [`DOLPHIN_REF`](DOLPHIN_REF), applies only the patches for the selected platform, and packages the exact corresponding GPL source.

## Build matrix

| Target | Runtime/display path | Frontend | Intended use |
|---|---|---|---|
| `muos` | FBDev + SDL/EGL/GLES; Wayland/X11 disabled | NoGUI | muOS Andromeda on H700, launched by Rt:Core / Rt:UI |
| `knulli` | FBDev + SDL/EGL/GLES; Wayland/X11 disabled | NoGUI | Knulli H700 |
| `rocknix` | Wayland + SDL/EGL/GLES | NoGUI | ROCKNIX H700; applies the platform patch series |
| `desktop` | X11 + Wayland | Qt GUI and/or NoGUI | Generic ARM64 Linux desktop and diagnostics |

The embedded targets intentionally use Dolphin's **NoGUI frontend**. This does not mean games render without graphics; it means Dolphin does not create its own desktop management window. The game is rendered through the selected backend. muOS already provides its own user-facing GUI through the Rt:Core LÖVE application and muOS launcher. A Qt desktop window is not a suitable replacement for that firmware integration.

The desktop target builds upstream's two frontends separately:
- `dolphin`: NoGUI frontend.
- `dolphin-gui`: Qt desktop frontend.

## Local usage

Run on a native AArch64 Debian/Ubuntu host, or use GitHub Actions:

```bash
# muOS Andromeda / H700
./build-dolphin.sh --target muos --frontend nogui --out ./out/muos

# Knulli / H700
./build-dolphin.sh --target knulli --frontend nogui --out ./out/knulli

# ROCKNIX / H700
./verify-patches.sh
./build-dolphin.sh --target rocknix --frontend nogui --out ./out/rocknix

# ARM64 Linux desktop: both frontends
./build-dolphin.sh --target desktop --frontend both --out ./out/desktop
```

Options include `--ref SHA`, `--jobs N`, `--no-lto`, `--tune cortex-a53|none`, `--deps`, and `--no-deps`. H700 tuning uses `-mtune=cortex-a53` only: it does not require additional CPU instructions, preserving AArch64 compatibility.

## CI artifacts

The native ARM64 workflow builds muOS, Knulli and ROCKNIX NoGUI variants, plus ARM64 desktop NoGUI and Qt GUI variants. Each successful job uploads its binary, `BUILDINFO.txt`, hashes and GPL corresponding-source archive. A CI build is not a hardware certification; each firmware/device combination still needs a real-device smoke test.

## Release engineering rules

1. Keep the upstream commit pinned; do not silently float to upstream HEAD.
2. Keep platform-specific patches isolated. ROCKNIX Wayland patches must not leak into muOS/Knulli fbdev builds.
3. Preserve the muOS launcher contract: `/opt/muos/share/emulator/dolphin/dolphin -e ROM -u EMUDIR`.
4. Never label a build hardware-tested until it has been launched on the actual device.
5. Distribute the exact corresponding source archive with every binary, as required by the GPL.
