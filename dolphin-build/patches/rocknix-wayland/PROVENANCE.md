# Wayland patches for Dolphin — provenance

These five patches are **unmodified copies** from the ROCKNIX distribution:

- Repository: https://github.com/ROCKNIX/distribution
- Commit copied from: `f0c505fec9baf42095ba7476fa19765e8ee81b93` (2026-11-06)
- Path: `projects/ROCKNIX/packages/emulators/standalone/dolphin-sa/patches/`
- Package licence: `GPL-2.0-or-later` (as declared in that package's `package.mk`); Dolphin itself is GPL-2.0-or-later.

| Patch | What it does | Needed for |
| :--- | :--- | :--- |
| `000-hotkeys.patch` | adds a `HOTKEY` pad button and its handling | `015` references `PAD_BUTTON_HOTKEY` |
| `011-wayland-cmake.patch` | `ENABLE_WAYLAND` option, finds wayland-client/-egl/-scanner/-protocols | build |
| `012-wayland-surface-dimensions.patch` | window-system info carries the surface size | video |
| `013-wayland-egl.patch` | EGL context on a `wl_egl_window` | OpenGL ES rendering |
| `015-wayland-nogui-platform.patch` | **`--platform=wayland` for the nogui frontend** (xdg-shell, decorations, fractional scale, viewporter) | the actual window |

Skipped on purpose: `001`–`010` (ROCKNIX defaults, paths, OSD, 240p…: they would fight Rt:Core's own layout),
`014` (Vulkan on Wayland: Panfrost on the H700 has no Vulkan), `016`/`017` (Qt).

Verified here: the five apply cleanly, in this order, on upstream Dolphin commit `6094cfcf7b8fba733b3116fdf3414d51c1c0e4a4`
(2606), and `PlatformWayland.cpp`, `EGLWayland.cpp` and `GLContext.cpp` pass a C++23 syntax-only compile against the real
Wayland headers. **Not verified:** a full build, and running it on a device. Run `../../verify-patches.sh` to repeat the checks.
