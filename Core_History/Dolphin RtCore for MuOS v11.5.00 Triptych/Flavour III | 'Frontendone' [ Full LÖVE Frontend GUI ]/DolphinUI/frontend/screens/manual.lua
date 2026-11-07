-- frontend/screens/manual.lua — Full technical manual.
--
-- ── v1.0.0 — rich manual ─────────────────────────────────────
--   * Nine SECTORS, each with chapters and sub-chapters.
--   * Typed content blocks: h1, h2, h3, p, quote, code,
--     table, diagram, buttons, list, spacer, kv.
--   * Procedural renderer: every block measures its height before
--     the draw, so scrolling is pixel-precise.
--   * Rich formatting: 6 different fonts (Oxanium, JetBrains,
--     Audiowide, Orbitron, ChakraPetch, GameCube.ttf for brand),
--     per-type colors, zebra tables, procedural diagrams, inline
--     button badges.
--   * Sidebar with sector LEDs, number and chapter progress bar.
--   * Navigation: L1/R1 change sector, ↑↓ scroll, ←→ chapter.

local A     = require("assets")
local SFX   = require("sfx")
local State = require("state")
local IM    = require("input_map")
local D     = require("ui.draw")
local BG    = require("ui.bg")
local Header= require("ui.header")
local Icons = require("ui.icons")
local BI    = require("ui.button_icons")
local GL    = require("ui.glyph")

local S = {}
local W, H = 640, 480

local SIDEBAR_W  = 170
local TOP_Y      = 64
local BOTTOM_Y   = H - 34
local CONTENT_X  = SIDEBAR_W + 24
local CONTENT_W  = W - CONTENT_X - 20

-- Font paths
local F_MONO   = "assets/fonts/JetBrainsMono-Regular.ttf"
local F_MONO_B = "assets/fonts/JetBrainsMono-Bold.ttf"
local F_BODY   = "assets/fonts/Oxanium-Regular.ttf"
local F_BOLD   = "assets/fonts/Oxanium-Bold.ttf"
local F_FUTURE = "assets/fonts/Audiowide-Regular.ttf"
local F_ORBIT  = "assets/fonts/Orbitron-Bold.ttf"
local F_QUOTE  = "assets/fonts/ChakraPetch-Bold.ttf"

-- Type colors
local C_H1     = {0.96, 0.77, 0.26}   -- amber
local C_H2     = {0.55, 0.35, 0.95}   -- violet
local C_H3     = {0.20, 0.72, 0.98}   -- blue
local C_BODY   = {0.86, 0.90, 0.96}
local C_QUOTE  = {0.30, 0.85, 0.40}
local C_CODE   = {0.75, 0.85, 0.70}
local C_TABLE  = {0.20, 0.72, 0.98}
local C_KV_K   = {0.55, 0.62, 0.78}

-- ══════════════════════════════════════════════════════════════
--  SECTORS — manual content
-- ══════════════════════════════════════════════════════════════

local SECTORS = {}

-- ── SECTOR 1 — Introduction ──────────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "intro",
  num   = "01",
  title = "Introduction",
  icon  = "info",
  color = {0.55, 0.35, 0.95},
  chapters = {
    {
      title = "What is DolphinUI",
      blocks = {
        { k = "h1", text = "DolphinUI" },
        { k = "p", text =
          "Dual-faced frontend for Dolphin Rt:Core on muOS. " ..
          "Born as an interface for the ARM port of the famous " ..
          "GameCube/Wii emulator, it has become a complete " ..
          "ecosystem for managing, tuning and documenting the " ..
          "gaming experience on Anbernic H700 hardware." },

        { k = "p", text =
          "The SPDW Factory Lab project picked up the work of " ..
          "the original porters (up to v9), filling structural " ..
          "gaps: working hotkeys, profile system, graphical UI, " ..
          "resource downloader, report collection." },

        { k = "quote", text =
          "Where most would say stop. Still Sbrobbing, still " ..
          "Rintromping." },

        { k = "h2", text = "Design philosophy" },
        { k = "list", items = {
          "**Offline-first**: no cloud dependency, everything " ..
            "lives locally on the SD card.",
          "**Zero barrier**: every feature is reachable in a " ..
            "few button presses.",
          "**Historical memory**: reports, logs and snapshots " ..
            "survive reboots.",
          "**Open**: no hidden binary blobs, everything is " ..
            "inspectable.",
        }},
      },
    },
    {
      title = "Architecture",
      blocks = {
        { k = "h1", text = "Architecture" },
        { k = "p", text =
          "DolphinUI is a LÖVE (LuaJIT) application running on " ..
          "top of the muOS runtime. The architecture is layered:" },

        { k = "diagram", name = "architecture" },

        { k = "h2", text = "The three layers" },
        { k = "table",
          headers = { "Layer", "Role", "Files" },
          rows = {
            { "Boot",   "First-screen selection, ROM scan, data download", "main.lua" },
            { "Core",   "State, settings, profile, launcher, input routing",     "state.lua, settings_store.lua" },
            { "UI",     "Screens, overlays, transitions, sfx",                     "screens/*, ui/*" },
          },
        },

        { k = "h2", text = "Runtime" },
        { k = "kv",
          rows = {
            { "Runtime",    "LÖVE 11.5 (Mysterious Mysteries)" },
            { "Interpreter","LuaJIT 2.1 (Lua 5.1 compatible)" },
            { "Platform",   "Linux ARM64 (Allwinner H700)" },
            { "Target",     "Anbernic RG35XX H, RG40XX H, RG CubeXX" },
          },
        },
      },
    },
  },
}

