<div align="center">
  <img src="https://github.com/SilverCrow2323/dolphin-rt-core/raw/main/assets/Dolphin_RtCore_Flavour3_FrontendONE_Boxart.jpeg" alt="Rt:Core FrontendONE" width="380" style="border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.35); margin-bottom: 15px;">

  <h1>🐬 Flavour III: <u>FrontendONE</u></h1>
  <h3><i>Dolphin Rt:Core Controller-First Frontend for muOS</i></h3>

  <p>
    <a href="https://github.com/SilverCrow2323/dolphin-rt-core/releases/latest">
      <img src="https://img.shields.io/badge/version-11.5.00-8C59F2?style=for-the-badge&logo=github" alt="Version">
    </a>
    <img src="https://img.shields.io/badge/Rt%3AUI-3.4.0%20Triage-4FA8C7?style=for-the-badge" alt="Rt:UI">
    <img src="https://img.shields.io/badge/platform-muOS%20Jacaranda-4FA8C7?style=for-the-badge&logo=linux" alt="Platform">
    <img src="https://img.shields.io/badge/type-frontend-F5C542?style=for-the-badge" alt="Frontend">
    <img src="https://img.shields.io/badge/superset-Bash%20Arsenal-4CC850?style=for-the-badge" alt="Superset">
  </p>
</div>

---

> ### ⚡ **TL;DR — <u>One App. Every Knob. No Task Toolkit Digging.</u>**
> ***If Comfort Zone is "plug and play" and Bash Arsenal is "tweak every knob," FrontendONE is "every knob, on one screen, with covers."*** 🎮
>
> **FrontendONE** is the **<u>graphical front door</u>** of Dolphin Rt:Core. A single muOS application (**Dolphin Rt:FinalCut**) that gives you a **<u>game library with covers & compatibility data</u>**, **<u>per-game options</u>**, a **<u>Cheats & Boost database</u>**, a **<u>Mod Vault</u>**, a **<u>hotkey designer</u>**, a **<u>profile editor</u>** and an **<u>environment triage</u>** — all controller-first on the 640×480 handheld screen. Everything from Flavour I and II is preserved **100% intact**; Flavour III only *drives* it.

---

## 📖 <u>Overview & Philosophy</u>

<div>
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/ticket.png" width="48" align="left" style="margin-right: 15px; margin-bottom: 10px;">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/dolphinrt_icon.png" alt="Rt:Core Branding" width="75" align="right" style="margin-left: 15px; margin-bottom: 10px;">

  **FrontendONE** turns Dolphin Rt:Core into an **<u>appliance</u>**. Instead of Content Explorer → Assign Core → Task Toolkit → text files, you open **one app**, pick a game, press **X**, and change *its* profile, tier, controller, hotkeys, cheats and mods — saved instantly to the game's own card, applied on the next launch. *Zero file editing, zero guesswork.*
</div>

<br clear="all">

### 💡 <u>Why FrontendONE is a Superset (Not a Replacement)</u>

```mermaid
graph TD
    subgraph FCZ ["🛋️ Flavour I: Comfort Zone (Base Engine)"]
        A[JITARM64 + Async Shaders] --> B[START+SELECT Native Exit]
        B --> C[Curated GameSettings & HD CNK Pack]
    end

    subgraph FBA ["🔧 Flavour II: Bash Arsenal (Power Layer)"]
        D[🟢🟡🔴 Tiers: Lite / Standard / Max]
        E[🧰 Task Toolkit Scripts]
        F[🔍 Mod Scanner]
    end

    subgraph FFO ["🖥️ Flavour III: FrontendONE (Graphical Front Door)"]
        G[📚 Library + Covers + Compatibility]
        H[🎛️ Per-Game Options]
        I[⚡ Cheats & Boost DB]
        J[🧩 Mod Vault]
        K[🩺 Env Triage I · II · III]
    end

    FCZ -->|Embedded Base| FBA
    FBA -->|Driven by| FFO

    style FCZ fill:#1e293b,stroke:#8c59f2,stroke-width:2px,color:#fff
    style FBA fill:#0f172a,stroke:#4cc850,stroke-width:2px,color:#fff
    style FFO fill:#0b1b2e,stroke:#4fa8c7,stroke-width:2px,color:#fff
```

