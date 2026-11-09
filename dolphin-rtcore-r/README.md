# Dolphin Rt:Core R — ROCKNIX (experimental)

> [!WARNING]
> **Status, from the first real test on a device:** the installer works, the Rt:Core systems and the options show up in
> EmulationStation, you can pick a game — **and the emulator does not start.** Run `./rtcore.sh doctor` (below) to see why.

## Why it probably does not start
The `dolphin` binary used so far is built for **muOS / Knulli**: its no-GUI frontend can only open a window through
`fbdev` (the Mali blob's framebuffer EGL) or `headless` — it contains no X11, Wayland or KMS platform. **ROCKNIX on the H700
runs a Wayland compositor (sway) on the open-source Panfrost/Mesa GPU stack**, where that path does not exist. On top of that
the binary asks for an unversioned `libEGL.so` that a ROCKNIX image usually only has as `libEGL.so.1`.

The launcher now links the libraries it can find (`<release>/lib`) and logs what is still missing, but a window platform cannot be
faked: ROCKNIX needs a Dolphin **built for it** (Wayland or X11 under XWayland, GLES via Mesa). That is a build job, not a settings one.

## The way out: a Dolphin built for ROCKNIX
ROCKNIX's own Dolphin package carries Wayland patches (a `--platform=wayland` for the no-GUI frontend, an EGL-on-Wayland context).
[`../dolphin-build/`](../dolphin-build) applies exactly those on top of upstream Dolphin 2606 and builds the no-GUI binary for
aarch64 in CI. The launcher already knows what to do with it: if the binary contains the Wayland platform and a compositor is running
it passes `--platform=wayland` by itself (option *Window platform → Auto*); a muOS/Knulli (fbdev-only) binary is never asked for Wayland.
That build is **verified up to the patches and the new sources; it has not been compiled or run yet** — see its README.

## Find out in 10 seconds
```sh
cd /storage/emulators/dolphin-rtcore-r      # wherever you extracted it
./rtcore.sh doctor                          # changes nothing; prints the verdict
```
It reports: binary architecture, missing libraries, the display stack (sway, Wayland/X11 variables, `/dev/fb0`, GPU driver),
the window platforms the binary offers, whether ES picked up our systems and options, and the tail of `logs/launch.log`.
When a game exits within 6 seconds the launcher writes the same short report into `logs/launch.log` by itself.

## Options (24 per-game settings)
Open a game's *Advanced options* in EmulationStation. **Every new option starts at "Profile default", which changes nothing** — so
if you never touch them, games behave exactly as the chosen profile says. Settings are stored per game in
`/storage/.config/system/configs/system.cfg` and applied to Dolphin at launch with `-C Section.Key=Value`.
The list lives in one file, [`config/options.tsv`](config/options.tsv); the ES menu and the launcher are both generated from it.

**Game**

| Option | What it does | Choices |
| :--- | :--- | :--- |
| Game Settings | Apply the per-game .ini fixes shipped with the core. | On · Off |
| Hd Textures | Load custom textures from core/Load/Textures. | Off · On |
| Cheats | Enable cheat codes. | Off · On |
| Show Fps | Show the FPS counter. | Off · On |

**Controls**

| Option | What it does | Choices |
| :--- | :--- | :--- |
| Controller | Stick layout used by the controller profiles. | 2 sticks · 1 stick · No sticks |
| Wiimote Position | Wii only. How the Wiimote is held. | Upright · Sideways |
| Safe Exit | Button combo that closes the game cleanly. | Select + Start · Menu + Start |

**Graphics**

| Option | What it does | Choices |
| :--- | :--- | :--- |
| Internal Resolution | Render scale. 1x is native (640x480); higher is much heavier. | Profile default · 1x (native) · 2x · 3x |
| Aspect Ratio | How the picture is fitted to the screen. | Profile default · Game default (auto) · Force 16:9 · Force 4:3 · Stretch to screen |
| Widescreen Hack | Stretch 4:3 games to 16:9 without distortion (can glitch some games). | Profile default · On · Off |
| Anisotropic Filtering | Sharper textures at an angle. Costs GPU time. | Profile default · Off · 2x · 4x · 8x · 16x |
| Force Texture Filtering | Smooth every texture, even ones the game wants blocky. | Profile default · On · Off |
| Anti-Aliasing (Msaa) | Smooths edges. Very heavy on this GPU. | Profile default · Off · 2x · 4x |
| V-Sync | Wait for the screen refresh (removes tearing, can lower FPS). | Profile default · On · Off |
| Shader Compilation | How shaders are built when a game first needs them. | Profile default · Synchronous (stutter, no glitches) · Synchronous ubershaders · Asynchronous ubershaders · Asynchronous (skip drawing, fastest) |
| Efb Access From Cpu | Needed by some effects (e.g. lens flares); slows games down. | Profile default · On · Off |
| Pixel Lighting | Per-pixel lighting. Heavy. | Profile default · On · Off |

**Performance**

| Option | What it does | Choices |
| :--- | :--- | :--- |
| Emulation Speed | Game speed limit. | Profile default · 50% · 75% · 100% · 125% · 150% · Unlimited |
| Cpu Clock | Emulated CPU speed. Below 1x can speed up heavy games (and desync some). | Profile default · 0.5x · 0.75x · 1.5x · 2x · 1x (normal) |
| Dual Core | Run CPU and GPU emulation on separate threads. | Profile default · On · Off |
| Mmu Emulation | Needed by a few games; slower. | Profile default · On · Off |

**Audio**

| Option | What it does | Choices |
| :--- | :--- | :--- |
| Volume | Emulated volume. | Profile default · 100% · 75% · 50% · 25% · Mute |
| Audio Engine (Hle) | On = fast high-level audio. Off = accurate but very heavy. | Profile default · On · Off |

Add or change an option by editing `config/options.tsv`, then run `./install.sh` again (it re-merges the menu, idempotently).

## How the ES menu is installed
This EmulationStation reads **one** `es_features.cfg` (your `/storage/.emulationstation/es_features.cfg` first, else the system one)
and does not merge extra files, and it does not know `<sharedFeatures>`. So the installer inserts our `<emulator name="rtcore-r">`
block between `RTCORE-R BEGIN/END` markers in your file (starting from a copy of the system file if you have none), keeps a one-time
backup `es_features.cfg.rtcore.bak`, validates the XML before writing, and `./uninstall.sh` takes the block out again.

## Differences from the Knulli port
| | Knulli (K) | ROCKNIX (R) |
| :--- | :--- | :--- |
| user data | `/userdata` | `/storage` |
| ES custom systems | `…/configs/emulationstation/es_systems_*.cfg` | `/storage/.emulationstation/es_systems_*.cfg` |
| settings file | `batocera.conf` | `/storage/.config/system/configs/system.cfg` |
| option menu | `es_features_rtcore.cfg` (shared features) | block merged into `es_features.cfg` (inline features, submenus) |
| restart ES | `S31emulationstation` | `systemctl restart emulationstation` |
| exit | Rt watcher on `/dev/input/js0` | Rt watcher **and** ROCKNIX's own hotkey (`set_kill`) |

## Install
```sh
./install.sh --dry-run     # writes nothing
./install.sh               # systems + options, restarts ES
./uninstall.sh             # removes both; this folder, ROMs and saves are untouched
```
You must supply an aarch64 `core/dolphin` (see the root `tools/make-port-release.sh`).