-- ── SECTOR 2 — First boot ─────────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "setup",
  num   = "02",
  title = "First boot",
  icon  = "play",
  color = {0.30, 0.85, 0.40},
  chapters = {
    {
      title = "Boot sequence",
      blocks = {
        { k = "h1", text = "Boot sequence" },
        { k = "p", text =
          "On every launch the app walks through a " ..
          "deterministic sequence of phases:" },

        { k = "list", items = {
          "**SPDW Advisory** — informational screen (once per " ..
            "session). Can be disabled in Settings → Advanced.",
          "**Onboarding** — only on the very first launch. " ..
            "Collects ROM paths.",
          "**Boot animation** — 3.2 s glitch/radial intro, " ..
            "skippable with any key after 0.5 s.",
          "**Nexus** — the main menu.",
        }},

        { k = "h2", text = "State file" },
        { k = "p", text =
          "Persistent state is stored in `frontend/data/frontendone.json`. " ..
          "It's written atomically every time the user changes an " ..
          "option." },

        { k = "code", text =
          "{\n" ..
          "  \"general\": { \"theme\": \"gc\", \"onboarding_done\": true },\n" ..
          "  \"roms\":    { \"paths_gc\": [\"/mnt/mmc/ROMS/gamecube\"] },\n" ..
          "  \"sfx\":     { \"enabled\": true, \"volume\": 70 }\n" ..
          "}" },
      },
    },
    {
      title = "ROM configuration",
      blocks = {
        { k = "h1", text = "ROM configuration" },
        { k = "p", text =
          "DolphinUI supports both GameCube and Wii. Multiple " ..
          "paths are allowed per system." },

        { k = "h2", text = "Recommended paths" },
        { k = "table",
          headers = { "System", "Path", "Notes" },
          rows = {
            { "GameCube", "/mnt/mmc/ROMS/gamecube",        "primary folder" },
            { "GameCube", "/mnt/sdcard/roms/gc",           "alternative" },
            { "Wii",      "/mnt/mmc/ROMS/wii",             "primary folder" },
            { "Wii",      "/mnt/sdcard/roms/Nintendo Wii", "alternative" },
          },
        },

        { k = "h2", text = "Supported extensions" },
        { k = "p", text =
          "The scanner recognises ISO, GCM, RVZ, WBFS, WIA, CISO, " ..
          "NKIT, GCZ. Each format is processed by the header " ..
          "parser to extract the GameID without reading the " ..
          "whole file." },
      },
    },
  },
}

-- ── SECTOR 3 — Interface ──────────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "ui",
  num   = "03",
  title = "Interface",
  icon  = "ui",
  color = {0.20, 0.72, 0.98},
  chapters = {
    {
      title = "The Nexus",
      blocks = {
        { k = "h1", text = "The Nexus (main menu)" },
        { k = "p", text =
          "Central hub of the app. Cyberpunk-styled panel grid " ..
          "that groups every feature." },

        { k = "table",
          headers = { "Panel", "Function", "Key" },
          rows = {
            { "GAME LIBRARY", "Game library",       "[A] enter" },
            { "HOMEBREW HUB", "Homebrew manager",   "[A] enter" },
            { "RT:ENHANCER",  "Resource store",     "[A] enter" },
            { "COMPATIBILITY","Test database",      "[A] enter" },
            { "WORKSHOP",     "Config editor",      "[A] enter" },
            { "SETTINGS",     "App settings",       "[A] enter" },
            { "RESTART",      "Restart frontend",   "[A] confirm" },
            { "LOG OUT",      "Close frontend",     "[A] confirm" },
          },
        },

        { k = "h2", text = "Mirror layout" },
        { k = "p", text =
          "On the Wii theme the grid is horizontally mirrored. " ..
          "This also reflects D-pad navigation: ← and → follow " ..
          "the visual layout." },
      },
    },
    {
      title = "Game Library",
      blocks = {
        { k = "h1", text = "Game Library" },
        { k = "p", text =
          "5×2 grid per page with covers, community rating " ..
          "badges, quick launch. Mirror-aware for Wii theme." },

        { k = "h2", text = "Filters" },
        { k = "list", items = {
          "**AUTO** — follows the active theme (GC or Wii)",
          "**GC** — GameCube only",
          "**WII** — Wii only",
          "**ALL** — everything",
        }},
        { k = "buttons", text = "[Y] Change filter" },

        { k = "h2", text = "Covers" },
        { k = "p", text =
          "DolphinUI looks for cover art in this order:" },
        { k = "list", items = {
          "Local folders next to the ROM: `media/`, `images/`, " ..
            "`boxart/`, `covers/`, `artwork/`",
          "Remote cache downloaded from GameTDB into `data/covers/`",
          "On-demand download via GameTDB (falls back to title " ..
            "search if the ID can't be extracted from the filename)",
        }},
      },
    },
    {
      title = "Compatibility",
      blocks = {
        { k = "h1", text = "Compatibility" },
        { k = "p", text =
          "Community test report database. Scrollable list " ..
          "with rating, FPS, boot, playable status." },

        { k = "h2", text = "Rating scale" },
        { k = "table",
          headers = { "Rating", "Label", "Meaning" },
          rows = {
            { "5", "PERFECT",     "runs flawlessly" },
            { "4", "PLAYABLE",    "playable with minor drops" },
            { "3", "WITH ISSUES", "acceptable, with issues" },
            { "2", "UNPLAYABLE",  "too slow" },
            { "1", "BROKEN",      "severe glitches" },
            { "0", "NO BOOT",     "won't start" },
          },
        },

        { k = "h2", text = "Search modes" },
        { k = "buttons", text = "[X] Search   [START] Mode" },
        { k = "p", text =
          "The START key toggles between SYSTEM (standard " ..
          "navigation) and LETTER (alphabetical jump via L1/R1)." },
      },
    },
  },
}

-- ── SECTOR 4 — Controls ──────────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "controls",
  num   = "04",
  title = "Controls",
  icon  = "controller",
  color = {0.96, 0.77, 0.26},
  chapters = {
    {
      title = "Gamepad mapping",
      blocks = {
        { k = "h1", text = "Gamepad mapping" },
        { k = "p", text =
          "DolphinUI uses SDL GameController semantics. Any " ..
          "controller recognised by muOS works out of the box." },

        { k = "table",
          headers = { "Key", "Function" },
          rows = {
            { "A",       "Confirm / Select" },
            { "B",       "Back / Cancel" },
            { "X / Y",   "Context actions per screen" },
            { "L1 / R1", "Tab / Previous next page" },
            { "L2",      "Open this overlay guide" },
            { "R2",      "Download manager" },
            { "START",   "Context quick action" },
            { "SELECT",  "System toggle (per screen)" },
            { "MENU",    "Live Menu in-game" },
          },
        },

        { k = "buttons", text = "[L2] Open guide   [R2] Downloads" },

        { k = "h2", text = "Force quit" },
        { k = "p", text =
          "Hold START+SELECT to open the force quit panel. " ..
          "Then hold A for 1.5 s to terminate." },
      },
    },
    {
      title = "Live Menu",
      blocks = {
        { k = "h1", text = "Live Menu in-game" },
        { k = "p", text =
          "Curses overlay accessible during emulation. " ..
          "Pauses the Dolphin process (SIGSTOP) while open." },

        { k = "h2", text = "Activation" },
        { k = "buttons", text = "[MENU] + [START]  Open Live Menu" },
        { k = "buttons", text = "[MENU] alone      Exit to frontend" },

        { k = "h2", text = "Features" },
        { k = "list", items = {
          "**Save State** — 3 available slots",
          "**Load State** — load from slot 1, 2, 3",
          "**Reset Game** — soft reset the emulator",
          "**Quick Toggles** — FPS, speed%, frame counter, input display",
          "**Exit to Frontend** — closes Dolphin, returns to DolphinUI",
          "**Close Emulator** — force kill",
        }},

        { k = "h2", text = "Key injection" },
        { k = "p", text =
          "The Live Menu uses `/dev/uinput` to emulate a virtual " ..
          "keyboard and send hotkeys to Dolphin. Requires " ..
          "`Hotkeys.ini` configured for `SDL/0/Keyboard Mouse`." },
      },
    },
  },
}