* **<u>100% Flavour I & II Compatibility</u>** — *the app calls `ext-dolphinrt.sh`'s own recipe and `RtSys/apply_profile.sh`; nothing is replaced.*
* **<u>Per-Game Everything</u>** — *profile, tier, controller, hotkeys, overlays, mods and cheats live in each game's `rtid` card.*
* **<u>One Launch Loop</u>** — *LÖVE → Dolphin → LÖVE without ever dropping back to the muOS menu.*
* **<u>Handheld-Tuned</u>** — *adaptive FPS (60 → 30 → 20 when idle), cached text and one pre-rendered background: no background daemons.*

---

## 🖥️ <u>The Screens</u>

<div>
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/powerup_machine.png" width="48" align="left" style="margin-right: 15px; margin-bottom: 10px;">

  Open **<u>Applications → Dolphin Rt:FinalCut</u>**. Every screen shares one design system (chamfered panels, one accent per section, ≥ 14 px type) and remembers the row you left from.
</div>

<br clear="all">

| Screen | 🧭 What it does |
| :--- | :--- |
| 📚 **`Library`** | *GC + Wii games with cover, compatibility data, filters (ALL / GC / WII / ★ / Boost), letter jump, last-game memory.* |
| 🎛️ **`Game Options`** | *Per-game profile, tier (LITE / STANDARD / MAX), controller, hotkeys, overlays, mods, quick boost, reset.* |
| ⚡ **`Cheats & Boost`** | *Rogue database, fetched per game — BOOST / FPS / CHEATS tabs; your toggles always win.* |
| 🗂️ **`Cheat DB`** | *Every title in the index: which have Boost, which you own.* |
| 🧩 **`Mod Vault`** | *Textures · Wii SD Sync · Riivolution · Dynamic Input · Graphic Mods — on/off per game.* |
| ⌨️ **`Hotkeys`** | *Design combos on the pad, conflict warnings, copy profiles.* |
| 🕹️ **`Controller Map`** | *Per-game controller mapping with GC / Wii button art.* |
| 🧬 **`Rt:Profiles`** | *Pick a profile and edit its Dolphin.ini / GFX.ini in a category-based editor with guide text and warnings.* |
| 📊 **`Compatibility`** | *The whole `games_data.json`: filters, detail panel with FPS, stars, profile, devices.* |
| ⚙️ **`Settings`** | *5 coloured sections: Library · Editors · Display & Sound · System · About & Tools.* |
| 🩺 **`Env Triage`** | *Is Flavour I, II and III really installed? See below.* |

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/07_compat.png" width="31%" alt="Compatibility">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/08_cheatdb.png" width="31%" alt="Cheat DB">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/06_settings.png" width="31%" alt="Settings">
</div>

---

## 🩺 <u>Rt:Core Env Triage — The Health Check</u>

<div>
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/star.png" width="48" align="left" style="margin-right: 15px; margin-bottom: 10px;">

  **Settings → About & Tools → Rt:Core Env Triage.** In about a second it tells you whether the **three layers** are installed, which one is broken, and **what to fix first**. Perfect for bug reports: press <kbd>X</kbd> and attach the saved report.
</div>

<br clear="all">

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/01_triage_healthy.png" width="48%" alt="Triage — healthy">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/02_triage_degraded.png" width="48%" alt="Triage — broken install">
</div>

