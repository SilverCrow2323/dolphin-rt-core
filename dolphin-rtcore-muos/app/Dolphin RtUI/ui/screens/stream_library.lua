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
local GRID = { cols = 5, cw = 88, ch = 120, cellw = 120, rowh = 150, x0 = 20, y0 = 88, rows = 2 }
local FW, FH, FBASE = 132, 184, 330

local tab, view, filter, sort = 1, 1, 1, 1
local sel, scroll = { 1, 1, 1 }, { 0, 0, 0 }
local flowPos, t, health_t = 1, 0, 0
local covers, ncovers = {}, 0
local cache, dirty = {}, true
local launching
S.list = K.List(K.MARGIN, 88, K.W - K.MARGIN * 2 - 14, 270, 40)

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
  if not g then return false, "no stream game selected" end
  if not Stream.configured() then
    Notify.show("warning", "Set the PC address first (START)")
    return false, "stream host is not configured"
  end
  launching = { g = g, t = 0, phase = "check" }
  os.remove(Stream.DIR .. "/h_launch.done")
  local ok, result, err = pcall(Stream.spawn, "health.sh",
      "http://" .. Stream.s.HOST .. ":47989/serverinfo", Stream.DIR .. "/h_launch.done")
  if not ok or result == false then
    launching = nil
    return false, tostring(err or result)
  end
  SFX.play("menu_select")
  return true
end

