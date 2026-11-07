<div align="center">
  <h1>
    <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/dolphinrt_icon.png" width="48" alt="Dolphin Rt:Stream" style="vertical-align: middle; margin-right: 12px;">
    Dolphin Rt:Stream
    <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/spdw_symbol.png" width="36" alt="SPDW" style="vertical-align: middle; margin-left: 12px;">
  </h1>
  <h3><b><i>Your GameCube &amp; Wii library — streamed to the handheld, no disc required.</i></b></h3>
  <p><b>Sunshine + Moonlight, with a GameCube-style 2.5D frontend, editable controller profiles, and one-tap library sync.</b></p>
  <p>
    <a href="https://github.com/SilverCrow2323/dolphin-rt-stream/releases/latest">
      <img src="https://img.shields.io/badge/version-4.2.1-8C59F2?style=for-the-badge&logo=github" alt="Version">
    </a>
    <img src="https://img.shields.io/badge/platform-muOS-4FA8C7?style=for-the-badge&logo=linux" alt="Platform">
    <img src="https://img.shields.io/badge/stream-Sunshine%20%C2%B7%20Moonlight-FF6F00?style=for-the-badge" alt="Stream">
    <img src="https://img.shields.io/badge/lab-SPDW%20Factory-00FFCC?style=for-the-badge" alt="SPDW">
    <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License">
  </p>
</div>
<div align="center">
  <img src="https://github.com/SilverCrow2323/dolphin-rt-stream/blob/main/docs/img/mock-cover.jpeg" alt="Boxart" width="500" style="border-radius: 50%; box-shadow: 0 4px 10px rgba(0,0,0,0.3); margin-bottom: 8px;">
</div>

---

### ⚡ **TL;DR — <u>The Pitch</u>**

