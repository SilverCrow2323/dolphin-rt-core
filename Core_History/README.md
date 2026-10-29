<div align="center">

# <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/spdw_symbol.png" width="35" alt="SPDW Symbol" style="vertical-align: middle;"> Dolphin <i>(pre)</i>Rt:Core &bull; **🏛️ History & Core Archive**
<br>

<p align="center">
  <img src="https://github.com/SilverCrow2323/Dolphin-Core-for-MuOS/blob/main/assets/Dolphin_Core_00_RoadmanArchive_Boxart.png?raw=true" alt="Core History Header Banner" width="380" style="border-radius: 10px; box-shadow: 0 4px 14px rgba(0,0,0,0.3);">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-archived-8C59F2?style=for-the-badge" alt="Archived Status">
  <img src="https://img.shields.io/badge/platform-muOS%20%26%20Knulli%20ECOSYSTEM-4FA8C7?style=for-the-badge" alt="Platform">
  <img src="https://img.shields.io/badge/era-V5%20to%20V12.0.00-FF6F00?style=for-the-badge" alt="Era">
  <img src="https://img.shields.io/badge/origin-MustardOS%20Forum%20%23491-4CC850?style=for-the-badge" alt="Forum Post">
</p>

> ### 🏛️ *Welcome to the <u>digital fossil record</u>.*
> This directory houses all legacy iterations, test builds, experimental packages, and control profiles of the **Dolphin Core** (**Nintendo GameCube** & **Nintendo Wii**) compiled for **muOS** *before* the transition to **Knulli OS** and the establishment of the **Dolphin Rt:Core Triptych** & **Rt:Stream** ecosystem.
>
> These legacy artifacts trace the origin story of low-level ARM64 recompiler experimentation on the **Allwinner H700 SoC** ($4\times \text{Cortex-A53} \text{ @ } 1.5\text{ GHz}$), initiated by [**@Speedrun**](https://community.muos.dev/u/speedrun) and supported by early community pioneers.

</div>

---

## 📌 1. OVERVIEW & ARCHIVE STRUCTURE

This repository section serves as a technical and historical archive documenting the step-by-step evolution of standalone Dolphin emulation on handheld devices prior to the Knulli OS v12.0.00 release.

### 📁 Archive Directory Layout

```text
Core_History/
├── HISTORY_README.md                                 # 📜 This historical record document
├── README.md                                         # Historical overview document
├── Dolphin for MuOS v7/                              # 📦 v7 Early dual/no-joystick builds
├── Dolphin for MuOS v8/                              # 📦 v8 Source compilation & single-stick builds
├── Dolphin for MuOS v9/                              # 📦 v9 Universal auto-detect & Goose updates
├── Dolphin for MuOS v10 [SPDW]/                      # 📦 v10 / v10.5 SPDW custom speedhack forks
└── Dolphin RtCore for MuOS v11.5.00 Triptych/        # 🏆 Final muOS Triptych Release Archive
    ├── README.md                                     # Complete muOS v11.5.00 documentation
    ├── Flavour I | 'Comfort Zone'/                   # Standalone daily driver core & profiles
    ├── Flavour II | 'Bash Arsenal'/                  # Extended administrative task toolkit
    └── Flavour III | 'Frontendone'/                  # Full LÖVE 2D standalone frontend suite
```

- **🎯 Target Hardware (muOS Era):** Handhelds powered by the **Allwinner H700** chipset running **muOS** (Pixie, Goose, Jacaranda standards) featuring 0, 1, or 2 analog joysticks:
  * 🕹️ **Dual-Joystick Devices:** Anbernic **RG35XX H**, **RG40XX H**, **RG CubeXX**.
  * 🕹 **Single-Joystick Devices:** Anbernic **RG35XX SP**.
  * 🕹️ **Zero-Joystick Devices:** Anbernic **RG35XX Plus**.
- **⚠️ Incompatible Hardware:** <u>**Anbernic RG28XX is explicitly unsupported**</u> due to display resolution ($640\times 480$ vs ultra-small panel limits), strict memory limitations ($1\text{ GB}$ shared LPDDR4), and missing hardware inputs.

---

## 🛰️ 2. SPIN-OFF PROJECT: DOLPHIN RT:STREAM

Alongside the core emulator optimizations, a dedicated performance spin-off was branched out for remote rendering and ultra-low-latency local network streaming:

* 📡 **[Dolphin Rt:Stream Repository](https://github.com/SilverCrow2323/dolphin-rt-stream)** — Designed specifically to bridge low-power handhelds with remote host nodes, allowing GameCube and Wii streaming while maintaining the signature Dolphin Rt zero-lag latency pipelines.

---

## 💬 3. ORIGINAL COMMUNITY ANNOUNCEMENT & ARCHIVE RECORD

Below is the preserved announcement from the **MustardOS Community Forum ([Topic #491](https://community.muos.dev/t/core-dolphin-for-muos-v9-take-3-by-speedrun/491))**, capturing the exact historical context when the Dolphin core was first brought to the handheld community.

<details>
<summary><b>🔍 Click here to expand Original Forum Announcement & Screenshots</b></summary>

<br>

<div align="center">
  <img src="https://github.com/SilverCrow2323/Dolphin-Core-for-MuOS/blob/main/assets/muos_post.png?raw=true" alt="Original Forum Post Screenshot" width="750" style="border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.3);">
</div>

<br>

> **Original Post Narrative by [@Magnaderra](https://community.muos.dev/u/magnaderra) (preserves [@Speedrun](https://community.muos.dev/u/speedrun)'s work):**
> 
> *"Hi everyone, this is a project to port the **Dolphin emulator**, the core for emulating the _Nintendo GameCube_ and _Nintendo Wii_.  
> Its author - dear [**@Speedrun**](https://community.muos.dev/u/speedrun) [+.[\].%] - has done his best and is leaving it to <u>posterity</u>.  
> 
> You can download it here (Google Drive) and here (Mega). Game compatibility list is available.  
> <u>**RG28XX is not supported**</u>.  
> Huge thanks to [**@FireBattleInMtl**](https://community.muos.dev/u/firebattleinmtl) for all changes after V8.  
> 
> **Changes in V5–V8:**  
> * Fixed file execution permissions thanks to [**@FireBattleInMtl**](https://community.muos.dev/u/firebattleinmtl) & [**@Snow**](https://community.muos.dev/u/snow).  
> * Updated Dolphin binary compiled directly from source by [**@Snow**](https://community.muos.dev/u/snow).  
> * Custom `gcpadnew.ini` profiles introduced for zero-joystick and single-joystick handhelds.  
> * Automated `launch.sh` auto-injection script created by [**@FireBattleInMtl**](https://community.muos.dev/u/firebattleinmtl).  
> * V8 split package system (`hasjoys`, `hasjoy`, `nojoys`).  
> * V9 unified all profiles into a single universal auto-detecting core payload.  
> 
> **[UPD]** Now compatible with Goose! You can get adopted version here. Thanks to [**@bitter_bizarro**](https://community.muos.dev/u/bitter_bizarro)!"*

</details>

---

## 📂 4. HISTORICAL RELEASE INDEX & FILE INVENTORY

All archived packages, individual release binaries, and companion repositories preserved in this historical directory are cataloged below:

| Version | File / Directory Target | Format | Target Architecture & Milestone Notes |
| :--- | :--- | :---: | :--- |
| **v7** | `Dolphin for muOS V7-hasjoys.zip` | *Zip Archive* | Early build tailored for dual-joystick handhelds (`Dolphin for MuOS v7/`). |
| **v7** | `Dolphin for muOS V7-nojoys.zip` | *Zip Archive* | Tailored for devices lacking physical analog joysticks (`Dolphin for MuOS v7/`). |
| **v8** | `Dolphin for muOS V8-hasjoy.zip` | *Zip Archive* | First build introducing single-joystick (`hasjoy`) bindings (`Dolphin for MuOS v8/`). |
| **v8** | `Dolphin for muOS V8-hasjoys.zip` | *Zip Archive* | Dual-joystick release with **freshly recompiled binary** (`Dolphin for MuOS v8/`). |
| **v8** | `Dolphin for muOS V8-nojoys.zip` | *Zip Archive* | Refined layout for joystick-free hardware (`Dolphin for MuOS v8/`). |
| **v9 (Take 1)** | `Dolphin for muOS V9-take1.muxupd` | **.muxupd Package** | Initial attempt at a universal hardware consolidation payload (`Dolphin for MuOS v9/`). |
| **v9 (Take 2)** | `Dolphin for muOS V9-take2.muxupd` | **.muxupd Package** | Iterative update fixing permission bugs and launcher script hooks (`Dolphin for MuOS v9/`). |
| **v9 (Take 3)** | `Dolphin for muOS V9-take3.muxupd` | **.muxupd Package** | **Historical Benchmark Release** by [**@Speedrun**](https://community.muos.dev/u/speedrun) unifying all hardware classes (`Dolphin for MuOS v9/`). |
| **v9 (Goose)** | `Dolphin for muOS V9-Goose.muxupd` | **.muxupd Package** | Adapted by [**@bitter_bizarro**](https://community.muos.dev/u/bitter_bizarro) for **muOS Goose** file standards (`Dolphin for MuOS v9/`). |
| **v10 [SPDW]** | `Dolphin for muOS v10_SPDW.muxupd` | **.muxupd Package** | First custom fork release by [**@SilverCrow2323**](https://github.com/SilverCrow2323) introducing initial speedhacks (`Dolphin for MuOS v10 [SPDW]/`). |
| **v10.5.124 [SPDW]** | `Dolphin_for_MuOS_v10.5.124_SPDW.muxupd` | **.muxupd Package** | Pre-Rt:Core release testing per-game engine overrides and PAL $50\text{ Hz}$ targets (`Dolphin for MuOS v10 [SPDW]/`). |
| **v10.5.300 [SPDW]** | `Dolphin_for_MuOS_v10.5.300_SPDW.muxupd` | **.muxupd Package** | Global GC tuning milestone (Dolphin.ini / GFX.ini optimization) & target fixes for *Scaler*, *Super Mario Strikers*, and *Luigi's Mansion* (`Dolphin for MuOS v10 [SPDW]/`). |
| **v11.5.00 [SPDW]** | `Dolphin RtCore for MuOS v11.5.00 Triptych/` | **Directory Archive** | 🏆 **The Triptych Milestone:** Complete muOS release containing Flavour I (Comfort Zone), Flavour II (Bash Arsenal), and Flavour III (Frontendone). |
| **Spin-Off** | `dolphin-rt-stream` | **GitHub Repository** | 📡 **Rt:Stream Companion Branch:** Ultra-low-latency remote rendering and local network streaming spin-off (`[Repository Link](https://github.com/SilverCrow2323/dolphin-rt-stream)`). |

---

## 📜 5. TECHNICAL EVOLUTION & DETAILED CHANGELOG

### 👥 Key Contributors & Pioneer Directory

| Pioneer Contributor | Community Role & Engineering Contributions |
| :--- | :--- |
| [**@Speedrun**](https://community.muos.dev/u/speedrun) | **Lead Core Developer** & Creator of the original port, low-level JIT tweaks, and the V9 universal architecture. |
| [**@Magnaderra**](https://community.muos.dev/u/magnaderra) | Community chronicler who published and documented the original release thread on MustardOS forums. |
| [**@FireBattleInMtl**](https://community.muos.dev/u/firebattleinmtl) | Shell developer who engineered the `launch.sh` auto-injection pipeline and fixed post-V8 Linux execution permissions. |
| [**@Snow**](https://community.muos.dev/u/snow) | Systems compiler who recompiled the core Dolphin binary directly from source for ARM64 optimizations. |
| [**@bitter_bizarro**](https://community.muos.dev/u/bitter_bizarro) | System maintainer who updated assign structures and launcher syntax for **muOS Goose** compliance. |
| [**@SilverCrow2323**](https://github.com/SilverCrow2323) | Author of the **SPDW Custom Core Fork** (V10 / V10.5 / V11.5.00), creator of the **Rt:Core Triptych**, and developer of **Dolphin Rt:Stream**. |

---

### 🚀 Chronological Technical Evolution

```mermaid
timeline
    title Dolphin on muOS & Ecosystem Technical Evolution Timeline
    V5 - V6 : Launcher Auto-Injection Script : GCPad Remapping for No-Joystick Devices
    V7 - V8 : Binary Recompiled from Source : Split Packages (hasjoys / hasjoy / nojoys) : C-Stick L2 Modifier Injected
    V9 Universal : Consolidation into Unified .muxupd : Auto-Detect Hardware Abstraction Layer
    V9 Goose : Restructured Core Assign Files : Compatibility with muOS Goose Standards
    V10 - V10.5 SPDW : First SPDW Custom Core Fork : Global GC Tuning (v10.5.300) & Target GameSettings Overrides
    V11.5.00 Triptych : Flavour I (Comfort Zone) : Flavour II (Bash Arsenal) : Flavour III (Frontendone)
    Rt:Stream Spin-Off : Remote Streaming & Low-Latency Network Rendering : Official Companion Framework
```

---

#### 🟢 **[V5 – V6] Early Experiments & System Integration**
- **V5 Release Features:**
  * **System Integration:** Embedded an automated installation script to inject Dolphin execution hooks directly into muOS's `/opt/muos/script/launch.sh` pipeline *(Authored by [**@FireBattleInMtl**](https://community.muos.dev/u/firebattleinmtl))*.
  * **Permissions Hardening:** Fixed non-executable file attributes (`chmod +x`) on Dolphin binaries and wrapper scripts *(Authored by [**@FireBattleInMtl**](https://community.muos.dev/u/firebattleinmtl) & [**@Snow**](https://community.muos.dev/u/snow))*.
- **V6 Release Features:**
  * **Control Remapping (`gcpadnew.ini`):** Resolved fundamental input barriers on devices *lacking physical analog joysticks* (e.g., RG35XX Plus):
    * `D-Pad` defaults to directing the **Main Analog Stick**.
    * `L2 + D-Pad Direction` triggers native **GameCube D-Pad** inputs.

---

#### 🟡 **[V7 – V8] Hardware Split & Virtual C-Stick Era**
- **V7 Release Features:**
  * **Split Build System:** Divided installer packages into hardware-specific archives (`hasjoys` for dual-joystick devices vs `nojoys` for zero-joystick devices).
- **V8 Release Features:**
  * **Source Recompilation:** Updated core binary using a **fresh ARM64 build compiled from source**, delivering noticeable frame-time stabilization *(Authored by [**@Snow**](https://community.muos.dev/u/snow))*.
  * **Single-Joystick Support:** Introduced the `hasjoy` configuration variant for single-analog devices like the **RG35XX SP**.
  * **C-Stick Virtualization (`gcpadnew.ini`):** Implemented modifier hotkeys (`L2 + A/B/X/Y`) to simulate **GameCube C-Stick** axis movements on hardware lacking a second analog stick.

---

#### 🟡 **[V9 – V10.5] Universal Unification & SPDW Calibration Milestone**
- **V9 Universal Milestone (Take 1 – Take 3):**
  * **Hardware Consolidation:** Merged `hasjoys`, `hasjoy`, and `nojoys` variants into a **single, universal `.muxupd` package**.
  * **Hardware Fallback Model:** Internal device hardware determines profile initialization. Connecting an external dual-analog controller to a single-stick handheld preserves internal binding priorities.
- **V9 Goose Adapter:**
  * Package structure refactored by [**@bitter_bizarro**](https://community.muos.dev/u/bitter_bizarro) to comply with updated core assignment standards on **muOS Goose** firmware.
- **V10 & V10.5 SPDW Custom Core Iterations:**
  * `v10_SPDW`: Initial custom fork by [**@SilverCrow2323**](https://github.com/SilverCrow2323), introducing underclock tweaks ($\text{CPU clock} = 0.50\times$) and custom graphics hacks.
  * `v10.5.124_SPDW`: Advanced pre-release testing targeted game-specific overrides (e.g., *Super Mario Strikers*, *Luigi's Mansion*) and established the $50\text{ Hz}$ PAL regional standard.
  * **`v10.5.300_SPDW` Pre-release Milestone:**
    * **Global GameCube Tuning:** Extensive structural updates to base `Dolphin.ini` and `GFX.ini` files to balance frame rate stability, mitigate audio crackling/desyncs, and minimize CPU load.
    * **Experimental Target GameSettings:** Integrated custom parameter presets designed to lighten render workloads for demanding titles: *Scaler*, *Super Mario Strikers*, and *Luigi's Mansion*.
    * **Safe Console Reboot Exit:** Recommended using `L2` + `R2` + `SELECT` (muOS Safe Console Reboot) to terminate Dolphin cleanly without corruption risks.

---

#### 🏆 **[V11.5.00] The Triptych Ecosystem (Final muOS Release)**
- **Flavour I: Comfort Zone:** Zero-config daily driver featuring 7 battle-tested profiles, engine-wide bloom stripping, DOF removal for 10 heavy titles, and CNK HD texture fixes.
- **Flavour II: Bash Arsenal:** Administrative extension adding the muOS Task Toolkit system, tiered execution (`Lite`, `Std`, `Max`), dynamic graphic mod scanner, and on-device 13-page technical manual.
- **Flavour III: Frontendone:** Full LÖVE 2D interactive console UI with 3D Dashboard rotation between GameCube and Wii aesthetics.

> *All v11.5.00 components are fully preserved in `history/Dolphin RtCore for MuOS v11.5.00 Triptych/`.*

---

#### 📡 **[Rt:Stream] Official Performance Spin-Off Branch**
- **Dolphin Rt:Stream Ecosystem:** Developed by **[@SilverCrow2323](https://github.com/SilverCrow2323)** (`[Repository Link](https://github.com/SilverCrow2323/dolphin-rt-stream)`).
- **Core Mission:** Bridges low-power ARM64 hardware constraints by offloading heavy geometry and render pipelines to remote host nodes via ultra-low-latency local network streaming, preserving zero-lag input responsiveness.

---

## 🎮 6. CONTROL SHORTCUTS & HOTKEYS (`gcpadnew.ini`)

> [!WARNING]
> **Historical Hotkey Legacy Note:** Early V5–V9 releases documented a safe exit combo (`L1 + L2 + R1 + R2 + Power`). On newer muOS releases (Goose / Jacaranda / v10.5+), this combination was superseded by hardware reset shortcuts or native `L2` + `R2` + `SELECT` safe rebooting.

| Execution Command | Button Combination | Scope & Context |
| :--- | :--- | :--- |
| **Legacy Safe Exit Combo** | `L1` + `L2` + `R1` + `R2` + **Hold Power (2s)** | *V5–V9 legacy combo (Deprecated on modern muOS firmware).* |
| **muOS Safe Reboot** | `L2` + `R2` + `START` | *Hardware reboot shortcut.* |
| **muOS Safe Shutdown / Exit** | `L2` + `R2` + `SELECT` | *Hardware power-off / safe termination shortcut.* |
| **Main Analog Emulation** | `D-Pad` | Native binding on **zero-joystick handhelds** (V6+). |
| **Native D-Pad Trigger** | `L2` + `D-Pad Direction` | Direct D-Pad input override for **zero-joystick devices** (V6+). |
| **Virtual C-Stick Direct** | `L2` + `A` / `B` / `X` / `Y` | Virtual C-Stick deflection on **single/zero-joystick devices** (V8+). |

---

## 🔗 7. SOURCES, REFERENCES & COMMUNITY ARCHIVES

- 💬 **MustardOS Discussion Thread:** [[Core] Dolphin for MuOS V9 Take 3 by @Speedrun (Topic #491)](https://community.muos.dev/t/core-dolphin-for-muos-v9-take-3-by-speedrun/491)
- 📡 **Rt:Stream Companion Spin-Off:** [Dolphin Rt:Stream Repository](https://github.com/SilverCrow2323/dolphin-rt-stream)
- 📊 **Community Test Matrix:** [Google Sheets Legacy GameCube/Wii Compatibility Sheet](https://docs.google.com/spreadsheets/u/0/d/1LHXQV78yAuvii8J77KUgEt3Ap6TagjQzN48gdB9iVKY/htmlview)
- ☁ **Community Cloud Mirrors:**
  * Legacy mirror packages preserved on [Google Drive Archive Mirror](https://drive.google.com/drive/folders/1oIdjzDEuOw0CfErXUgp5cKmyypjnrjoJ?usp=sharing).
  * Legacy mirror packages preserved on [MEGA Archive Mirror](https://mega.nz/folder/OtViWDyR#9FMAES423bckWKd3Rwsjdw).

---

<div align="center">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/spdw_symbol.png" alt="SPDW Symbol" width="45" style="vertical-align: middle; margin-right: 10px;">
  <img src="https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/main/assets/dolphinrt_icon.png" alt="Dolphin Rt Icon" width="45" style="vertical-align: middle;">
  <br><br>
  <b>Dolphin Core for muOS — Historical Archive Record</b><br>
  <b><u>Honoring the Pioneers. Preserving the Code.</u></b> 🎮
</div>