-- NEXUS actions expose the Stream browser's existing tab/view/filter and launch model.
function S.register_actions(ui)
  if not ui or type(ui.register_action) ~= "function" then
    return false, "UI action registrar unavailable"
  end
  local function selected() return cur() end
  local function refresh_list()
    invalidate()
    sync_list_widget()
    flowPos = sel[tab]
  end
  local specs = {
    { id = "stream_library.refresh", title = "Refresh Stream library", order = 10,
      run = function()
        local ok, err = pcall(Stream.reload)
        if not ok then return false, tostring(err) end
        for i = 1, 3 do sel[i] = 1; scroll[i] = 0 end
        refresh_list(); covers, ncovers = {}, 0
        return true
      end },
    { id = "stream_library.set_tab", title = "Set Stream library tab", order = 20,
      run = function(tab_id)
        local indexes = { library = 1, favourites = 2, recent = 3 }
        if type(tab_id) ~= "string" or not indexes[tab_id] then
          return false, "tab must be library, favourites or recent"
        end
        tab = indexes[tab_id]; refresh_list(); SFX.play("menu_pagescroll")
        return true
      end },
    { id = "stream_library.set_view", title = "Set Stream library view", order = 30,
      run = function(view_id)
        local indexes = { flow = 1, grid = 2, list = 3 }
        if type(view_id) ~= "string" or not indexes[view_id] then
          return false, "view must be flow, grid or list"
        end
        view = indexes[view_id]
        Settings.set("stream_view", view)
        SFX.play("menu_select")
        return true
      end },
    { id = "stream_library.set_filter", title = "Set Stream library system filter", order = 40,
      run = function(filter_id)
        local indexes = { all = 1, gamecube = 2, wii = 3 }
        if type(filter_id) ~= "string" or not indexes[filter_id] then
          return false, "filter must be all, gamecube or wii"
        end
        filter = indexes[filter_id]; refresh_list(); SFX.play("menu_pagescroll")
        return true
      end },
    { id = "stream_library.set_sort", title = "Set Stream library sort order", order = 50,
      run = function(sort_id)
        local indexes = { az = 1, recent = 2, most_played = 3 }
        if type(sort_id) ~= "string" or not indexes[sort_id] then
          return false, "sort must be az, recent or most_played"
        end
        sort = indexes[sort_id]; refresh_list()
        return true
      end },
    { id = "stream_library.select", title = "Select Stream game", order = 60,
      run = function(index)
        local items = cur_list()
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #items then
          return false, "Stream selection index out of range"
        end
        sel[tab] = index; S.list.sel = index; S.list:_aim(true); flowPos = index
        return true
      end },
    { id = "stream_library.toggle_favourite", title = "Toggle selected Stream favourite", order = 70,
      run = function()
        local game = selected()
        if not game then return false, "no Stream game selected" end
        local ok, result = pcall(Stream.toggle_fav, game.app)
        if not ok then return false, tostring(result) end
        refresh_list(); SFX.play("menu_toggleoption")
        return true, result
      end },
    { id = "stream_library.launch_selected", title = "Launch selected Stream game", order = 80,
      run = function() return start_launch(selected()) end },
    { id = "stream_library.cancel_launch", title = "Cancel Stream launch preflight", order = 90,
      run = function()
        if not launching then return false, "no Stream launch is active" end
        launching = nil
        return true
      end },
    { id = "stream_library.state", title = "Get Stream library state", order = 100,
      run = function()
        local game = selected()
        local stats = game and Stream.stat(game.app) or nil
        return { tab = TABS[tab]:lower(), view = VIEWS[view]:lower(),
          filter = FILTERS[filter]:lower(), sort = SORTS[sort]:lower(),
          selected_app = game and game.app, selected_title = game and game.title,
          selected_kind = game and game.kind, favourite = stats and stats.fav or false,
          launch_phase = launching and launching.phase or nil,
          game_count = #cur_list() }
      end },
  }
  for _, spec in ipairs(specs) do
    local ok, err = ui.register_action(spec.id, spec.run, {
      title = spec.title, group = "stream", order = spec.order, screen = "stream_library",
    })
    if not ok then return false, err or ("could not register " .. spec.id) end
  end
  return true
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
  K.text("body", K.clip("body", g.title, w - 150), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
  K.pill(g.kind == "wii" and "WII" or "GC", x + w - 12, y + h / 2, acc, focused)
  if Stream.stat(g.app).fav then K.star(x + w - 64, y + h / 2, 7, K.ACC.boost, 1) end
end

local function led(x, y, state, label)
  local c = state == "ok" and K.C.ok or (state == "fail" and K.C.bad or K.C.faint)
  K.color(c, 0.25); lg.circle("fill", x, y, 7); K.color(c, 1); lg.circle("fill", x, y, 4)
  K.text("small", label, x + 11, y - 8, K.C.dim)
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
  K.set_accent(g and acc_of(g) or K.ACC.gc)
  K.bg()
  K.header("RT:STREAM", TABS[tab] .. "   " .. VIEWS[view] .. "   " .. FILTERS[filter] .. "   " .. #list .. " games", nil, { accent = K.acc })
  led(K.W - 214, 56, Stream.health.library, "PORTAL")
  led(K.W - 124, 56, Stream.health.sunshine, "SUNSHINE")

  if #list == 0 then
    local msg = not Stream.configured() and "Set your PC address in START > Stream settings, then sync."
      or (#Stream.games == 0 and "No games yet. START > Sync library." or "Nothing here yet.")
    K.cube(K.W / 2, 190, 34, t * 0.8, 0.55, K.acc, 0.9)
    K.text("body", msg, 0, 250, K.C.dim, 1, K.W, "center")
  elseif view == 1 then draw_flow(list)
  elseif view == 2 then draw_grid(list)
  else S.list:draw(function(item, x, y, w, h, focused) draw_row(item, x, y, w, h, focused) end) end

  if g then
    local y = K.BOT - 40
    K.panel(K.MARGIN, y, K.W - K.MARGIN * 2, 40, { accent = acc_of(g), cut = 6 })
    K.text("body", K.clip("body", g.title, 380), K.MARGIN + 14, y + 10, K.C.text)
    local st = Stream.stat(g.app)
    local info = (g.id and (g.id .. "   ") or "") .. SL.ago(st.last, os.time())
    K.text("small", info, K.W - K.MARGIN - 14 - K.width("small", info), y + 12, K.C.dim)
  end
  K.footer({ { key = "A", label = "Play" }, { key = "X", label = "View" }, { key = "Y", label = "Fav" },
             { key = "L1/R1", label = "Tab" }, { key = "START", label = "Stream" } })
  if launching then draw_overlay() end
end

return S