-- ── SECTOR 5 — Configuration ─────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "config",
  num   = "05",
  title = "Configuration",
  icon  = "settings",
  color = {0.90, 0.35, 0.55},
  chapters = {
    {
      title = "Rt:Core Profiles",
      blocks = {
        { k = "h1", text = "Rt:Core Profiles" },
        { k = "p", text =
          "Eight preconfigured profiles covering every usage " ..
          "scenario: from the safe baseline to the " ..
          "ultra-aggressive experimental." },

        { k = "table",
          headers = { "Profile", "Overclock", "Use" },
          rows = {
            { "Default",         "1.00", "safe baseline" },
            { "Performance",     "0.70", "recommended daily driver" },
            { "Sweet Spot",      "0.70", "Performance + EFBScaledCopy" },
            { "Compatibility",   "1.00", "maximum accuracy" },
            { "Speedhack",       "0.60", "aggressive, proven" },
            { "Ultra",           "0.55", "experimental" },
            { "Ultra Extreme",   "0.50", "last resort" },
            { "Black Screen Fix","1.00", "black screen fix" },
          },
        },

        { k = "h2", text = "Application" },
        { k = "p", text =
          "The selected profile is written to the " ..
          "`dolphin-emu/Config/{Dolphin,GFX}.ini` files before " ..
          "every launch. An automatic backup is created in " ..
          "`Config/.backup_<timestamp>/`." },
      },
    },
    {
      title = "Controller Profiles",
      blocks = {
        { k = "h1", text = "Controller Profiles" },
        { k = "p", text =
          "Ready-made layouts for GameCube and Wii, each " ..
          "optimised for specific game genres." },

        { k = "h2", text = "GameCube" },
        { k = "list", items = {
          "Default, FPS (inverted Y), Inverted, Fighting, " ..
            "Platformer, Z_L3",
        }},

        { k = "h2", text = "Wii" },
        { k = "list", items = {
          "Default (Wiimote+Nunchuk), FPS (inverted IR), " ..
            "MotionPlus, Nunchuk-primary, NoNunchuk, Classic",
        }},

        { k = "h2", text = "Button numbering" },
        { k = "p", text =
          "Profiles use Dolphin numbering (Schema A). Full " ..
          "mapping is in `input_map.lua`." },
      },
    },
    {
      title = "Config Wizard",
      blocks = {
        { k = "h1", text = "Config Wizard" },
        { k = "p", text =
          "Guided wizard that generates a tailored profile " ..
          "based on your answers. Useful for users who don't " ..
          "want to learn INI key names." },

        { k = "h2", text = "Flow" },
        { k = "diagram", name = "wizard_flow" },

        { k = "h2", text = "Targets" },
        { k = "kv",
          rows = {
            { "core_profile", "Global profile (workshop/rtcoreprofile/)" },
            { "per_game",     "GameSettings override (workshop/gamesettings/)" },
          },
        },
      },
    },
  },
}

-- ── SECTOR 6 — Content ──────────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "content",
  num   = "06",
  title = "Content",
  icon  = "library",
  color = {0.30, 0.85, 0.40},
  chapters = {
    {
      title = "Rt:Enhancer Dock",
      blocks = {
        { k = "h1", text = "Rt:Enhancer Dock" },
        { k = "p", text =
          "Storefront for resources, muOS tools and homebrew. " ..
          "The catalogue is in `data/rtenhancerhub.json`." },

        { k = "h2", text = "Categories" },
        { k = "table",
          headers = { "Category", "Content" },
          rows = {
            { "RT RESOURCES",  "Texture packs, mods, cheats" },
            { "MUOS TOOLS",    "Companion apps (VoidDesk, BGM Norm)" },
            { "HOMEBREW",      "Wii/GC apps (Swiss, Nintendont, HBC)" },
            { "CONFIG PACKS",  "Preconfigured profiles" },
          },
        },

        { k = "h2", text = "Downloads" },
        { k = "p", text =
          "Downloads are asynchronous with a persistent queue. " ..
          "The queue survives reboots. Archives are validated " ..
          "before being extracted." },
      },
    },
    {
      title = "Test Report",
      blocks = {
        { k = "h1", text = "Test Report" },
        { k = "p", text =
          "System to document a test session and contribute to " ..
          "the community compatibility database." },

        { k = "h2", text = "Fields" },
        { k = "p", text =
          "Fields mirror the `games_data.json` schema: " ..
          "game_info, test_review, test_details, test_environment." },

        { k = "h2", text = "Auto-fill" },
        { k = "buttons", text = "[A] on AUTO-DETECT  Fills device/muos" },
        { k = "buttons", text = "[A] on LOAD LAST LOG  Extracts from log" },

        { k = "h2", text = "Auto-generated considerations" },
        { k = "p", text =
          "The report_generator automatically generates a " ..
          "human-readable description of the results by " ..
          "combining the structured values." },
      },
    },
  },
}

