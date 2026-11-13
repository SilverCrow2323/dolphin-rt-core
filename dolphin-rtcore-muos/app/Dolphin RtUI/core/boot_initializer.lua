-- core/boot_initializer.lua — orchestrated boot sequence, riscritto pulito.
--
-- Fasi:
--   update_check    → wait_update    → download_data
--   → scan_roms     → wait_gamesets  → download_cheats
--   → wait_cheats   → build_rtid     → done
--
-- Nel download_data scarichiamo 3 file JSON da GitHub (games_data,
-- gamesettings, rtcheats_db) e mostriamo una notifica aggregata: 3/3 updated
-- oppure N/3 updated (some failed).

local Hub   = require("core.notification_hub")
local Shell = require("core.shell")

local M = {}

local function require_optional(module_name)
  local ok, module = pcall(require, module_name)
  if not ok then
    pcall(function()
      require("ui.notify").show("warning",
        "Funzione non disponibile: " .. tostring(module_name))
    end)
  end
  return ok, module
end

local URLS = {
  games_data = os.getenv("DOLPHINUI_URL_GAMESDATA")
               or "https://github.com/SilverCrow2323/dolphin-rt-core/raw/refs/heads/main/data/games_data.json",
  gamesettings_json = os.getenv("DOLPHINUI_URL_GAMESETTINGS")
               or "https://github.com/SilverCrow2323/dolphin-rt-core/raw/refs/heads/main/data/gamesettings.json",
  rtcheats_db = os.getenv("DOLPHINUI_URL_RTCHEATS")
               or "https://github.com/SilverCrow2323/dolphin-rt-core/raw/refs/heads/main/data/rtcheats_db.json",
}

