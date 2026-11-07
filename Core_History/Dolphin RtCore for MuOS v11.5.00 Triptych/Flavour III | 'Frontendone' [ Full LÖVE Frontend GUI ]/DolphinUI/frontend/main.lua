-- frontend/main.lua — orchestration, dispatcher, transitions,
-- theme flip, input debounce, safe-screen wrapper, GC, log
-- rotation, async data reload, download queue polling, async
-- ROM scan, enhancer boot gating, priority routing.
--
-- v0.5.3
--   * finalize_scan() enriches ROM titles with GameTDB titles
--     (wii_title_db) and dedups by absolute path.
--   * minoru_room screen registered; accessible from the menu
--     and from Settings → About.
--   * Data refresh handler resets wii_title_db and re-applies
--     official titles without restarting.

local IM           = require("input_map")
local SFX          = require("sfx")
local State        = require("state")
local Modal        = require("modal")
local T            = require("ui.transition")
local Notify       = require("notify")
local Store        = require("settings_store")
local KB           = require("key_bindings")
local DL           = require("downloader")
local AsyncScanner = require("async_scanner")
local theme_gc     = require("theme_gc")
local theme_wii    = require("theme_wii")
local DLOverlay    = require("ui.download_overlay")
local QuickGuide   = require("ui.quick_guide_overlay")
local Crash        = require("crash_handler")

local W, H = 640, 480
local unpack = unpack or table.unpack

local APP_VERSION = "0.5.3"

-- ══════════════════════════════════════════════════════════════
--  System-level buttons
-- ══════════════════════════════════════════════════════════════
local SYSTEM_RAW_BUTTONS = { [1] = true, [2] = true }
local SYSTEM_SEMANTIC    = { volumeup = true, volumedown = true }

local ENTRY_SCREENS = {
  boot         = true,
  spdw_warning = true,
  onboarding   = true,
}

-- Screens that show the theme switch in the header. On every OTHER
-- screen, SELECT / TAB is a no-op. Kept in sync with
-- header.lua's BRANDED_SCREENS list.
local THEME_FLIP_SCREENS = {
  -- Only screens where flipping theme has a direct, visible effect
  -- on the content: library (filtered list + mirror layout) and
  -- compatibility (GC / Wii filtering + mirror layout). Everywhere
  -- else SELECT is a no-op.
  boot             = true,
  menu             = true,
  library          = true,
  compatibility    = true,
}

-- ══════════════════════════════════════════════════════════════
--  Boot utilities
-- ══════════════════════════════════════════════════════════════
local function log(msg) print("[main] " .. msg) end

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function rotate_logs(glob_pattern, keep)
  keep = keep or 20
  local h = io.popen('ls -1t ' .. shq(glob_pattern) .. ' 2>/dev/null')
  if not h then return end
  local i = 0
  for line in h:lines() do
    i = i + 1
    if i > keep then os.remove(line) end
  end
  h:close()
end

local function ensure_dir(p) os.execute("mkdir -p " .. shq(p)) end

local function rotate_all_logs()
  rotate_logs("data/logs/*.log", 20)
  rotate_logs("data/logs/launcher_*.log", 10)
  rotate_logs("data/logs/dolphinrtcore_*.log", 10)
  rotate_logs("data/logs/crash_*.log", 20)
end

-- ══════════════════════════════════════════════════════════════
--  Input state
-- ══════════════════════════════════════════════════════════════
local DPadHeld = {}
local DPadNext = {}
local DPAD_FIRST_DELAY = 0.35
local DPAD_REPEAT = 0.09
local last_input_t = 0
local DEBOUNCE = 0.08
local _last_raw_event_t = 0
local RAW_PRIORITY_WINDOW = 0.030
local HeldButtons = {}
local RAW_START  = 10
local RAW_SELECT = 9
local FORCE_QUIT_HOLD = 1.5
local _force_quit = { active = false, holding = false, t = 0 }

-- ══════════════════════════════════════════════════════════════
--  Theme + State boot
-- ══════════════════════════════════════════════════════════════
local function load_persisted_theme()
  pcall(Store.load)
  local t = Store.get("general", "theme")
  if t == "gc" or t == "wii" then return t end
  return "gc"
end

State.theme_name = load_persisted_theme()
State.theme      = (State.theme_name == "wii") and theme_wii or theme_gc
State.screen     = "spdw_warning"
State.history    = State.history or {}
State.t_ui       = 0
State.raw_input  = false

State.last_played     = State.last_played or nil
State.favorites       = State.favorites or {}
State.onboarding_done = false

local _flip_enabled = true
local _show_fps      = false

local function refresh_flip_setting()
  local v = Store.get("general", "flip_animation")
  _flip_enabled = (v ~= false)
end

