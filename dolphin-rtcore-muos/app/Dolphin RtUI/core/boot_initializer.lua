-- core/boot_initializer.lua — orchestrated boot sequence, riscritto pulito.
--
-- Fasi:
--   update_check → wait_update → scan_roms → download_data
--   → download_cheats → wait_cheats → build_rtid → done
--
-- Only game metadata and the cheat database are downloaded. No GameSettings
-- presets/catalogue are bundled, downloaded, or deployed at boot.

local Hub   = require("core.notification_hub")
local Shell = require("core.shell")
local Trace = require("core.debug_trace")
local _trace_step = nil

local M = {}

local URLS = {
  games_data = os.getenv("DOLPHINUI_URL_GAMESDATA")
               or "https://github.com/SilverCrow2323/dolphin-rt-core/raw/refs/heads/main/data/games_data.json",
  rtcheats_db = os.getenv("DOLPHINUI_URL_RTCHEATS")
               or "https://github.com/SilverCrow2323/dolphin-rt-core/raw/refs/heads/main/data/rtcheats_db.json",
}

local STATE = {
  step     = "idle",
  t        = 0,
  started  = 0,
  ids      = {},
  results  = { roms = 0, cards = 0 },
  _fast_done = false,
  skip_data_download = false,
  rom_setup_needed = false,
  scan_started = false,
}

local function marker(name) return "/tmp/rt_boot_" .. name .. ".done" end
local function script(name) return "/tmp/rt_boot_" .. name .. ".sh" end

local function spawn_dl(key, url, dest)
  local done = marker(key)
  os.remove(done)
  -- Valida prima di sostituire: un download troncato o una pagina d'errore HTML
  -- (non vuota!) sovrascriveva il JSON buono e l'app restava senza dati.
  -- Ora: deve iniziare con "{" e finire con "}"; il vecchio file va in .bak
  -- (core/compatibility.lua lo usa come fallback se l'attuale e' corrotto).
  local body = string.format([[
{ curl -fsSL --connect-timeout 3 --max-time 12 -o %s.tmp %s 2>/dev/null || \
  wget -q -T 8 --tries=1 -O %s.tmp %s 2>/dev/null; }
T=%s.tmp
if [ -s "$T" ] && [ "$(head -c 1 "$T")" = "{" ] \
   && [ "$(tail -c 8 "$T" | tr -d ' \n\r\t' | tail -c 1)" = "}" ]; then
  [ -s %s ] && cp -f %s %s.bak
  mv -f "$T" %s && touch %s
else
  rm -f "$T"
fi
]], Shell.shq(dest), Shell.shq(url),
    Shell.shq(dest), Shell.shq(url),
    Shell.shq(dest),
    Shell.shq(dest), Shell.shq(dest), Shell.shq(dest),
    Shell.shq(dest), Shell.shq(done))
  local f = io.open(script(key), "w")
  if not f then return false end
  f:write("#!/bin/sh\n" .. body); f:close()
  os.execute("chmod +x " .. Shell.shq(script(key)))
  os.execute("setsid sh " .. Shell.shq(script(key)) ..
             " </dev/null >/dev/null 2>&1 &")
  return true
end

local function is_done(key)
  local f = io.open(marker(key), "r")
  if f then f:close(); return true end
  return false
end

function M.start()
  Trace.write("BOOT", "start")
  _trace_step = nil
  STATE.step     = "update_check"
  STATE.t        = 0
  STATE.started  = os.time()
  STATE._fast_done = false
  STATE.skip_data_download = false
  STATE.rom_setup_needed = false
  STATE.scan_started = false
  Hub.push("info", "Boot sequence", "Starting up…", { silent = true, ttl = 2 })
end