-- ── SECTOR 7 — Optimisation ─────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "perf",
  num   = "07",
  title = "Optimisation",
  icon  = "advanced",
  color = {0.90, 0.55, 0.20},
  chapters = {
    {
      title = "Hardware reality",
      blocks = {
        { k = "h1", text = "H700 hardware reality" },
        { k = "p", text =
          "Before optimising, you need to know what you're " ..
          "optimising for. The Allwinner H700 SoC consists of:" },

        { k = "kv",
          rows = {
            { "CPU",   "Quad-core Cortex-A53 @ 1.5 GHz" },
            { "GPU",   "Mali-G31 MP2 @ 650 MHz" },
            { "RAM",   "1 GB LPDDR4" },
            { "Driver","Panfrost (Mesa, open-source Bifrost)" },
          },
        },

        { k = "h2", text = "The bottleneck" },
        { k = "p", text =
          "Dolphin's main thread (JIT ARM64) is CPU-bound. The " ..
          "GPU is secondary in almost every title. The A53 is " ..
          "an efficiency core, not a performance core." },
      },
    },
    {
      title = "Key techniques",
      blocks = {
        { k = "h1", text = "Key techniques" },

        { k = "h2", text = "1. Virtual CPU underclock" },
        { k = "p", text =
          "Dolphin lets you reduce the simulated PowerPC clock. " ..
          "Values 0.60-0.80 are the sweet spot for H700: the " ..
          "game runs slower in-game but perceived framerate " ..
          "improves dramatically." },

        { k = "h2", text = "2. Skip Drawing (shaders)" },
        { k = "p", text =
          "`ShaderCompilationMode = 3` makes Dolphin skip " ..
          "drawing objects whose shaders aren't ready yet. " ..
          "Trade-off: small visual pop-ins. Benefit: " ..
          "completely eliminates compilation stutter." },

        { k = "h2", text = "3. EFB copy to GPU" },
        { k = "p", text =
          "`EFBToTextureEnable = True` keeps EFB copies in " ..
          "VRAM instead of reading them into RAM. Eliminates " ..
          "the CPU↔GPU round-trip." },

        { k = "h2", text = "4. VISkip" },
        { k = "p", text =
          "Skips part of the vertex processing. **Never** on " ..
          "Zelda Wind Waker or Twilight Princess: they stop " ..
          "rendering entirely." },
      },
    },
    {
      title = "Troubleshooting",
      blocks = {
        { k = "h1", text = "Troubleshooting" },

        { k = "h2", text = "Black screen on boot" },
        { k = "p", text =
          "Try the **Black Screen Fix** profile. If the game " ..
          "uses EFB access for gameplay (e.g. Skies of Arcadia), " ..
          "enable `EFBAccessEnable` and `MMU` for that title." },

        { k = "h2", text = "Texture flicker" },
        { k = "p", text =
          "The first suspect is **FastDepthCalc**. Despite the " ..
          "name, it's the more accurate method on modern " ..
          "Dolphin, but on Panfrost it causes flicker in some " ..
          "titles. Try disabling it for the single game." },

        { k = "h2", text = "OOM crashes" },
        { k = "p", text =
          "With 1 GB of RAM, avoid unoptimised HD texture packs. " ..
          "Packs over 200 MB are a guarantee of swapping or " ..
          "crashes." },

        { k = "h2", text = "Pixelated/choppy FMVs" },
        { k = "p", text =
          "Raise `SafeTextureCacheColorSamples` to 512 **only** " ..
          "for that title. Don't touch the global." },
      },
    },
  },
}

-- ── SECTOR 8 — Development ─────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "dev",
  num   = "08",
  title = "Development",
  icon  = "wrench",
  color = {0.20, 0.72, 0.98},
  chapters = {
    {
      title = "Code structure",
      blocks = {
        { k = "h1", text = "Code structure" },
        { k = "p", text =
          "Code is organised into separate Lua modules by " ..
          "responsibility. Every file has a single purpose." },

        { k = "table",
          headers = { "Folder", "Content" },
          rows = {
            { "screens/",  "One screen per file, S.enter/S.draw/S.pad" },
            { "ui/",       "Reusable components (header, draw, glyph)" },
            { "minoru/",   "Autonomous character engine" },
            { "workshop/", "Profiles, snapshots, backups" },
            { "scripts/",  "Shell scripts + Live Menu Python" },
          },
        },

        { k = "h2", text = "Screen pattern" },
        { k = "code", text =
          "local S = {}\n" ..
          "function S.enter(params) end\n" ..
          "function S.leave() end\n" ..
          "function S.update(dt) end\n" ..
          "function S.draw() end\n" ..
          "function S.pad(b) end\n" ..
          "function S.hat(dir) end\n" ..
          "function S.key(k) end\n" ..
          "return S" },
      },
    },
    {
      title = "Dev workflow",
      blocks = {
        { k = "h1", text = "Dev workflow" },

        { k = "h2", text = "Scripts" },
        { k = "code", text =
          "./dev.sh run        # launch LÖVE\n" ..
          "./dev.sh check      # syntax check\n" ..
          "./dev.sh clean      # rotate logs\n" ..
          "./dev.sh logs       # tail latest log" },

        { k = "h2", text = "Logs" },
        { k = "p", text =
          "Every `dev.sh` invocation writes a detailed log to " ..
          "`.pclogs/dev_<timestamp>_<cmd>.log`. A symlink " ..
          "`latest.log` always points to the newest." },
      },
    },
  },
}

-- ── SECTOR 9 — Credits ──────────────────────────────────
SECTORS[#SECTORS+1] = {
  id    = "credits",
  num   = "09",
  title = "Credits",
  icon  = "about",
  color = {0.96, 0.77, 0.26},
  chapters = {
    {
      title = "Team & authors",
      blocks = {
        { k = "h1", text = "Credits" },
        { k = "p", text =
          "DolphinUI is a SPDW Factory Lab project, developed " ..
          "by sirpips (SilverCrow2323)." },

        { k = "h2", text = "Special thanks" },
        { k = "quote", text =
          "To my wife Sara, without whom this project would " ..
          "not exist." },

        { k = "h2", text = "Third-party" },
        { k = "table",
          headers = { "Who", "What" },
          rows = {
            { "Dolphin Emulator Team",     "the emulator itself" },
            { "@Speedrun, @FireBattleInMtl, @Snow, @bitter_bizarro", "original Rt:Core porters up to v9" },
            { "SilverCrow2323",            "compat DB, repository, infrastructure" },
            { "PortsMaster",               "gptokeyb2 (input remapper)" },
            { "LÖVE Development Team",     "the runtime" },
            { "muOS Community",            "testing, feedback, icons" },
            { "Admentus64",                "Enhancement codes" },
            { "FortuneStreetModding",      "Gecko codes DB" },
          },
        },

        { k = "h2", text = "Contact" },
        { k = "kv",
          rows = {
            { "GitHub", "github.com/SilverCrow2323" },
            { "Repo",   "github.com/SilverCrow2323/Dolphin-Core-for-MuOS" },
          },
        },
      },
    },
  },
}

