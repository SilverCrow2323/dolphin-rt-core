-- DOLPHIN STREAM 2.0 -- libreria GameCube / Wii per muOS (i giochi girano sul PC, stream via Moonlight)
-- Moduli: ui.lua (grafica/icone), cfg.lua (impostazioni/statistiche). Controlli: guarda il footer.
local ui  = require("ui")
local cfg = require("cfg")
local boot = require("boot")
local controls = require("controls")
local lg  = love.graphics

-- valida il nome app PRIMA di scrivere launch.txt: niente shell metacharacters
local function validApp(a)
  if type(a) ~= "string" or a == "" or #a > 64 then return false end
  -- niente metachar shell (sempre pericolosi)
  if a:match("[`$;&|<>(){}*?!\"#~\\]") then return false end
  -- niente newline/tab
  if a:match("[\n\r\t]") then return false end
  -- niente spazi iniziali/finali o multipli
  if a:match("^%s") or a:match("%s$") or a:match("%s%s") then return false end
  -- deve iniziare con lettera o numero (no "." o "-" leading)
  if not a:match("^[%w]") then return false end
  return true
end


local W, H = ui.W, ui.H
local base = love.filesystem.getSourceBaseDirectory()
local VERSION = "3.0"

-- layout verticale (schermo piccolo: tutto e' grande)
local GY0, CONTENT_BOT = 70, 350
local VIEWS = {
  { name = "Flow",    cols = 1, rows = 1, rowh = 1, flow = true },
  { name = "Grid", cols = 4, rows = 2, cw = 88, ch = 124, cellw = 150, rowh = 140, x0 = 20 },
  { name = "List",   cols = 1, rows = 5, rowh = 54, list = true },
}
local TAB_NAMES = { "GAMECUBE", "WII", "FAVORITES", "RECENT" }
local LAUNCH_T = 0.9

-- ===================================================================== stato
local fonts
local lib, all, lists = { gc = {}, wii = {} }, {}, {}
local dirty = true
local tab = 1
local sel, topRow, scrollY = { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
local search = { "", "", "", "" }
local health = { sunshine = "unknown", library = "unknown", timer = 5, polling = false, pollTimer = 0 }
local searchActive = { false, false, false, false }
local openSearch, clearSearch
local loaded, loadBudget = {}, 0
local t, tabFade = 0, 1
local sync = { on = false, msg = "", timer = 0, state = nil, show = 0 }
local toastT = { msg = nil, kind = "info", t = 0 }
local menus = {}
local kb, dlg, view = nil, nil, nil
local held = {}
local VIS = 6                         -- righe visibili nei menu
-- stato animazioni
local bootT = 0
local launching = nil
local flowPos, selPop, infoT = 1, 0, 1
local tabW = { 170, 60, 60, 60 }
local modalT, dlgT, dtG, lastKey = 1, 1, 0.016, "lib"

local function V() return VIEWS[cfg.ui.view] or VIEWS[1] end

local function q(s) return "'" .. (s:gsub("'", "'\\''")) .. "'" end
local function runTool(name)
  os.execute("sh " .. q(base .. "/tools/" .. name) .. " >/dev/null 2>&1 &")
end

-- HTTP check async: scrive "OK" o "FAIL" nel file .done
local function httpCheck(url, doneFile)
  local cmd = string.format(
    "sh -c 'if command -v curl >/dev/null 2>&1; then curl -fsS -m 3 -o /dev/null %s; R=$?; " ..
    "elif command -v wget >/dev/null 2>&1; then wget -q -T 3 -O /dev/null %s; R=$?; else R=1; fi; " ..
    "if [ $R -eq 0 ]; then echo OK > %s; else echo FAIL > %s; fi' &",
    q(url), q(url), doneFile, doneFile)
  os.execute(cmd)
end

local function toast(msg, kind) toastT.msg, toastT.kind, toastT.t = msg, kind or "info", 3.2 end

-- Soglia: se os.time() e' < 2025-01-01 (RTC scarico su handheld), considera
-- il timestamp "inaffidabile" e mostra "unknown" invece di "2047 anni fa".
local RTC_MIN_VALID = 1735689600  -- 2025-01-01 00:00 UTC

local function ago(ts)
  if not ts or ts == 0 then return "never played" end
  local now = os.time()
  if now < RTC_MIN_VALID or ts < RTC_MIN_VALID then return "unknown (RTC)" end
  local d = now - ts
  if d < 0 then d = 0 end
  if d < 120 then return "just now" end
  if d < 3600 then return math.floor(d / 60) .. " min ago" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  if d < 172800 then return "yesterday" end
  return math.floor(d / 86400) .. " d ago"
end

-- ===================================================================== libreria
local function loadLibrary()
  lib, all, loaded = { gc = {}, wii = {} }, {}, {}
  local s = cfg.readFile(base .. "/conf/library.tsv")
  if s then
    for line in s:gmatch("[^\n]+") do
      line = (line:gsub("\r", ""))
      if line ~= "" and line:sub(1, 1) ~= "#" then
        local f = cfg.split(line)
        local p, title, app = f[1], f[2], f[3]
        if lib[p] and title and title ~= "" and app and app ~= "" then
          local g = { kind = p, title = title, app = app, cover = f[4] or "", id = f[5] or "" }
          table.insert(lib[p], g); table.insert(all, g)
        end
      end
    end
  end
  dirty = true
end

local function cmpTitle(a, b) return a.title:lower() < b.title:lower() end
local function sortGames(list, mode)
  if mode == 2 then
    table.sort(list, function(a, b) return cmpTitle(b, a) end)
  elseif mode == 3 then
    table.sort(list, function(a, b)
      local x, y = cfg.stat(a.app).last, cfg.stat(b.app).last
      if x ~= y then return x > y end
      return cmpTitle(a, b)
    end)
  elseif mode == 4 then
    table.sort(list, function(a, b)
      local x, y = cfg.stat(a.app).plays, cfg.stat(b.app).plays
      if x ~= y then return x > y end
      return cmpTitle(a, b)
    end)
  else
    table.sort(list, cmpTitle)
  end
end

local function rebuildLists()
  local keep = {}
  for i = 1, 4 do
    local l = lists[i]
    keep[i] = l and l[sel[i]] and l[sel[i]].app or nil
  end
  lists = {}
  local mode = cfg.ui.sort
  for i, kind in ipairs({ "gc", "wii" }) do
    local l = {}
    for _, g in ipairs(lib[kind]) do l[#l + 1] = g end
    sortGames(l, mode); lists[i] = l
  end
  local fav = {}
  local seen = {}
  for _, g in ipairs(all) do
    if cfg.stat(g.app).fav then
      fav[#fav + 1] = g
      seen[g.app] = true
    end
  end
  sortGames(fav, mode)
  local rec = {}
  for _, g in ipairs(all) do
    if cfg.stat(g.app).plays > 0 and not seen[g.app] then
      rec[#rec + 1] = g
    end
  end
  sortGames(rec, 3)
  while #rec > 30 do table.remove(rec) end
  for _, g in ipairs(rec) do fav[#fav + 1] = g end
  lists[3] = fav
  lists[4] = {}
  for i = 1, 4 do
    if search[i] ~= "" then
      local ql = search[i]:lower()
      local filtered = {}
      for _, g in ipairs(lists[i]) do
        if g.title:lower():find(ql, 1, true) or g.app:lower():find(ql, 1, true) then
          filtered[#filtered + 1] = g
        end
      end
      lists[i] = filtered
    end
  end
  for i = 1, 4 do
    local n = #lists[i]
    if keep[i] then
      for idx, g in ipairs(lists[i]) do
        if g.app == keep[i] then sel[i] = idx; break end
      end
    end
    if sel[i] > n then sel[i] = math.max(1, n) end
    if sel[i] < 1 then sel[i] = 1 end
  end
  dirty = false
end

local function getList(i)
  if dirty then rebuildLists() end
  return lists[i]
end
local function curGame() return getList(tab)[sel[tab]] end

local function ensureVisible()
  local v = V()
  local n = #getList(tab)
  local row = math.floor((sel[tab] - 1) / v.cols)
  local maxTop = math.max(0, math.ceil(n / v.cols) - v.rows)
  if row < topRow[tab] then topRow[tab] = row
  elseif row > topRow[tab] + v.rows - 1 then topRow[tab] = row - v.rows + 1 end
  topRow[tab] = math.max(0, math.min(maxTop, topRow[tab]))
end

local function relayout()
  local v = V()
  for i = 1, 4 do
    local n = #getList(i)
    local maxTop = math.max(0, math.ceil(n / v.cols) - v.rows)
    topRow[i] = math.max(0, math.min(maxTop, math.floor((sel[i] - 1) / v.cols) - v.rows + 1))
    scrollY[i] = topRow[i] * v.rowh
  end
end

local function move(delta)
  local n = #getList(tab)
  if n == 0 then return end
  local old = sel[tab]
  sel[tab] = math.max(1, math.min(n, sel[tab] + delta))
  if sel[tab] ~= old then selPop, infoT = 1, 0 end
  ensureVisible()
end

local function setTab(i)
  tab = ((i - 1) % 4) + 1
  tabFade = 0
  flowPos, infoT, selPop = sel[tab], 0, 1
  loadBudget = 48                       -- burst: precarica le prime cover visibili
  ensureVisible()
end

local function loadState()
  local s = cfg.readFile(base .. "/conf/state.txt")
  if not s then return end
  local n = {}
  for d in s:gmatch("%d+") do n[#n + 1] = tonumber(d) end
  if n[1] then tab = math.max(1, math.min(4, n[1])) end
  for i = 1, 4 do if n[i + 1] then sel[i] = math.max(1, n[i + 1]) end end
end

local function saveState()
  cfg.writeFile(base .. "/conf/state.txt", string.format("%d %d %d %d %d\n", tab, sel[1], sel[2], sel[3], sel[4]))
end

-- Cache cover con LRU 256 (era 64): su librerie grandi riduce i ricaricamenti.
-- Budget alzato a 4/frame (era 2) + burst di 48 al cambio tab (vedi setTab).
local COVER_CACHE_MAX = 256
local function loadCover(g)
  if g.img ~= nil then return g.img end
  if loadBudget <= 0 then return nil end
  loadBudget = loadBudget - 1
  g.img = false
  if g.cover ~= "" then
    local data = cfg.readFile(base .. "/" .. g.cover)
    if data then
      local ok, img = pcall(function()
        return lg.newImage(love.filesystem.newFileData(data, g.cover))
      end)
      if ok and img then img:setFilter("linear", "linear"); g.img = img end
    end
  end
  table.insert(loaded, g)
  while #loaded > COVER_CACHE_MAX do
    local old = table.remove(loaded, 1)
    old.img = nil
  end
  return g.img
end

-- ===================================================================== azioni
local function startSync()
  if sync.on then return end
  os.remove(base .. "/conf/sync.done"); os.remove(base .. "/conf/sync.status")
  sync.on, sync.msg, sync.timer, sync.show = true, "Starting sync...", 0.3, 0
  runTool("sync.sh")
end

local function doPlay(g)
  if not g then return end
  if not validApp(g.app) then
    toast("Invalid app name, cannot launch: " .. tostring(g.app), "err")
    return
  end
  local s = cfg.mut(g.app)
  s.plays, s.last = s.plays + 1, os.time()
  cfg.saveStats()
  local ov, env = cfg.getOver(g.app), {}
  local w, h = ov.res:match("^(%d+)x(%d+)$")
  if w then env[#env + 1] = 'WIDTH="' .. w .. '"'; env[#env + 1] = 'HEIGHT="' .. h .. '"' end
  if ov.bitrate:match("^%d+$") then env[#env + 1] = 'BITRATE="' .. ov.bitrate .. '"' end
  if ov.fps:match("^%d+$") then env[#env + 1] = 'FPS="' .. ov.fps .. '"' end
  cfg.writeFile(base .. "/launch.env", table.concat(env, "\n") .. "\n")
  cfg.writeFile(base .. "/launch.txt", g.app)
  love.event.quit()
end

-- Pre-flight: ping in background, max 1s, without blocking the UI.
-- If ping is missing, write SKIP and let it pass.
local function pingHostAsync(host)
  os.remove("/tmp/ds_ping.done")
  local cmd = string.format(
    "(command -v ping >/dev/null 2>&1 || { echo SKIP >/tmp/ds_ping.done; exit 0; }; " ..
    "ping -c 1 -W 1 %s >/dev/null 2>&1 && echo OK >/tmp/ds_ping.done || echo FAIL >/tmp/ds_ping.done) &",
    q(host))
  os.execute(cmd)
end

local function play(g)
  if not g or launching then return end
  menus, kb, view, dlg = {}, nil, nil, nil
  local host = cfg.s.HOST
  if host == "" then
    launching = { g = g, t = 0, phase = "launch", reveal = 0 }
    return
  end
  pingHostAsync(host)
  launching = { g = g, t = 0, phase = "ping", host = host, t0 = t, reveal = 0 }
end

local function toggleFav(g)
  if not g then return end
  local s = cfg.mut(g.app)
  s.fav = not s.fav
  cfg.saveStats(); dirty = true
  toast(s.fav and "Added to favorites" or "Removed from favorites", "info")
end

local function openDlg(title, text, yes) dlg = { title = title, text = text, yes = yes } end

-- viewer di testo (log, statistiche, info, test, pairing)
local function wrapInto(flat, raw)
  local f = fonts.s
  for _, l in ipairs(raw) do
    local kind = "n"
    if l:match("^OK") then kind = "ok" elseif l:match("^ERR") or l:match("^FAIL") then kind = "err"
    elseif l:match("^#") then kind = "hl"; l = l:sub(2) end
    local a, b = f:getWrap(l == "" and " " or l, 560)
    local parts = (type(a) == "table" and a) or (type(b) == "table" and b) or { l }
    for _, p in ipairs(parts) do flat[#flat + 1] = { p, kind } end
    if #parts == 0 then flat[#flat + 1] = { "", kind } end
  end
end

local function setViewLines(v, raw)
  v.flat = {}
  wrapInto(v.flat, raw)
end

local function openView(title, raw, opt)
  opt = opt or {}
  view = { title = title, icon = opt.icon or "info", top = 0, poll = opt.poll, pair = opt.pair,
    onClose = opt.onClose, timer = 0, customDraw = opt.customDraw }
  setViewLines(view, raw)
end

local function readLines(path, tail)
  local s = cfg.readFile(path)
  if not s then return nil end
  local out = {}
  for l in s:gmatch("[^\n]+") do out[#out + 1] = (l:gsub("\r", "")) end
  if tail then while #out > tail do table.remove(out, 1) end end
  return out
end

-- Helper: apre una view che fa polling su un file di log + file .done
local function openToolView(title, script, logfile, donefile, icon, intro)
  os.remove(base .. "/" .. donefile)
  os.remove(base .. "/" .. logfile)
  runTool(script)
  openView(title, intro or { "Starting..." }, { icon = icon or "wrench",
    poll = function()
      local lines = readLines(base .. "/" .. logfile) or {}
      if not cfg.readFile(base .. "/" .. donefile) then
        lines[#lines + 1] = "..."
      end
      if #lines == 0 then lines = { "Starting..." } end
      return lines
    end })
end

local function openDiagnostics()
  openToolView("Diagnostics", "diagnostics.sh", "conf/diagnostics.txt", "conf/diagnostics.done", "info",
    { "Collecting system info...", "This may take a few seconds." })
end

local function openSunshineVerify()
  openToolView("Verify Sunshine apps", "sunshine_verify.sh", "conf/sunshine_verify.txt", "conf/sunshine_verify.done", "wifi",
    { "Comparing Sunshine app list with local library...", "Requires HOST set and PC reachable." })
end

local function openDiskSpace()
  openToolView("Disk space", "diskspace.sh", "conf/diskspace.txt", "conf/diskspace.done", "chart",
    { "Checking disk usage..." })
end

local function openLatency()
  openToolView("Measure latency", "latency.sh", "conf/latency.txt", "conf/latency.done", "clock",
    { "Pinging PC (10 packets)...", "Takes up to 10 seconds." })
end

local function openTest()
  os.remove(base .. "/conf/test.done"); os.remove(base .. "/conf/test.log")
  runTool("test.sh")
  openView("Connection test", { "Testing..." }, { icon = "wifi", poll = function()
    local lines = readLines(base .. "/conf/test.log") or {}
    if not cfg.readFile(base .. "/conf/test.done") then lines[#lines + 1] = "..." end
    if #lines == 0 then lines = { "Testing..." } end
    return lines
  end })
end

local function openPair()
  os.remove(base .. "/conf/pair.log")
  runTool("pair.sh")
  local intro = {
    "#HOW TO",
    "1) Open the Sunshine web UI on the PC (https://PC-IP:47990)",
    "2) Go to the PIN tab",
    "3) Enter the PIN shown above and confirm",
    "",
  }
  openView("Pair with Sunshine", intro, { icon = "link", pair = true,
    poll = function()
      local lines = readLines(base .. "/conf/pair.log") or {}
      local all_ = table.concat(lines, " ")
      view.pin = all_:match("[Pp][Ii][Nn][^%d]*(%d%d%d%d)")
      local out = {}
      for _, l in ipairs(intro) do out[#out + 1] = l end
      for _, l in ipairs(lines) do out[#out + 1] = l end
      return out
    end,
    onClose = function()
      os.execute("kill $(cat " .. q(base .. "/conf/pair.pid") .. " 2>/dev/null) >/dev/null 2>&1")
    end })
end

local function openStreamLog()
  local lines = readLines(base .. "/conf/last_stream.log", 80)
  if not lines or #lines == 0 then lines = { "No log yet: start a stream first." } end
  openView("Last stream log", lines, { icon = "list" })
  view.top = math.max(0, #view.flat - 20)
end

local function openStats()
  local plays, favs, top = 0, 0, {}
  for _, g in ipairs(all) do
    local s = cfg.stat(g.app)
    plays = plays + s.plays
    if s.fav then favs = favs + 1 end
    if s.plays > 0 then top[#top + 1] = g end
  end
  table.sort(top, function(a, b) return cfg.stat(a.app).plays > cfg.stat(b.app).plays end)
  local lines = {
    "#LIBRARY",
    string.format("Games: %d  (GameCube %d, Wii %d)", #all, #lib.gc, #lib.wii),
    string.format("Total launches: %d      Favorites: %d", plays, favs),
    "", "#MOST PLAYED",
  }
  if #top == 0 then lines[#lines + 1] = "No game launched yet." end
  for i = 1, math.min(8, #top) do
    lines[#lines + 1] = string.format("%d. %s  (%d)", i, top[i].title, cfg.stat(top[i].app).plays)
  end
  openView("Statistics", lines, { icon = "chart" })
end

local function openAbout()
  local s = cfg.s
  local lines = {
    "#DOLPHIN STREAM " .. VERSION,
    "GameCube / Wii library: games run on Dolphin on the PC, the stream arrives here.",
    "",
    "#CREDITS",
    "Created by: sirpips",
    "Part of: Dolphin Rt:Core for muOS Project",
    "Produced by: SPDW Factory Lab",
    "",
    "#STREAM",
    string.format("Host: %s   Sync port: %s", s.HOST ~= "" and s.HOST or "(not set)", s.SYNC_PORT),
    string.format("%sx%s @ %s fps, %d Mbps, codec %s", s.WIDTH, s.HEIGHT, s.FPS, math.floor((tonumber(s.BITRATE) or 0) / 1000), s.CODEC),
    "",
    "#LEAVING A STREAM",
    "Moonlight combo: START + SELECT + L1 + R1.",
    "",
    "#FOLDER",
    base,
  }
  openView("About", lines, { icon = "info" })
end

local function openGameInfo(g)
  local s, ov = cfg.stat(g.app), cfg.getOver(g.app)
  local lines = {
    "#" .. g.title,
    "Platform: " .. (g.kind == "gc" and "GameCube" or "Wii"),
    "Game ID: " .. (g.id ~= "" and g.id or "n/d"),
    "Sunshine app: " .. g.app,
    string.format("Launches: %d   Last: %s", s.plays, ago(s.last)),
    "",
    "#STREAM PROFILE",
    "Resolution: " .. (ov.res ~= "" and ov.res or "global"),
    "Bitrate: " .. (ov.bitrate ~= "" and (tonumber(ov.bitrate) / 1000 .. " Mbps") or "global"),
    "FPS: " .. (ov.fps ~= "" and ov.fps or "global"),
  }
  openView("Game info", lines, { icon = "disc" })
end


-- ===================================================================== color palette
-- Un colore per tipo di voce. Usato in automatico se l'item non ha `color`.
local UI_COLORS = {
  quick = { 0.40, 0.85, 1.00 },   -- ciano: azioni rapide
  act   = { 1.00, 0.60, 0.25 },   -- arancio: azioni
  ch    = { 0.62, 0.40, 1.00 },   -- viola: cicli/valori
  tg    = { 0.40, 0.90, 0.55 },   -- verde: toggle on/off
  txt   = { 0.40, 0.85, 1.00 },   -- ciano: input testuale
  sub   = { 0.62, 0.40, 1.00 },   -- viola: sottomenu
  sep   = { 0.50, 0.50, 0.55 },   -- grigio: separatore
}

local function itemColor(it)
  if it.color then return it.color end
  return UI_COLORS[it.t] or UI_COLORS.act
end

-- ===================================================================== definizione menu

local function opts(list, fmt)
  local o = {}
  for _, v in ipairs(list) do o[#o + 1] = { v = v, l = fmt and fmt(v) or tostring(v) } end
  return o
end
local function mbps(v) return string.format("%d Mbps", math.floor((tonumber(v) or 0) / 1000)) end

local RES   = { "640x480", "800x600", "960x720", "1024x768", "1280x720" }
local BITR  = { "2000", "4000", "6000", "8000", "10000", "15000", "20000", "30000" }
local FPSL  = { "30", "60" }
local SORTN = { "A - Z", "Z - A", "Recent", "Most played" }

local function S() return cfg.s end
local function setS(k, v)
  cfg.s[k] = v
  local ok, lost = cfg.saveStream()
  if not ok then toast("Cannot write stream.conf", "err")
  elseif lost then toast("Value sanitized: quotes removed", "info") end
end
local function setUi(k, v) cfg.ui[k] = v; cfg.saveUi() end

-- Helper: returns the currently selected item in a menu
local function curItem(m)
  if not m then return nil end
  local nA = m.actions and #m.actions or 0
  local nq = (not m.hero and m.quick) and #m.quick or 0
  if m.sel <= nA then return m.actions[m.sel] end
  if m.sel <= nA + nq then return m.quick[m.sel - nA] end
  if m.sel <= nA + nq + #m.items then return m.items[m.sel - nA - nq] end
  return m.exit
end

local function pushMenu(m, parentColor)
  m.sel, m.top = 1, 0
  m.color = parentColor or m.color or UI_COLORS.sub
  menus[#menus + 1] = m
end

local lastQuick = 1

-- ============ OVERLAY PANELS (quick advanced options) ============
overlay = nil

local OVERLAY_ICONS = {
  ["Streaming - advanced"] = "screen",
  ["Interface - advanced"] = "gear",
  ["Diagnostics"] = "info",
  ["Reset"] = "trash",
}

local function openOverlay(title, items)
  overlay = { title = title, items = items, sel = 1, t = 0,
              icon = OVERLAY_ICONS[title] or "info" }
end

local function openStreamingAdvanced()
  openOverlay("Streaming - advanced", {
    { t = "ch", label = "Codec", icon = "disc", opts = opts({ "auto", "h264", "h265" }),
      desc = "auto lets Moonlight choose. h264 is most compatible",
      guide = {
        intro = "Video codec. H264 = maximum compatibility. H265 = better compression.",
        values = {
          ["auto"] = { desc = "Moonlight picks based on GPU/PC.", recommended = true },
          ["h264"] = { desc = "Compatible with everything, more bandwidth." },
          ["h265"] = { desc = "Less bandwidth, needs HW support.", warning = true, warn = "May not work on older HW." },
        }
      },
      get = function() return S().CODEC end, set = function(v) setS("CODEC", v) end },
    { t = "tg", label = "Match PC resolution", icon = "screen",
      desc = "Asks the PC to match the stream resolution",
      guide = { intro = "Asks the PC to match the stream resolution" },
      get = function() return S().SOPS ~= "no" end, set = function(v) setS("SOPS", v and "yes" or "no") end },
    { t = "ch", label = "Network mode", icon = "wifi", opts = opts({ "auto", "yes", "no" }),
      desc = "Moonlight remote mode: yes for outside-LAN",
      guide = {
  intro = "Moonlight remote mode. 'auto' picks based on detected network, 'yes' forces remote (outside LAN), 'no' forces local LAN only.",
  values = {
    ["auto"] = { desc = "Auto-detect network type.", recommended = true },
    ["yes"]  = { desc = "Force remote mode (outside LAN)." },
    ["no"]   = { desc = "Force local LAN only." },
  }
},
      get = function() return S().REMOTE end, set = function(v) setS("REMOTE", v) end },
    { t = "ch", label = "Video driver", icon = "gear",
      opts = opts({ "", "sdl" }, function(v) return v == "" and "auto" or v end),
      desc = "If the stream does not fill the screen, try sdl",
      guide = {
  intro = "SDL driver for video output. Leave on 'auto' unless the stream does not fill the screen.",
  values = {
    [""]    = { desc = "Automatic (let Moonlight choose).", recommended = true },
    ["sdl"] = { desc = "Force SDL driver. Try if stream does not fill the screen." },
  }
},
      get = function() return S().PLATFORM end, set = function(v) setS("PLATFORM", v) end },
    { t = "txt", label = "Edit token", icon = "keyboard", maxlen = 16,
      desc = "Token shown in the PC portal",
      guide = { intro = "Token shown in the PC portal" },
      get = function() return S().TOKEN end, set = function(v) setS("TOKEN", v) end },
    { t = "txt", label = "Extra arguments", icon = "keyboard", maxlen = 60,
      desc = "Extra options passed to moonlight",
      guide = { intro = "Extra options passed to moonlight" },
      get = function() return S().EXTRA_ARGS end, set = function(v) setS("EXTRA_ARGS", v) end },
  })
end

local function openInterfaceAdvanced()
  openOverlay("Interface - advanced", {
    { t = "tg", label = "Boot animation", icon = "bolt", desc = "Startup animation",
      guide = { intro = "Startup animation" },
      get = function() return cfg.ui.boot end, set = function(v) setUi("boot", v) end },
    { t = "tg", label = "Animations", icon = "play", desc = "Moving background and effects",
      guide = { intro = "Moving background and effects" },
      get = function() return cfg.ui.anim end, set = function(v) setUi("anim", v) end },
    { t = "tg", label = "Scanlines", icon = "list", desc = "CRT screen effect",
      guide = { intro = "CRT screen effect" },
      get = function() return cfg.ui.scan end, set = function(v) setUi("scan", v) end },
    { t = "tg", label = "Battery saver", icon = "bolt", desc = "Limits to about 30 fps",
      guide = { intro = "Limits to about 30 fps" },
      get = function() return cfg.ui.eco end, set = function(v) setUi("eco", v) end },
    { t = "tg", label = "Swap A / B", icon = "swap", desc = "If A and B are swapped on your device",
      guide = { intro = "If A and B are swapped on your device" },
      get = function() return cfg.ui.swap end, set = function(v) setUi("swap", v) end },
    { t = "tg", label = "Confirm exit", icon = "close", desc = "Asks before closing",
      guide = { intro = "Asks before closing" },
      get = function() return cfg.ui.confirm end, set = function(v) setUi("confirm", v) end },
  })
end

local function openDiagnosticsOverlay()
  openOverlay("Diagnostics", {
    { t = "act", label = "Export diagnostics", icon = "info",
      desc = "Dump system info, config, logs to conf/diagnostics.txt",
      guide = { intro = "Dump system info, config, logs to conf/diagnostics.txt" },
      fn = function() overlay = nil; openDiagnostics() end },
    { t = "act", label = "Verify Sunshine apps", icon = "wifi",
      desc = "Compare Sunshine app list with local library",
      guide = { intro = "Compare Sunshine app list with local library" },
      fn = function() overlay = nil; openSunshineVerify() end },
    { t = "act", label = "Disk space", icon = "chart",
      desc = "Check filesystem and app folder sizes",
      guide = { intro = "Check filesystem and app folder sizes" },
      fn = function() overlay = nil; openDiskSpace() end },
    { t = "act", label = "Measure latency", icon = "clock",
      desc = "Ping PC 10 times and show min/avg/max/loss",
      guide = { intro = "Ping PC 10 times and show min/avg/max/loss" },
      fn = function() overlay = nil; openLatency() end },
  })
end

local function openResetOverlay()
  openOverlay("Reset", {
    { t = "act", label = "Reset statistics", icon = "trash",
      desc = "Clear launch counts. Favorites are kept.",
      guide = { intro = "Clear launch counts. Favorites are kept." },
      fn = function() overlay = nil; openDlg("Reset statistics", "Clear launch counts?", function()
        for _, st in pairs(cfg.stats) do st.plays, st.last = 0, 0 end
        cfg.saveStats(); dirty = true; toast("Statistics reset", "ok")
      end) end },
    { t = "act", label = "Reset favorites", icon = "star",
      desc = "Remove star from every game",
      guide = { intro = "Remove star from every game" },
      fn = function() overlay = nil; openDlg("Reset favorites", "Remove all favorites?", function()
        for _, st in pairs(cfg.stats) do st.fav = false end
        cfg.saveStats(); dirty = true; toast("Favorites reset", "ok")
      end) end },
    { t = "act", label = "Reset streaming", icon = "back",
      desc = "Restore streaming defaults. Host is kept.",
      guide = { intro = "Restore streaming defaults. Host is kept." },
      fn = function() overlay = nil; openDlg("Reset", "Restore streaming defaults?", function()
        cfg.resetStream(); toast("Streaming settings restored", "ok")
      end) end },
    { t = "act", label = "Clear cover cache", icon = "trash",
      desc = "Delete downloaded covers (then sync again)",
      guide = { intro = "Delete downloaded covers (then sync again)" },
      fn = function() overlay = nil; openDlg("Clear cache", "Delete all downloaded covers?", function()
        os.execute("rm -f " .. q(base .. "/covers") .. "/*.png")
        for _, g in ipairs(all) do g.img = nil end
        loaded = {}
        toast("Cover cache cleared", "ok")
      end) end },
  })
end

-- ============ MENU DEFINITIONS ============
local streamMenu, uiMenu, toolsMenu

streamMenu = function()
  return { title = "Streaming", icon = "screen", items = {
    { t = "txt", label = "PC host", icon = "link", maxlen = 40,
      desc = "IP or hostname of the PC running Sunshine",
      guide = { intro = "IP or hostname of the PC running Sunshine" },
      get = function() return S().HOST end, set = function(v) setS("HOST", v) end },
    { t = "txt", label = "Sync port", icon = "link", numeric = true, maxlen = 5,
      desc = "Port of the library sync server",
      guide = { intro = "Port of the library sync server" },
      get = function() return S().SYNC_PORT end,
      set = function(v) if v ~= "" then setS("SYNC_PORT", v) end end },
    { t = "ch", label = "Resolution", icon = "screen", opts = opts(RES),
      desc = "Stream resolution",
      guide = {
        intro = "Video stream resolution. Higher = more detail, but requires more bandwidth and PC CPU.",
        values = {
          ["640x480"]  = { desc = "Native screen. Maximum performance.", recommended = true },
          ["800x600"]  = { desc = "Slightly sharper, still light." },
          ["960x720"]  = { desc = "Balanced for LAN." },
          ["1024x768"] = { desc = "Good on fast LAN." },
          ["1280x720"] = { desc = "HD, needs stable LAN.", warning = true, warn = "May lag on 4G or weak WiFi." },
        }
      },
      get = function() return S().WIDTH .. "x" .. S().HEIGHT end,
      set = function(v) local w, h = v:match("^(%d+)x(%d+)$")
        if w then cfg.s.WIDTH, cfg.s.HEIGHT = w, h; cfg.saveStream() end end },
    { t = "ch", label = "Frame rate", icon = "clock", opts = opts(FPSL, function(v) return v .. " fps" end),
      desc = "Use 30 fps if the network is shaky",
      guide = {
        intro = "Frames per second of the stream. 60 fps is smooth but heavier on network/CPU.",
        values = {
          ["30"] = { desc = "Saves bandwidth, good for 4G.", warning = true, warn = "Less smooth in action games." },
          ["60"] = { desc = "Smooth, standard for gaming.", recommended = true },
        }
      },
      get = function() return S().FPS end, set = function(v) setS("FPS", v) end },
    { t = "ch", label = "Bitrate", icon = "chart", opts = opts(BITR, mbps),
      desc = "Video quality. 10 Mbps is fine on LAN",
      guide = {
        intro = "Maximum bandwidth for the stream. Higher = better quality, but saturates the network.",
        values = {
          ["2000"]  = { desc = "Extreme saving, weak 4G." },
          ["4000"]  = { desc = "Decent 4G." },
          ["6000"]  = { desc = "WiFi 2.4GHz." },
          ["8000"]  = { desc = "Good LAN compromise." },
          ["10000"] = { desc = "Recommended on stable LAN.", recommended = true },
          ["15000"] = { desc = "Fast LAN." },
          ["20000"] = { desc = "Gigabit LAN.", warning = true, warn = "Saturates 2.4GHz WiFi." },
          ["30000"] = { desc = "Wired gigabit LAN only.", warning = true, warn = "May lag on WiFi." },
        }
      },
      get = function() return S().BITRATE end, set = function(v) setS("BITRATE", v) end },
    { t = "sep" },
    { t = "act", label = "Advanced Options", icon = "gear",
      desc = "Codec, network mode, video driver, token, extra args",
      guide = { intro = "Codec, network mode, video driver, token, extra args" },
      fn = function() openStreamingAdvanced() end },
  } }
end

uiMenu = function()
  local tn = {}
  for i, th in ipairs(ui.themes) do tn[i] = i end
  return { title = "Interface", icon = "gear", items = {
    { t = "ch", label = "Color theme", icon = "star", desc = "Interface color palette",
      guide = { intro = "Interface color palette" },
      opts = opts(tn, function(i) return ui.themes[i].name end),
      get = function() return cfg.ui.theme end,
      set = function(v) setUi("theme", v); ui.setTheme(v) end },
    { t = "ch", label = "Library view", icon = "grid", desc = "Cover flow, grid or list",
      guide = {
  intro = "How the game list is displayed.",
  values = {
    ["1"] = { desc = "Cover Flow: 2.5D carousel with reflections.", recommended = true },
    ["2"] = { desc = "Grid: thumbnail grid, more games visible." },
    ["3"] = { desc = "List: text rows with cover on the right." },
  }
},
      opts = opts({ 1, 2, 3 }, function(i) return VIEWS[i].name end),
      get = function() return cfg.ui.view end,
      set = function(v) setUi("view", v); relayout() end },
    { t = "ch", label = "Sort order", icon = "sort", desc = "How games are sorted",
      guide = {
  intro = "Order of games inside each tab.",
  values = {
    ["1"] = { desc = "A to Z alphabetical.", recommended = true },
    ["2"] = { desc = "Z to A reverse alphabetical." },
    ["3"] = { desc = "Recently played first." },
    ["4"] = { desc = "Most played first." },
  }
},
      opts = opts({ 1, 2, 3, 4 }, function(i) return SORTN[i] end),
      get = function() return cfg.ui.sort end,
      set = function(v) setUi("sort", v); dirty = true end },
    { t = "sep" },
    { t = "act", label = "Advanced Options", icon = "gear",
      desc = "Boot animation, scanlines, eco mode, swap A/B",
      guide = { intro = "Boot animation, scanlines, eco mode, swap A/B" },
      fn = function() openInterfaceAdvanced() end },
  } }
end

toolsMenu = function()
  return { title = "Tools", icon = "wrench", items = {
    { t = "act", label = "Connection test", icon = "wifi",
      desc = "Checks ping, sync server and Sunshine",
      guide = { intro = "Checks ping, sync server and Sunshine" },
      fn = function() openTest() end },
    { t = "act", label = "Pair with Sunshine", icon = "link",
      desc = "Shows the PIN to enter in the Sunshine web UI",
      guide = { intro = "Shows the PIN to enter in the Sunshine web UI" },
      fn = function() openPair() end },
    { t = "act", label = "Last stream log", icon = "list",
      desc = "Moonlight output: useful if a stream does not start",
      guide = { intro = "Moonlight output: useful if a stream does not start" },
      fn = function() openStreamLog() end },
    { t = "sep" },
        { t = "act", label = "Diagnostics", icon = "info",
      desc = "Export, verify Sunshine, disk space, latency",
      guide = { intro = "Export, verify Sunshine, disk space, latency" },
      fn = function() openDiagnosticsOverlay() end },
    { t = "act", label = "Reset", icon = "trash",
      desc = "Statistics, favorites, streaming, cover cache",
      guide = { intro = "Statistics, favorites, streaming, cover cache" },
      fn = function() openResetOverlay() end },
    { t = "sep" },
    { t = "act", label = "About", icon = "info",
      desc = "Version, statistics, current configuration",
      guide = { intro = "Version, statistics, current configuration" },
      fn = function() openAbout() end },
  } }
end

local function mainMenu()
  return {
    title = "Menu", icon = "menu",
    desc = "Quick actions on top, sections below. Pick a game from the library to play.",
    quick = {
      { t = "quick", icon = "search", label = "Search", color = UI_COLORS.quick,
        desc = "Filter the current tab by title or app name",
      guide = { intro = "Filter the current tab by title or app name" },
      fn = function() openSearch() end },
      { t = "quick", icon = "sync", label = "Sync", color = { 1.00, 0.82, 0.30 },
        desc = "Download games and covers from the PC",
        guide = {
          intro = "Sync downloads the game list and covers from Dolphin Rt:Stream Portal on the PC. All requirements below must be met before syncing.",
          values = {
            ["1"] = { desc = "Console connected via WiFi or LAN, with internet access", recommended = true },
            ["2"] = { desc = "Dolphin Rt:Stream Portal installed and running on the PC", recommended = true },
            ["3"] = { desc = "Sunshine server enabled and running in the portal", recommended = true },
            ["4"] = { desc = "Library server enabled in the portal", recommended = true },
            ["5"] = { desc = "Port open in firewall and matching Sync port in START > Streaming", recommended = true },
          }
        },
        opts = {
          { v = "1", l = "1. Console online" },
          { v = "2", l = "2. Portal running" },
          { v = "3", l = "3. Sunshine server" },
          { v = "4", l = "4. Library server" },
          { v = "5", l = "5. Port match" },
        },
        fn = function() startSync() end },
    },
    items = {
      { t = "sub", label = "Streaming", icon = "screen", color = { 0.62, 0.40, 1.00 },
        desc = "Host, resolution, bitrate, codec",
        guide = { intro = "Stream settings for Moonlight: PC host, sync port, resolution, frame rate, bitrate. Open Advanced Options for codec, network mode, video driver, token and extra arguments." },
        menu = streamMenu },
      { t = "act", label = "Controller profiles", icon = "gamepad", color = UI_COLORS.quick,
        desc = "Edit Dolphin controller mapping (muos* profiles only)",
      guide = { intro = "Edit Dolphin controller mapping (muos* profiles only)" },
      fn = function() controls.open() end },
      { t = "sub", label = "Interface", icon = "gear", color = { 0.40, 0.90, 0.55 },
        desc = "Theme, view, sorting, effects",
        guide = { intro = "Interface look & feel: color theme, library view (Flow, Grid, List), sort order. Open Advanced Options for boot animation, scanlines, battery saver and button swap." },
        menu = uiMenu },
      { t = "sub", label = "Tools", icon = "wrench", color = { 1.00, 0.60, 0.25 },
        desc = "Diagnostics, pairing, reset",
        guide = { intro = "Maintenance and diagnostics: connection test, Sunshine pairing, last stream log, diagnostics overlay (export, verify apps, disk space, latency), reset overlay, about." },
        menu = toolsMenu },
    }
  }
end

local function gameMenu(g)
  local function chOv(label, key, list, fmt, icon, desc)
    local o = { { v = "", l = "Global" } }
    for _, v in ipairs(list) do o[#o + 1] = { v = v, l = fmt and fmt(v) or v } end
    return { t = "ch", label = label, icon = icon, desc = desc,
      guide = { intro = desc or "Per-game override. Global uses the streaming settings." },
      opts = o,
      get = function() return cfg.getOver(g.app)[key] end,
      set = function(v) cfg.setOver(g.app, key, v) end }
  end
  return {
    title = g.title,
    icon = "disc",
    hero = { cover = g },
    actions = {
      { t = "act", label = "PLAY", icon = "play", color = { 0.35, 0.90, 0.45 },
        desc = "Start the Moonlight stream",
        guide = { intro = "Starts the Moonlight stream. Pre-flight pings the PC first, so you get a clear error if the PC is off." },
        fn = function() play(g) end },
      { t = "tg", label = "FAVORITE", icon = "star", color = { 1.00, 0.82, 0.30 },
        desc = "Toggle favorite",
        guide = { intro = "Star or unstar this game. Starred games appear first in the Favorites tab." },
        get = function() return cfg.stat(g.app).fav end,
        set = function(v) cfg.mut(g.app).fav = v; cfg.saveStats(); dirty = true end },
      { t = "act", label = "INFO", icon = "info", color = { 0.40, 0.85, 1.00 },
        desc = "Game details and stream profile",
        guide = { intro = "Show game ID, platform, launch count and current stream profile (resolution, bitrate, fps)." },
        fn = function() openGameInfo(g) end },
    },
    items = {
      chOv("Resolution", "res", RES, nil, "screen", "Per-game resolution override."),
      chOv("Bitrate", "bitrate", BITR, mbps, "chart", "Per-game bitrate override."),
      chOv("Frame rate", "fps", FPSL, function(v) return v .. " fps" end, "clock", "Per-game frame rate override."),
    },
  }
end

-- ===================================================================== tastiera virtuale
local function chars(s)
  local r = {}
  for ch in s:gmatch(".") do r[#r + 1] = ch end
  return r
end
local function kbRows(numeric)
  if numeric then return { chars("1234567890"), { "DEL", "OK" } } end
  return { chars("1234567890"), chars("qwertyuiop"), chars("asdfghjkl-"), chars("zxcvbnm._:"),
    { "/", "=", ",", "@", "+", "SPC", "DEL", "OK" } }
end

local function openKb(it)
  kb = { title = it.label, value = it.get() or "", set = it.set, maxlen = it.maxlen or 40, r = 1, c = 1,
    rows = kbRows(it.numeric) }
end

clearSearch = function(i)
  search[i] = ""
  searchActive[i] = false
  sel[i] = 1
  topRow[i] = 0
  scrollY[i] = 0
  dirty = true
end

openSearch = function()
  menus = {}
  openKb({
    label = "Search " .. TAB_NAMES[tab],
    get = function() return search[tab] end,
    set = function(v)
      search[tab] = v
      searchActive[tab] = (v ~= "")
      sel[tab] = 1
      topRow[tab] = 0
      scrollY[tab] = 0
      dirty = true
    end,
    maxlen = 40,
  })
end

local function kbCommit()
  local k = kb; kb = nil
  k.set(k.value)
end

-- ===================================================================== input
local press

local function menuMove(m, d)
  local nA = m.actions and #m.actions or 0
  local nq = (not m.hero and m.quick) and #m.quick or 0
  local nTop = nA + nq
  local ni = #m.items
  local hasExit = m.exit ~= nil
  local total = nTop + ni + (hasExit and 1 or 0)
  if total == 0 then return end

  local function skipSepFwd(idx)
    while idx > nTop and idx <= nTop + ni and m.items[idx - nTop].t == "sep" do idx = idx + 1 end
    return idx
  end
  local function skipSepBack(idx)
    while idx > nTop and idx <= nTop + ni and m.items[idx - nTop].t == "sep" do idx = idx - 1 end
    return idx
  end

  if d == -1 then
    if m.sel == 1 then m.sel = total
    elseif m.sel <= nTop then m.sel = m.sel - 1
    elseif m.sel == nTop + 1 then m.sel = nTop
    else m.sel = skipSepBack(m.sel - 1) end
  elseif d == 1 then
    if m.sel == total then m.sel = 1
    elseif m.sel <= nTop then m.sel = skipSepFwd(nTop + 1)
    else
      local nxt = skipSepFwd(m.sel + 1)
      m.sel = (nxt > total) and 1 or nxt
    end
  end

  local item_idx = m.sel - nTop
  if item_idx >= 1 and item_idx <= ni then
    if item_idx <= m.top then m.top = math.max(0, item_idx - 1) end
    if item_idx > m.top + VIS then m.top = item_idx - VIS end
  end
end

local function chStep(it, d)
  local cur, idx = it.get(), 0
  for i, o in ipairs(it.opts) do if o.v == cur then idx = i end end
  idx = idx + d
  if idx < 1 then idx = #it.opts elseif idx > #it.opts then idx = 1 end
  it.set(it.opts[idx].v)
end

local function itemUse(it, dir)
  if not it then return end
  if it.t == "sep" then return end
  if it.fn and (it.t == "act" or it.t == "quick") then
    if dir == 0 then it.fn() end
  elseif it.t == "sub" then
    if dir >= 0 then pushMenu(it.menu(), itemColor(it)) end
  elseif it.t == "tg" then
    it.set(not it.get())
  elseif it.t == "ch" then
    chStep(it, dir == 0 and 1 or dir)
  elseif it.t == "txt" then
    if dir == 0 then openKb(it) end
  end
end

local function menuPress(b)
  local m = menus[#menus]
  if not m then return end
  local cur = curItem(m)
  if b == "up" then menuMove(m, -1)
  elseif b == "down" then menuMove(m, 1)
  elseif b == "l2" then menuMove(m, -VIS)
  elseif b == "r2" then menuMove(m, VIS)
  elseif b == "left" then itemUse(cur, -1)
  elseif b == "right" then itemUse(cur, 1)
  elseif b == "a" then itemUse(cur, 0)
  elseif b == "b" then table.remove(menus)
  elseif b == "start" then menus = {}
  end
end

local function viewVis() return math.floor((420 - (view.pair and 150 or 76)) / 22) end

local function viewPress(b)
  local maxTop = math.max(0, #view.flat - viewVis())
  if b == "up" then view.top = math.max(0, view.top - 1)
  elseif b == "down" then view.top = math.min(maxTop, view.top + 1)
  elseif b == "l2" or b == "left" then view.top = math.max(0, view.top - viewVis())
  elseif b == "r2" or b == "right" then view.top = math.min(maxTop, view.top + viewVis())
  elseif b == "b" or b == "a" then
    local v = view; view = nil
    if v.onClose then v.onClose() end
  end
end

local function kbPress(b)
  local row = kb.rows[kb.r]
  if b == "up" then kb.r = math.max(1, kb.r - 1); kb.c = math.min(kb.c, #kb.rows[kb.r])
  elseif b == "down" then kb.r = math.min(#kb.rows, kb.r + 1); kb.c = math.min(kb.c, #kb.rows[kb.r])
  elseif b == "left" then kb.c = kb.c - 1; if kb.c < 1 then kb.c = #row end
  elseif b == "right" then kb.c = kb.c + 1; if kb.c > #row then kb.c = 1 end
  elseif b == "a" then
    local tok = row[kb.c]
    if tok == "OK" then kbCommit()
    elseif tok == "DEL" then kb.value = kb.value:sub(1, -2)
    elseif tok == "SPC" then if #kb.value < kb.maxlen then kb.value = kb.value .. " " end
    elseif #kb.value < kb.maxlen then kb.value = kb.value .. tok end
  elseif b == "x" then kb.value = kb.value:sub(1, -2)
  elseif b == "start" then kbCommit()
  elseif b == "b" then kb = nil
  end
end

local function dlgPress(b)
  if b == "a" or b == "start" then
    local f = dlg.yes; dlg = nil; f()
  elseif b == "b" then
    dlg = nil
  end
end

local function libPress(b)
  if b == "up" then move(V().flow and -4 or -V().cols)
  elseif b == "down" then move(V().flow and 4 or V().cols)
  elseif b == "left" then if V().list then move(-V().rows) else move(-1) end
  elseif b == "right" then if V().list then move(V().rows) else move(1) end
  elseif b == "l1" then setTab(tab - 1)
  elseif b == "r1" then setTab(tab + 1)
  elseif b == "l2" then move(V().flow and -8 or -V().cols * V().rows)
  elseif b == "r2" then move(V().flow and 8 or V().cols * V().rows)
  elseif b == "a" then play(curGame())
  elseif b == "x" then
    if search[tab] ~= "" then openSearch()
    else toggleFav(curGame()) end
  elseif b == "y" then
    local g = curGame()
    if g then pushMenu(gameMenu(g)) end
  elseif b == "select" then startSync()
  elseif b == "start" then pushMenu(mainMenu())
  elseif b == "b" then
    if search[tab] ~= "" then clearSearch(tab)
    elseif cfg.ui.confirm then openDlg("Exit", "Close Dolphin Stream?", function() love.event.quit() end)
    else love.event.quit() end
  end
end

press = function(b)
  if bootT < boot.dur then
    if bootT < boot.dur - 0.45 then bootT = boot.dur - 0.45 end
    return
  end
  if launching then return end
  -- Overlay has absolute priority: when open, it captures ALL keys
  if dlg then dlgPress(b); return end
  if guide then guidePress(b); return end
  if b == "guide" and (overlay or #menus > 0) then
    if overlay then
      local ovcur = overlay.items[overlay.sel]
      if ovcur then openGuide(ovcur, ovcur.label, ovcur.icon) end
    elseif #menus > 0 then
      local mcur = curItem(menus[#menus])
      if mcur then openGuide(mcur, mcur.label, mcur.icon) end
    end
    return
  end
  if overlay then overlayPress(b); return end
  if kb then kbPress(b)
  elseif view then viewPress(b)
  elseif controls.active() then controls.press(b)
  elseif #menus > 0 then menuPress(b)
  else libPress(b) end
end

local keymap = {
  up = "up", down = "down", left = "left", right = "right",
  z = "a", x = "b", c = "x", v = "y", q = "l1", e = "r1", pageup = "l2", pagedown = "r2",
  tab = "select", ["return"] = "start", escape = "b", backspace = "b",
  m = "guide",
}
local padmap = {
  dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
  a = "a", b = "b", x = "x", y = "y", leftshoulder = "l1", rightshoulder = "r1",
  back = "select", start = "start", guide = "guide", mode = "guide",
}
local DIRS = { up = true, down = true, left = true, right = true }

local lastFire = {}
local spin_quads = nil
local function fire(name)
  -- Debounce: il pad della console manda 2 eventi (hat + gamepad)
  -- per una singola pressione. Ignoriamo i duplicati entro 80ms.
  local now = love.timer.getTime()
  if DIRS[name] then
    if lastFire[name] and (now - lastFire[name]) < 0.08 then return end
    lastFire[name] = now
  end
  press(name)
  if DIRS[name] then held[name] = { t = 0, r = 0 } end
end

function love.keypressed(key)
  if keymap[key] then fire(keymap[key]) end
end

function love.gamepadpressed(_, button)
  if cfg.ui.swap then
    if button == "a" then button = "b" elseif button == "b" then button = "a" end
  end
  if padmap[button] then fire(padmap[button]) end
end

local trig = { triggerleft = false, triggerright = false }
function love.gamepadaxis(_, axis, value)
  if axis == "triggerleft" or axis == "triggerright" then
    local on = value > 0.5
    if on and not trig[axis] then press(axis == "triggerleft" and "l2" or "r2") end
    trig[axis] = on
  end
end

local function isDown(name)
  if love.keyboard.isDown(name) then return true end
  for _, js in ipairs(love.joystick.getJoysticks()) do
    if js:isGamepad() and js:isGamepadDown("dp" .. name) then return true end
  end
  return false
end

-- ===================================================================== love
function love.load()
  love.mouse.setVisible(false)
  cfg.init(base)
  ui.setTheme(cfg.ui.theme)
  ui.loadFonts(); ui.initBg(); ui.initScan(); boot.init()
  controls.init({ base = base, toast = toast, runTool = runTool })
  fonts = ui.fonts
  bootT = (cfg.ui.boot and cfg.ui.anim) and 0 or boot.dur
  loadLibrary()
  loadState()
  getList(tab)
  relayout()
  -- burst: carica tutte le cover in memoria al primo frame (5 giochi = 1 frame)
  loadBudget = #all + 1
  flowPos = sel[tab]
  local r = cfg.readFile(base .. "/conf/last_result.txt")
  if r then
    os.remove(base .. "/conf/last_result.txt")
    local rc, dur = r:match("rc=(%d+)%s+dur=(%d+)")
    toast(string.format("Stream ended (code %s, %ss). See Tools > Last stream log", rc or "?", dur or "?"), "err")
  elseif cfg.s.HOST == "" then
    toast("Set the PC address: START > Streaming > PC host", "info")
  elseif os.time() < 1735689600 then
    toast("RTC not set: dates will show 'unknown'. Set the clock from muOS", "info")
  end
end

function love.quit() saveState() end

function love.update(dt)
  dt = math.min(dt, 0.1)
  dtG = dt
  t = t + dt

  -- ==== health check (SUNSHINE + LIBRARY) ====
  if health.polling then
    health.pollTimer = health.pollTimer + dt
    local s = cfg.readFile("/tmp/ds_health_sunshine.done")
    local l = cfg.readFile("/tmp/ds_health_library.done")
    if s then
      health.sunshine = s:match("OK") and "ok" or "fail"
      os.remove("/tmp/ds_health_sunshine.done")
    end
    if l then
      health.library = l:match("OK") and "ok" or "fail"
      os.remove("/tmp/ds_health_library.done")
    end
    if health.pollTimer > 4 then
      health.polling = false
      if health.sunshine == "unknown" then health.sunshine = "fail" end
      if health.library == "unknown" then health.library = "fail" end
    end
  end
  health.timer = health.timer - dt
  if health.timer <= 0 and not health.polling then
    health.timer = 15
    local host = cfg.s.HOST
    if host == "" then
      health.sunshine, health.library = "unknown", "unknown"
    else
      local sp = cfg.s.SYNC_PORT or "8765"
      os.remove("/tmp/ds_health_sunshine.done")
      os.remove("/tmp/ds_health_library.done")
      health.polling = true
      health.pollTimer = 0
      httpCheck(string.format("http://%s:47989/serverinfo", host), "/tmp/ds_health_sunshine.done")
      httpCheck(string.format("http://%s:%s/library.tsv", host, sp), "/tmp/ds_health_library.done")
    end
  end
  -- ==== end health check ====
  tabFade = math.min(1, tabFade + dt * 5)
  if bootT < boot.dur then bootT = bootT + dt end
  selPop = math.max(0, selPop - dt * 5)
  infoT = math.min(1, infoT + dt * 5)
  flowPos = cfg.ui.anim and (flowPos + (sel[tab] - flowPos) * math.min(1, dt * 11)) or sel[tab]
  if math.abs(flowPos - sel[tab]) < 0.002 then flowPos = sel[tab] end
  for i = 1, 4 do
    local target = (i == tab) and 170 or 60
    tabW[i] = cfg.ui.anim and (tabW[i] + (target - tabW[i]) * math.min(1, dt * 14)) or target
  end
  local key = tostring(kb or view or menus[#menus] or "lib")
  if key ~= lastKey then lastKey = key; modalT = 0 end
  modalT = modalT + dt
  dlgT = dlg and (dlgT + dt) or 0
  if launching then
    launching.reveal = math.min(1, launching.reveal + dt * 4)
    if launching.phase == "ping" then
      local r = cfg.readFile("/tmp/ds_ping.done")
      if r then
        os.remove("/tmp/ds_ping.done")
        if r:match("FAIL") then
          toast("PC " .. launching.host .. " not responding. Tools > Connection test", "err")
          launching = nil
        else
          -- OK o SKIP (ping assente): prosegui
          launching.phase = "launch"; launching.t = 0
        end
      elseif t - launching.t0 > 2.5 then
        -- ping sospeso troppo: procedi (non bloccare l utente)
        launching.phase = "launch"; launching.t = 0
      end
    else
      launching.t = launching.t + dt
      if launching.t >= LAUNCH_T then local g = launching.g; launching = nil; doPlay(g) end
    end
  end
  loadBudget = 4
  controls.update(dt)
  if overlay then overlay.t = overlay.t + dt end
  if guide then guide.t = guide.t + dt end
  if toastT.t > 0 then toastT.t = toastT.t - dt end
  if sync.show > 0 then sync.show = sync.show - dt end

  local v = V()
  local target = topRow[tab] * v.rowh
  scrollY[tab] = scrollY[tab] + (target - scrollY[tab]) * math.min(1, dt * 14)

  for name, h in pairs(held) do
    if isDown(name) then
      h.t = h.t + dt
      if h.t > 0.4 then
        h.r = h.r + dt
        while h.r > 0.07 do h.r = h.r - 0.07; press(name) end
      end
    else
      held[name] = nil
    end
  end

  if sync.on then
    sync.timer = sync.timer - dt
    if sync.timer <= 0 then
      sync.timer = 0.3
      local s = cfg.readFile(base .. "/conf/sync.status")
      if s then sync.msg = (s:gsub("%s+$", "")) end
      if cfg.readFile(base .. "/conf/sync.done") then
        sync.on, sync.show = false, 5
        loadLibrary(); getList(tab); ensureVisible()
        if sync.msg:match("^ERR") then sync.state = "err"; toast(sync.msg, "err")
        else sync.state = "ok"; toast(sync.msg, "ok") end
      end
    end
  end

  if view and view.poll then
    view.timer = view.timer - dt
    if view.timer <= 0 then
      view.timer = 0.5
      local raw = view.poll()
      if raw then
        local keepBottom = view.top >= math.max(0, #view.flat - viewVis())
        setViewLines(view, raw)
        if keepBottom then view.top = math.max(0, #view.flat - viewVis()) end
      end
    end
  end
end

-- ===================================================================== disegno
local function tabAcc(i)
  local th = ui.th
  if i == 1 then return th.gc elseif i == 2 then return th.wii elseif i == 3 then return th.fav end
  return th.text
end

local function drawCover(g, x, y, w, h, acc, ga)
  local img = loadCover(g)
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min(w / iw, h / ih)
    local dw, dh = iw * s, ih * s
    local dx, dy = x + (w - dw) / 2, y + (h - dh)
    lg.setColor(1, 1, 1, ga)
    lg.draw(img, dx, dy, 0, s, s)
    return dx, dy, dw, dh
  end
  lg.setColor(acc[1] * 0.18, acc[2] * 0.18, acc[3] * 0.18, ga); ui.chamfer("fill", x, y, w, h, 8)
  lg.setColor(acc[1], acc[2], acc[3], 0.6 * ga); lg.setLineWidth(1.5); ui.chamfer("line", x + 0.5, y + 0.5, w - 1, h - 1, 8)
  ui.icon("disc", x + w / 2, y + h * 0.27, math.min(w, h) * 0.12, acc, 0.8 * ga)
  lg.setFont(fonts.xs); lg.setColor(1, 1, 1, 0.9 * ga)
  lg.printf(g.title, x + 6, y + h * 0.45, w - 12, "center")
  lg.setLineWidth(1)
  return x, y, w, h
end

-- cornice luminosa attorno alla cover selezionata
local function selFrame(dx, dy, dw, dh, acc, pulse)
  lg.setColor(acc[1], acc[2], acc[3], 0.10 + 0.14 * pulse); ui.chamfer("fill", dx - 9, dy - 9, dw + 18, dh + 18, 10)
  lg.setColor(acc[1], acc[2], acc[3], 1); lg.setLineWidth(3); ui.chamfer("line", dx - 3, dy - 3, dw + 6, dh + 6, 6)
  lg.setLineWidth(2); ui.brackets(dx - 10, dy - 10, dw + 20, dh + 20, 12)
  if cfg.ui.anim then
    lg.setColor(1, 1, 1, 0.30); lg.rectangle("fill", dx, dy + ((t * 80) % dh), dw, 2)
  end
  lg.setLineWidth(1)
end

-- ---------------------------------------------------------------- vista Flow (cover flow 2.5D)
local FW, FH, FBASE = 140, 196, 296
local function drawFlow(list)
  local n = #list
  local cx = W / 2
  local items = {}
  for i = math.max(1, math.floor(flowPos) - 4), math.min(n, math.ceil(flowPos) + 4) do
    items[#items + 1] = { i, i - flowPos }
  end
  table.sort(items, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
  for _, it in ipairs(items) do
    local g, d = list[it[1]], it[2]
    local ad = math.min(math.abs(d), 1)
    local ex = math.max(0, math.abs(d) - 1)
    local sg = d < 0 and -1 or 1
    local near = math.max(0, 1 - math.abs(d) * 2)          -- 1 sulla cover al centro
    local x = cx + sg * (ad * 158 + ex * 64)
    local sc = 1 - 0.30 * ad - 0.07 * math.min(ex, 2.5) + 0.07 * selPop * near
    local ga = ui.clamp(1 - 0.17 * math.abs(d), 0.25, 1) * tabFade
    local acc = ui.accent(g.kind)
    lg.push()
    lg.translate(x, FBASE)
    lg.scale(sc * (1 - 0.20 * ad), sc)
    lg.shear(0, -sg * 0.18 * ad)
    -- riflesso
    lg.push(); lg.scale(1, -1)
    drawCover(g, -FW / 2, -FH, FW, FH, acc, ga * 0.16)
    lg.pop()
    ui.slab(-FW / 2, -FH, FW, FH, acc, 9, ga)
    local dx, dy, dw, dh = drawCover(g, -FW / 2, -FH, FW, FH, acc, ga)
    if ad > 0.01 then lg.setColor(0, 0, 0, 0.38 * ad * ga); lg.rectangle("fill", dx, dy, dw, dh) end
    if near > 0.5 then
      selFrame(dx, dy, dw, dh, acc, cfg.ui.anim and (0.5 + 0.5 * math.sin(t * 5)) or 0.5)
    end
    lg.pop()
  end
end

-- ---------------------------------------------------------------- vista griglia
local function drawGrid(list, v)
  local n = #list
  local sy = scrollY[tab]
  local r0 = math.max(0, math.floor(sy / v.rowh) - 1)
  local first = r0 * v.cols + 1
  local last = math.min(n, (r0 + v.rows + 3) * v.cols)
  local selRect
  for i = first, last do
    local c = (i - 1) % v.cols
    local r = math.floor((i - 1) / v.cols)
    local x = v.x0 + c * v.cellw + (v.cellw - v.cw) / 2
    local y = GY0 + 10 + r * v.rowh - sy
    if y + v.ch > GY0 and y < CONTENT_BOT then
      if i == sel[tab] then selRect = { list[i], x, y }
      else
        local g = list[i]
        ui.slab(x, y, v.cw, v.ch, ui.accent(g.kind), 5, 0.8 * tabFade)
        drawCover(g, x, y, v.cw, v.ch, ui.accent(g.kind), 0.9 * tabFade)
      end
    end
  end
  if selRect then
    local g, x, y = selRect[1], selRect[2], selRect[3]
    local acc = ui.accent(g.kind)
    local cxs, cys = x + v.cw / 2, y + v.ch
    local sc = 1.10 + 0.08 * selPop
    lg.push(); lg.translate(cxs, cys); lg.scale(sc); lg.translate(-cxs, -cys)
    ui.slab(x, y, v.cw, v.ch, acc, 8, 1)
    local dx, dy, dw, dh = drawCover(g, x, y, v.cw, v.ch, acc, 1)
    selFrame(dx, dy, dw, dh, acc, cfg.ui.anim and (0.5 + 0.5 * math.sin(t * 5)) or 0.5)
    lg.pop()
  end
end

-- ---------------------------------------------------------------- vista lista
local function drawList(list, v)
  local th = ui.th
  local n = #list
  local sy = scrollY[tab]
  local r0 = math.max(0, math.floor(sy / v.rowh) - 1)
  for i = r0 + 1, math.min(n, r0 + v.rows + 3) do
    local g = list[i]
    local y = GY0 + 8 + (i - 1) * v.rowh - sy
    if y + v.rowh > GY0 and y < CONTENT_BOT then
      local acc = ui.accent(g.kind)
      local on = (i == sel[tab])
      local o = on and -2 or 0
      if on then ui.plate(14 + o, y + o, 392, v.rowh - 8, acc, { depth = 5, sel = true, glow = 0.14 })
      else ui.plate(14, y, 392, v.rowh - 8, th.line, { depth = 2, alpha = 0.7 }) end
      ui.chip(g.kind == "gc" and "GC" or "WII", 24 + o, y + 8 + o, acc, on and 1 or 0.65)
      ui.text(ui.fit(g.title, fonts.m, 276), 90 + o, y + 6 + o, fonts.m, on and th.text or th.dim, 1)
      if cfg.stat(g.app).fav then ui.icon("star", 394 + o, y + 19 + o, 9, th.fav, 1, true) end
    end
  end
  local g = list[sel[tab]]
  if g then
    local acc = ui.accent(g.kind)
    local bx, by, bw, bh = 432, GY0 + 14, 180, 250
    ui.slab(bx, by, bw, bh, acc, 9, 1)
    local dx, dy, dw, dh = drawCover(g, bx, by, bw, bh, acc, tabFade)
    selFrame(dx, dy, dw, dh, acc, 0.5)
  end
end

local function drawEmpty()
  local th = ui.th
  local acc = tabAcc(tab)
  local cx = W / 2
  local bob = cfg.ui.anim and math.sin(t * 2) * 5 or 0
  ui.cube3d(cx, 150 + bob, 30, t * 1.2, 0.55, acc, 0.9)
  local msg, k, p = "LIBRARY EMPTY", "SELECT", "sync"
  if search[tab] ~= "" then msg, k, p = "NO MATCHES", "B", "back"
  elseif tab == 3 then msg, k, p = "NO FAVORITES", "X", "star"
  elseif tab == 4 then msg, k, p = "NO GAME LAUNCHED YET", "A", "play"
  elseif #all > 0 then msg = "NO GAMES ON " .. (tab == 1 and "GAMECUBE" or "WII") end
  ui.textf(msg, 0, 200, W, "center", fonts.ol, th.text, 0.95)
  local kw = ui.key(k, 0, 0, true)
  local x = cx - (kw + 8 + 26) / 2
  x = x + ui.key(k, x, 262)
  ui.icon(p, x + 8 + 13, 262, 10, th.text, 0.95, false)
  if tab <= 2 and #all == 0 then
    ui.textf("Set the host and sync from the PC", 0, 296, W, "center", fonts.s, th.dim, 1)
  end
end

-- ---------------------------------------------------------------- status LED
local function drawStatusLed(x, y, label, state)
  local col
  if state == "ok" then col = { 0.40, 0.95, 0.50 }
  elseif state == "fail" then col = { 1.00, 0.40, 0.40 }
  elseif state == "syncing" then
    local k = 0.5 + 0.5 * math.sin(t * 8)
    col = { 1.00, 0.85, 0.30 * k + 0.30 }
  else col = { 0.55, 0.55, 0.60 } end
  -- glow
  lg.setColor(col[1], col[2], col[3], 0.30)
  lg.circle("fill", x, y, 7)
  -- core
  lg.setColor(col[1], col[2], col[3], 1)
  lg.circle("fill", x, y, 4)
  -- ring
  lg.setColor(col[1], col[2], col[3], 0.7)
  lg.setLineWidth(1)
  lg.circle("line", x, y, 5)
  -- label
  ui.text(label, x + 16, y - 6, fonts.xs, col, 0.95)
end

-- ---------------------------------------------------------------- header
local function drawHeader(list)
  local th = ui.th
  lg.setColor(th.panel[1], th.panel[2], th.panel[3], 1); lg.rectangle("fill", 0, 0, W, 62)
  for k = 5, 1, -1 do                                  -- bordo inferiore estruso
    local c = ui.mix(th.panel, { 0, 0, 0 }, 1 - k / 5)
    lg.setColor(c[1], c[2], c[3], 1); lg.rectangle("fill", 0, 62 + (5 - k), W, 1)
  end
  local ac = tabAcc(tab)
  lg.setColor(ac[1], ac[2], ac[3], 0.8); lg.rectangle("fill", 0, 61, W, 2)
  local spin = false -- _SPIN_ICON disabled, using logo.png (restore: ui.img("dolphin_icon_spin.png"))
  if spin then
    local bob = cfg.ui.anim and math.sin(t * 2.2) * 2.5 or 0
    lg.setColor(0, 0, 0, 0.35); lg.ellipse("fill", 34, 56, 18 - bob, 3)
    local iw, ih = spin:getDimensions()
    local frames, fw, fh = 1, iw, ih
    if iw > ih and iw % ih == 0 then frames = iw / ih; fw = ih
    elseif ih > iw and ih % iw == 0 then frames = ih / iw; fh = iw
    end
    if not spin_quads then
      spin_quads = {}
      for i = 0, frames - 1 do
        local qx, qy = 0, 0
        if iw > ih then qx = i * fw else qy = i * fh end
        spin_quads[i] = lg.newQuad(qx, qy, fw, fh, iw, ih)
      end
    end
    local frame = math.floor(t * 12) % frames
    local q = frames > 1 and spin_quads[frame] or nil
    lg.setColor(1, 1, 1, 1)
    local sc = 50 / math.max(fw, fh)
    if q then lg.draw(spin, q, 34, 30 + bob, 0, sc, sc, fw/2, fh/2)
    else lg.draw(spin, 34, 30 + bob, 0, sc, sc, fw/2, fh/2) end
  else
    local logo = ui.img("logo.png")
    if logo then
      local bob = cfg.ui.anim and math.sin(t * 2.2) * 2.5 or 0
      lg.setColor(0, 0, 0, 0.35); lg.ellipse("fill", 34, 56, 18 - bob, 3)
      lg.setColor(1, 1, 1, 1); lg.draw(logo, 34, 30 + bob, 0, 50 / logo:getWidth(), 50 / logo:getHeight(), logo:getWidth() / 2, logo:getHeight() / 2)
    end
  end
  local x = 70
  for i = 1, 4 do
    local w = tabW[i]
    local on = (i == tab)
    local c = tabAcc(i)
    local y, h = on and 8 or 17, on and 46 or 38
    local face = ui.mix(th.panel, c, on and 0.55 or 0.12)
    for k = 5, 1, -1 do
      lg.setColor(0, 0, 0, 0.5 - k * 0.07); lg.polygon("fill", x + 12 + k, y + k, x + w + k, y + k, x + w - 12 + k, y + h + k, x + k, y + h + k)
    end
    lg.setColor(face[1], face[2], face[3], 1); lg.polygon("fill", x + 12, y, x + w, y, x + w - 12, y + h, x, y + h)
    local hi = ui.mix(c, { 1, 1, 1 }, 0.5)
    lg.setColor(hi[1], hi[2], hi[3], on and 1 or 0.45); lg.setLineWidth(1.5)
    lg.line(x + 12, y + 1, x + w, y + 1); lg.polygon("line", x + 12, y, x + w, y, x + w - 12, y + h, x, y + h)
    lg.setLineWidth(1)
    local cy = y + h / 2
    local iconx = x + 26
    if i == 1 or i == 2 then
      local im = ui.img(i == 1 and "gc.png" or "wii.png")
      if im then lg.setColor(1, 1, 1, on and 1 or 0.6); lg.draw(im, iconx, cy, 0, 30 / 64, 30 / 64, 32, 32) end
    elseif i == 3 then ui.icon("star", iconx, cy, 11, on and c or th.dim, 1, true)
    else ui.icon("clock", iconx, cy, 11, on and c or th.dim, 1) end
    if on and w > 110 then
      ui.text(TAB_NAMES[i], x + 46, cy - fonts.os:getHeight() / 2, fonts.os, ui.mix(c, { 1, 1, 1 }, 0.7), 1)
    end
    x = x + w - 6
  end

  -- === Server status header (sopra il panel) ===
  ui.textf("SERVER STATUS", 440, 2, 194, "center", fonts.xs, th.dim, 0.9)

  -- === Server status panel con LED ===
  ui.plate(440, 16, 194, 44, th.line, { depth = 2, alpha = 0.75 })
  drawStatusLed(455, 30, "SUNSHINE", health.sunshine)
  drawStatusLed(455, 48, "LIBRARY", sync.on and "syncing" or health.library)

  local sc = (sync.state == "ok" and { 0.4, 0.95, 0.5 }) or (sync.state == "err" and { 1, 0.4, 0.4 }) or th.gc
  ui.cube3d(W - 24, 30, 11, t * (sync.on and 7 or 1.3), 0.55, sc, 0.95)
end

local function ts(g) return g.kind == "gc" and "GAMECUBE" or "WII" end

-- ---------------------------------------------------------------- barra info e footer
local function drawInfo(g)
  local th = ui.th
  local acc = tabAcc(tab)
  ui.plate(8, 352, W - 22, 66, acc, { depth = 5 })
  if search[tab] ~= "" then
    ui.text("SEARCH", 22, 358, fonts.os, acc, 1)
    ui.text(ui.fit("\"" .. search[tab] .. "\"", fonts.l, 500), 22, 380, fonts.l, th.text, 1)
    local n = #getList(tab)
    ui.textf(n .. (n == 1 and " result" or " results"), W - 80, 358, 60, "right", fonts.os, th.dim, 1)
    ui.text("X edit  ·  B clear", W - 200, 388, 180, "right", fonts.s, th.dim, 0.9)
    return
  end
  if not g then return end
  local ga = ui.accent(g.kind)
  local pop = ui.outCubic(infoT)
  ui.text(ui.fit(g.title, fonts.l, 560), 22 + (1 - pop) * 18, 354, fonts.l, th.text, pop)
  local x, y = 22, 390
  x = ui.chip(ts(g), x, y, ga)
  if g.id ~= "" then x = ui.chip(g.id, x, y, th.dim) end
  local s = cfg.stat(g.app)
  x = ui.chip(s.plays .. (s.plays == 1 and " launch" or " launches"), x, y, th.dim)
  x = ui.chip(ago(s.last), x, y, th.dim)
  local ov = cfg.getOver(g.app)
  if ov.res ~= "" or ov.bitrate ~= "" or ov.fps ~= "" then x = ui.chip("PROFILE", x, y, th.fav) end
  if s.fav then ui.icon("star", W - 40, 384, 14, th.fav, 1, true) end
end

local function drawFooterBand()
  local th = ui.th
  lg.setColor(th.panel[1], th.panel[2], th.panel[3], 1); lg.rectangle("fill", 0, 428, W, 52)
  lg.setColor(th.line[1], th.line[2], th.line[3], 0.7); lg.rectangle("fill", 0, 428, W, 2)
end

local function drawToast()
  if toastT.t <= 0 or not toastT.msg then return end
  local th = ui.th
  local e = ui.outBack(math.min(1, (3.2 - toastT.t) * 4))
  local a = math.min(1, toastT.t * 3)
  local col = (toastT.kind == "err" and { 1, 0.4, 0.4 }) or (toastT.kind == "ok" and { 0.4, 0.95, 0.5 }) or th.text
  local f = fonts.s
  local w = math.min(600, f:getWidth(toastT.msg) + 84)
  local x, y = (W - w) / 2, 300 + (1 - e) * 60
  ui.plate(x, y, w, 42, col, { depth = 4, alpha = a })
  ui.icon(toastT.kind == "err" and "close" or (toastT.kind == "ok" and "check" or "info"), x + 26, y + 21, 9, col, a)
  ui.textf(ui.fit(toastT.msg, f, w - 80), x + 48, y + 10, w - 60, "left", f, th.text, a)
end

local function libFooter(g)
  if search[tab] ~= "" then
    ui.footer({
      { k = { "L1", "R1" }, txt = "Tab" },
      { k = { "A" }, txt = "Play" },
      { k = { "X" }, txt = "Edit" },
      { k = { "B" }, txt = "Clear" },
      { k = { "START" }, txt = "Menu" },
    })
    return
  end
  local fav = g and cfg.stat(g.app).fav
  ui.footer({
    { k = { "L1", "R1" }, txt = "Tab" },
    { k = { "A" }, txt = "Play" },
    { k = { "X" }, txt = fav and "Unfav" or "Fav", col = ui.th.fav },
    { k = { "Y" }, txt = "Game" },
    { k = { "SELECT" }, txt = "Sync" },
    { k = { "START" }, txt = "Menu" },
    { k = { "B" }, txt = "Exit" },
  })
end

local function drawLibrary()
  local list = getList(tab)
  local v = V()
  ui.bg(t, cfg.ui.anim)
  if #list == 0 then drawEmpty()
  elseif v.flow then drawFlow(list)
  elseif v.list then drawList(list, v)
  else drawGrid(list, v) end
  drawHeader(list)
  drawInfo(list[sel[tab]])
  drawFooterBand()
  libFooter(list[sel[tab]])
end

-- ---------------------------------------------------------------- menu e schermate modali
local function drawSwitch(x, y, k, acc)
  local th = ui.th
  lg.setColor(0, 0, 0, 0.4); lg.rectangle("fill", x + 2, y - 11, 54, 26, 13, 13)
  local c = ui.mix(th.dim, acc, k)
  lg.setColor(c[1], c[2], c[3], 0.35 + 0.4 * k); lg.rectangle("fill", x, y - 13, 54, 26, 13, 13)
  lg.setColor(c[1], c[2], c[3], 1); lg.setLineWidth(2); lg.rectangle("line", x, y - 13, 54, 26, 13, 13); lg.setLineWidth(1)
  lg.setColor(0, 0, 0, 0.4); lg.circle("fill", x + 14 + 26 * k + 1, y + 2, 10)
  lg.setColor(1, 1, 1, 1); lg.circle("fill", x + 14 + 26 * k, y, 10)
end

local function modalHeader(title, icon, crumb, accentColor)
  local th = ui.th
  local ac = accentColor or th.gc
  lg.setColor(th.panel[1], th.panel[2], th.panel[3], 1); lg.rectangle("fill", 0, 0, W, 62)
  lg.setColor(ac[1], ac[2], ac[3], 0.9); lg.rectangle("fill", 0, 61, W, 2)
  ui.cube3d(34, 31, 13, t * 1.4, 0.55, ac, 1)
  crumb = crumb or ""
  if crumb ~= "" then ui.text(crumb, 62, 6, fonts.xs, th.dim, 1) end
  ui.text(ui.fit(title, fonts.ol, 540), 62, crumb ~= "" and 20 or 14, crumb ~= "" and fonts.om or fonts.ol, th.text, 1)
  if icon then ui.icon(icon, W - 36, 31, 13, th.gc, 1) end
end

local ROWH = 46
local function drawMenu(m)
  if not m then return end
  local th = ui.th
  local acc = m.color or th.gc
  ui.bg(t, cfg.ui.anim)
  local crumb = (#menus > 1) and string.upper(menus[#menus - 1].title) or ""
  modalHeader(string.upper(m.title), m.icon, crumb, acc)

  local nA = m.actions and #m.actions or 0
  local nq = (not m.hero and m.quick) and #m.quick or 0
  local ni = #m.items
  local nTop = nA + nq
  local hasExit = m.exit ~= nil
  local total = nTop + ni + (hasExit and 1 or 0)
  local pulse = cfg.ui.anim and (0.5 + 0.5 * math.sin(t * 5)) or 0.5

  local y = 74

  -- === HERO: 2.5D cover on the left + large PLAY + FAV/INFO side by side ===
  if m.hero and m.actions and nA > 0 then
    local hx, hy = 24, y
    local cw, ch = 100, 140
    local rx = hx + cw + 14
    local rw = W - rx - 24
    local coverGame = m.hero.cover
    local cAcc = ui.accent(coverGame.kind)
    if m.sel == 1 then
      lg.setColor(0.35, 0.90, 0.45, 0.18 * pulse)
      ui.chamfer("fill", hx - 5, hy - 5, cw + 10, ch + 10, 10)
    end
    ui.slab(hx, hy, cw, ch, cAcc, 8, 1)
    drawCover(coverGame, hx, hy, cw, ch, cAcc, 1)
    lg.setColor(cAcc[1], cAcc[2], cAcc[3], 0.9)
    lg.setLineWidth(2)
    ui.chamfer("line", hx + 0.5, hy + 0.5, cw - 1, ch - 1, 8)
    lg.setLineWidth(1)

    local play = m.actions[1]
    local pOn = (m.sel == 1)
    local pO = pOn and -2 or 0
    local pCol = play.color or { 0.35, 0.90, 0.45 }
    if pOn then ui.plate(rx + pO, hy + pO, rw, 56, pCol, { depth = 5, sel = true, glow = 0.20 + 0.10 * pulse })
    else ui.plate(rx, hy, rw, 56, th.line, { depth = 3, alpha = 0.85 }) end
    local pic = pOn and pCol or { pCol[1] * 0.75, pCol[2] * 0.75, pCol[3] * 0.75 }
    ui.icon("play", rx + 32 + pO, hy + 28 + pO, 18, pic, 1)
    ui.text(play.label or "PLAY", rx + 64 + pO, hy + 14 + pO, fonts.ol, pOn and th.text or th.dim, 1)
    ui.textf("Press A to start", rx + pO, hy + 44 + pO, rw, "center", fonts.xs, th.dim, 0.9)

    local by = hy + 56 + 10
    local bh = 44
    local gap = 8
    local bw = (rw - gap) / 2
    for i = 2, math.min(3, nA) do
      local act = m.actions[i]
      local qx = rx + (i - 2) * (bw + gap)
      local on = (m.sel == i)
      local o = on and -2 or 0
      local qcol = act.color or acc
      if on then ui.plate(qx + o, by + o, bw, bh, qcol, { depth = 4, sel = true, glow = 0.15 })
      else ui.plate(qx, by, bw, bh, th.line, { depth = 2, alpha = 0.85 }) end
      local filled = act.t == "tg" and act.get() or false
      local ic = on and qcol or { qcol[1] * 0.80, qcol[2] * 0.80, qcol[3] * 0.80 }
      ui.icon(act.icon or "dot", qx + 26 + o, by + bh / 2 + o, 11, ic, 1, filled)
      ui.text(act.label or "", qx + 46 + o, by + bh / 2 - fonts.os:getHeight() / 2 + o, fonts.os, on and th.text or th.dim, 1)
    end

    y = math.max(hy + ch, by + bh) + 10
  end

  -- === QUICK (only if no hero) ===
  if not m.hero and nq > 0 then
    local qw = math.floor((W - 48 - 12) / 2)
    local qh = 62
    for i, q in ipairs(m.quick) do
      local qx = 16 + (i - 1) * (qw + 12)
      local on = (m.sel == i)
      local o = on and -2 or 0
      local qcol = q.color or acc
      if on then ui.plate(qx + o, y + o, qw, qh, qcol, { depth = 5, sel = true, glow = 0.14 + 0.10 * pulse })
      else ui.plate(qx, y, qw, qh, th.line, { depth = 3, alpha = 0.85 }) end
      local cx = qx + qw / 2 + o
      local filled = q.t == "tg" and q.get() or false
      local ic = on and qcol or { qcol[1] * 0.80, qcol[2] * 0.80, qcol[3] * 0.80 }
      ui.icon(q.icon, cx, y + 18 + o, 14, ic, 1, filled)
      ui.textf(q.label, qx + o, y + 36 + o, qw, "center", fonts.om, on and th.text or th.dim, 1)
    end
    y = y + 62 + 8
    lg.setColor(th.line[1], th.line[2], th.line[3], 0.4)
    lg.rectangle("fill", 24, y, W - 48, 1)
    y = y + 8
  end

  -- === ITEMS LIST ===
  local rowH = (m.hero and 40) or ROWH
  m.vtop = m.vtop or m.top or 0
  m.vtop = m.vtop + ((m.top or 0) - m.vtop) * math.min(1, dtG * 14)
  local list_y0 = y
  local visible_rows = math.max(1, math.floor((330 - list_y0) / rowH))

  for i = 1, ni do
    local it = m.items[i]
    local item_y = list_y0 + (i - 1 - m.vtop) * rowH
    if it.t == "sep" then
      if item_y > 62 and item_y < 352 then
        lg.setColor(th.line[1], th.line[2], th.line[3], 0.35)
        lg.rectangle("fill", 32, item_y + rowH / 2, W - 64, 1)
      end
    elseif item_y > 62 - rowH and item_y + rowH < 352 + rowH then
      local on = (m.sel == nTop + i)
      local o = on and -2 or 0
      if on then ui.plate(16 + o, item_y + o, W - 48, rowH - 6, acc, { depth = 5, sel = true, glow = 0.10 + 0.08 * pulse })
      else ui.plate(16, item_y, W - 48, rowH - 6, th.line, { depth = 2, alpha = 0.75 }) end
      local cy = item_y + (rowH - 6) / 2 + o
      local isAdvanced = (it.label == "Advanced Options")
      local baseCol = itemColor(it)
      local iconCol
      if isAdvanced then iconCol = th.dim
      elseif on then iconCol = baseCol
      else iconCol = { baseCol[1] * 0.80, baseCol[2] * 0.80, baseCol[3] * 0.80 } end
      local textCol = isAdvanced and th.dim or (on and th.text or th.dim)
      ui.icon(it.icon or "dot", 46 + o, cy, 11, iconCol, 1, false)
      ui.text(it.label, 74 + o, cy - fonts.om:getHeight() / 2, fonts.om, textCol, 1)
      local rx = W - 48 - 18 + o
      if it.t == "sub" then
        local bc = itemColor(it)
        lg.setColor(bc[1], bc[2], bc[3], on and 1 or 0.65)
        lg.rectangle("fill", 18, item_y + 6, 3, rowH - 20, 2, 2)
        local nud = (on and cfg.ui.anim) and math.sin(t * 8) * 2 or 0
        ui.icon("chevron", rx - 4 + nud, cy, 9, on and acc or th.dim, 1)
      elseif it.t == "ch" then
        local cur = it.get()
        local vt = tostring(cur)
        for _, op in ipairs(it.opts) do if op.v == cur then vt = op.l end end
        ui.textf(ui.fit(vt, fonts.m, 190), rx - 214, cy - fonts.m:getHeight() / 2, 190, "center", fonts.m, on and acc or th.text, 1)
        if on then
          local nud = cfg.ui.anim and math.sin(t * 8) * 2 or 0
          ui.icon("back", rx - 226 - nud, cy, 7, acc, 1)
          ui.icon("play", rx - 2 + nud, cy, 7, acc, 1)
        end
      elseif it.t == "tg" then
        local target = it.get() and 1 or 0
        it._k = ui.lerp(it._k or target, target, math.min(1, dtG * 14))
        drawSwitch(rx - 56, cy, it._k, acc)
      elseif it.t == "txt" then
        local vt = it.get()
        if vt == "" then vt = "-" end
        ui.textf(ui.fit(vt, fonts.m, 230), rx - 250, cy - fonts.m:getHeight() / 2, 230, "right", fonts.m, on and acc or th.text, 1)
      end
    end
  end

  -- scrollbar items
  local scroll_n = 0
  for _, it in ipairs(m.items) do if it.t ~= "sep" then scroll_n = scroll_n + 1 end end
  if scroll_n > visible_rows then
    local bh = visible_rows * rowH - 10
    lg.setColor(1, 1, 1, 0.10); lg.rectangle("fill", W - 20, list_y0, 6, bh, 3, 3)
    local th_ = math.max(24, bh * visible_rows / scroll_n)
    lg.setColor(acc[1], acc[2], acc[3], 0.9)
    lg.rectangle("fill", W - 20, list_y0 + (bh - th_) * (m.vtop / math.max(1, scroll_n - visible_rows)), 6, th_, 3, 3)
  end

  -- EXIT
  if hasExit then
    local exit_col = { 1.0, 0.45, 0.45 }
    local exit_y = 302
    lg.setColor(th.line[1], th.line[2], th.line[3], 0.4)
    lg.rectangle("fill", 24, exit_y - 6, W - 48, 1)
    local on = (m.sel == total)
    local o = on and -2 or 0
    if on then ui.plate(16 + o, exit_y + o, W - 48, 42, exit_col, { depth = 4, sel = true, glow = 0.20 + 0.10 * pulse })
    else ui.plate(16, exit_y, W - 48, 42, th.line, { depth = 2, alpha = 0.75 }) end
    ui.icon("close", 46 + o, exit_y + 21 + o, 11, on and exit_col or th.dim, 1)
    ui.text("Exit", 74 + o, exit_y + 21 - fonts.om:getHeight() / 2 + o, fonts.om, on and th.text or th.dim, 1)
  end

  -- description panel
  ui.plate(8, 352, W - 22, 66, th.line, { depth = 5 })
  local selItem = curItem(m)
  if selItem and selItem.desc then
    ui.icon("info", 34, 385, 10, acc, 0.95)
    lg.setFont(fonts.s); lg.setColor(th.text[1], th.text[2], th.text[3], 0.95)
    lg.printf(selItem.desc, 56, 360, W - 100, "left")
  end

  drawFooterBand()
  local f = { { k = { "DPADV" }, txt = "Move" } }
  local cur = selItem
  if cur and (cur.t == "ch" or cur.t == "tg") then f[#f + 1] = { k = { "DPADH" }, txt = "Change" } end
  f[#f + 1] = { k = { "A" }, txt = (cur and cur.t == "act") and "Select" or "Confirm" }
  f[#f + 1] = { k = { "M" }, txt = "Guide" }
  f[#f + 1] = { k = { "B" }, txt = "Back" }
  f[#f + 1] = { k = { "START" }, txt = "Close" }
  ui.footer(f)
end



-- ===================================================================== GUIDE PANEL (M)
guide = nil

function openGuide(item, title, icon)
  -- Se l'item e' un submenu, cattura i suoi sotto-item da mostrare
  local submenu = nil
  if item and item.t == "sub" and type(item.menu) == "function" then
    local ok, sub = pcall(item.menu)
    if ok and sub and sub.items then
      submenu = {}
      for _, si in ipairs(sub.items) do
        if si.t ~= "sep" then submenu[#submenu + 1] = si end
      end
    end
  end
  guide = {
    item = item,
    title = title or (item and item.label) or "Guide",
    icon = icon or (item and item.icon) or "info",
    intro = (item and item.guide and item.guide.intro) or (item and item.desc) or "No description.",
    values = (item and item.guide and item.guide.values) or nil,
    opts = (item and item.opts) or nil,
    submenu = submenu,
    top = 0,
    t = 0,
  }
end

function guidePress(b)
  if not guide then return end
  if b == "b" or b == "start" then guide = nil; return end
  local nvals = 0
  if guide.opts then nvals = #guide.opts
  elseif guide.submenu then nvals = #guide.submenu end
  local visible = 5
  local maxTop = math.max(0, nvals - visible)
  if b == "up" then guide.top = math.max(0, guide.top - 1)
  elseif b == "down" then guide.top = math.min(maxTop, guide.top + 1)
  elseif b == "l2" then guide.top = math.max(0, guide.top - visible)
  elseif b == "r2" then guide.top = math.min(maxTop, guide.top + visible) end
end

function drawGuide()
  if not guide then return end
  local th = ui.th
  local acc = th.gc
  lg.setColor(0, 0, 0, 0.85); lg.rectangle("fill", 0, 0, W, H)
  local e = ui.outBack(math.min(1, guide.t * 5))
  lg.push(); lg.translate(W / 2, 220); lg.scale(0.90 + 0.10 * e); lg.translate(-W / 2, -220)

  ui.plate(24, 24, W - 48, 56, acc, { depth = 5 })
  ui.icon(guide.icon, 58, 52, 14, acc, 1)
  ui.text(ui.fit(guide.title, fonts.ol, W - 130), 88, 36, fonts.ol, th.text, 1)

  ui.plate(24, 92, W - 48, 80, th.line, { depth = 3 })
  lg.setFont(fonts.s); lg.setColor(th.text[1], th.text[2], th.text[3], 0.95)
  lg.printf(guide.intro, 42, 104, W - 84, "left")

  ui.plate(24, 184, W - 48, 220, th.line, { depth = 3 })
  if guide.submenu and #guide.submenu > 0 then
    -- Mostra i sotto-item del submenu come lista con icone
    local visible = 5
    local y0 = 196
    local rowH = 40
    for idx = guide.top + 1, math.min(#guide.submenu, guide.top + visible) do
      local sub = guide.submenu[idx]
      local y = y0 + (idx - guide.top - 1) * rowH
      ui.icon(sub.icon or "dot", 52, y + rowH / 2 - 2, 9, th.dim, 1)
      lg.setFont(fonts.os); lg.setColor(th.text[1], th.text[2], th.text[3], 1)
      lg.print(ui.fit(sub.label or "", fonts.os, 150), 70, y + 2)
      if sub.desc then
        lg.setFont(fonts.xs); lg.setColor(th.dim[1], th.dim[2], th.dim[3], 0.95)
        lg.printf(ui.fit(sub.desc, fonts.xs, W - 320), 240, y + 6, W - 330, "left")
      end
    end
    if #guide.submenu > visible then
      local bh = 220 - 16
      local th_ = math.max(24, bh * visible / #guide.submenu)
      lg.setColor(1, 1, 1, 0.10); lg.rectangle("fill", W - 32, 196, 5, bh, 2, 2)
      lg.setColor(acc[1], acc[2], acc[3], 0.9)
      lg.rectangle("fill", W - 32, 196 + (bh - th_) * (guide.top / math.max(1, #guide.submenu - visible)), 5, th_, 2, 2)
    end
  elseif guide.opts and #guide.opts > 0 then
    local cur = guide.item and guide.item.get and guide.item.get() or nil
    local visible = 5
    local y0 = 196
    local rowH = 40
    for idx = guide.top + 1, math.min(#guide.opts, guide.top + visible) do
      local opt = guide.opts[idx]
      local y = y0 + (idx - guide.top - 1) * rowH
      local meta = guide.values and guide.values[opt.v] or nil
      local isCurrent = (cur ~= nil and opt.v == cur)
      if isCurrent then
        lg.setColor(acc[1], acc[2], acc[3], 0.18)
        ui.chamfer("fill", 38, y - 2, W - 76, rowH - 4, 5)
      end
      local mx, my = 52, y + rowH / 2 - 2
      if meta and meta.recommended then
        lg.setColor(0.4, 0.95, 0.5, 1)
        lg.circle("fill", mx, my, 7)
        lg.setColor(0, 0, 0, 1); lg.setLineWidth(2)
        lg.line(mx - 3, my, mx - 1, my + 3, mx + 4, my - 3)
        lg.setLineWidth(1)
      elseif meta and meta.warning then
        lg.setColor(1, 0.85, 0.30, 1)
        lg.polygon("fill", mx, my - 8, mx - 8, my + 5, mx + 8, my + 5)
        lg.setColor(0, 0, 0, 1); lg.setLineWidth(1.5)
        lg.line(mx, my - 4, mx, my + 1); lg.circle("fill", mx, my + 3.5, 1.2)
        lg.setLineWidth(1)
      else
        local pIcon = (guide.item and guide.item.icon) or "dot"
        ui.icon(pIcon, mx, my, 7, th.dim, 0.75)
      end
      lg.setFont(fonts.os); lg.setColor(isCurrent and acc or th.text, 1)
      lg.print(ui.fit(opt.l, fonts.os, 150), mx + 18, y + 2)
      if meta and meta.desc then
        lg.setFont(fonts.xs); lg.setColor(th.dim[1], th.dim[2], th.dim[3], 0.95)
        lg.printf(ui.fit(meta.desc, fonts.xs, W - 320), 240, y + 4, W - 330, "left")
      end
      if meta and meta.warn then
        lg.setFont(fonts.xs); lg.setColor(1, 0.85, 0.30, 0.95)
        lg.printf("! " .. meta.warn, 240, y + 20, W - 330, "left")
      end
    end
    if #guide.opts > visible then
      local bh = 220 - 16
      local th_ = math.max(24, bh * visible / #guide.opts)
      lg.setColor(1, 1, 1, 0.10); lg.rectangle("fill", W - 32, 196, 5, bh, 2, 2)
      lg.setColor(acc[1], acc[2], acc[3], 0.9)
      lg.rectangle("fill", W - 32, 196 + (bh - th_) * (guide.top / math.max(1, #guide.opts - visible)), 5, th_, 2, 2)
    end
  else
    lg.setFont(fonts.s); lg.setColor(th.dim[1], th.dim[2], th.dim[3], 1)
    lg.printf("This option has no selectable values or nested entries.", 42, 270, W - 84, "center")
  end

  lg.pop()
  drawFooterBand()
  ui.footer({
    { k = { "DPADV" }, txt = "Scroll" },
    { k = { "B" }, txt = "Close" },
  })
end

function drawOverlay()
  if not overlay then return end
  local th = ui.th
  local acc = overlay.color or th.gc
  lg.setColor(0, 0, 0, 0.72); lg.rectangle("fill", 0, 0, W, H)
  local e = ui.outBack(math.min(1, overlay.t * 5))
  lg.push(); lg.translate(W / 2, 220); lg.scale(0.88 + 0.12 * e); lg.translate(-W / 2, -220)

  ui.plate(40, 60, W - 80, 360, acc, { depth = 8 })

  -- Header: icona + titolo MAIUSCOLO + divisore
  ui.icon(overlay.icon or "info", 62, 82, 11, acc, 1)
  ui.text(ui.fit(string.upper(overlay.title), fonts.om, W - 140), 84, 72, fonts.om, acc, 1)
  lg.setColor(acc[1], acc[2], acc[3], 0.35)
  lg.rectangle("fill", 56, 98, W - 112, 1)

  -- Intro compatta (42px)
  local y0 = 108
  if overlay.intro then
    local introH = 42
    ui.plate(56, 106, W - 112, introH, th.line, { depth = 2, alpha = 0.7 })
    ui.icon("info", 72, 122, 8, acc, 0.9)
    lg.setFont(fonts.xs); lg.setColor(th.text[1], th.text[2], th.text[3], 0.92)
    lg.printf(overlay.intro, 90, 110, W - 156, "left")
    y0 = 106 + introH + 4
  end

  -- === itemH DINAMICO: fit tutte le voci se possibile ===
  local n = #overlay.items
  local availH = 415 - y0
  local itemH = math.floor(availH / math.max(1, n))
  if itemH > 50 then itemH = 50 end
  if itemH < 38 then itemH = 38 end
  local visible = math.floor(availH / itemH)
  if visible < 1 then visible = 1 end

  -- Scroll: mostra l'item selezionato (mantieni in view senza scrollare troppo)
  local visStart = 0
  if n > visible then
    if overlay.sel > visible then visStart = overlay.sel - visible end
    if visStart > n - visible then visStart = n - visible end
    if visStart < 0 then visStart = 0 end
  end

  for i = visStart + 1, math.min(n, visStart + visible) do
    local it = overlay.items[i]
    local y = y0 + (i - visStart - 1) * itemH
    local on = (i == overlay.sel)
    local o = on and -2 or 0
    if on then ui.plate(56 + o, y + o, W - 112, itemH - 4, acc, { depth = 3, sel = true, glow = 0.15 })
    else ui.plate(56, y, W - 112, itemH - 4, th.line, { depth = 1, alpha = 0.55 }) end

    local cy = y + 13 + o
    local baseCol = itemColor(it)
    local ic = on and baseCol or { baseCol[1] * 0.80, baseCol[2] * 0.80, baseCol[3] * 0.80 }
    ui.icon(it.icon or "dot", 82 + o, cy, 9, ic, 1)

    -- Label + valore sulla stessa riga
    ui.text(it.label or "", 106 + o, cy - fonts.os:getHeight() / 2, fonts.os, on and th.text or th.dim, 1)
    local rx = W - 112 - 8 + o
    if it.t == "ch" then
      local cur = it.get()
      local vt = tostring(cur)
      for _, op in ipairs(it.opts) do if op.v == cur then vt = op.l end end
      ui.textf(ui.fit(vt, fonts.s, 180), rx - 180, cy - fonts.s:getHeight() / 2, 180, "right", fonts.s, on and acc or th.text, 1)
    elseif it.t == "tg" then
      local target = it.get() and 1 or 0
      it._k = ui.lerp(it._k or target, target, math.min(1, dtG * 14))
      drawSwitch(rx - 60, cy, it._k, acc)
    elseif it.t == "txt" then
      local vt = it.get()
      if vt == "" then vt = "-" end
      ui.textf(ui.fit(vt, fonts.s, 200), rx - 200, cy - fonts.s:getHeight() / 2, 200, "right", fonts.s, on and acc or th.text, 1)
    end

    -- Desc inline su una riga sola
    if it.desc then
      lg.setFont(fonts.xs); lg.setColor(th.dim[1], th.dim[2], th.dim[3], on and 0.95 or 0.72)
      lg.printf(ui.fit(it.desc, fonts.xs, W - 180), 106 + o, y + 24 + o, W - 180, "left")
    end
  end

  -- Scrollbar se serve
  if n > visible then
    local bh = visible * itemH - 6
    lg.setColor(1, 1, 1, 0.10); lg.rectangle("fill", W - 26, y0, 5, bh, 2, 2)
    local th_ = math.max(20, bh * visible / n)
    lg.setColor(acc[1], acc[2], acc[3], 0.9)
    lg.rectangle("fill", W - 26, y0 + (bh - th_) * (visStart / math.max(1, n - visible)), 5, th_, 2, 2)
  end

  lg.pop()

  ui.footer({
    { k = { "DPADV" }, txt = "Move" },
    { k = { "A" }, txt = "Select" },
    { k = { "M" }, txt = "Guide" },
    { k = { "B" }, txt = "Back" },
  })
end

function overlayPress(b)
  if not overlay then return end
  local ov = overlay
  local n = #ov.items
  local it = ov.items[ov.sel]
  if b == "guide" then
    if it and openGuide then openGuide(it, it.label, it.icon) end
    return
  end
  if b == "up" then ov.sel = math.max(1, ov.sel - 1)
  elseif b == "down" then ov.sel = math.min(n, ov.sel + 1)
  elseif b == "left" then
    if it.t == "tg" then it.set(not it.get())
    elseif it.t == "ch" then chStep(it, -1) end
  elseif b == "right" then
    if it.t == "tg" then it.set(not it.get())
    elseif it.t == "ch" then chStep(it, 1) end
  elseif b == "a" then
    if it.t == "act" then it.fn()
    elseif it.t == "tg" then it.set(not it.get())
    elseif it.t == "ch" then chStep(it, 1)
    elseif it.t == "txt" then openKb(it) end
  elseif b == "b" or b == "start" then overlay = nil
  end
end

local LH = 22
local function drawView()
  local th = ui.th
  local acc = th.gc
  ui.bg(t, cfg.ui.anim)
  modalHeader(view.title, view.icon)
  local y0 = view.pair and 150 or 76
  if view.pair then
    ui.plate(150, 74, 340, 64, acc, { depth = 5 })
    if view.pin then
      ui.textf(view.pin, 150, 78, 340, "center", fonts.oxl, acc, 1)
    else
      ui.textf("waiting for the PIN...", 150, 92, 340, "center", fonts.om, th.dim, 0.6 + 0.4 * math.sin(t * 4))
    end
  end
  local vis = viewVis()
  local f = fonts.s
  for i = 1, vis do
    local l = view.flat[view.top + i]
    if not l then break end
    local col = (l[2] == "ok" and { 0.4, 0.95, 0.5 }) or (l[2] == "err" and { 1, 0.4, 0.4 }) or (l[2] == "hl" and acc) or th.text
    ui.text(l[1], 30, y0 + (i - 1) * LH, l[2] == "hl" and fonts.om or f, col, l[2] == "n" and 0.92 or 1)
  end
  local n = #view.flat
  if n > vis then
    local bh = vis * LH
    lg.setColor(1, 1, 1, 0.10); lg.rectangle("fill", W - 20, y0, 6, bh, 3, 3)
    local th_ = math.max(20, bh * vis / n)
    lg.setColor(acc[1], acc[2], acc[3], 0.9)
    lg.rectangle("fill", W - 20, y0 + (bh - th_) * (view.top / (n - vis)), 6, th_, 3, 3)
  end
  if view.customDraw then view.customDraw() end
  drawFooterBand()
  ui.footer({ { k = { "DPADV" }, p = "updown" }, { k = { "L2", "R2" }, p = "page" }, { k = { "B" }, p = "back" } })
end

local function drawDlg()
  local th = ui.th
  local acc = th.gc
  lg.setColor(0, 0, 0, 0.72); lg.rectangle("fill", 0, 0, W, H)
  local e = ui.outBack(math.min(1, dlgT * 5))
  lg.push(); lg.translate(W / 2, 230); lg.scale(0.85 + 0.15 * e); lg.translate(-W / 2, -230)
  ui.plate(50, 120, W - 100, 220, acc, { depth = 8 })
  ui.cube3d(92, 166, 16, t * 1.6, 0.55, acc, 1)
  ui.text(dlg.title, 130, 148, fonts.ol, acc, 1)
  lg.setFont(fonts.m); lg.setColor(th.text[1], th.text[2], th.text[3], 1)
  lg.printf(dlg.text, 78, 204, W - 156, "left")
  ui.footer({ { k = { "A" }, p = "check" }, { k = { "B" }, p = "close" } }, 308)
  lg.pop()
end

local KEYH, KGAP = 50, 5
local function kbTokW2(tok) return (#tok > 1) and 92 or 52 end
local function drawKb()
  local th = ui.th
  local acc = th.gc
  ui.bg(t, cfg.ui.anim)
  modalHeader(kb.title, "keyboard")
  ui.plate(30, 72, W - 60, 52, acc, { depth = 5, face = ui.mix(th.panel, { 0, 0, 0 }, 0.4) })
  local cursor = (math.floor(t * 2) % 2 == 0) and "_" or " "
  ui.text(ui.fit(kb.value .. cursor, fonts.l, W - 120), 48, 80, fonts.l, th.text, 1)
  local y = 138
  for r, row in ipairs(kb.rows) do
    local total = 0
    for _, tok in ipairs(row) do total = total + kbTokW2(tok) + KGAP end
    local x = (W - total + KGAP) / 2
    for c, tok in ipairs(row) do
      local w = kbTokW2(tok)
      local on = (r == kb.r and c == kb.c)
      if on then ui.plate(x - 1, y - 2, w, KEYH - 6, acc, { depth = 4, sel = true, glow = 0.30 })
      else ui.plate(x, y, w, KEYH - 6, th.line, { depth = 3, alpha = 0.85 }) end
      local cx, cy = x + w / 2 + (on and -1 or 0), y + (KEYH - 6) / 2 + (on and -2 or 0)
      if tok == "DEL" then ui.icon("back", cx, cy, 11, on and acc or th.text, 1)
      elseif tok == "OK" then ui.icon("check", cx, cy, 11, on and acc or th.text, 1)
      elseif tok == "SPC" then
        lg.setColor(th.text[1], th.text[2], th.text[3], on and 1 or 0.85); lg.setLineWidth(2.4)
        lg.line(cx - 22, cy - 5, cx - 22, cy + 5, cx + 22, cy + 5, cx + 22, cy - 5); lg.setLineWidth(1)
      else ui.textf(tok, x, cy - fonts.om:getHeight() / 2, w, "center", fonts.om, on and acc or th.text, 1) end
      x = x + w + KGAP
    end
    y = y + KEYH + 2
  end
  drawFooterBand()
  ui.footer({ { k = { "DPAD" }, p = "updown" }, { k = { "A" }, p = "check" }, { k = { "X" }, p = "back" },
    { k = { "START" }, p = "menu" }, { k = { "B" }, p = "close" } })
end

-- ---------------------------------------------------------------- lancio gioco
local function drawLaunch()
  local th = ui.th
  local p = launching.t / LAUNCH_T
  local reveal = ui.outCubic(launching.reveal or 1)
  local e = (launching.phase == "ping") and reveal or ui.outCubic(math.min(1, p * 1.6))
  lg.setColor(0, 0, 0, 0.94 * e); lg.rectangle("fill", 0, 0, W, H)
  local acc = ui.accent(launching.g.kind)
  for i = 1, 4 do
    lg.setColor(acc[1], acc[2], acc[3], 0.06 * e); lg.circle("fill", W / 2, 215, 40 + i * 30 + math.sin(t * 6 + i) * 5)
  end
  ui.cube3d(W / 2, 215, 62 * ui.outBack(math.min(1, p * 2)), t * 5, 0.55, acc, 1)
  if launching.phase == "ping" then
    ui.textf("CHECKING PC...", 0, 320, W, "center", fonts.ol, th.text, e * (0.7 + 0.3 * math.sin(t * 9)))
    ui.textf(ui.fit(launching.host or "", fonts.m, 560), 40, 364, W - 80, "center", fonts.m, acc, e)
    local sp = (t * 3) % (math.pi * 2)
    lg.setColor(acc[1], acc[2], acc[3], e); lg.setLineWidth(4)
    lg.arc("line", "open", W / 2, 414, 12, sp, sp + math.pi * 1.5, 24)
    lg.setLineWidth(1)
  else
    ui.textf("CONNECTING TO STREAM", 0, 320, W, "center", fonts.ol, th.text, e * (0.7 + 0.3 * math.sin(t * 9)))
    ui.textf(ui.fit(launching.g.title, fonts.m, 560), 40, 364, W - 80, "center", fonts.m, acc, e)
    local bw = 300
    lg.setColor(1, 1, 1, 0.15 * e); lg.rectangle("fill", (W - bw) / 2, 410, bw, 8, 4, 4)
    lg.setColor(acc[1], acc[2], acc[3], e); lg.rectangle("fill", (W - bw) / 2, 410, bw * math.min(1, p), 8, 4, 4)
  end
end

local function drawScene()
  if kb or view or overlay or guide or #menus > 0 then
    local e = cfg.ui.anim and ui.outCubic(math.min(1, modalT / 0.28)) or 1
    lg.push(); lg.translate((1 - e) * 46, 0)
    if kb then drawKb() elseif view then drawView() elseif controls.active() then controls.draw(t) elseif guide then if menus[#menus] then drawMenu(menus[#menus]) else ui.bg(t, cfg.ui.anim) end; if overlay then drawOverlay() end; drawGuide() elseif overlay then if menus[#menus] then drawMenu(menus[#menus]) else ui.bg(t, cfg.ui.anim) end; drawOverlay() else drawMenu(menus[#menus]) end
    lg.pop()
    if e < 1 then lg.setColor(0, 0, 0, (1 - e) * 0.55); lg.rectangle("fill", 0, 0, W, H) end
  else
    drawLibrary()
  end
  if dlg then drawDlg() end
  drawToast()
  if launching then drawLaunch() end
  ui.vignette()
  if cfg.ui.scan then ui.scanlines() end
end

function love.draw()
  local sw, sh = lg.getDimensions()
  local s = math.min(sw / W, sh / H)
  local booting = bootT < boot.dur
  if booting then boot.render(bootT) end
  lg.clear(0, 0, 0, 1)
  lg.push()
  lg.translate((sw - W * s) / 2, (sh - H * s) / 2)
  lg.scale(s)
  lg.setLineWidth(1)
  local ga = 1
  if booting then ga = ui.clamp((boot.dur - bootT) / 0.5, 0, 1) end
  if not booting or ga < 1 then drawScene() end
  if booting then boot.blit(bootT, ga) end
  lg.pop()
  if cfg.ui.eco then love.timer.sleep(0.015) end
end
