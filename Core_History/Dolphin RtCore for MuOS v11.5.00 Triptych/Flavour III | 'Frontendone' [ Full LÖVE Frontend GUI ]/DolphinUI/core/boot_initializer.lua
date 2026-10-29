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
  results  = { roms = 0, gamesets = 0, cards = 0 },
  _fast_done = false,
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

function M.start()
  STATE.step     = "update_check"
  STATE.t        = 0
  STATE.started  = os.time()
  STATE._fast_done = false
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
      STATE.step = "download_data"; STATE.t = 0
      spawn_dl("games_data",        URLS.games_data,        "data/games_data.json")
      spawn_dl("gamesettings_json", URLS.gamesettings_json, "data/gamesettings.json")
      spawn_dl("rtcheats_db",       URLS.rtcheats_db,       "data/rtcheats_db.json")
      return
    end
    local ok, AU = pcall(require, "core.app_updater")
    if ok then AU.check_async() end
    STATE.step = "wait_update"; STATE.t = 0

  elseif step == "wait_update" then
    local ok, AU = pcall(require, "core.app_updater")
    if not ok or AU.poll() or STATE.t > 3 then
      STATE.step = "download_data"; STATE.t = 0
      spawn_dl("games_data",        URLS.games_data,        "data/games_data.json")
      spawn_dl("gamesettings_json", URLS.gamesettings_json, "data/gamesettings.json")
      spawn_dl("rtcheats_db",       URLS.rtcheats_db,       "data/rtcheats_db.json")
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
      if n_ok == 3 then
        Hub.push("success", "Data Center", "3/3 updated", { ttl = 4 })
      else
        Hub.push("warning", "Data Center", n_ok .. "/3 updated (some failed)", { ttl = 4 })
      end
      local ok_dep, DEP = pcall(require, "core.gamesettings_deployer")
      if ok_dep and DEP then pcall(DEP.start) end
      STATE.step = "scan_roms"; STATE.t = 0
    end

  elseif step == "scan_roms" then
    local ok, Library = pcall(require, "core.library")
    local n = 0
    if ok and Library then
      pcall(function() Library.scan() end)
      n = #(Library.games or {})
    end
    STATE.results.roms = n
    Hub.push("scan", "ROM scan complete",
      string.format("%d ROM(s) indexed", n), { silent = true, ttl = 4 })
    STATE.ids = {}
    if ok and Library then
      for _, g in ipairs(Library.games or {}) do
        if g.id and g.id ~= "" then STATE.ids[#STATE.ids+1] = g.id end
      end
    end
    STATE.step = "wait_gamesets"; STATE.t = 0

  elseif step == "wait_gamesets" then
    local ok_dep, DEP = pcall(require, "core.gamesettings_deployer")
    local done, res = true, {}
    if ok_dep and DEP then done, res = DEP.poll() end
    if done or STATE.t > 20 then
      if res and res.deployed and res.deployed > 0 then
        STATE.results.gamesets = res.deployed
        Hub.push("success", "GameSettings deployed",
          string.format("%d preset(s) from the Rt database", res.deployed),
          { silent = true, ttl = 5 })
      end
      STATE.step = "download_cheats"; STATE.t = 0
    end

  elseif step == "download_cheats" then
    local ok, CD = pcall(require, "core.cheats_downloader")
    if ok then CD.start_for(STATE.ids) end
    STATE.step = "wait_cheats"; STATE.t = 0

  elseif step == "wait_cheats" then
    local ok, CD = pcall(require, "core.cheats_downloader")
    local done = true
    if ok then
      local d, _ = CD.poll()
      done = d
    end
    if done or STATE.t > 20 then
      STATE.step = "build_rtid"; STATE.t = 0
    end

  elseif step == "build_rtid" then
    local ok, RB = pcall(require, "core.rtid_builder")
    if ok then
      local res = RB.rebuild_all()
      STATE.results.cards = res.built or 0
      Hub.push("success", "GamesLibrary updated",
        string.format("%d cards · %d updated · %d orphans",
          res.built or 0, res.updated or 0, res.orphans or 0),
        { silent = true, ttl = 5 })
    else
      Hub.push("warning", "GamesLibrary", "Rebuild skipped", { silent = true, ttl = 4 })
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

function M.is_done() return STATE.step == "done" end
function M.step()    return STATE.step end

M._spawn_dl = spawn_dl      -- esposto per i test

return M