-- ══════════════════════════════════════════════════════════════
--  PROCEDURAL DIAGRAMS
-- ══════════════════════════════════════════════════════════════
local DIAGRAMS = {}

-- ── Layered architecture ──────────────────────────────────
function DIAGRAMS.architecture(x, y, w)
  local layer_h = 40
  local layers = {
    { label = "USER INPUT",      sub = "Gamepad · Keyboard · Live Menu",  col = {0.20, 0.72, 0.98} },
    { label = "SCREEN LAYER",    sub = "screens/*.lua  ·  ui/*.lua",     col = {0.55, 0.35, 0.95} },
    { label = "CORE LAYER",      sub = "state.lua  ·  settings  ·  launch", col = {0.30, 0.85, 0.40} },
    { label = "DOLPHIN RT:CORE", sub = "dolphin-emu/dolphin  ·  Config/", col = {0.96, 0.77, 0.26} },
    { label = "HARDWARE",        sub = "H700  ·  Mali-G31  ·  Panfrost",  col = {0.90, 0.35, 0.55} },
  }

  local total_h = #layers * (layer_h + 6) - 6
  local cx = x + w / 2
  local cy = y

  for i, layer in ipairs(layers) do
    local lw = w * (0.85 - (i - 1) * 0.05)
    local lx = cx - lw / 2
    local ly = cy + (i - 1) * (layer_h + 6)

    love.graphics.setColor(layer.col[1] * 0.18, layer.col[2] * 0.18,
      layer.col[3] * 0.18, 1)
    love.graphics.rectangle("fill", lx, ly, lw, layer_h, 4, 4)
    love.graphics.setColor(layer.col)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", lx, ly, lw, layer_h, 4, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(F_BOLD, 11))
    love.graphics.printf(layer.label, lx, ly + 6, lw, "center")
    love.graphics.setColor(layer.col[1], layer.col[2], layer.col[3], 0.75)
    love.graphics.setFont(A.font(F_MONO, 8))
    love.graphics.printf(layer.sub, lx, ly + 22, lw, "center")

    if i < #layers then
      love.graphics.setColor(0.55, 0.62, 0.78, 0.6)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(cx - 6, ly + layer_h, cx - 6, ly + layer_h + 6)
      love.graphics.line(cx + 6, ly + layer_h, cx + 6, ly + layer_h + 6)
      love.graphics.polygon("fill",
        cx,     ly + layer_h + 6,
        cx - 4, ly + layer_h + 2,
        cx + 4, ly + layer_h + 2)
      love.graphics.setLineWidth(1)
    end
  end

  return total_h
end

-- ── Wizard flow ───────────────────────────────────────────
function DIAGRAMS.wizard_flow(x, y, w)
  local box_h = 34
  local node_w = 130
  local gap_y  = 12
  local cx = x + w / 2

  local nodes = {
    { label = "Goal",    sub = "Perf / Fix / Acc", col = {0.20, 0.72, 0.98} },
    { label = "Tier",    sub = "Mild / Rec / Aggr", col = {0.96, 0.77, 0.26} },
    { label = "Review",  sub = "Changes preview", col = {0.55, 0.35, 0.95} },
    { label = "Save",    sub = "Profile name", col = {0.30, 0.85, 0.40} },
  }

  for i, n in ipairs(nodes) do
    local nx = cx - node_w / 2
    local ny = y + (i - 1) * (box_h + gap_y)

    love.graphics.setColor(n.col[1] * 0.18, n.col[2] * 0.18, n.col[3] * 0.18, 1)
    love.graphics.rectangle("fill", nx, ny, node_w, box_h, 6, 6)
    love.graphics.setColor(n.col)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", nx, ny, node_w, box_h, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(F_BOLD, 11))
    love.graphics.printf(n.label, nx, ny + 4, node_w, "center")
    love.graphics.setColor(n.col[1], n.col[2], n.col[3], 0.8)
    love.graphics.setFont(A.font(F_MONO, 8))
    love.graphics.printf(n.sub, nx, ny + 20, node_w, "center")

    if i < #nodes then
      local ay = ny + box_h
      love.graphics.setColor(0.55, 0.62, 0.78, 0.65)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(cx, ay, cx, ay + gap_y)
      love.graphics.polygon("fill",
        cx,     ay + gap_y,
        cx - 4, ay + gap_y - 4,
        cx + 4, ay + gap_y - 4)
      love.graphics.setLineWidth(1)
    end
  end

  return #nodes * (box_h + gap_y)
end

-- ══════════════════════════════════════════════════════════════
--  BLOCK RENDERER — measure and draw
-- ══════════════════════════════════════════════════════════════

