# dolphin-build // Reproducible ARM64 builds

> **Reference board: Anbernic RG35XX H / Allwinner H700 / AArch64.**
>
> This directory builds the upstream Dolphin revision pinned in [DOLPHIN_REF](DOLPHIN_REF), applies only the patches for the selected platform, validates the produced ELF payloads and packages the corresponding GPL source.

## Build matrix

| Target | Runtime/display path | Frontend | Intended use |
|---|---|---|---|
| **muos** | FBDev + SDL/EGL/GLES; Wayland/X11 disabled | NoGUI | muOS Andromeda on RG35XX H / H700, launched by Rt:Core / Rt:UI |
| **muos-qt** | Qt GUI, EGLFS intended; X11/Wayland disabled | NoGUI + Qt GUI | Experimental muOS Qt frontend; runtime compatibility unverified |
| **knulli** | FBDev + SDL/EGL/GLES; Wayland/X11 disabled | NoGUI | Knulli on RG35XX H / H700 |
| **rocknix** | Wayland + SDL/EGL/GLES | NoGUI | ROCKNIX H700; applies the platform patch series |
| **desktop** | X11 + Wayland | Qt GUI and/or NoGUI | Generic ARM64 Linux desktop and diagnostics |

The embedded targets intentionally use Dolphin's **NoGUI frontend**. This does not mean games render without graphics; it means Dolphin does not create its own desktop management window. The game is rendered through the selected backend. muOS supplies its own user-facing integration through the Rt:Core LÖVE application and launcher.

The separate **muos-qt** experiment tests whether Dolphin Qt can run through Qt EGLFS without X11/Wayland. It is not the recommended muOS path and must not replace the stable NoGUI executable. A successful compile is not evidence that Qt EGLFS, the H700 Mali driver, input, display sizing, rendering or shutdown will work on the actual device.

## Local usage

Run on a native AArch64 Debian/Ubuntu host, or use GitHub Actions:

~~~bash
# muOS Andromeda / RG35XX H (H700)
./build-dolphin.sh --target muos --frontend nogui --out ./out/muos

# Knulli / RG35XX H
./build-dolphin.sh --target knulli --frontend nogui --out ./out/knulli

# ROCKNIX / H700
./verify-patches.sh
./build-dolphin.sh --target rocknix --frontend nogui --out ./out/rocknix

# Experimental Qt frontend for muOS (compile test; device/runtime validation required)
./build-dolphin.sh --target muos-qt --frontend both --out ./out/muos-qt

# ARM64 Linux desktop: both frontends
./build-dolphin.sh --target desktop --frontend both --out ./out/desktop
~~~

Options include **--ref SHA**, **--jobs N**, **--no-lto**, **--tune cortex-a53|none**, **--deps** and **--no-deps**. H700 tuning uses **-mtune=cortex-a53** only: it does not require additional CPU instructions and preserves AArch64 compatibility.

## Frontends and runtime models

- **NoGUI**: Dolphin does not provide the desktop management window. The platform integration starts a game using the firmware display stack.
- **Qt GUI**: desktop-oriented GUI path. On muOS it is only an experimental EGLFS build, not the primary launcher.
- **muOS**: FBDev/EGL path using the firmware's graphics stack. Keep the production launcher contract aligned with the muOS runtime scripts.
- **Knulli**: separate fbdev-oriented package and launcher integration.
- **ROCKNIX**: Wayland/Panfrost path; its patch series is isolated and must not leak into muOS/Knulli builds.

## Output contract

Each successful build writes an output directory containing the applicable files:

- **dolphin** — NoGUI executable.
- **dolphin-gui** — Qt GUI executable when requested.
- **Sys/** — exact upstream Dolphin system resources from the same checkout for handheld targets.
- **lib/** — private HIDAPI runtime dependency for muOS targets.
- **qt6/** — experimental Qt runtime and EGLFS plugin for **muos-qt**.
- **BUILDINFO.txt** — upstream revision, compiler, flags, patch hashes and dependency information.
- **source-<ref>.tar.xz** — corresponding source archive.

Keep the executable and **Sys/** tree from the same output. The package builders validate required GameCube fonts and DSP resources; do not substitute resources from another Dolphin revision.

## ELF validation

The native ARM64 workflow calls [validate-aarch64-elf.sh](validate-aarch64-elf.sh) for the main executables and relevant runtime libraries/plugins before artifact upload. It fails closed if the file is missing/empty/unreadable, **readelf** fails, the ELF class is not ELF64 or the machine is not AArch64.

Run the validator and its mocked regression contract locally:

~~~bash
bash dolphin-build/validate-aarch64-elf.sh ./out/muos/dolphin
bash tests/test_aarch64_elf_validator.sh
~~~

The contract test covers a valid AArch64 header, ELF32, x86-64, malformed headers, readelf failure, missing/empty files, missing arguments and missing **readelf**.

## Package the exact build output

### muOS Andromeda

~~~bash
DOLPHIN_BIN="$PWD/out/muos/dolphin" DOLPHIN_SYS_DIR="$PWD/out/muos/Sys" DOLPHIN_LIB_DIR="$PWD/out/muos/lib" bash dolphin-rtcore-muos/tools/build-muxupd.sh ./dist
~~~

### Experimental muOS Qt 6

~~~bash
DOLPHIN_NO_GUI_BIN="$PWD/out/muos-qt/dolphin" DOLPHIN_QT_BIN="$PWD/out/muos-qt/dolphin-gui" DOLPHIN_QT_LIB_DIR="$PWD/out/muos-qt/qt6/lib" DOLPHIN_QT_PLUGIN_DIR="$PWD/out/muos-qt/qt6/plugins" DOLPHIN_LIB_DIR="$PWD/out/muos-qt/lib" DOLPHIN_SYS_DIR="$PWD/out/muos-qt/Sys" bash dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh ./dist
~~~

The Qt launcher defaults to **QT_QPA_PLATFORM=eglfs**. Treat this package as a test payload until the exact RG35XX H / muOS image has been validated with real input and display hardware.

### Knulli and ROCKNIX

~~~bash
./tools/make-port-release.sh k --binary "$PWD/out/knulli/dolphin" --sys-dir "$PWD/out/knulli/Sys"
./tools/make-port-release.sh r --binary "$PWD/out/rocknix/dolphin" --sys-dir "$PWD/out/rocknix/Sys"
~~~

## CI artifacts

The native ARM64 workflow builds muOS NoGUI, experimental muOS Qt plus its matching NoGUI base, Knulli and ROCKNIX NoGUI variants, and ARM64 desktop NoGUI/Qt GUI variants. Each successful job uploads the binary, **BUILDINFO.txt**, hashes and corresponding GPL source archive. Artifacts are only available after successful completion; queued or in-progress runs are not releases.

A CI build is not a hardware certification. For the RG35XX H, record the firmware version, build SHA and test the launcher, private libraries, system fonts, DSP resources, controller input, video, audio and clean exit on the physical device.

## Release engineering rules

1. Keep the upstream commit pinned; do not silently float to upstream HEAD.
2. Keep platform-specific patches isolated. ROCKNIX Wayland patches must not leak into muOS/Knulli fbdev builds.
3. Preserve the muOS launcher contract: **/opt/muos/share/emulator/dolphin/dolphin --platform=fbdev --video_backend=OGL -e ROM -u EMUDIR**.
4. Build every handheld target with relocatable **Sys/** resources beside the executable.
5. Keep the stable muOS NoGUI executable separate from the experimental Qt 6 payload.
6. Never label a build hardware-tested until it has been launched on the actual device and the test evidence is recorded.
7. Distribute the exact corresponding source archive with every binary, as required by the GPL.