| Element | 🔍 Meaning |
| :--- | :--- |
| 🪪 **Flavour cards** | *I Comfort Zone · II Bash Arsenal · III FrontendONE — **READY / PARTIAL / MISSING**, one segment per check.* |
| ✅ **Checklist** | *Every file the layer needs, with vector ✓/✗; non-executable scripts show **`not +x`**.* |
| 💬 **Info line** | *What breaks if the highlighted item is missing, plus its full path.* |
| ⭕ **Verdict ring** | *`HEALTHY` · `DEGRADED` · `BROKEN`, % of checks passed and the **FIX FIRST** item.* |
| 🔢 **Numbers** | *ROMs (GC / Wii, from your Settings ROM folders), emulator size, SD free, profiles, cheat titles, Rt:UI · core versions.* |

**<u>Controls:</u>** <kbd>↑</kbd><kbd>↓</kbd> / <kbd>L1</kbd><kbd>R1</kbd> switch flavour · <kbd>A</kbd> inspect checks one by one · <kbd>X</kbd> save `data/logs/triage_report.txt` · <kbd>Y</kbd> rescan · <kbd>B</kbd> back.

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/03_triage_inspect.png" width="31%" alt="Triage — inspecting a check">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/10_triage_flavour3.png" width="31%" alt="Triage — Flavour III checklist">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/screenshots/04_triage_empty.png" width="31%" alt="Triage — nothing installed">
</div>

> [!NOTE]
> **<u>Non-blocking by design.</u>** The scan runs in small steps, so the UI keeps animating and the cards fill in live. Roles are weighted: a missing **critical** file (emulator, `dolphin`, launcher, RtSys, `launch.sh`…) makes a flavour **MISSING**; missing optional items make it **PARTIAL**.

---

## 🔁 <u>The Launch Cycle</u>

```mermaid
sequenceDiagram
    participant M as 🅼 mux_launch.sh
    participant U as 🖥️ Rt:UI (LÖVE)
    participant L as 🚀 scripts/launch.sh
    participant D as 🐬 Dolphin

    M->>U: start frontend
    U->>M: launch.request + launch_cmd.sh
    M->>L: run (DOLPHINUI_LOOP=1)
    L->>L: 1 RtSys baseline · 2 profile+tier · 3 controller/hotkeys<br/>4 cheats & overlays · 5 graphic mods
    L->>D: ./dolphin -e ROM -u emu_dir
    D-->>L: exit (START+SELECT)
    L-->>M: done
    M->>U: restart on the same screen
```

`mux_launch.sh` stays the muOS "app" for the **whole** cycle, so muOS never paints its menu over Dolphin and CAFFEINE / OSD / gptokeyb2 stay in the state the emulator needs. Settings are layered in this order:

| # | Layer | 📂 Source |
| :---: | :--- | :--- |
| 1️⃣ | **Device baseline** | `RtSys/apply_profile.sh` *(Flavour II)* |
| 2️⃣ | **Profile → family[/tier] → game** | `workshop/rtcoreprofile`, per-game card |
| 3️⃣ | **Controller · hotkeys · logging** | `workshop/controller`, `hotkeys`, `logging` |
| 4️⃣ | **Cheats + overlays** | `Dolphin.ini` / `GFX.ini` keys |
| 5️⃣ | **Graphic mods** | only the ones you left **on** for that game |

> [!IMPORTANT]
> **<u>Tiers belong to Rt:Core families only.</u>** LITE / STANDARD / MAX appear for `RtBoost`, `RtPrime` and `RtPure`; other profiles have no tier selector.

---

## 🎮 <u>Controls</u>

| Input | Action |
| :---: | :--- |
| <kbd>D-PAD</kbd> | *Move (hold to scroll)* |
| <kbd>A</kbd> / <kbd>B</kbd> | *Select · play / Back* |
| <kbd>X</kbd> / <kbd>Y</kbd> | *Options / Favourite* |
| <kbd>L1</kbd><kbd>R1</kbd> | *Filter · tab · section* |
| <kbd>L2</kbd><kbd>R2</kbd> | *Letter jump* |
| <kbd>START</kbd> | *Settings* |
| <kbd>MENU</kbd> | *System drawer — operations & notification history* |
| <kbd>START</kbd> + <kbd>SELECT</kbd> | *Quit Rt:UI (in-game: Dolphin safe exit)* |