-- ══════════════════════════════════════════════════════════════
--  Screens registry
-- ══════════════════════════════════════════════════════════════
local screens = {
  onboarding             = require("screens.onboarding"),
  spdw_warning           = require("screens.spdw_warning"),
  boot                   = require("screens.boot"),
  menu                   = require("screens.menu"),
  library                = require("screens.library"),
  compatibility          = require("screens.compatibility"),
  homebrew_hub           = require("screens.homebrew_hub"),
  homebrew               = require("screens.homebrew"),
  enhancer_boot          = require("screens.enhancer_boot"),
  ethostore              = require("screens.ethostore"),
  workshop               = require("screens.workshop"),
  workshop_profiles      = require("screens.workshop_profiles"),
  workshop_data          = require("screens.workshop_data"),
  workshop_files         = require("screens.workshop_files"),
  workshop_mods          = require("screens.workshop_mods"),
  workshop_controller    = require("screens.workshop_controller"),
  workshop_hotkeys       = require("screens.workshop_hotkeys"),
  workshop_gamesets      = require("screens.workshop_gamesets"),
  workshop_rollback      = require("screens.workshop_rollback"),
  workshop_diff          = require("screens.workshop_diff"),
  workshop_import        = require("screens.workshop_import"),
  workshop_snapshots     = require("screens.workshop_snapshots"),
  workshop_hotkey_edit   = require("screens.workshop_hotkey_edit"),
  report_window          = require("screens.report_window"),
  settings               = require("screens.settings"),
  settings_app           = require("screens.settings_app"),
  settings_keymap        = require("screens.settings_keymap"),
  input_center           = require("screens.input_center"),
  input_debug            = require("screens.input_debug"),
  external_input_station = require("screens.external_input_station"),
  external               = require("screens.external"),
  manual                 = require("screens.manual"),
  game_detail            = require("screens.game_detail"),
  saves                  = require("screens.saves"),
  cheats                 = require("screens.cheats"),
  config_choice          = require("screens.config_choice"),
  config_wizard          = require("screens.config_wizard"),
  rom_paths              = require("screens.rom_paths"),
  file_explorer          = require("screens.file_explorer"),
  about                  = require("screens.about"),
  minoru_room            = require("screens.minoru_room"),
}

-- ══════════════════════════════════════════════════════════════
--  Theme cycling
-- ══════════════════════════════════════════════════════════════
local THEME_ORDER = { "gc", "wii" }

local function pick_theme(id)
  return (id == "wii") and theme_wii or theme_gc
end

local flip = { active = false, t = 0, dur = 0.35, dir = 1 }