function M.update(dt)
  if STATE.step == "idle" or STATE.step == "done" then return end

  -- fast boot
  local _fb = (os.getenv("DOLPHINUI_FAST_BOOT") == "1")
  if not _fb then
    pcall(function()
      local S = require("core.settings")
      if S.get("fast_boot") == true then _fb = true end
    end)
  end
  if _fb and not STATE._fast_done
     and STATE.step ~= "scan_roms"
     and STATE.step ~= "build_rtid" then
    STATE._fast_done = true
    STATE.skip_data_download = true
    STATE.step = "scan_roms"; STATE.t = 0
    return
  end

  STATE.t = STATE.t + dt

  local step = STATE.step
  if step ~= _trace_step then Trace.write("BOOT_STEP", tostring(_trace_step), "->", tostring(step)); _trace_step = step end

  if step == "update_check" then
    local skip_update = false
    pcall(function()
      local S = require("core.settings")
      if S.get("auto_update_check") == false then skip_update = true end
    end)
    if skip_update then
      STATE.step = "scan_roms"; STATE.t = 0
      return
    end
    local ok, AU = (function() local ok,m = pcall(require, "core.app_updater"); if not ok then require("ui.notify").show("warning", "Funzione non disponibile: core.app_updater") end; return ok and m end)()
    if ok then AU.check_async() end
    STATE.step = "wait_update"; STATE.t = 0

  elseif step == "wait_update" then
    local ok, AU = pcall(require, "core.app_updater")
    if not ok or AU.poll() or STATE.t > 3 then
      STATE.step = "scan_roms"; STATE.t = 0
    end

  elseif step == "download_data" then
    local all_done = is_done("games_data") and is_done("rtcheats_db")
    if all_done or STATE.t > 14 then
      local ok_a = is_done("games_data")
      local ok_b = is_done("rtcheats_db")
      local n_ok = (ok_a and 1 or 0) + (ok_b and 1 or 0)
      Trace.write("BOOT_DOWNLOADS", "games_data=" .. tostring(ok_a),
        "cheats=" .. tostring(ok_b), "successes=" .. tostring(n_ok))
      if n_ok == 2 then
        Hub.push("success", "Data Center", "2/2 updated", { ttl = 4 })
      else
        Hub.push("warning", "Data Center", n_ok .. "/2 updated · using cached data", { ttl = 4 })
      end
      STATE.step = "download_cheats"; STATE.t = 0
    end

  elseif step == "scan_roms" then
    local ok, Library = pcall(require, "core.library")
    local n = 0
    if ok and Library then
      if not STATE.scan_started then
        local started, err = pcall(Library.scan_begin)
        if started then
          STATE.scan_started = true
          return
        end
        print("[RtUI] incremental ROM scan could not start: " .. tostring(err))
      else
        -- Process a small slice each frame. A blocking full-library scan here
        -- froze the 2.5D intro on large SD cards and made boot look stuck.
        local scan_ok, done = pcall(Library.scan_step, 0.006)
        if scan_ok and not done then
          STATE.results.roms = #(Library.games or {})
          return
        end
        if not scan_ok then
          print("[RtUI] incremental ROM scan failed: " .. tostring(done))
        end
        STATE.scan_started = false
        n = #(Library.games or {})
      end
    end
    STATE.results.roms = n
    pcall(function()
      local Settings = require("core.settings")
      STATE.rom_setup_needed = Settings.get("rom_discovery_done") ~= true
    end)
    Trace.write("ROM_SCAN", "complete", "count=" .. tostring(n), "setup_needed=" .. tostring(STATE.rom_setup_needed))
    Hub.push("scan", "ROM scan complete",
      string.format("%d ROM(s) indexed", n), { silent = true, ttl = 4 })
    STATE.ids = {}
    if ok and Library then
      for _, g in ipairs(Library.games or {}) do
        if g.id and g.id ~= "" then STATE.ids[#STATE.ids+1] = g.id end
      end
    end
    if STATE.skip_data_download then
      STATE.step = "download_cheats"; STATE.t = 0
    else
      spawn_dl("games_data", URLS.games_data, "data/games_data.json")
      spawn_dl("rtcheats_db", URLS.rtcheats_db, "data/rtcheats_db.json")
      STATE.step = "download_data"; STATE.t = 0
    end

  elseif step == "download_cheats" then
    local ok, CD = pcall(require, "core.cheats_downloader")
    if not ok then
      Trace.write("BOOT_CHEATS", "downloader unavailable", tostring(CD))
    elseif type(CD) == "table" and type(CD.start_for) == "function" then
      local started, err = pcall(CD.start_for, STATE.ids)
      if not started then Trace.write("BOOT_CHEATS", "start failed", tostring(err)) end
    end
    STATE.step = "wait_cheats"; STATE.t = 0

  elseif step == "wait_cheats" then
    local ok, CD = pcall(require, "core.cheats_downloader")
    local done = true
    if ok and type(CD) == "table" and type(CD.poll) == "function" then
      local polled, d = pcall(CD.poll)
      done = not polled or d
    end
    if done or STATE.t > 8 then
      STATE.step = "build_rtid"; STATE.t = 0
    end

  elseif step == "build_rtid" then
    local ok, RB = pcall(require, "core.rtid_builder")
    if ok and RB and type(RB.rebuild_all) == "function" then
      local rebuilt, res = pcall(RB.rebuild_all)
      if rebuilt and type(res) == "table" then
        STATE.results.cards = res.built or 0
        Hub.push("success", "GamesLibrary updated",
          string.format("%d cards · %d updated · %d orphans",
            res.built or 0, res.updated or 0, res.orphans or 0),
          { silent = true, ttl = 5 })
      else
        Trace.write("BOOT_RTID_REBUILD", "failed", tostring(res))
        Hub.push("warning", "GamesLibrary", "Card refresh skipped; existing cards kept", { silent = true, ttl = 4 })
      end
    else
      Trace.write("BOOT_RTID", "builder unavailable", tostring(RB))
      Hub.push("warning", "GamesLibrary", "Card refresh skipped; existing cards kept", { silent = true, ttl = 4 })
    end
    Hub.push("success", "Boot complete",
      string.format("%d games · %d cards",
        STATE.results.roms or 0,
        STATE.results.cards or 0),
      { ttl = 4 })
    STATE.step = "done"

  else
    STATE.step = "done"
  end
end

function M.is_done() return STATE.step == "done" end
function M.step()    return STATE.step end
function M.needs_rom_setup() return STATE.rom_setup_needed == true end

M._spawn_dl = spawn_dl      -- esposto per i test

return M