local STATE = {
  step     = "idle",
  t        = 0,
  started  = 0,
  ids      = {},
  results  = {
    roms = 0, gamesets = 0, cards = 0, downloads = {},
    update_status = "waiting", gamesets_status = "waiting",
    cheats_status = "waiting", cards_status = "waiting",
  },
  _fast_done = false,
  scan_library = nil,
  scan_driver = false,
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
{ curl -fsSL --connect-timeout 8 --max-time 90 -o %s.tmp %s 2>/dev/null || \
  wget -q -T 20 --tries=2 -O %s.tmp %s 2>/dev/null; }
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

local function start_data_downloads()
  spawn_dl("games_data",        URLS.games_data,        "data/games_data.json")
  spawn_dl("gamesettings_json", URLS.gamesettings_json, "data/gamesettings.json")
  spawn_dl("rtcheats_db",       URLS.rtcheats_db,       "data/rtcheats_db.json")
end

function M.start()
  STATE.step     = "update_check"
  STATE.t        = 0
  STATE.started  = os.time()
  STATE.results = {
    roms = 0, gamesets = 0, cards = 0, downloads = {},
    update_status = "waiting", gamesets_status = "waiting",
    cheats_status = "waiting", cards_status = "waiting",
  }
  STATE._fast_done = false
  STATE.scan_library = nil
  STATE.scan_driver = false
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
    STATE.step = "scan_roms"; STATE.t = 0
    return
  end

  STATE.t = STATE.t + dt
  if STATE.t > 90 then
    -- If boot owns an incremental ROM scan, close it cleanly and keep the
    -- partial index rather than leaving Library.scanning stuck forever.
    if STATE.scan_driver and STATE.scan_library
       and STATE.scan_library.scanning then
      pcall(STATE.scan_library.scan_finish)
      STATE.results.roms = #(STATE.scan_library.games or {})
    end
    STATE.scan_library = nil
    STATE.scan_driver = false
    Hub.push("warning", "Boot sequence", "Timed out")
    STATE.step = "done"
    return
  end

  local step = STATE.step

  if step == "update_check" then
    local skip_update = false
    pcall(function()
      local S = require("core.settings")
      if S.get("auto_update_check") == false then skip_update = true end
    end)
    if skip_update then
      STATE.results.update_status = "skipped"
      STATE.step = "download_data"; STATE.t = 0
      start_data_downloads()
      return
    end
    local ok, AU = require_optional("core.app_updater")
    if ok and AU and AU.available ~= false and AU.check_async then
      local called = pcall(AU.check_async)
      if called then
        STATE.results.update_status = "checking"
        STATE.step = "wait_update"; STATE.t = 0
        return
      end
    end
    -- The bundled app_updater is deliberately disabled in this release.
    STATE.results.update_status = "disabled"
    STATE.step = "download_data"; STATE.t = 0
    start_data_downloads()

  elseif step == "wait_update" then
    local ok, AU = pcall(require, "core.app_updater")
    local complete = (not ok) or (not AU) or AU.available == false or type(AU.poll) ~= "function"
    if not complete then
      local poll_ok, result = pcall(AU.poll)
      complete = (not poll_ok) or result == true
      if not poll_ok then STATE.results.update_status = "failed"
      elseif result == true then STATE.results.update_status = "up_to_date" end
    end
    if complete or STATE.t > 3 then
      if STATE.results.update_status == "checking" then STATE.results.update_status = "timeout" end
      STATE.step = "download_data"; STATE.t = 0
      start_data_downloads()
    end

  elseif step == "download_data" then
    local all_done = is_done("games_data")
                 and is_done("rtcheats_db")
                 and is_done("gamesettings_json")
    if all_done or STATE.t > 40 then
      local ok_a = is_done("games_data")
      local ok_b = is_done("rtcheats_db")
      local ok_c = is_done("gamesettings_json")
      local n_ok = (ok_a and 1 or 0) + (ok_b and 1 or 0) + (ok_c and 1 or 0)
      STATE.results.downloads = {
        games_data = ok_a, rtcheats_db = ok_b, gamesettings_json = ok_c,
      }
      if n_ok == 3 then
        Hub.push("success", "Data Center", "3/3 updated", { ttl = 4 })
      else
        Hub.push("warning", "Data Center", n_ok .. "/3 updated (some failed)", { ttl = 4 })
      end
      local ok_dep, DEP = require_optional("core.gamesettings_deployer")
      if ok_dep and DEP and DEP.start then
        local started, accepted = pcall(DEP.start)
        STATE.results.gamesets_status = (started and accepted ~= false) and "running" or "unavailable"
      else
        STATE.results.gamesets_status = "unavailable"
      end
      STATE.step = "scan_roms"; STATE.t = 0
    end

  elseif step == "scan_roms" then
    if not STATE.scan_library then
      local ok, Library = pcall(require, "core.library")
      if ok and Library then
        STATE.scan_library = Library
        if Library.scanning then
          -- Adopt any asynchronous scan rather than waiting on a UI screen
          -- that may have been left. Mark it boot-owned so the two layers
          -- never drive the same queue in one frame.
          if Library.scan_owner ~= "blocking" then
            Library.scan_owner = "boot"
            STATE.scan_driver = true
          else
            STATE.scan_driver = false
          end
        else
          local began, err = pcall(Library.scan_begin, "boot")
          if not began then
            Hub.push("warning", "ROM scan", tostring(err))
            STATE.scan_library = nil
          else
            STATE.scan_driver = true
          end
        end
      else
        Hub.push("warning", "ROM scan", "Library scanner unavailable")
      end
    end

    local Library = STATE.scan_library
    if not Library then
      STATE.results.roms = 0
      STATE.ids = {}
      STATE.step = "wait_gamesets"; STATE.t = 0
      return
    end

    -- One small slice per frame. Library.scan() is intentionally not used
    -- here: it drains the complete queue synchronously and freezes the intro.
    if STATE.scan_driver and Library.scanning then
      local ok, finished = pcall(Library.scan_step, 0.008)
      if not ok then
        Hub.push("warning", "ROM scan", tostring(finished))
        pcall(Library.scan_finish)
      end
    end

    if not Library.scanning then
      STATE.results.roms = #(Library.games or {})
      STATE.ids = {}
      for _, g in ipairs(Library.games or {}) do
        if g.id and g.id ~= "" then STATE.ids[#STATE.ids+1] = g.id end
      end
      STATE.scan_library = nil
      STATE.scan_driver = false
      STATE.step = "wait_gamesets"; STATE.t = 0
    end

  elseif step == "wait_gamesets" then
    local ok_dep, DEP = pcall(require, "core.gamesettings_deployer")
    local done, res = true, {}
    if ok_dep and DEP and DEP.poll then
      local poll_ok, finished, result = pcall(DEP.poll)
      if poll_ok then done, res = finished == true, result or {}
      else done, res = true, {failed = 1, error = tostring(finished)} end
    end
    if done or STATE.t > 20 then
      if STATE.t > 20 and not done then
        STATE.results.gamesets_status = "timeout"
      elseif (tonumber(res.failed) or 0) > 0 then
        STATE.results.gamesets_status = "partial"
      elseif (tonumber(res.deployed) or 0) > 0 then
        STATE.results.gamesets_status = "complete"
      else
        STATE.results.gamesets_status = "empty"
      end
      STATE.results.gamesets = tonumber(res.deployed) or 0
      if STATE.results.gamesets > 0 then
        Hub.push("success", "GameSettings deployed",
          string.format("%d preset(s) from the Rt database", STATE.results.gamesets),
          { silent = true, ttl = 5 })
      elseif STATE.results.gamesets_status == "partial" then
        Hub.push("warning", "GameSettings", "Some bundled configs could not be deployed",
          { silent = true, ttl = 5 })
      end
      STATE.step = "download_cheats"; STATE.t = 0
    end

  elseif step == "download_cheats" then
    local ok, CD = require_optional("core.cheats_downloader")
    if ok and CD and CD.start_for then
      local called, accepted = pcall(CD.start_for, STATE.ids)
      STATE.results.cheats_status = (called and accepted ~= false) and "running" or "failed"
    else
      STATE.results.cheats_status = "unavailable"
    end
    STATE.step = "wait_cheats"; STATE.t = 0

  elseif step == "wait_cheats" then
    local ok, CD = pcall(require, "core.cheats_downloader")
    local done, result = true, nil
    if ok and CD and CD.poll then
      local poll_ok, finished, status = pcall(CD.poll)
      if poll_ok then done, result = finished == true, status
      else done, result = true, {state = "fail", msg = tostring(finished)} end
    end
    if done or STATE.t > 75 then
      if STATE.t > 75 and not done then
        STATE.results.cheats_status = "timeout"
      elseif result and result.state == "fail" then
        STATE.results.cheats_status = "failed"
        Hub.push("warning", "Cheat database", tostring(result.msg or "Sync failed"),
          { silent = true, ttl = 5 })
      elseif result and tostring(result.msg or ""):find("failed", 1, true) then
        STATE.results.cheats_status = "partial"
      elseif result and tostring(result.msg or ""):find("no games", 1, true) then
        STATE.results.cheats_status = "skipped"
      else
        STATE.results.cheats_status = "complete"
      end
      STATE.step = "build_rtid"; STATE.t = 0
    end

  elseif step == "build_rtid" then
    local ok, RB = require_optional("core.rtid_builder")
    if ok and RB and RB.available ~= false and RB.rebuild_all then
      local called, res = pcall(RB.rebuild_all)
      if called and type(res) == "table" then
        STATE.results.cards = tonumber(res.built) or 0
        STATE.results.cards_status = "complete"
        Hub.push("success", "GamesLibrary updated",
          string.format("%d cards · %d updated · %d orphans",
            res.built or 0, res.updated or 0, res.orphans or 0),
          { silent = true, ttl = 5 })
      else
        STATE.results.cards_status = "failed"
        Hub.push("warning", "GamesLibrary", "Card rebuild failed",
          { silent = true, ttl = 4 })
      end
    else
      -- RTID cards are generated on demand when the user opens a game.
      STATE.results.cards_status = "on_demand"
    end
    Hub.push("success", "Boot complete",
      string.format("%d games · %d presets · %d cards",
        STATE.results.roms or 0,
        STATE.results.gamesets or 0,
        STATE.results.cards or 0),
      { ttl = 4 })
    STATE.step = "done"

  else
    STATE.step = "done"
  end
end

local DATABASES = {
  games_data = "data/games_data.json",
  gamesettings_json = "data/gamesettings.json",
  rtcheats_db = "data/rtcheats_db.json",
}

local function local_file_info(path)
  local f = io.open(path, "rb")
  if not f then return false, 0 end
  local size = f:seek("end") or 0
  f:close()
  return true, size
end

local function database_snapshot(key, path)
  local present, size = local_file_info(path)
  local result = STATE.results.downloads or {}
  local state
  if result[key] == true or (STATE.step == "download_data" and is_done(key)) then
    state = "updated"
  elseif result[key] == false then
    state = present and "retained" or "failed"
  elseif STATE.step == "download_data" then
    state = "downloading"
  elseif present then
    state = "cached"
  elseif STATE.step == "idle" then
    state = "not_checked"
  else
    state = "missing"
  end
  return {state = state, present = present, size = size}
end

function M.snapshot()
  local databases = {}
  for key, path in pairs(DATABASES) do
    databases[key] = database_snapshot(key, path)
  end
  return {
    step = STATE.step,
    done = STATE.step == "done",
    databases = databases,
    update = {status = STATE.results.update_status or "waiting"},
    gamesets = {
      status = STATE.results.gamesets_status or "waiting",
      deployed = STATE.results.gamesets or 0,
    },
    cheats = {status = STATE.results.cheats_status or "waiting"},
    roms = STATE.results.roms or 0,
    cards = STATE.results.cards or 0,
    cards_status = STATE.results.cards_status or "waiting",
  }
end

function M.is_done() return STATE.step == "done" end
function M.step()    return STATE.step end

M._spawn_dl = spawn_dl      -- esposto per i test

return M