---

## 📦 <u>Install & Update</u>

1. Install **Flavour I** (Rt:Core package) and, for tiers/Task Toolkit, **Flavour II** — see their READMEs.
2. Copy **`Dolphin_RtUI_v3_4_0.muxapp`** to the SD card and install it with **muOS Archive Manager**.
3. Open **Applications → Dolphin Rt:FinalCut**, then run **Settings → Rt:Core Env Triage** — you want **HEALTHY**.
4. **Settings → ROM folders** → point to your *Nintendo GameCube* / *Nintendo Wii* folders if they differ from the defaults.

> [!WARNING]
> **<u>Updating over an older Rt:UI replaces `data/settings.json`</u>** with the shipped defaults. Back up `data/settings.json` and your `workshop/` folder first. Profiles, controllers and game cards you created are kept (only same-named files are replaced).

**Uninstall:** delete the *Dolphin RtUI* application folder. Flavours I and II are untouched.

---

## ⚠️ <u>Technical Notes & Hardware Reality</u>

> [!IMPORTANT]
> **<u>The frontend is not a CPU upgrade.</u>** The **Allwinner H700** stays at the entry limit for GameCube/Wii. FrontendONE makes the *settings* effortless; it cannot add compute. Expect the same reality as Flavour II: lightweight titles `30 – 50 FPS`, medium `15 – 25 FPS`, heavy `5 – 15 FPS`.

* 🔄 **<u>When changes apply:</u>** every option is written to the game's card instantly and applied on the **next launch**.
* 🐍 **<u>python3 is optional.</u>** `launch.sh` uses `python3` (if present) to layer *Default ← profile ← game* into one INI. Without it the profile's own `Dolphin.ini` / `GFX.ini` are copied as-is. Everything else is pure Lua/shell.
* 🌐 **<u>Databases:</u>** `games_data.json`, `gamesettings.json` and `rtcheats_db.json` are validated before replacing the live copy; the previous one is kept as `.bak` for fallback.
* 🖼️ **<u>Other resolutions:</u>** the UI is a fixed 640×480 canvas, scaled with black bars on 720×480, 720×720, 1280×720 panels.
* 🧪 **<u>Dev tools:</u>** `DOLPHINUI_SHOT=out.png:2.5 love . --screen=triage` takes a headless screenshot; `DOLPHINUI_TRIAGE_ROOT=<dir>` runs the triage against a fake muOS tree.

---

## 🙏 <u>Credits & Acknowledgments</u>

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/sirpips.jpeg" alt="sirpips" width="110" style="border-radius: 50%; box-shadow: 0 4px 12px rgba(0,0,0,0.3); margin-bottom: 8px;">
  <br>
  <b>sirpips aka SilverCrow2323</b>
  <br>
  <i>SPDW Factory Lab</i>
</div>

<br>

| Contributor / Project | Key Contribution |
| :--- | :--- |
| 🐬 **Dolphin Emulator Team** | Core emulation software engine and graphics backend |
| 🏭 **SPDW Factory Lab / sirpips** | FrontendONE design & code, Rt:UI design system, Env Triage, launch pipeline |
| 💾 **muOS Development Team** | Operating system, application framework, launch integration |
| 💚 **LÖVE team** | The 2D framework Rt:UI runs on (LÖVE 11.5 / LuaJIT) |
| 👥 **Dolphin Community** | Compatibility data, graphic mods, texture references, benchmarking |

---

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/spdw_symbol.png" alt="SPDW Symbol" width="45" style="vertical-align: middle; margin-right: 10px;">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/assets/dolphinrt_icon.png" alt="Dolphin Rt Icon" width="45" style="vertical-align: middle;">
  <br><br>
  <b>Dolphin Rt:Core — Flavour III: FrontendONE v1.0 · Rt:UI 3.4.0 "Triage"</b><br>
  <b><u>Still Sbrobbing. Always Rintromping.</u></b> 🎮
</div>
