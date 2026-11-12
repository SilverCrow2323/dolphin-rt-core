-- ui/screens/stream_library.lua — Rt:Stream: games hosted on the PC, played over Moonlight.
-- Tabs (Library / Favourites / Recent), three views (Flow 2.5D / Grid / List),
-- portal + Sunshine status LEDs, and a launch overlay with a pre-flight check.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local Notify   = require("ui.notify")
local Settings = require("core.settings")
local Stream   = require("core.stream")
local SL       = require("core.stream_lib")
local lg       = love.graphics

local S = {}
local TABS    = { "LIBRARY", "FAVOURITES", "RECENT" }
local VIEWS   = { "FLOW", "GRID", "LIST" }
local FILTERS = { "ALL", "GAMECUBE", "WII" }
local SORTS   = { "A-Z", "RECENT", "MOST PLAYED" }
local GRID = { cols = 5, cw = 82, ch = 112, cellw = 120, rowh = 136, x0 = 20, y0 = 116, rows = 2 }
local FW, FH, FBASE = 126, 176, 330

local tab, view, filter, sort = 1, 1, 1, 1
local sel, scroll = { 1, 1, 1 }, { 0, 0, 0 }
local flowPos, t, health_t = 1, 0, 0
local covers, ncovers = {}, 0
local cache, dirty = {}, true
local launching
S.list = K.List(K.MARGIN, 114, K.W - K.MARGIN * 2 - 14, 270, 40)

local function acc_of(g) return g.kind == "wii" and K.ACC.wii or K.ACC.gc end

