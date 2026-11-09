# dolphin-build — build the emulator, with the source

The `dolphin` binary used so far (`Dolphin 2412-81-dirty`, aarch64) opens windows only through **fbdev** (muOS / Knulli and their
Mali framebuffer). **ROCKNIX on the H700 has no fbdev path and no X server** (its wlroots is built with `-Dxwayland=disabled`):
it needs a build whose no-GUI frontend can talk **Wayland**. This folder builds one, and it also makes the build reproducible,
which is what the GPL asks of anyone who ships the binary.

## What it builds
| `--target` | Window platforms | Patches |
| :--- | :--- | :--- |
| `rocknix` | Wayland (+ headless) | ROCKNIX's `000, 011, 012, 013, 015` — see [`patches/rocknix-wayland/PROVENANCE.md`](patches/rocknix-wayland/PROVENANCE.md) |
| `fbdev` | fbdev (+ headless): same feature set as the current muOS/Knulli binary | none (add yours in `patches/local/`) |

Base: upstream Dolphin commit pinned in [`DOLPHIN_REF`](DOLPHIN_REF) (`6094cfc`, release **2606**). The old binary is 2412 plus 81 commits
plus local changes nobody has the source of; **2606 is a different base**, so behaviour can differ. Profiles use plain Dolphin keys that
are stable across these versions, but test.

Flags worth knowing: no Qt, no Vulkan (Panfrost on the H700 has none), no Discord/RetroAchievements/mGBA/analytics (less code and fewer
runtime libraries), `-mtune=cortex-a53` (scheduling only: no new instructions, still runs on every aarch64 core), LTO on by default.

## Run it
- **In CI (recommended):** GitHub → Actions → *Build Dolphin (aarch64)* → Run workflow. Native arm64 runner, Debian trixie, ~1–3 h.
  It uploads `dolphin`, `BUILDINFO.txt` and `source-<ref>.tar.xz` as an artifact.
- **On an arm64 Debian/Ubuntu box:** `sudo ./build-dolphin.sh --target rocknix --deps`
- **Check the patches only (1 minute, any machine):** `./verify-patches.sh --syntax`

Then build the port archive with it: `tools/make-port-release.sh r --binary out/dolphin`.

## What is verified, and what is not
| Verified here | Not verified |
| :--- | :--- |
| the five patches apply cleanly, in order, to the pinned upstream commit | **a full build** (this machine has 1 core / 3 GB: Dolphin does not fit) |
| `PlatformWayland.cpp`, `EGLWayland.cpp`, `GLContext.cpp` compile (C++23, syntax only) against the real Wayland headers | the first CI run may need a dependency added to the list in `build-dolphin.sh` |
| every `-D` flag exists in the patched CMake files | **running on a device**: Panfrost GLES3 on a Mali-G31 may be slower or lack features Dolphin wants |
| the launcher picks `--platform=wayland` only when the binary has it (tests) | whether the pad / hotkey patch (`000`) needs extra mapping in the profiles |

## GPL
Dolphin is GPL-2.0-or-later. Whoever distributes a binary built here must offer the corresponding source: `source-<ref>.tar.xz`
(upstream tree + the applied patches + these scripts) is produced next to every binary for exactly that. Put your own changes in
`patches/local/` so they are part of it.