> ***Dolphin runs on your PC. The handheld is the TV. Moonlight is the wire. Dolphin Rt:Stream is the frontend that makes it feel like a real console.***
>
> The handheld gets a **GameCube-style 2.5D library** with cover flow, a boot animation, and a streaming session. The PC keeps the ROMs, the emulator, and the controller mapping — but you can **edit that mapping from the handheld itself** without ever touching the PC's desktop.
>
> Part of the **[Dolphin Rt:Core](https://github.com/SilverCrow2323/Dolphin-Rt-Core)** ecosystem.


## What it is / What it's not

**It is** — a handheld app (LÖVE, 2.5D GameCube UI) that streams from Sunshine, plus a PC portal (Python/Tk) that scans your ROMs, registers them in Sunshine, serves the library over HTTP, and lets you edit Dolphin's controller mapping from the handheld itself.

**It's not** — an emulator. The handheld never decodes a GameCube frame. The PC does all the rendering; Moonlight streams the video + virtual Xbox pad.

```
PC (Linux, X11)                      Handheld 
────────────────────                 ─────────────────────
Dolphin ──render──▶ Sunshine          Moonlight ──▶ screen
Sunshine :47989 ──H.264/H.265───────▶ Moonlight ──▶ pad
Library :8765 ──library.tsv─────────▶ Dolphin Rt:Stream
Profiles ◀──────── /ctl ──────────── edit mapping
```

---

## What's inside

### Handheld (`Dolphin RtStream/`)

| Feature | Notes |
|---|---|
| Cover Flow / Grid / List library | GameCube, Wii, Favorites tabs (Recent merged into Favorites) |
| Boot animation | 120-frame sprite sheet, "Dolphin Rt:Core" logo with electric flicker |
| **SERVER STATUS panel** | SUNSHINE + LIBRARY LEDs, refreshed every 15s |
| **Pre-flight ping** | A on a game → checks PC first, clear error if off |
| **Guide panel (M)** | short intro + per-value descriptions, ✓ recommended, ▲ warning |
| **Controls screen** | virtual pad drawn on screen, edit bindings with ◀▶, Y to switch profile |
| **Search** | filter current tab by title or app name |
| 5 themes · on-screen keyboard · everything touch-free | START ▸ Interface |

### PC (`pc/`)

| Feature | Notes |
|---|---|
| ROM scan on every start | keeps `library.tsv` + Sunshine `apps.json` fresh |
| Cover art auto-download | GameTDB, or `<rom>.png` next to the ROM |
| Dolphin fullscreen | no main window, no desktop visible, panel hidden |
| 4:3 during stream | `xrandr`, restored automatically (X11 only) |
| Controller profile manager | GCPad / Wiimote / Hotkeys families, applied before each launch |
| Library server | `:8765` + `/profiles.tsv` + `/ctl` (token-protected) |
| Header LEDs | SUNSHINE + LIBRARY, always visible |
| Connection test | ping LAN + WAN, port checks, tuning advice |
| Quick tools | rebuild, refresh/cleanup covers, config export/import |
| Autostart | Sunshine, server, portal, optional LightDM autologin |

---

## Quick start

> **Install guide:** see **[docs/INSTALL.md](docs/INSTALL.md)** for the full step-by-step (PC + handheld + first pairing + troubleshooting).

### Requirements

| | |
|---|---|
| **PC** | Linux **X11** (XFCE / MX Linux tested), Python ≥ 3.9 + Tk, [Dolphin](https://dolphin-emu.org), [Sunshine](https://github.com/LizardByte/Sunshine) |
| **Handheld** | muOS with LÖVE + Moonlight, or the `.muxapp` full bundle |
| **Network** | LAN, or Tailscale / WireGuard |

### 1. PC

```bash
sudo apt install ./spdw-stream-portal_4.2.1_all.deb
spdw-stream-portal
```

1. **LIBRARY** — add GameCube / Wii ROM folders (scanned at every start)
2. **SERVICES** — install/start Sunshine, start the library server
3. **SYSTEM** — checklist should be green; install controller profiles; copy the edit token
4. Restart Sunshine once

### 2. Handheld

1. Copy either `DolphinStream-muOS-4.2.1.zip` or `Dolphin_RtStream-4.2.1.muxapp` to the SD card
2. Install via **muOS → Applications**, or unzip to `ROMS/APPLICATIONS/` → get `Dolphin RtStream/`
3. **START ▸ Streaming** — set PC host + Edit token
4. **START ▸ Tools ▸ Pair with Sunshine** — type the PIN into Sunshine's web UI
5. **SELECT** to sync, **A** to play

Leave a stream with `START + SELECT + L1 + R1`, or the Dolphin hotkey `MODE + START`.

### Which package?

| Package | Size | Target |
|---|---|---|
| `spdw-stream-portal_4.2.1_all.deb` | 398 KB | PC only |
| `DolphinStream-muOS-4.2.1.zip` | ~1.5 MB | Handheld with muOS Moonlight installed |
| `Dolphin_RtStream-4.2.1.muxapp` | ~3.5 MB | Handheld without Moonlight (full bundle) |

Both handheld packages use the same `tools/paths.sh`: if muOS provides `love`/`moonlight`/`keys`, the app uses them; otherwise the `.muxapp` ships its own. `gptokeyb2` is bundled in both — muOS Moonlight does not include it.

---

## Controls (handheld)

| Button | Library | Menus | Overlays |
|---|---|---|---|
| **D-pad ◀ ▶** | prev / next cover | change value | — |
| **D-pad ▲ ▼** | jump 4 covers | move | move |
| **L1 / R1** | switch tab | prev / next section | — |
| **A** | play | confirm | select |
| **X** | favorite | — | — |
| **Y** | game menu | switch profile (Controls) | — |
| **M** | — | guide | guide |
| **SELECT** | sync | — | — |
| **START** | main menu | close all | close |
| **B** | exit | back | back |

Full controller mapping reference: **[docs/CONTROLS.md](docs/CONTROLS.md)**.

---

## Controller Profiles — Dolphin Sees an Xbox Pad

Moonlight turns the handheld's buttons into an Xbox pad. Sunshine exposes it on the PC as `Sunshine (libvirtualhid) X-Box Series Controller`. Dolphin's profile maps its GameCube/Wii buttons onto that virtual pad.

| Kind | Profiles | Notes |
|---|---|---|
| **GCPad** | `muos`, `muos-xbox` | `muos` = layout tested on RG35XX H · `muos-xbox` = standard Xbox positions |
| **Wiimote** | `muos`, `muos-nunchuk` | Sideways remote for 2D games · remote + nunchuk with IR on the right stick |
| **Hotkeys** | `muos`, `muos-minimal` | Everything on a MODE layer (hold MODE): Exit, Pause, save/load state, volume, speed |

**Hotkeys (muos):** `MODE+START` exit · `MODE+SELECT` pause · `MODE+TL/TR` save/load slot 1 · `MODE+D-pad ▲▼` volume · `MODE+D-pad ◀▶` speed · `MODE+Y` screenshot. Toggle Fullscreen is deliberately unmapped — it would bring the desktop back into the stream.

### Edit from anywhere:

```bash
# From the handheld: START ▸ CONTROLLER PROFILES
# From the portal:    SYSTEM ▸ CONTROLLER PROFILES
# From the CLI:
spdw-stream profiles list
spdw-stream profiles set GCPad muos Buttons/Z TL      # one binding
spdw-stream profiles active Wiimote muos-nunchuk      # switch profile
spdw-stream profiles apply --backup                   # write into Dolphin now
```

---

## No More Black Bars — 4:3 During the Stream

A 16:9 desktop is letterboxed on a 4:3 handheld. While a game streams, the PC switches to a 4:3 mode (default `1280x960`, via `xrandr`, X11 only) and restores the original mode afterwards. Dolphin fills that mode, the stream fills the handheld screen, nothing is stretched.

Configure in **SYSTEM ▸ DISPLAY ▸ Stream display mode** or keep the current mode. Stuck in 4:3 after a crash?

```bash
sh /usr/lib/spdw-stream-portal/display-mode.sh restore
```

---

## Diagnostics

```bash
spdw-stream preflight                    # 8 checks, exit 1 on critical failure
spdw-stream test-connection              # ping LAN + WAN, port checks, advice
spdw-stream cleanup covers               # remove orphan cover PNGs
spdw-stream config export ~/backup.json  # backup config
spdw-stream config import ~/backup.json  # restore config
spdw-stream status                       # human-readable checks
```

Handheld side: **START ▸ Tools ▸ Connection test, Last stream log, Verify Sunshine apps, Measure latency, Export diagnostics**.

Something broken? Start here: **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

---

## Documentation

- **`docs/INSTALL.md`** — Full step-by-step install + first pairing + troubleshooting
- **`docs/ARCHITECTURE.md`** — How the two halves talk
- **`docs/CONTROLS.md`** — Every controller mapping, in full
- **`docs/PROTOCOL.md`** — HTTP wire formats, token checks
- **`docs/TROUBLESHOOTING.md`** — What to do when it doesn't work
- **`docs/DEVELOPMENT.md`** — Build, test, screenshots
- **`CONTRIBUTING.md`** — How to send a pull request
- **`SECURITY.md`** — Threat model, what's protected
- **`CHANGELOG.md`** — Every release, in full

---

## Build from source

```bash
make test                                  # Python + headless Lua tests
make deb                                   # dist/spdw-stream-portal_*.deb
make muos                                  # dist/DolphinStream-muOS-*.zip
bash tools/build-muxapp.sh                 # dist/Dolphin_RtStream-*.muxapp
```

---

## Status

| Area | Verified |
|---|---|
| PC portal, profile manager, server, token checks | automated tests (CI) |
| Handheld UI, boot, Controls | LÖVE 11.5 + headless mock fuzz |
| Handheld → PC profile edit | end-to-end |
| Search, pre-flight, LEDs, guide panel | tested on RG35XX H |
| Dolphin flags, hotkey names, xrandr 4:3, panel hiding, pairing | confirmed on real hardware (base flow) |

---

## Screenshots

### Handheld

![Boot](docs/img/muos-boot.png)
![Hero](docs/img/muos-hero.png)
![Flow](docs/img/muos-flow.png)
![Grid](docs/img/muos-grid.png)
![List](docs/img/muos-list.png)
![Menu](docs/img/muos-menu.png)
![Streaming](docs/img/muos-streaming.png)
![Overlay](docs/img/muos-overlay.png)
![Guide](docs/img/muos-guide.png)
![Game Menu](docs/img/muos-game-menu.png)
![Interface](docs/img/muos-interface.png)
![Server Status](docs/img/muos-server-status.png)
![Controls GC](docs/img/muos-controls-gc.png)

### PC portal

![Portal Library](docs/img/portal-library.png)
![Portal Services](docs/img/portal-services.png)
![Portal System](docs/img/portal-system.png)
![Portal System Profiles](docs/img/portal-system-profiles.png)

*All cover art in the screenshots is generated demo art.*

---

## Visual vocabulary

Icons used across the handheld UI (from `muos/*/gui/assets/`).

| Icon | Name | Where it appears |
|---|---|---|
| <img src="docs/img/icons/gc.png" width="28"> | GameCube | GameCube tab, per-system chips |
| <img src="docs/img/icons/wii.png" width="28"> | Wii | Wii tab, per-system chips |
| <img src="docs/img/icons/star.png" width="24"> | Favorite | Favorites tab, per-game star |
| <img src="docs/img/icons/logo.png" width="120"> | Brand logo | Boot animation, About |

---

## Repository Layout

```text
dolphin-rt-stream/
├── muos/
│   └── Dolphin RtStream/          → copy to ROMS/APPLICATIONS
│       ├── gui/                   → LÖVE app (main.lua, boot.lua, controls.lua, ui.lua, cfg.lua)
│       ├── tools/                 → sync.sh, pair.sh, test.sh, ctl.sh, paths.sh, ...
│       ├── conf/                  → runtime config (stream.conf, ui.cfg) — NOT committed
│       ├── covers/                → cover PNG cache — NOT committed
│       └── mux_launch.sh          → launcher loop (love → moonlight)
├── pc/
│   ├── portal/                    → Tk portal, core, profile manager
│   ├── profiles/                  → packaged Dolphin controller profiles
│   ├── assets/                    → logos, cube sprites, Orbitron font (OFL)
│   ├── standalone/                → no-GUI script (scan ROMs, write Sunshine apps, serve)
│   └── packaging/debian/          → .deb metadata
├── docs/                          → architecture, protocol, controls, troubleshooting, development, install
├── tests/                         → unit tests + headless GUI tests
└── tools/                         → build-deb.sh, build-muos.sh, build-muxapp.sh
```

---

## Credits & The SPDW Lineage

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/sirpips.jpeg" alt="sirpips" width="110" style="border-radius: 50%; box-shadow: 0 4px 10px rgba(0,0,0,0.3); margin-bottom: 8px;">
  <br>
  <b>sirpips aka SilverCrow2323</b>
  <br>
  <i>SPDW Factory Lab — Lead Maintainer</i>
</div>

> [!NOTE]
> **Part of the broader Dolphin Rt:Core project.**
>
> **Dolphin Rt:Core** is the emulator side: surgical tuning of GameCube & Wii execution on the Allwinner H700, three flavours of deployment (Comfort Zone, Bash Arsenal, Frontendone), and a compatibility database with 200+ tested titles.
>
> **Dolphin Rt:Stream** is the frontend side: the handheld app that streams from a PC instead of emulating on-device, with the same GameCube visual language.

### Built on the shoulders of giants:

| Project | Role |
|---|---|
| **Dolphin Emulator** | The emulator itself |
| **Sunshine** | Game-stream host on the PC |
| **Moonlight** | Stream client on the handheld |
| **LÖVE** | The 2D framework powering the handheld UI |
| **GameTDB** | Cover art source |
| **Orbitron** | The font (SIL OFL 1.1) |

---

## Links & Resources

- 🏛️ **[Dolphin Rt:Core](https://github.com/SilverCrow2323/Dolphin-Rt-Core)** — the emulator side of the family
- 🌐 **[GitHub Repository](https://github.com/SilverCrow2323/dolphin-rt-stream)**
- 📦 **[Latest Releases](https://github.com/SilverCrow2323/dolphin-rt-stream/releases/latest)**
- 📖 **[docs/INSTALL.md](docs/INSTALL.md)** — step-by-step install guide
- 📖 **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the two halves talk
- 📖 **[docs/CONTROLS.md](docs/CONTROLS.md)** — every controller mapping, in full
- 📖 **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — what to do when it doesn't work
- 💾 **[Official muOS Documentation](https://muos.dev)**
- 🐬 **[Dolphin Emulator Project](https://dolphin-emu.org)**

---

## License

- **Code:** MIT — see [LICENSE](LICENSE)
- **Logos** (Dolphin Rt:Core, Dolphin Rt:Stream, SPDW): © SPDW Factory Lab, not covered by MIT
- **Font:** Orbitron — SIL Open Font License 1.1 (`pc/assets/OFL-Orbitron.txt`)
- GameCube and Wii are trademarks of Nintendo. This project is not affiliated with or endorsed by Nintendo.
- The GC/Wii logos used as small tab icons can be removed from `assets/` without affecting functionality.

> [!IMPORTANT]
> No ROMs, BIOS or firmware are included or distributed. Use your own legally obtained backups.

---

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/spdw_symbol.png" alt="SPDW Symbol" width="50" style="vertical-align: middle; margin-right: 10px;">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/dolphinrt_icon.png" alt="Dolphin Rt Icon" width="50" style="vertical-align: middle;">
  <br><br>
  <b>Dolphin Rt:Stream</b><br>
  <b><u>Streaming the Mecha-Dolphin. One handheld at a time.</u></b> 🎮
</div>