local function swap_theme()
  local idx = 1
  for i, id in ipairs(THEME_ORDER) do
    if id == State.theme_name then idx = i break end
  end
  idx = (idx % #THEME_ORDER) + 1
  State.theme_name = THEME_ORDER[idx]
  State.theme      = pick_theme(State.theme_name)
  State.page_lib   = 1
  State.focus_lib  = { x = 0, y = 0 }
  love.graphics.setBackgroundColor(State.theme.bg)
  pcall(function()
    Store.set("general", "theme", State.theme_name)
    Store.save()
  end)
  pcall(function()
    local C = require("chips")
    if C and C.invalidate then C.invalidate() end
  end)
  log("theme -> " .. State.theme_name)
end

-- ══════════════════════════════════════════════════════════════
--  Transitions + navigation
-- ══════════════════════════════════════════════════════════════
local TRANSITION_BY_NAME = {
  spdw_warning     = "fade",
  onboarding       = "fade",
  menu             = "zoom",
  library          = "slide",
  homebrew_hub     = "wipe",
  workshop         = "glitch",
  settings_keymap  = "glitch",
  input_center     = "glitch",
  external_input_station = "glitch",
  ethostore        = "fade",
  compatibility    = "fade",
  settings         = "fade",
  boot             = "glitch",
  rom_paths        = "slide",
  file_explorer    = "zoom",
  about            = "fade",
  minoru_room      = "fade",
}

local function transition_style_for(name)
  return TRANSITION_BY_NAME[name] or "fade"
end

local function call_enter(target, args)
  if not target or type(target) ~= "table" or not target.enter then return end
  local ok, err = pcall(target.enter, unpack(args or {}))
  if not ok then log("[enter] " .. tostring(err)) end
end

local function call_leave(target)
  if target and type(target) == "table" and target.leave then
    pcall(target.leave)
  end
end

local function reset_input_state()
  State.raw_input    = false
  State.capture_mode = false
  DPadHeld = {}
  DPadNext = {}
end

local function redirect_by_flags(name)
  if name == "enhancer_boot" then
    if State.enhancer_boot_done then return "ethostore" end
    if Store.get("advanced", "enhancer_boot_animation") == false then
      State.enhancer_boot_done = true
      return "ethostore"
    end
  end
  if name == "homebrew_hub"
     and Store.get("advanced", "homebrew_hub_splash") == false then
    return "homebrew"
  end
  return name
end

local function navigate_to(name, reset_history, ...)
  if T.busy() then return end
  name = redirect_by_flags(name)
  call_leave(screens[State.screen])

  local args  = { ... }
  local style = transition_style_for(name)
  T.change(style, function()
    local target = screens[name]
    if not target or type(target) ~= "table" then
      log("[go] unknown screen: " .. tostring(name))
      return
    end
    State.screen = name

    if reset_history or ENTRY_SCREENS[name] then
      State.history = { name }
    else
      table.insert(State.history, name)
    end

    reset_input_state()
    call_enter(target, args)
  end)
end

function State.go(name, ...)
  navigate_to(name, false, ...)
end

function State.go_root(name, ...)
  navigate_to(name, true, ...)
end

function State.go_boot()
  State.go_root("boot")
end

function State.back()
  if T.busy() then return end
  if #State.history <= 1 then return end

  call_leave(screens[State.screen])
  reset_input_state()

  table.remove(State.history)

  while #State.history > 1
        and State.history[#State.history] == "enhancer_boot"
        and State.enhancer_boot_done do
    table.remove(State.history)
  end

  local prev = State.history[#State.history]
  if not prev then
    State.history = { "menu" }
    prev = "menu"
  end

  local style = "fade"
  if     prev == "menu"      then style = "zoom"
  elseif prev == "library"   then style = "slide"
  elseif prev == "rom_paths" then style = "slide" end

  T.change(style, function()
    local target = screens[prev]
    if not target or type(target) ~= "table" then
      log("[back] unknown screen: " .. tostring(prev))
      return
    end
    State.screen = prev
    reset_input_state()
    call_enter(target)
    if target.re_enter then
      local ok, err = pcall(target.re_enter)
      if not ok then log("[re_enter] " .. prev .. ": " .. tostring(err)) end
    end
  end)
end

-- ══════════════════════════════════════════════════════════════
--  SFX preload
-- ══════════════════════════════════════════════════════════════
SFX.preload({
  "menu_move","menu_select","menu_back","menu_flip",
  "menu_pagescroll","menu_toggleoption","gamecube_startup",
  "livemenu_open","notif_general",
  "dead_space_ui_sound_1","dead_space_menu_sound","dead_space_locator",
  "ethostore_move",
})

-- ══════════════════════════════════════════════════════════════
--  Apply settings
-- ══════════════════════════════════════════════════════════════
local function apply_settings()
  local d = Store.data()
  if d.sfx then
    SFX.muted  = (d.sfx.enabled == false)
    local vol  = tonumber(d.sfx.volume) or 70
    SFX.volume = math.max(0, math.min(1, vol / 100))
  end
  pcall(function()
    local BG = require("ui.bg")
    if BG.set_particles_enabled and d.ui then
      BG.set_particles_enabled(d.ui.particles ~= false)
    end
  end)
  _show_fps = (d.ui and d.ui.show_fps == true) or false
  refresh_flip_setting()
end
State.apply_settings = apply_settings

-- ══════════════════════════════════════════════════════════════
--  Update check
-- ══════════════════════════════════════════════════════════════
local _update_checked = false

local function parse_semver(v)
  local a, b, c = tostring(v):match("^(%d+)%.(%d+)%.(%d+)")
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function is_newer(remote, local_v)
  local rM, rm, rp = parse_semver(remote)
  local lM, lm, lp = parse_semver(local_v)
  if rM ~= lM then return rM > lM end
  if rm ~= lm then return rm > lm end
  return rp > lp
end

local function check_local_update()
  if _update_checked then return end
  if Store.get("advanced", "update_check") == false then
    _update_checked = true
    return
  end
  local f = io.open("data/rtenhancerhub.json", "r")
  if not f then return end
  _update_checked = true
  local content = f:read("*a"); f:close()
  local ok, decoded = pcall(require("json").decode, content)
  if not ok or type(decoded) ~= "table" then return end
  local d = decoded.dolphinui
  if type(d) ~= "table" then return end
  local latest = tostring(d.latest_version or "")
  if latest == "" then return end
  if is_newer(latest, APP_VERSION) then
    State.update_available = {
      version = latest,
      url     = d.url
                or "https://github.com/SilverCrow2323/Dolphin-Core-for-MuOS",
      notes   = d.notes,
    }
    log("update available: v" .. latest)
  end
end

-- ══════════════════════════════════════════════════════════════
--  Data auto-download
-- ══════════════════════════════════════════════════════════════
local _bd = nil
local _bd_polled = false

local function schedule_data_download()
  local ok, bd = pcall(require, "boot_downloader")
  if ok and bd and bd.update_all then
    _bd = bd
    bd.update_all()
  end
end

-- Re-apply official GameTDB titles to every ROM in State.roms.
-- Called after a fresh wiitdb.txt has been downloaded and after
-- the DB module has been reset, so newly-known titles take effect
-- without needing an app restart.
local function reenrich_rom_titles()
  if not State.roms then return end
  local ok, WDB = pcall(require, "wii_title_db")
  if not ok or not WDB then return end
  local n = 0
  for _, r in ipairs(State.roms) do
    if not r.virtual and r.id and #r.id == 6 then
      local t = WDB.title_for(r.id)
      if t and t ~= "" and r.title ~= t then
        r.file_title   = r.file_title or r.title
        r.title        = t
        r.title_source = "wiitdb"
        n = n + 1
      end
    end
  end
  if n > 0 then
    log(string.format("reenriched %d ROM titles from wiitdb.txt", n))
  end
end

local function poll_data_download()
  if not _bd or _bd_polled then return end
  if _bd.poll_ready and _bd.poll_ready() then
    _bd_polled = true
    log("data refresh completed, reloading in-memory indexes")
    pcall(function() State.load_games_data()   end)
    pcall(function() State.load_enhancer_hub() end)
    pcall(function()
      local W = require("wii_title_db")
      if W and W.reset then W.reset() end
    end)
    pcall(reenrich_rom_titles)
    pcall(function()
      local Chips = require("chips")
      if Chips and Chips.invalidate then Chips.invalidate() end
    end)
    _update_checked = false
    check_local_update()
    if Notify and Notify.show then
      Notify.show("success", "Data refreshed")
    end
  end
end

-- ══════════════════════════════════════════════════════════════
--  ROM scan (async)
-- ══════════════════════════════════════════════════════════════
local _scan_started   = false
local _scan_polled_at = 0
local SCAN_POLL_INTERVAL = 0.5
local _rescan_armed     = false
local _rescan_delay     = 0
local _rescan_baseline  = nil
local _pending_diff     = nil

local function finalize_scan(roms)
  local baseline = _pending_diff
  _pending_diff  = nil
  local first_scan = (baseline == nil)

  -- 1. Dedup by absolute path (removes overlaps from scan paths and
  --    keyword-fallback directories).
  if State.dedupe_roms then
    roms = State.dedupe_roms(roms or {})
  end

  -- 2. Enrich every ROM with the official title from wiitdb.txt,
  --    using the GameID extracted from the binary file header by
  --    async_scanner.lua. rom.file_title keeps the filename-derived
  --    title for fallback and for use in filenames.
  local enriched, fallback = 0, 0
  local ok, WDB = pcall(require, "wii_title_db")
  if ok and WDB then
    for _, r in ipairs(roms or {}) do
      if r.id and #r.id == 6 then
        local official = WDB.title_for(r.id)
        if official and official ~= "" then
          r.file_title   = r.title
          r.title        = official
          r.title_source = "wiitdb"
          enriched = enriched + 1
        else
          r.title_source = "filename"
          fallback = fallback + 1
        end
      else
        r.title_source = "filename"
        r.id = nil
        fallback = fallback + 1
      end
    end
  else
    fallback = #(roms or {})
  end

  State.roms = {}
  table.insert(State.roms, { title = "GameCube Console", sys = "GC",
                             virtual = "gc"  })
  table.insert(State.roms, { title = "Wii System Menu",  sys = "Wii",
                             virtual = "wii" })
  for _, r in ipairs(roms or {}) do table.insert(State.roms, r) end
  State.scan_done = true

  log(string.format(
    "async scan done: %d roms  (wiitdb: %d matched, %d fallback)",
    #State.roms - 2, enriched, fallback))

  pcall(function() State.scan_homebrew() end)

  if first_scan then
    schedule_data_download()
    check_local_update()
  end

  local n = #State.roms - 2
  if baseline then
    local new_count = 0
    for _, r in ipairs(State.roms) do
      if r.path and not baseline[r.path] then new_count = new_count + 1 end
    end
    if Notify and Notify.show then
      if new_count > 0 then
        Notify.show("success",
          string.format("Scan: %d ROMs  (+%d new)", n, new_count), 3.0)
      else
        Notify.show("info", string.format("Scan: %d ROMs", n), 3.0)
      end
    end
  else
    if Notify and Notify.show then
      Notify.show(n > 0 and "success" or "info",
        string.format("Library ready: %d ROM(s)", n), 3.0)
    end
  end
end

local function start_scan()
  if _scan_started then return end
  _scan_started = true
  log("scan: starting async ROM scan")
  AsyncScanner.start()
end

local function poll_async_scan(dt)
  if not AsyncScanner.is_running() then return end
  _scan_polled_at = _scan_polled_at + dt
  if _scan_polled_at < SCAN_POLL_INTERVAL then return end
  _scan_polled_at = 0
  local done, roms = AsyncScanner.poll()
  if done then finalize_scan(roms or {}) end
end

local function arm_rescan(delay)
  local baseline = {}
  for _, r in ipairs(State.roms or {}) do
    if r.path then baseline[r.path] = true end
  end
  _rescan_baseline = baseline
  _rescan_armed    = true
  _rescan_delay    = delay or 0.6
end
State.arm_rescan = arm_rescan

local function poll_rom_rescan(dt)
  if State._rescan_pending then
    State._rescan_pending = false
    arm_rescan(State._rescan_delay or 0.6)
  end
  if not _rescan_armed then return end
  _rescan_delay = _rescan_delay - dt
  if _rescan_delay > 0 then return end
  _rescan_armed  = false
  _pending_diff  = _rescan_baseline or {}
  _rescan_baseline = nil
  AsyncScanner.start()
end

-- ══════════════════════════════════════════════════════════════
--  Input debounce
-- ══════════════════════════════════════════════════════════════
local function input_ok()
  local now = love.timer.getTime()
  if now - last_input_t < DEBOUNCE then return false end
  last_input_t = now
  return true
end

-- ══════════════════════════════════════════════════════════════
--  Safe dispatch
-- ══════════════════════════════════════════════════════════════
local function current_screen() return screens[State.screen] end

local function safe_draw(s)
  if not s or type(s) ~= "table" or not s.draw then return end
  local ok, err = pcall(s.draw)
  if not ok then
    love.graphics.setColor(0.9, 0.2, 0.2, 1)
    love.graphics.print("DRAW ERROR:\n" .. tostring(err), 20, 20)
    log("[draw] " .. tostring(err))
  end
end

local function safe_update(s, dt)
  if not s or type(s) ~= "table" or not s.update then return end
  local ok, err = pcall(s.update, dt)
  if not ok then log("[update] " .. tostring(err)) end
end

local function safe_key(s, k)
  if not s or type(s) ~= "table" or not s.key then return end
  local ok, err = pcall(s.key, k)
  if not ok then log("[key] " .. tostring(err)) end
end

local function safe_pad(s, b)
  if not s or type(s) ~= "table" or not s.pad then return end
  if b == nil then return end
  local ok, err = pcall(s.pad, b)
  if not ok then log("[pad] " .. tostring(err)) end
end

local function safe_hat(s, dir)
  if not s or type(s) ~= "table" or not s.hat then return end
  local ok, err = pcall(s.hat, dir)
  if not ok then log("[hat] " .. tostring(err)) end
end

-- ══════════════════════════════════════════════════════════════
--  Gamepad detection
-- ══════════════════════════════════════════════════════════════
local function detect_joysticks()
  if not (love.joystick and love.joystick.getJoysticks) then return end
  for i, j in ipairs(love.joystick.getJoysticks()) do
    local name, is_gp = "?", false
    pcall(function() name  = j:getName() end)
    pcall(function() is_gp = j:isGamepad() end)
    log(string.format("joystick #%d: '%s'  isGamepad=%s",
      i, name, tostring(is_gp)))
  end
end

-- ══════════════════════════════════════════════════════════════
--  Logical dispatch
-- ══════════════════════════════════════════════════════════════
local function dispatch_logical(logical)
  if not logical then return end
  if logical == "UP"    then safe_hat(current_screen(), "up");    return end
  if logical == "DOWN"  then safe_hat(current_screen(), "down");  return end
  if logical == "LEFT"  then safe_hat(current_screen(), "left");  return end
  if logical == "RIGHT" then safe_hat(current_screen(), "right"); return end

  if logical == "L2"
     and not State.capture_mode
     and not DLOverlay.is_open()
     and not QuickGuide.is_open() then
    QuickGuide.open()
    return
  end

  if State.raw_input then
    local semantic = IM[logical]
    if semantic then safe_pad(current_screen(), semantic) end
    return
  end

  if logical == "R2" then DLOverlay.toggle(); return end

  if logical == "SELECT" then
    local s = current_screen()
    if s and s.on_select then
      local ok, err = pcall(s.on_select)
      if not ok then log("[on_select] " .. tostring(err)) end
    elseif THEME_FLIP_SCREENS[State.screen] then
      trigger_flip()
    end
    return
  end

  if logical == "B" then
    local prev = State.history[#State.history - 1]
    local is_top = (prev == nil) or ENTRY_SCREENS[prev] or false
    if not is_top and #State.history > 1 then
      SFX.play("menu_back")
      State.back()
    end
    return
  end

  local semantic = IM[logical]
  if semantic then safe_pad(current_screen(), semantic) end
end

-- ══════════════════════════════════════════════════════════════
--  D-pad repeat
-- ══════════════════════════════════════════════════════════════
local function dpad_dir_from_logical(logical)
  if logical == "UP"    then return "up"    end
  if logical == "DOWN"  then return "down"  end
  if logical == "LEFT"  then return "left"  end
  if logical == "RIGHT" then return "right" end
  return nil
end

local function update_dpad(dt)
  local to_remove = nil
  for dir, t in pairs(DPadNext) do
    if DPadHeld[dir] then
      t = t - dt
      if t <= 0 then
        safe_hat(current_screen(), dir)
        DPadNext[dir] = DPAD_REPEAT
      else
        DPadNext[dir] = t
      end
    else
      if not to_remove then to_remove = {} end
      to_remove[#to_remove + 1] = dir
    end
  end
  if to_remove then
    for _, dir in ipairs(to_remove) do DPadNext[dir] = nil end
  end
end

-- ══════════════════════════════════════════════════════════════
--  Force-quit panel
-- ══════════════════════════════════════════════════════════════
local function open_force_quit()
  if _force_quit.active then return end
  _force_quit.active  = true
  _force_quit.holding = false
  _force_quit.t       = 0
  SFX.play("menu_select")
end

local function close_force_quit()
  if not _force_quit.active then return end
  _force_quit.active  = false
  _force_quit.holding = false
  _force_quit.t       = 0
  SFX.play("menu_back")
end

local function maybe_fire_force_quit(button)
  local is_start  = (button == RAW_START)
  local is_select = (button == RAW_SELECT)
  if not (is_start or is_select) then return false end
  local other = is_start and RAW_SELECT or RAW_START
  if not HeldButtons[other] then return false end
  open_force_quit()
  return true
end

local function update_force_quit(dt)
  if not _force_quit.active then return end
  if _force_quit.holding then
    _force_quit.t = _force_quit.t + dt
    if _force_quit.t >= FORCE_QUIT_HOLD then
      log("force quit via START+SELECT (held " .. FORCE_QUIT_HOLD .. "s)")
      HeldButtons = {}
      pcall(function() require("covers").flush() end)
      pcall(Store.save)
      pcall(function() AsyncScanner.cancel() end)
      pcall(function() SFX.stop_all() end)
      os.exit(0)
    end
  end
end

local function draw_force_quit()
  local w, h = 460, 180
  local x, y = (W - w) / 2, (H - h) / 2
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, W, H)
  love.graphics.setColor(0.06, 0.06, 0.10, 0.98)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)
  local col = {0.90, 0.30, 0.30}
  love.graphics.setColor(col)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 8, 8)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(require("assets").font(State.theme.font_title, 16))
  love.graphics.printf("FORCE QUIT", x, y + 18, w, "center")
  love.graphics.setColor(State.theme.text)
  love.graphics.setFont(require("assets").font(State.theme.font_body, 11))
  love.graphics.printf(
    "Hold [A] for " .. string.format("%.1f", FORCE_QUIT_HOLD) ..
    " s to terminate DolphinUI.\n\n" ..
    "Background downloads keep running.\nPress [B] to cancel.",
    x + 20, y + 54, w - 40, "center")
  local bar_x, bar_y = x + 40, y + h - 42
  local bar_w, bar_h = w - 80, 12
  love.graphics.setColor(0.10, 0.10, 0.14, 1)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 6, 6)
  local p = math.min(1, _force_quit.t / FORCE_QUIT_HOLD)
  if p > 0 then
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * p, bar_h, 6, 6)
  end
  love.graphics.setColor(0.85, 0.85, 0.90)
  love.graphics.setFont(require("assets").font(State.theme.font_body_bold, 10))
  love.graphics.printf(("%d%%"):format(math.floor(p * 100)),
    x, bar_y - 18, w, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Boot screen selection
-- ══════════════════════════════════════════════════════════════
local function choose_first_screen()
  if Store.get("general", "onboarding_done") ~= true then
    State.screen  = "onboarding"
    State.history = { "onboarding" }
    call_enter(screens.onboarding)
    return
  end
  if Store.get("advanced", "spdw_warning") == false then
    State.screen  = "boot"
    State.history = { "boot" }
    call_enter(screens.boot)
    return
  end
  State.screen  = "spdw_warning"
  State.history = { "spdw_warning" }
  call_enter(screens.spdw_warning)
end

-- ══════════════════════════════════════════════════════════════
--  LÖVE callbacks
-- ══════════════════════════════════════════════════════════════
function love.load()
  Crash.install(APP_VERSION)

  log("boot v" .. APP_VERSION .. "  theme=" .. State.theme_name)
  ensure_dir("data/logs")
  ensure_dir("data/reports")
  ensure_dir("data/exports")
  ensure_dir("data/downloads")
  ensure_dir("data/installed")
  ensure_dir("data/icons")
  ensure_dir("data/covers")
  ensure_dir("minoru/data")
  rotate_all_logs()
  Crash.surface_previous()

  KB.init()
  DL.init()
  if DL.reap_stale then pcall(DL.reap_stale) end

  apply_settings()
  State.onboarding_done = (Store.get("general", "onboarding_done") == true)

  if Store.get("advanced", "sfx_diagnose") == true then
    SFX.diagnose()
  end

  love.graphics.setBackgroundColor(State.theme.bg)
  love.graphics.setDefaultFilter("linear", "linear")

  reset_input_state()
  State.scan_done = false

  choose_first_screen()

  detect_joysticks()

  local function scan_fast()
    local ok, feat = pcall(require, "features")
    if ok and feat and feat.detect then State.features = feat.detect() end
    pcall(function() State.load_games_data()   end)
    pcall(function() State.load_enhancer_hub() end)
  end
  scan_fast()

  start_scan()
end

function love.joystickadded(_j)
  pcall(function() IM.refresh_joystick_state() end)
  detect_joysticks()
end

local gc_t = 0
function love.update(dt)
  State.t_ui = State.t_ui + dt
  update_force_quit(dt)
  poll_async_scan(dt)
  poll_rom_rescan(dt)

  if flip.active then
    flip.t = flip.t + dt
    if flip.dir == 1 and flip.t >= flip.dur / 2 then
      swap_theme(); flip.dir = -1
    end
    if flip.t >= flip.dur then
      flip.active = false; flip.t = 0; flip.dir = 1
    end
  end

  T.update(dt)
  Notify.update(dt)
  QuickGuide.update(dt)
  poll_data_download()
  DL.update(dt)
  DLOverlay.update(dt)
  update_dpad(dt)

  pcall(function()
    local C = require("covers")
    if C and C.update_remote then C.update_remote(dt) end
  end)

  gc_t = gc_t + dt
  if gc_t > 0.5 then
    gc_t = 0
    pcall(collectgarbage, "step", 128)
  end

  if not DLOverlay.is_open() and not _force_quit.active
     and not QuickGuide.is_open() then
    safe_update(current_screen(), dt)
  end
end

local function flip_scale()
  if not flip.active then return 1 end
  local p = flip.t / flip.dur
  return math.abs(math.cos(p * math.pi))
end

function love.draw()
  Modal.drawn_this_frame = false
  love.graphics.setBackgroundColor(State.theme.bg)

  love.graphics.push()
  local sx = flip_scale()
  love.graphics.translate(W / 2, H / 2)
  love.graphics.scale(sx, 1)
  love.graphics.translate(-W / 2, -H / 2)
  safe_draw(current_screen())
  love.graphics.pop()

  if Modal.is_open() and not Modal.drawn_this_frame
     and not DLOverlay.is_open() and not _force_quit.active then
    pcall(Modal.draw)
  end

  T.draw(W, H)
  if DLOverlay.is_open() then DLOverlay.draw(W, H) end
  Notify.draw(W, H)
  if _force_quit.active then draw_force_quit() end
  QuickGuide.draw(W, H)

  if _show_fps then
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(tostring(love.timer.getFPS()) .. " fps", W - 56, 3)
  end
end

function trigger_flip()
  if flip.active then return end
  if not _flip_enabled then return end
  flip.active = true; flip.t = 0; flip.dir = 1
  SFX.play("menu_flip")
end
State.flip_trigger = trigger_flip

-- ══════════════════════════════════════════════════════════════
--  Restart / quit
-- ══════════════════════════════════════════════════════════════
local _quit_confirmed = false

local function read_self_cmdline()
  local f = io.open("/proc/self/cmdline", "rb")
  if not f then return nil end
  local c = f:read("*a"); f:close()
  if not c or c == "" then return nil end
  local args = {}
  for a in c:gmatch("[^\0]+") do
    if a ~= "" then table.insert(args, a) end
  end
  return (#args > 0) and args or nil
end

function State.restart_app()
  _quit_confirmed = true
  local args = read_self_cmdline()
  if args then
    local script = "/tmp/dolphinui_restart.sh"
    local f = io.open(script, "w")
    if f then
      f:write("#!/bin/sh\n")
      f:write("sleep 0.5\n")
      f:write("exec")
      for _, a in ipairs(args) do f:write(" " .. shq(a)) end
      f:write("\n")
      f:close()
      os.execute("chmod +x " .. shq(script))
      os.execute("setsid sh " .. shq(script) ..
                 " </dev/null >/dev/null 2>&1 &")
      love.event.quit()
      return
    end
  end
  love.event.quit("restart")
end

-- ══════════════════════════════════════════════════════════════
--  Keyboard input
-- ══════════════════════════════════════════════════════════════
function love.keypressed(key)
  if key == "volumeup" or key == "volumedown" then return end

  if _force_quit.active then
    if key == "a" then _force_quit.holding = true
    elseif key == "escape" or key == "b" then close_force_quit() end
    return
  end

  if QuickGuide.is_open() then
    if key == "f1" or key == "escape" or key == "l2" then
      QuickGuide.close()
    else
      QuickGuide.key(key)
    end
    return
  end

  if DLOverlay.is_open() then
    if key == "f9" then DLOverlay.close()
    else DLOverlay.key(key) end
    return
  end

  if not State.capture_mode and key == "f1" then
    QuickGuide.open()
    return
  end

  if key == "f10" then
    if State.screen == "input_debug" then State.back()
    else State.go("input_debug") end
    return
  end

  if key == "f9" then DLOverlay.open(); return end
  if Modal.is_open() then Modal.key(key); return end
  if T.busy() then return end
  if State.capture_mode then safe_key(current_screen(), key); return end

  -- Gli screen che possiedono raw_input devono bypassare il debounce
  -- globale e la traduzione tasti. Altrimenti la Minoru Room perde
  -- caratteri quando si digita veloce.
  if State.raw_input then
    safe_key(current_screen(), key)
    return
  end

  if not input_ok() then return end

  local translated = KB.translate(key)

  if not State.raw_input then
    if translated == "escape" then
      local prev = State.history[#State.history - 1]
      local is_top = (prev == nil) or ENTRY_SCREENS[prev] or false
      if not is_top and #State.history > 1 then
        SFX.play("menu_back"); State.back()
      else
        love.event.quit()
      end
      return
    end
    if translated == "tab" and THEME_FLIP_SCREENS[State.screen] then
      trigger_flip()
      return
    end
  end

  safe_key(current_screen(), translated)
end

function love.keyreleased(key)
  if _force_quit.active and key == "a" then
    _force_quit.holding = false
    _force_quit.t = 0
  end
end

-- ══════════════════════════════════════════════════════════════
--  Gamepad RAW
-- ══════════════════════════════════════════════════════════════
function love.joystickpressed(joystick, button)
  if SYSTEM_RAW_BUTTONS[button] then return end
  HeldButtons[button] = true

  if _force_quit.active then
    local logical = IM.raw_to_logical[button]
    if logical == "A" then _force_quit.holding = true
    elseif logical == "B" then close_force_quit() end
    return
  end

  if QuickGuide.is_open() then
    QuickGuide.close()
    return
  end

  if maybe_fire_force_quit(button) then return end

  if DLOverlay.is_open() then
    local logical = IM.raw_to_logical[button]
    if not logical then return end
    if logical == "R2" then DLOverlay.close(); return end
    local d = dpad_dir_from_logical(logical)
    if d then DLOverlay.hat(d)
    else
      local semantic = IM[logical]
      if semantic then DLOverlay.pad(semantic) end
    end
    return
  end

  if Modal.is_open() then
    local lg = IM.raw_to_logical[button]
    Modal.pad(lg and IM[lg] or button)
    return
  end

  local s = current_screen()
  if s and type(s) == "table" and s.joystickpressed then
    s.joystickpressed(joystick, button); return
  end
  if T.busy() then return end
  if State.capture_mode then safe_pad(s, button); return end
  if not input_ok() then return end

  _last_raw_event_t = love.timer.getTime()
  local logical = IM.raw_to_logical[button]
  if not logical then return end

  local d = dpad_dir_from_logical(logical)
  if d then
    DPadHeld[d] = true
    DPadNext[d] = DPAD_FIRST_DELAY
    safe_hat(s, d)
    return
  end
  dispatch_logical(logical)
end

function love.joystickreleased(_, button)
  HeldButtons[button] = nil
  if _force_quit.active then
    local logical = IM.raw_to_logical[button]
    if logical == "A" then
      _force_quit.holding = false
      _force_quit.t = 0
    end
  end
  local logical = IM.raw_to_logical[button]
  if not logical then return end
  local d = dpad_dir_from_logical(logical)
  if d then DPadHeld[d] = nil end
end

-- ══════════════════════════════════════════════════════════════
--  Gamepad SEMANTIC
-- ══════════════════════════════════════════════════════════════
function love.gamepadpressed(joystick, name)
  if SYSTEM_SEMANTIC[name] then return end

  if _force_quit.active then
    if name == "a" then _force_quit.holding = true
    elseif name == "b" then close_force_quit() end
    return
  end

  if QuickGuide.is_open() then
    QuickGuide.close()
    return
  end

  if DLOverlay.is_open() then
    local logical = IM.semantic_to_logical[name]
    if not logical then return end
    if logical == "R2" then DLOverlay.close(); return end
    local d = dpad_dir_from_logical(logical)
    if d then DLOverlay.hat(d)
    else
      local semantic = IM[logical]
      if semantic then DLOverlay.pad(semantic) end
    end
    return
  end

  if Modal.is_open() then Modal.pad(name); return end

  local s = current_screen()
  if s and type(s) == "table" and s.gamepadpressed then
    s.gamepadpressed(joystick, name); return
  end
  if love.timer.getTime() - _last_raw_event_t < RAW_PRIORITY_WINDOW then return end
  if T.busy() then return end
  if State.capture_mode then safe_pad(s, name); return end
  if not input_ok() then return end

  local logical = IM.semantic_to_logical[name]
  if not logical then return end

  local d = dpad_dir_from_logical(logical)
  if d then
    DPadHeld[d] = true
    DPadNext[d] = DPAD_FIRST_DELAY
    safe_hat(s, d)
    return
  end
  dispatch_logical(logical)
end

function love.gamepadreleased(_, name)
  if _force_quit.active and name == "a" then
    _force_quit.holding = false
    _force_quit.t = 0
  end
  local logical = IM.semantic_to_logical[name]
  if not logical then return end
  local d = dpad_dir_from_logical(logical)
  if d then DPadHeld[d] = nil end
end

function love.joystickhat(joystick, hat, dir)
  if _force_quit.active then return end
  if QuickGuide.is_open() then
    if dir ~= "c" then QuickGuide.close() end
    return
  end
  if DLOverlay.is_open() then
    if dir ~= "c" then DLOverlay.hat(dir) end
    return
  end
  if Modal.is_open() then return end

  local s = current_screen()
  if s and type(s) == "table" and s.joystickhat then
    s.joystickhat(joystick, hat, dir); return
  end
  if T.busy() then return end
  if dir == "c" then return end
  if next(DPadHeld) then return end
  if not input_ok() then return end
  safe_hat(s, dir)
end

-- ══════════════════════════════════════════════════════════════
--  Analog axes
-- ══════════════════════════════════════════════════════════════
local AXIS_ON   = 0.65
local AXIS_OFF  = 0.35
local _axis_dir = { x = 0, y = 0 }
local _trig     = { l2 = false, r2 = false }

local AXIS_MAP = {
  x = { [-1] = "left", [1] = "right" },
  y = { [-1] = "up",   [1] = "down"  },
}

local function axis_to_dpad(key, value)
  local prev = _axis_dir[key]
  local now  = prev
  if     value >= AXIS_ON   then now = 1
  elseif value <= -AXIS_ON  then now = -1
  elseif math.abs(value) < AXIS_OFF then now = 0 end
  if now == prev then return end
  _axis_dir[key] = now

  if prev ~= 0 then DPadHeld[AXIS_MAP[key][prev]] = nil end
  if now == 0 then return end
  if Modal.is_open() or T.busy() or State.capture_mode then return end
  if _force_quit.active then return end

  if DLOverlay.is_open() then DLOverlay.hat(AXIS_MAP[key][now]); return end
  if not input_ok() then return end
  local d = AXIS_MAP[key][now]
  DPadHeld[d] = true
  DPadNext[d] = DPAD_FIRST_DELAY
  safe_hat(current_screen(), d)
end

function love.joystickaxis(joystick, axis, value)
  if _force_quit.active then return end
  if QuickGuide.is_open() then return end
  if DLOverlay.is_open() then
    if axis == 1 then axis_to_dpad("x", value)
    elseif axis == 2 then axis_to_dpad("y", value) end
    return
  end
  local s = current_screen()
  if s and type(s) == "table" and s.joystickaxis then
    s.joystickaxis(joystick, axis, value); return
  end
  if axis == 1 then axis_to_dpad("x", value)
  elseif axis == 2 then axis_to_dpad("y", value) end
end

function love.gamepadaxis(joystick, axis, value)
  local key
  if     axis == "triggerleft"  then key = "l2"
  elseif axis == "triggerright" then key = "r2"
  else return end

  local down = value > 0.5
  if down == _trig[key] then return end
  _trig[key] = down
  if not down then return end
  if _force_quit.active then return end
  if QuickGuide.is_open() then QuickGuide.close(); return end

  if key == "r2" then
    if not Modal.is_open() and not T.busy()
       and not State.capture_mode and not State.raw_input then
      DLOverlay.toggle()
    end
    return
  end

  if Modal.is_open() or T.busy() or State.capture_mode then return end
  if not input_ok() then return end
  dispatch_logical((key == "l2") and "L2" or "R2")
end

-- ══════════════════════════════════════════════════════════════
--  Shutdown
-- ══════════════════════════════════════════════════════════════
function love.quit()
  if not _quit_confirmed
     and Store.get("general", "confirm_exit") ~= false
     and not ENTRY_SCREENS[State.screen] then
    Modal.show("Exit DolphinUI?", "Saved reports and settings are kept.", {
      accept_label = "Exit",
      cancel_label = "Stay",
      on_accept = function()
        _quit_confirmed = true
        love.event.quit()
      end,
    })
    return true
  end

  pcall(function() require("covers").flush() end)
  pcall(Store.save)
  pcall(function() AsyncScanner.cancel() end)
  pcall(function() SFX.stop_all() end)
  pcall(function()
    local History = require("minoru.history")
    if History and History.flush then History.flush() end
  end)
  pcall(function()
    local Persona = require("minoru.persona")
    if Persona and Persona.flush then Persona.flush() end
  end)
  pcall(function()
    local Workspace = require("minoru.workspace")
    if Workspace and Workspace.flush then Workspace.flush() end
  end)
  log("shutdown")
  return false
end