-- Computes a block's height without drawing it.
local function measure_block(blk)
  local pad = 4
  if blk.k == "h1" then
    return 38
  elseif blk.k == "h2" then
    return 30
  elseif blk.k == "h3" then
    return 24
  elseif blk.k == "p" then
    local fnt = A.font(F_BODY, 12)
    local _, lines = fnt:getWrap(blk.text, CONTENT_W)
    return #lines * 17 + 8
  elseif blk.k == "quote" then
    local fnt = A.font(F_QUOTE, 13)
    local _, lines = fnt:getWrap(blk.text, CONTENT_W - 40)
    return #lines * 20 + 18
  elseif blk.k == "code" then
    local fnt = A.font(F_MONO, 10)
    local n = 0
    for _ in blk.text:gmatch("[^\n]*\n?") do n = n + 1 end
    return n * 15 + 16
  elseif blk.k == "table" then
    return (1 + #blk.rows) * 22 + 12
  elseif blk.k == "list" then
    local total = 0
    local fnt = A.font(F_BODY, 11)
    for _, item in ipairs(blk.items) do
      local s = item:gsub("%*%*", "")
      local _, lines = fnt:getWrap(s, CONTENT_W - 30)
      total = total + #lines * 16 + 6
    end
    return total + 6
  elseif blk.k == "kv" then
    return #blk.rows * 18 + 12
  elseif blk.k == "buttons" then
    return 26
  elseif blk.k == "diagram" then
    if blk.name == "architecture" then
      return 5 * (40 + 6) - 6 + 12
    elseif blk.name == "wizard_flow" then
      return 4 * (34 + 12) + 12
    end
    return 100
  elseif blk.k == "spacer" then
    return blk.h or 12
  end
  return 0
end

local function total_height(sector)
  local h = 0
  for _, ch in ipairs(sector.chapters) do
    h = h + 30  -- chapter title strip
    for _, blk in ipairs(ch.blocks) do
      h = h + measure_block(blk)
    end
    h = h + 20  -- gap between chapters
  end
  return h + 20
end

-- ── Draw ──────────────────────────────────────────────────
local function draw_h1(blk, x, y)
  love.graphics.setColor(C_H1)
  love.graphics.setFont(A.font(F_FUTURE, 20))
  love.graphics.print(blk.text, x, y + 4)

  local w = love.graphics.getFont():getWidth(blk.text)
  love.graphics.setColor(C_H1[1], C_H1[2], C_H1[3], 0.35)
  love.graphics.setLineWidth(2)
  love.graphics.line(x, y + 30, x + w + 20, y + 30)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(C_H1[1], C_H1[2], C_H1[3], 0.15)
  love.graphics.rectangle("fill", x, y + 32, w + 20, 1)
end

local function draw_h2(blk, x, y)
  love.graphics.setColor(C_H2)
  love.graphics.setFont(A.font(F_BOLD, 15))
  love.graphics.print(blk.text, x, y + 4)
end

local function draw_h3(blk, x, y)
  love.graphics.setColor(C_H3)
  love.graphics.setFont(A.font(F_BOLD, 12))
  love.graphics.print(blk.text, x, y + 4)
end

local function draw_p(blk, x, y)
  love.graphics.setColor(C_BODY)
  love.graphics.setFont(A.font(F_BODY, 12))
  love.graphics.printf(blk.text, x, y + 4, CONTENT_W, "left")
end

local function draw_quote(blk, x, y)
  local fnt = A.font(F_QUOTE, 13)
  local _, lines = fnt:getWrap(blk.text, CONTENT_W - 40)
  local h = #lines * 20 + 8

  love.graphics.setColor(C_QUOTE[1], C_QUOTE[2], C_QUOTE[3], 0.12)
  love.graphics.rectangle("fill", x, y, CONTENT_W, h + 10, 4, 4)

  love.graphics.setColor(C_QUOTE)
  love.graphics.rectangle("fill", x, y, 4, h + 10, 2, 2)

  love.graphics.setColor(C_QUOTE)
  love.graphics.setFont(fnt)
  love.graphics.printf("\"" .. blk.text .. "\"", x + 20, y + 6,
    CONTENT_W - 40, "left")
end

local function draw_code(blk, x, y)
  local fnt = A.font(F_MONO, 10)
  local n = 0
  for _ in blk.text:gmatch("[^\n]*\n?") do n = n + 1 end
  local h = n * 15 + 12

  love.graphics.setColor(0.05, 0.06, 0.09, 0.98)
  love.graphics.rectangle("fill", x, y, CONTENT_W, h, 4, 4)
  love.graphics.setColor(0.55, 0.35, 0.95, 0.55)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, CONTENT_W, h, 4, 4)

  love.graphics.setColor(C_CODE)
  love.graphics.setFont(fnt)
  local cy = y + 8
  for line in (blk.text .. "\n"):gmatch("([^\n]*)\n") do
    love.graphics.print(line, x + 10, cy)
    cy = cy + 15
  end
end

local function draw_table(blk, x, y)
  local row_h = 22
  local n_cols = #blk.headers
  local col_w = CONTENT_W / n_cols

  -- Header
  love.graphics.setColor(C_TABLE[1], C_TABLE[2], C_TABLE[3], 0.28)
  love.graphics.rectangle("fill", x, y, CONTENT_W, row_h, 3, 3)
  love.graphics.setColor(C_TABLE)
  love.graphics.setLineWidth(1.2)
  love.graphics.rectangle("line", x, y, CONTENT_W, row_h, 3, 3)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(A.font(F_BOLD, 10))
  for i, hdr in ipairs(blk.headers) do
    love.graphics.setColor(C_TABLE)
    love.graphics.printf(hdr, x + (i-1) * col_w + 6, y + 5, col_w - 12, "left")
  end

  -- Rows (zebra)
  for r, row in ipairs(blk.rows) do
    local ry = y + r * row_h
    if r % 2 == 0 then
      love.graphics.setColor(0.55, 0.62, 0.78, 0.08)
      love.graphics.rectangle("fill", x, ry, CONTENT_W, row_h)
    end
    love.graphics.setColor(0.55, 0.62, 0.78, 0.18)
    love.graphics.line(x, ry, x + CONTENT_W, ry)

    for i, cell in ipairs(row) do
      love.graphics.setColor(C_BODY)
      love.graphics.setFont(A.font(F_MONO, 9))
      local cx = x + (i-1) * col_w + 6
      local cw = col_w - 12
      local s = tostring(cell)
      if #s > 24 then s = s:sub(1, 22) .. "…" end
      love.graphics.printf(s, cx, ry + 6, cw, "left")
    end
  end
end

local function draw_list(blk, x, y)
  local fnt = A.font(F_BODY, 11)
  local cy = y + 4
  for _, item in ipairs(blk.items) do
    -- Bullet
    love.graphics.setColor(C_H3)
    love.graphics.circle("fill", x + 6, cy + 8, 3)

    -- Text (strip **bold** markers for now)
    local s = item:gsub("%*%*", "")
    love.graphics.setColor(C_BODY)
    love.graphics.setFont(fnt)
    love.graphics.printf(s, x + 18, cy, CONTENT_W - 30, "left")

    local _, lines = fnt:getWrap(s, CONTENT_W - 30)
    cy = cy + #lines * 16 + 6
  end
end

local function draw_kv(blk, x, y)
  local cy = y + 4
  for _, row in ipairs(blk.rows) do
    love.graphics.setColor(C_KV_K)
    love.graphics.setFont(A.font(F_BOLD, 10))
    love.graphics.print(tostring(row[1] or ""), x + 8, cy)

    love.graphics.setColor(C_BODY)
    love.graphics.setFont(A.font(F_MONO, 10))
    local v = tostring(row[2] or "—")
    if #v > 42 then v = v:sub(1, 40) .. "…" end
    love.graphics.print(v, x + 130, cy)

    cy = cy + 18
  end