-- ── data ────────────────────────────────────────────────────
local function build(i)
  if dirty then cache = {}; dirty = false end
  if cache[i] then return cache[i] end
  local out = {}
  for _, g in ipairs(Stream.games) do
    local s = Stream.stat(g.app)
    local ok = (i == 1) or (i == 2 and s.fav) or (i == 3 and s.plays > 0)
    if ok and filter == 2 then ok = g.kind == "gc" elseif ok and filter == 3 then ok = g.kind == "wii" end
    if ok then out[#out + 1] = g end
  end
  local mode = (i == 3) and 2 or sort
  table.sort(out, function(a, b)
    local sa, sb = Stream.stat(a.app), Stream.stat(b.app)
    if mode == 2 and sa.last ~= sb.last then return sa.last > sb.last end
    if mode == 3 and sa.plays ~= sb.plays then return sa.plays > sb.plays end
    return a.title:lower() < b.title:lower()
  end)
  cache[i] = out
  sel[i] = math.max(1, math.min(sel[i], math.max(1, #out)))
  return out
end
local function cur_list() return build(tab) end
local function cur() return cur_list()[sel[tab]] end
local function invalidate() dirty = true end

local function load_cover(g)
  if not g.cover then return nil end
  local c = covers[g.cover]
  if c == nil then
    if ncovers > 36 then covers, ncovers = {}, 0 end       -- 1 GB device: keep the cache small
    c = false
    local d = Stream.read(Stream.DIR .. "/covers/" .. g.cover)
    if d then
      local ok, img = pcall(function() return lg.newImage(love.filesystem.newFileData(d, g.cover)) end)
      if ok and img then img:setFilter("linear", "linear"); c = img end
    end
    covers[g.cover] = c; ncovers = ncovers + 1
  end
  return c or nil
end

local function sync_list_widget()
  local l = cur_list()
  local items = {}
  for i, g in ipairs(l) do items[i] = g end
  S.list:set(items, true)
  S.list.sel = sel[tab]; S.list:_aim(true)
end

local function reload()
  Stream.reload(); invalidate(); covers, ncovers = {}, 0
  for i = 1, 3 do sel[i] = 1; scroll[i] = 0 end
  flowPos = 1; sync_list_widget()
end

-- ── lifecycle ───────────────────────────────────────────────
function S.enter(params)
  K.set_accent("gc"); t = 0
  Stream.init()
  view = tonumber(Settings.get("stream_view")) or 1
  if view < 1 or view > 3 then view = 1 end
  invalidate(); sync_list_widget(); flowPos = sel[tab]
  Stream.check_health(); health_t = 0
  launching = nil
  local r = Stream.last_result()
  if r then
    local rc, dur = tonumber(r:match("rc=(%d+)")), tonumber(r:match("dur=(%d+)"))
    local msg
    if rc and rc ~= 0 and r:find("missing") then msg = "Moonlight problem: " .. r:gsub("^rc=%d+%s*", "")
    elseif rc and rc ~= 0 then msg = "Stream ended with an error (code " .. rc .. "). See Stream settings > Diagnostics."
    else msg = "Stream ended after " .. (dur or 0) .. " s. Is the PC awake and Sunshine running?" end
    Notify.show("warning", msg, 5)
  end
  if S.reload_pending then S.reload_pending = false; reload() end
end
function S.leave() covers, ncovers = {}, 0 end

function S.update(dt)
  t = t + dt
  S.list:update(dt)
  flowPos = flowPos + (sel[tab] - flowPos) * (1 - math.exp(-dt * 12))
  if math.abs(flowPos - sel[tab]) < 0.002 then flowPos = sel[tab] end
  local rows = math.ceil(#cur_list() / GRID.cols)
  local row = math.floor((sel[tab] - 1) / GRID.cols)
  local want = math.max(0, math.min(math.max(0, rows - GRID.rows), row - (GRID.rows - 1) / 2 + 0.5)) * GRID.rowh
  scroll[tab] = scroll[tab] + (want - scroll[tab]) * (1 - math.exp(-dt * 12))
  Stream.poll_health()
  health_t = health_t + dt
  if health_t > 30 and not launching then health_t = 0; Stream.check_health() end

  if launching then
    launching.t = launching.t + dt
    if launching.phase == "check" then
      local r = Stream.read(Stream.DIR .. "/h_launch.done")
      if launching.t > 0.5 and r then
        if r:match("^OK") then launching.phase = "go"; launching.t = 0
        else launching.phase = "fail" end
      elseif launching.t > 9 then launching.phase = "fail" end
    elseif launching.phase == "go" and launching.t > 0.9 then
      local ok, err = Stream.request_launch(launching.g, "stream_library")
      if ok then love.timer.sleep(0.35); love.event.quit()
      else Notify.show("error", tostring(err)); launching = nil end
    end
  end
end

-- ── input ───────────────────────────────────────────────────
local function move(d)
  local n = #cur_list(); if n == 0 then return end
  local i = sel[tab] + d
  if i < 1 then i = 1 elseif i > n then i = n end
  if i ~= sel[tab] then sel[tab] = i; S.list.sel = i; S.list:_aim(); SFX.play("menu_move") end
end

local function start_launch(g)
  if not Stream.configured() then Notify.show("warning", "Set the PC address first (START)"); return end
  launching = { g = g, t = 0, phase = "check" }
  os.remove(Stream.DIR .. "/h_launch.done")
  Stream.spawn("health.sh", "https://" .. Stream.s.HOST .. ":47989/serverinfo", Stream.DIR .. "/h_launch.done")
  SFX.play("menu_select")
end

function S.pad(b)
  if launching then
    if b == "B" then launching = nil
    elseif b == "A" and launching.phase == "fail" then launching.phase = "go"; launching.t = 0 end   -- try anyway
    return
  end
  local g = cur()
  local step = (view == 2) and GRID.cols or 1
  if     b == "LEFT"  then move(view == 3 and -5 or -1)
  elseif b == "RIGHT" then move(view == 3 and 5 or 1)
  elseif b == "UP"    then move(view == 1 and -1 or -step)
  elseif b == "DOWN"  then move(view == 1 and 1 or step)
  elseif b == "L1" then tab = (tab - 2) % 3 + 1; flowPos = sel[tab]; sync_list_widget(); SFX.play("menu_pagescroll")
  elseif b == "R1" then tab = tab % 3 + 1; flowPos = sel[tab]; sync_list_widget(); SFX.play("menu_pagescroll")
  elseif b == "L2" then filter = (filter - 2) % 3 + 1; invalidate(); sync_list_widget(); SFX.play("menu_pagescroll")
  elseif b == "R2" then filter = filter % 3 + 1; invalidate(); sync_list_widget(); SFX.play("menu_pagescroll")
  elseif b == "X" then view = view % 3 + 1; Settings.set("stream_view", view); SFX.play("menu_select")
  elseif b == "SELECT" then sort = sort % 3 + 1; invalidate(); sync_list_widget(); Notify.show("info", "Sort: " .. SORTS[sort], 1.2)
  elseif b == "Y" and g then
    local f = Stream.toggle_fav(g.app); invalidate()
    Notify.show("info", f and "Added to favourites" or "Removed from favourites", 1.2); sync_list_widget()
  elseif b == "A" and g then start_launch(g)
  elseif b == "START" then require("ui").go("stream_settings", { on_back_reload = true })
  elseif b == "B" then
    local UI = require("ui")
    if UI.is_root() then UI.go_instant("library") else UI.back() end
  end
end

-- ── drawing ─────────────────────────────────────────────────
local function placeholder(g, x, y, w, h, acc, a)
  K.panel(x, y, w, h, { accent = acc, cut = 8, alpha = 0.9 })
  K.cube(x + w / 2, y + h * 0.32, math.min(w, h) * 0.13, t * 0.9, 0.55, acc, a)
  K.text("small", K.clip("small", g.title, w - 12), x + 6, y + h * 0.58, K.C.text, a, w - 12, "center")
end

local function draw_cover(g, x, y, w, h, a)
  local acc = acc_of(g)
  local img = load_cover(g)
  if not img then placeholder(g, x, y, w, h, acc, a); return x, y, w, h end
  local iw, ih = img:getDimensions()
  local s = math.min(w / iw, h / ih)
  local dw, dh = iw * s, ih * s
  local dx, dy = x + (w - dw) / 2, y + (h - dh)
  lg.setColor(1, 1, 1, a); lg.draw(img, dx, dy, 0, s, s)
  return dx, dy, dw, dh
end

local function sel_frame(dx, dy, dw, dh, acc)
  local p = 0.5 + 0.5 * math.sin(t * 5)
  K.color(acc, 0.10 + 0.12 * p); lg.rectangle("fill", dx - 8, dy - 8, dw + 16, dh + 16, 8, 8)
  K.color(acc, 1); lg.setLineWidth(3); lg.rectangle("line", dx - 3, dy - 3, dw + 6, dh + 6, 5, 5); lg.setLineWidth(1)
end

local function draw_flow(list)
  local n, cx = #list, K.W / 2
  local items = {}
  for i = math.max(1, math.floor(flowPos) - 4), math.min(n, math.ceil(flowPos) + 4) do items[#items + 1] = { i, i - flowPos } end
  table.sort(items, function(a, b) return math.abs(a[2]) > math.abs(b[2]) end)
  for _, it in ipairs(items) do
    local g, d = list[it[1]], it[2]
    local ad, sg = math.min(math.abs(d), 1), (d < 0 and -1 or 1)
    local ex = math.max(0, math.abs(d) - 1)
    local x = cx + sg * (ad * 150 + ex * 58)
    local sc = 1 - 0.30 * ad - 0.07 * math.min(ex, 2.5)
    local a = math.max(0.25, math.min(1, 1 - 0.17 * math.abs(d)))
    lg.push(); lg.translate(x, FBASE); lg.scale(sc * (1 - 0.20 * ad), sc); lg.shear(0, -sg * 0.18 * ad)
    local dx, dy, dw, dh = draw_cover(g, -FW / 2, -FH, FW, FH, a)
    if ad > 0.01 then lg.setColor(0, 0, 0, 0.38 * ad * a); lg.rectangle("fill", dx, dy, dw, dh) end
    if math.abs(d) < 0.5 then sel_frame(dx, dy, dw, dh, acc_of(g)) end
    lg.pop()
  end
end

local function draw_grid(list)
  local n = #list
  local first = math.max(0, math.floor(scroll[tab] / GRID.rowh) - 1) * GRID.cols + 1
  local last = math.min(n, first + (GRID.rows + 3) * GRID.cols)
  lg.setScissor(0, GRID.y0 - 6, K.W, GRID.rows * GRID.rowh + 8)
  for i = first, last do
    local c, r = (i - 1) % GRID.cols, math.floor((i - 1) / GRID.cols)
    local x = GRID.x0 + c * GRID.cellw + (GRID.cellw - GRID.cw) / 2
    local y = GRID.y0 + r * GRID.rowh - scroll[tab]
    local dx, dy, dw, dh = draw_cover(list[i], x, y, GRID.cw, GRID.ch, 1)
    if i == sel[tab] then sel_frame(dx, dy, dw, dh, acc_of(list[i])) end
  end
  lg.setScissor()
end

local function draw_row(g, x, y, w, h, focused)
  local acc = acc_of(g)
  K.panel(x, y + 2, w, h - 4, { focus = focused, accent = acc, cut = 7 })
  K.color(acc, focused and 1 or 0.6)
  love.graphics.rectangle("fill", x + 9, y + 10, 3, h - 20, 1.5, 1.5)
  local title = K.clip("body", g.title, w - 178)
  K.text("body", title, x + 22, y + h / 2 - 9, focused and K.C.text or K.C.dim)
  local st = Stream.stat(g.app)
  if st.fav then K.star(x + w - 108, y + h / 2, 7, K.ACC.boost, 1) end
  K.pill(g.kind == "wii" and "WII" or "GC", x + w - 12, y + h / 2, acc, focused)
  local plays = tostring(st.plays or 0) .. " PLAYS"
  K.text("key", plays, x + w - 176, y + h / 2 - 6, K.C.faint)
end

local function led(x, y, state, label)
  local c = state == "ok" and K.C.ok or (state == "fail" and K.C.bad or K.C.faint)
  K.color(c, 0.25); lg.circle("fill", x, y, 7); K.color(c, 1); lg.circle("fill", x, y, 4)
  K.text("small", label, x + 11, y - 8, K.C.dim)
end

local NEON_PINK = { 0.98, 0.28, 0.72 }
local NEON_CYAN = { 0.20, 0.88, 0.96 }
local NEON_PURPLE = { 0.48, 0.30, 0.98 }
local NEON_ORANGE = { 1.00, 0.48, 0.40 }

local function draw_vaporwave_backdrop()
  -- Retrowave sunset: restrained neon so covers and text stay readable.
  local sx, sy, sr = 514, 212, 76
  K.color(NEON_PINK, 0.12)
  lg.circle("fill", sx, sy, sr + 9)
  for yy = -sr, sr, 6 do
    local half = math.sqrt(math.max(0, sr * sr - yy * yy))
    local c = yy < -16 and NEON_PINK or (yy < 28 and NEON_ORANGE or NEON_PURPLE)
    K.color(c, 0.42)
    lg.rectangle("fill", sx - half, sy + yy, half * 2, 3)
  end

  -- Perspective grid converges at the horizon and fades toward the footer.
  local horizon = 292
  K.color(NEON_CYAN, 0.15)
  for i = -10, 10 do
    local bx = K.W / 2 + i * 42
    lg.line(K.W / 2, horizon, bx, K.H)
  end
  for i = 0, 10 do
    local p = i / 10
    local yy = horizon + p * p * 150
    K.color(NEON_PURPLE, 0.10 + p * 0.08)
    lg.line(0, yy, K.W, yy)
  end
  K.color(NEON_PINK, 0.16)
  lg.line(0, horizon, K.W, horizon)
end

local function draw_stream_header()
  K.panel(K.MARGIN, 8, K.W - K.MARGIN * 2, 92,
    { cut = 12, accent = NEON_PURPLE })
  K.text("key", "SUNSHINE  /  MOONLIGHT  //  NIGHT DRIVE", K.MARGIN + 14, 14, NEON_CYAN)
  K.text("title", "RT:STREAM", K.MARGIN + 14, 30, K.C.text)

  -- Connection indicators occupy a dedicated upper-right lane.
  local host = Stream.configured() and ("PC  " .. tostring(Stream.s.HOST)) or "PC NOT CONFIGURED"
  K.text("key", K.clip("key", host, 190), K.W - K.MARGIN - 204,
    14, Stream.configured() and NEON_CYAN or K.C.warn)
  led(K.MARGIN + 286, 45, Stream.health.library, "PORTAL")
  led(K.MARGIN + 390, 45, Stream.health.sunshine, "SUNSHINE")

  -- Tabs, system filter and visual modes are three non-overlapping control
  -- groups. X cycles the presentation; L1/R1 and L2/R2 keep their old roles.
  local tab_labels = { "LIBRARY", "FAVES", "RECENT" }
  local tab_x, tab_y, tab_w, tab_gap = K.MARGIN + 14, 66, 68, 5
  for i = 1, #TABS do
    local x = tab_x + (i - 1) * (tab_w + tab_gap)
    local active = i == tab
    local c = active and NEON_PINK or K.C.faint
    K.color(c, active and 0.22 or 0.06)
    lg.rectangle("fill", x, tab_y, tab_w, 22, 5, 5)
    K.color(c, active and 1 or 0.35)
    lg.rectangle("line", x, tab_y, tab_w, 22, 5, 5)
    K.text("key", tab_labels[i], x + 2, tab_y + 6, active and K.C.text or K.C.dim,
      1, tab_w - 4, "center")
  end

  local filter_x, filter_w = 270, 84
  K.color(NEON_CYAN, 0.10); lg.rectangle("fill", filter_x, tab_y, filter_w, 22, 5, 5)
  K.color(NEON_CYAN, 0.5); lg.rectangle("line", filter_x, tab_y, filter_w, 22, 5, 5)
  K.text("key", "FILTER  " .. (filter == 1 and "ALL" or filter == 2 and "GC" or "WII"),
    filter_x + 2, tab_y + 6, NEON_CYAN, 1, filter_w - 4, "center")

  local view_x, view_w, view_gap = 364, 76, 5
  for i, label in ipairs({ "FLOW", "GRID", "LIST" }) do
    local x = view_x + (i - 1) * (view_w + view_gap)
    local active = i == view
    local c = active and NEON_PURPLE or K.C.faint
    K.color(c, active and 0.25 or 0.05)
    lg.rectangle("fill", x, tab_y, view_w, 22, 5, 5)
    K.color(c, active and 1 or 0.32)
    lg.rectangle("line", x, tab_y, view_w, 22, 5, 5)
    K.text("key", label, x, tab_y + 6, active and K.C.text or K.C.dim,
      1, view_w, "center")
  end
end

local function draw_overlay()
  local g = launching.g
  lg.setColor(0, 0, 0, 0.72); lg.rectangle("fill", 0, 0, K.W, K.H)
  local w, h = 420, 170
  local x, y = (K.W - w) / 2, (K.H - h) / 2
  local acc = acc_of(g)
  K.panel(x, y, w, h, { accent = acc, cut = 12, focus = true, force = true })
  K.cube(x + 52, y + h / 2, 26, t * 1.6, 0.55, acc, 1)
  K.text("title", K.clip("title", g.title, w - 130), x + 96, y + 22, K.C.text)
  local msg, sub, c = "Checking your PC...", "Sunshine on " .. Stream.s.HOST, K.C.dim
  if launching.phase == "go" then msg, sub, c = "Streaming...", "Starting Moonlight", K.C.ok
  elseif launching.phase == "fail" then msg, sub, c = "PC not reachable", "A = try anyway    B = cancel", K.C.bad end
  K.text("body", msg, x + 96, y + 66, c)
  K.text("small", sub, x + 96, y + 94, K.C.dim)
  if launching.phase ~= "fail" then
    K.bar(x + 96, y + 128, w - 120, 6, launching.phase == "go" and math.min(1, launching.t / 0.9) or ((launching.t * 0.5) % 1), acc)
  end
end

function S.draw()
  local list = cur_list()
  local g = list[sel[tab]]
  K.set_accent(g and acc_of(g) or NEON_PURPLE)
  K.bg()
  draw_vaporwave_backdrop()
  draw_stream_header()

  if #list == 0 then
    local msg = not Stream.configured() and "SET YOUR PC ADDRESS IN STREAM SETTINGS"
      or (#Stream.games == 0 and "SYNC YOUR SUNSHINE LIBRARY TO GET STARTED" or "NOTHING IN THIS SECTION YET")
    K.panel(76, 164, K.W - 152, 174, { cut = 14, accent = NEON_PINK })
    K.cube(K.W / 2, 220, 34, t * 0.8, 0.55, NEON_PURPLE, 0.9)
    K.text("body", msg, 92, 286, K.C.text, 1, K.W - 184, "center")
    K.text("small", "START  ·  CONNECTION & SYNC TOOLS", 92, 311, NEON_CYAN, 1, K.W - 184, "center")
  elseif view == 1 then
    draw_flow(list)
  elseif view == 2 then
    draw_grid(list)
  else
    S.list:draw(function(item, x, y, w, h, focused) draw_row(item, x, y, w, h, focused) end)
  end

  if g then
    local y = K.BOT - 40
    K.panel(K.MARGIN, y, K.W - K.MARGIN * 2, 40, { accent = acc_of(g), cut = 8 })
    K.text("body", K.clip("body", g.title, 300), K.MARGIN + 14, y + 8, K.C.text)
    local st = Stream.stat(g.app)
    local details = (g.id and (g.id .. "  ·  ") or "") .. tostring(st.plays or 0) ..
      " PLAYS  ·  " .. SL.ago(st.last, os.time())
    K.text("small", K.clip("small", details, 244), K.W - K.MARGIN - 14 - 244,
      y + 12, NEON_CYAN, 1, 244, "right")
  end

  K.footer({
    { key = "A", label = "Play" }, { key = "X", label = "View" },
    { key = "Y", label = "Favourite" }, { key = "L1/R1", label = "Tab" },
    { key = "SELECT", label = "Sort" }, { key = "START", label = "Connect" },
  })
  if launching then draw_overlay() end
end

return S