end

local function draw_buttons_block(blk, x, y)
  local items = {}
  for _, token in ipairs(BI.parse_hint(blk.text)) do
    if token.key then
      local mapped = token.key:upper()
      local aliases = {
        ["↑↓"] = "dpad", ["←→"] = "dpad",
        ["↑"] = "dpad", ["↓"] = "dpad",
        ["←"] = "dpad", ["→"] = "dpad",
      }
      mapped = aliases[token.key] or mapped:lower()
      items[#items + 1] = { key = mapped, label = token.label }
    elseif token.label and token.label ~= "" then
      items[#items + 1] = { label = token.label }
    end
  end

  local cx = x + 6
  local font = A.font(F_BODY, 11)
  local badge_size, inner_pad, gap = 18, 6, 10

  for i, it in ipairs(items) do
    if it.key then
      BI.draw(State.theme, it.key, cx, y + 4, badge_size)
      cx = cx + badge_size
      if it.label and it.label ~= "" then
        love.graphics.setFont(font)
        love.graphics.setColor(C_BODY)
        love.graphics.print(it.label, cx + inner_pad, y + 8)
        cx = cx + inner_pad + font:getWidth(it.label)
      end
    else
      love.graphics.setFont(font)
      love.graphics.setColor(C_BODY)
      love.graphics.print(it.label, cx, y + 8)
      cx = cx + font:getWidth(it.label)
    end
    if i < #items then cx = cx + gap end
  end
end

local function draw_block(blk, x, y)
  if     blk.k == "h1"      then draw_h1(blk, x, y)
  elseif blk.k == "h2"      then draw_h2(blk, x, y)
  elseif blk.k == "h3"      then draw_h3(blk, x, y)
  elseif blk.k == "p"       then draw_p(blk, x, y)
  elseif blk.k == "quote"   then draw_quote(blk, x, y)
  elseif blk.k == "code"    then draw_code(blk, x, y)
  elseif blk.k == "table"   then draw_table(blk, x, y)
  elseif blk.k == "list"    then draw_list(blk, x, y)
  elseif blk.k == "kv"      then draw_kv(blk, x, y)
  elseif blk.k == "buttons" then draw_buttons_block(blk, x, y)
  elseif blk.k == "spacer"  then -- nothing
  elseif blk.k == "diagram" then
    local fn = DIAGRAMS[blk.name]
    if fn then fn(x, y, CONTENT_W) end
  end
end

-- ══════════════════════════════════════════════════════════════
--  STATE + LIFECYCLE
-- ══════════════════════════════════════════════════════════════
S.sector_i  = 1
S.chapter_i = 1
S.scroll    = 0
S._total_h  = 0
S._enter_t  = 0

local function current_sector() return SECTORS[S.sector_i] end

local function max_scroll()
  local vis = BOTTOM_Y - TOP_Y
  return math.max(0, (S._total_h or 0) - vis)
end

local function recompute_height()
  local sec = current_sector()
  if not sec then return end
  S._total_h = total_height(sec)
end

function S.enter()
  S.sector_i  = 1
  S.chapter_i = 1
  S.scroll    = 0
  S._enter_t  = 0
  recompute_height()
  SFX.play("menu_select")
end

function S.re_enter()
  recompute_height()
end

-- ── Input ─────────────────────────────────────────────────
local function change_sector(delta)
  local n = #SECTORS
  local ni = math.max(1, math.min(n, S.sector_i + delta))
  if ni ~= S.sector_i then
    S.sector_i  = ni
    S.chapter_i = 1
    S.scroll    = 0
    recompute_height()
    SFX.play("menu_pagescroll")
  end
end

local function change_chapter(delta)
  local sec = current_sector()
  if not sec then return end
  local n = #sec.chapters
  local ni = math.max(1, math.min(n, S.chapter_i + delta))
  if ni ~= S.chapter_i then
    S.chapter_i = ni
    -- Find the scroll that brings the chapter into view
    local target_scroll = 0
    for i = 1, ni - 1 do
      local ch = sec.chapters[i]
      target_scroll = target_scroll + 30
      for _, blk in ipairs(ch.blocks) do
        target_scroll = target_scroll + measure_block(blk)
      end
      target_scroll = target_scroll + 20
    end
    S.scroll = math.min(target_scroll, max_scroll())
    SFX.play("menu_pagescroll")
  end
end

local function scroll_by(delta)
  S.scroll = math.max(0, math.min(max_scroll(), S.scroll + delta))
end

function S.pad(b)
  if     b == IM.L1 then change_sector(-1)
  elseif b == IM.R1 then change_sector(1)
  elseif b == IM.X  then change_chapter(-1)
  elseif b == IM.Y  then change_chapter(1)
  elseif b == IM.B  then
    State.raw_input = false
    State.back()
  end
end

function S.hat(dir)
  if     dir == "up"    then scroll_by(-24)
  elseif dir == "down"  then scroll_by(24)
  elseif dir == "left"  then change_sector(-1)
  elseif dir == "right" then change_sector(1) end
end

function S.key(k)
  if     k == "up"    then scroll_by(-24)
  elseif k == "down"  then scroll_by(24)
  elseif k == "left"  or k == "q" then change_sector(-1)
  elseif k == "right" or k == "e" then change_sector(1)
  elseif k == "pageup"   then change_chapter(-1)
  elseif k == "pagedown" then change_chapter(1)
  elseif k == "escape" then
    State.raw_input = false
    State.back()
  end
end

function S.update(dt)
  S._enter_t = (S._enter_t or 0) + dt
end

-- ══════════════════════════════════════════════════════════════
--  DRAW
-- ══════════════════════════════════════════════════════════════

local function draw_sidebar(th)
  local sec = current_sector()
  local y = TOP_Y
  local pad = 12
  local w = SIDEBAR_W

  love.graphics.setColor(0.03, 0.05, 0.09, 0.92)
  love.graphics.rectangle("fill", pad - 4, TOP_Y - 6, w - pad + 8,
    BOTTOM_Y - TOP_Y + 12, 6, 6)

  love.graphics.setColor(sec.color[1], sec.color[2], sec.color[3], 0.30)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", pad - 4, TOP_Y - 6, w - pad + 8,
    BOTTOM_Y - TOP_Y + 12, 6, 6)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(0.55, 0.62, 0.78)
  love.graphics.setFont(A.font(F_BOLD, 9))
  love.graphics.print("SECTORS", pad + 4, y - 12)
  love.graphics.setColor(0.55, 0.62, 0.78, 0.35)
  love.graphics.rectangle("fill", pad + 4, y - 2, w - pad - 8, 1)

  y = y + 8
  local t = State.t_ui or 0

  for i, s in ipairs(SECTORS) do
    local focused = (i == S.sector_i)
    local row_h = 22

    if focused then
      local pulse = 0.5 + 0.5 * math.sin(t * 3)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.18)
      love.graphics.rectangle("fill", pad, y - 2, w - pad * 2 + 8, row_h, 3, 3)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.75)
      love.graphics.rectangle("fill", pad, y - 2, 3, row_h, 1, 1)
      love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.45 + pulse * 0.35)
      love.graphics.circle("fill", pad + w - 20, y + row_h / 2 - 2, 3)
    end

    love.graphics.setColor(focused and {1,1,1} or {0.65, 0.70, 0.80})
    love.graphics.setFont(A.font(F_MONO, 10))
    love.graphics.print(s.num, pad + 6, y + 2)

    love.graphics.setColor(focused and {1,1,1} or {0.75, 0.80, 0.88})
    love.graphics.setFont(A.font(F_BOLD, 10))
    love.graphics.print(s.title, pad + 22, y + 2)

    y = y + row_h
  end

  -- Global progress bar
  local total_ch = 0
  for _, s in ipairs(SECTORS) do
    total_ch = total_ch + #s.chapters
  end

  local cy = BOTTOM_Y - 30
  love.graphics.setColor(0.15, 0.18, 0.24, 0.9)
  love.graphics.rectangle("fill", pad, cy, w - pad * 2 + 8, 4, 2, 2)
  local prog = (#SECTORS > 1)
    and (S.sector_i - 1) / (#SECTORS - 1) or 0
  love.graphics.setColor(sec.color[1], sec.color[2], sec.color[3], 0.85)
  love.graphics.rectangle("fill", pad, cy, (w - pad * 2 + 8) * prog, 4, 2, 2)

  love.graphics.setColor(0.55, 0.62, 0.78)
  love.graphics.setFont(A.font(F_MONO, 8))
  love.graphics.printf(("%s of %s"):format(sec.num, SECTORS[#SECTORS].num),
    pad, cy + 8, w - pad * 2 + 8, "center")
end

local function draw_chapter_tab(th, sec)
  local y = TOP_Y - 20
  love.graphics.setColor(0.55, 0.62, 0.78)
  love.graphics.setFont(A.font(F_BOLD, 9))
  love.graphics.print(sec.title:upper(), CONTENT_X, y)

  love.graphics.setColor(sec.color[1], sec.color[2], sec.color[3], 0.35)
  love.graphics.rectangle("fill", CONTENT_X, y + 12, CONTENT_W, 1)

  local cx = CONTENT_X + love.graphics.getFont():getWidth(sec.title:upper()) + 12
  love.graphics.setColor(sec.color)
  love.graphics.setFont(A.font(F_MONO, 8))
  love.graphics.print(("%02d/%02d"):format(S.chapter_i, #sec.chapters), cx, y)
end

function S.draw()
  local th = State.theme
  BG.draw_book(W, H, love.timer.getDelta(), th.accent)
  Header.draw("RT:MANUAL", "manual", "manual")

  draw_sidebar(th)

  local sec = current_sector()
  if not sec then return end

  draw_chapter_tab(th, sec)

  -- Content with scissor
  love.graphics.setScissor(CONTENT_X, TOP_Y, CONTENT_W, BOTTOM_Y - TOP_Y)

  local cy = TOP_Y - S.scroll

  for chi, ch in ipairs(sec.chapters) do
    -- Chapter title strip
    local is_current = (chi == S.chapter_i)
    local strip_h = 30

    love.graphics.setColor(
      sec.color[1] * (is_current and 0.25 or 0.10),
      sec.color[2] * (is_current and 0.25 or 0.10),
      sec.color[3] * (is_current and 0.25 or 0.10), 0.95)
    love.graphics.rectangle("fill", CONTENT_X - 4, cy, CONTENT_W + 8, strip_h, 4, 4)

    love.graphics.setColor(sec.color[1], sec.color[2], sec.color[3],
      is_current and 0.95 or 0.55)
    love.graphics.rectangle("fill", CONTENT_X - 4, cy, 4, strip_h, 2, 2)

    love.graphics.setFont(A.font(F_ORBIT, 12))
    love.graphics.setColor(sec.color[1], sec.color[2], sec.color[3],
      is_current and 1 or 0.85)
    love.graphics.print(string.format("%s.%d", sec.num, chi),
      CONTENT_X + 4, cy + 6)

    love.graphics.setFont(A.font(F_BOLD, 13))
    love.graphics.setColor(is_current and {1,1,1} or {0.75, 0.80, 0.88})
    love.graphics.print(ch.title, CONTENT_X + 40, cy + 6)

    cy = cy + strip_h + 6

    -- Blocks
    for _, blk in ipairs(ch.blocks) do
      local bh = measure_block(blk)
      if cy + bh > TOP_Y - 60 and cy < BOTTOM_Y + 60 then
        draw_block(blk, CONTENT_X, cy)
      end
      cy = cy + bh
    end

    cy = cy + 20  -- gap
  end

  love.graphics.setScissor()

  -- Scroll rail
  local vis_h = BOTTOM_Y - TOP_Y
  if S._total_h > vis_h then
    local rail_x = W - 8
    love.graphics.setColor(0.20, 0.22, 0.28, 0.6)
    love.graphics.rectangle("fill", rail_x, TOP_Y, 3, vis_h, 1, 1)
    local ratio = vis_h / S._total_h
    local bar_h = math.max(20, vis_h * ratio)
    local span = S._total_h - vis_h
    local bar_y = TOP_Y + (span > 0 and (S.scroll / span) * (vis_h - bar_h) or 0)
    love.graphics.setColor(sec.color)
    love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
  end

  -- Footer
  BI.draw_footer(th, {
    { key = "l1",   label = "Sector -" },
    { key = "r1",   label = "Sector +" },
    { key = "dpad", label = "Scroll" },
    { key = "x",    label = "Ch -" },
    { key = "y",    label = "Ch +" },
    { key = "b",    label = "Back" },
  }, W, H - 22, A.font(th.font_body, 11))
end

return S