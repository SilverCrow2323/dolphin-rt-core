-- controls.lua - Dolphin controller mapping screen (view + edit from the handheld)
--
-- Data comes from the PC (conf/profiles.tsv, fetched by tools/profiles.sh). Edits are sent back to the
-- PC library server (tools/ctl.sh -> /ctl?token=...) and applied by the portal before the next game launch.
local ui = require("ui")
local cfg = require("cfg")
local lg = love.graphics

local C = {}
local W, H = 640, 480
local ctx = { base = ".", toast = function() end, runTool = function() end }
local fonts

local KINDS = { "GCPad", "Wiimote", "Hotkeys" }
local KIND_TITLES = { GCPad = "GAMECUBE", Wiimote = "WII REMOTE", Hotkeys = "HOTKEYS" }
local KIND_ICONS = { GCPad = "gamepad", Wiimote = "wifi", Hotkeys = "keyboard" }
local BUTTONS = { "SOUTH", "EAST", "WEST", "NORTH", "TL", "TR", "SELECT", "START", "MODE", "THUMBL", "THUMBR" }
local HOTKEY_CHOICES = {}
for _, b in ipairs(BUTTONS) do if b ~= "MODE" then HOTKEY_CHOICES[#HOTKEY_CHOICES + 1] = "MODE&" .. b end end
for _, a in ipairs({ "`Axis 7-`", "`Axis 7+`", "`Axis 6-`", "`Axis 6+`" }) do HOTKEY_CHOICES[#HOTKEY_CHOICES + 1] = "MODE&" .. a end

local data = { active = {}, profiles = {}, names = {} }     -- profiles[kind][name] = { {key=, value=}, ... }
local rev = 0
local st = nil                                              -- open screen state
local cache = {}
local pending, queue, busy = {}, {}, false
local VISR, ROWH, LISTY = 6, 42, 96

-- ------------------------------------------------------------------ data
local function split(line)
  local t = {}
  for f in (line .. "\t"):gmatch("([^\t]*)\t") do t[#t + 1] = f end
  return t
end

function C.load()
  local s = cfg.readFile(ctx.base .. "/conf/profiles.tsv")
  if not s then return false end
  local d = { active = {}, profiles = {}, names = {} }
  for _, k in ipairs(KINDS) do d.profiles[k], d.names[k] = {}, {} end
  for line in s:gmatch("[^\n]+") do
    line = (line:gsub("\r", ""))
    if line:sub(1, 1) ~= "#" then
      local f = split(line)
      if f[1] == "@active" and f[2] and f[3] then
        d.active[f[2]] = f[3]
      elseif d.profiles[f[1]] and f[2] and f[3] and f[4] then
        local nm_lower = f[2]:lower()
        if not (nm_lower:match("ds4") or nm_lower:match("dualshock") or nm_lower:match("dualsense")) then
          local list = d.profiles[f[1]][f[2]]
          if not list then
            list = {}; d.profiles[f[1]][f[2]] = list
            table.insert(d.names[f[1]], f[2])
          end
          list[#list + 1] = { key = f[3], value = f[4] }
        end
      end
    end
  end
  data = d
  rev = rev + 1
  cache = {}
  return true
end

-- ------------------------------------------------------------------ labels / tokens
local function label(kind, key)
  if kind == "Hotkeys" then
    local k = key:match("([^/]+)$") or key
    k = k:gsub("Emulation Speed", "Speed"):gsub("State Slot ", "State "):gsub("Take Screenshot", "Screenshot")
    k = k:gsub("^Toggle ", ""):gsub("Disable Speed Limit", "No speed limit"):gsub("Undo Load State", "Undo load")
    return k
  end
  local k = key:gsub("^Buttons/", "")
  k = k:gsub("^Triggers/", ""):gsub("^Main Stick/", "Stick "):gsub("^C%-Stick/", "C-Stick ")
  k = k:gsub("^D%-Pad/", "D-Pad "):gsub("^Nunchuk/Buttons/", "Nunchuk "):gsub("^Nunchuk/Stick/", "Nunchuk stick ")
  k = k:gsub("^Nunchuk/Shake/", "Nunchuk shake "):gsub("^IR/", "IR "):gsub("^Shake/", "Shake "):gsub("^Options/", "")
  return (k:gsub("/", " "))
end

local PRETTY = { ["Axis 7-"] = "D-Pad Up", ["Axis 7+"] = "D-Pad Down", ["Axis 6-"] = "D-Pad Left", ["Axis 6+"] = "D-Pad Right",
  ["Axis 0-"] = "L-Stick Left", ["Axis 0+"] = "L-Stick Right", ["Axis 1-"] = "L-Stick Up", ["Axis 1+"] = "L-Stick Down",
  ["Axis 3-"] = "R-Stick Left", ["Axis 3+"] = "R-Stick Right", ["Axis 4-"] = "R-Stick Up", ["Axis 4+"] = "R-Stick Down",
  ["Full Axis 2+"] = "LT", ["Full Axis 5+"] = "RT" }

local function prettyToken(tok)
  tok = tok:gsub("`", "")
  return PRETTY[tok] or tok
end

local function pretty(value)
  local parts = {}
  for tok in (value .. "&"):gmatch("([^&]*)&") do parts[#parts + 1] = prettyToken(tok) end
  return table.concat(parts, " + ")
end

-- which parts of the drawn pad a value involves
local ELEM = { SOUTH = "A", EAST = "B", WEST = "X", NORTH = "Y", TL = "LB", TR = "RB", SELECT = "BACK", START = "START",
  MODE = "MODE", THUMBL = "LS", THUMBR = "RS", ["Full Axis 2+"] = "LT", ["Full Axis 5+"] = "RT" }
local function elementsOf(value)
  local set = {}
  for tok in (value .. "&"):gmatch("([^&]*)&") do
    tok = tok:gsub("`", "")
    local e = ELEM[tok]
    if not e then
      local n = tok:match("Axis (%d)")
      if n == "0" or n == "1" then e = "LS" elseif n == "3" or n == "4" then e = "RS" elseif n == "6" or n == "7" then e = "DPAD" end
    end
    if e then set[e] = true end
  end
  return set
end

-- ------------------------------------------------------------------ rows
local function rowsFor(kind)
  local name = data.active[kind]
  local key = kind .. "|" .. tostring(name) .. "|" .. rev
  if cache[key] then return cache[key] end
  local list = (data.profiles[kind] or {})[name] or {}
  local rows = {}
  for _, e in ipairs(list) do
    if not e.key:match("^Options/") and not e.key:match("Dead Zone$") and e.key ~= "Extension" and e.key ~= "Source" then
      local choices
      if kind == "Hotkeys" then choices = HOTKEY_CHOICES
      elseif e.value:match("^%u+$") then choices = BUTTONS end
      rows[#rows + 1] = { entry = e, key = e.key, label = label(kind, e.key), choices = choices }
    end
  end
  cache[key] = rows
  return rows
end

local function curKind() return KINDS[st.kind] end

-- ------------------------------------------------------------------ talking to the PC
local function enc(s) return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end)) end

local function send(kind, name, key, value)
  local q = "op=set&kind=" .. enc(kind) .. "&profile=" .. enc(name) .. "&key=" .. enc(key) .. "&value=" .. enc(value)
  os.remove(ctx.base .. "/conf/ctl.result")
  busy = true
  os.execute("sh '" .. ctx.base .. "/tools/ctl.sh' '" .. q .. "' >/dev/null 2>&1 &")
end

local function sendActive(kind, name)
  local q = "op=active&kind=" .. enc(kind) .. "&profile=" .. enc(name)
  queue[#queue + 1] = q
end

local function refresh()
  os.remove(ctx.base .. "/conf/profiles.done")
  st.refreshing = true
  os.execute("sh '" .. ctx.base .. "/tools/profiles.sh' >/dev/null 2>&1 &")
end

local function flushPending()
  for k, p in pairs(pending) do
    queue[#queue + 1] = "op=set&kind=" .. enc(p.kind) .. "&profile=" .. enc(p.name) .. "&key=" .. enc(p.key) .. "&value=" .. enc(p.value)
    pending[k] = nil
  end
end

-- ------------------------------------------------------------------ public API
function C.init(c)
  ctx = c
  fonts = ui.fonts
  C.load()
end

function C.active() return st ~= nil end

function C.open()
  st = { kind = 1, sel = { 1, 1, 1 }, top = { 0, 0, 0 }, t = 0 }
  if not data.active.GCPad then C.load() end
  refresh()
end

function C.close()
  flushPending()
  st = nil
end

local function move(d)
  local rows = rowsFor(curKind())
  local n = #rows
  if n == 0 then return end
  local k = st.kind
  st.sel[k] = math.max(1, math.min(n, st.sel[k] + d))
  if st.sel[k] <= st.top[k] then st.top[k] = st.sel[k] - 1 end
  if st.sel[k] > st.top[k] + VISR then st.top[k] = st.sel[k] - VISR end
end

local function edit(d)
  local rows = rowsFor(curKind())
  local r = rows[st.sel[st.kind]]
  if not r then return end
  if not r.choices then
    ctx.toast("Read-only here: axes and numbers are edited on the PC", "info")
    return
  end
  local idx = 0
  for i, v in ipairs(r.choices) do if v == r.entry.value then idx = i end end
  idx = idx + d
  if idx < 1 then idx = #r.choices elseif idx > #r.choices then idx = 1 end
  r.entry.value = r.choices[idx]
  local kind, name = curKind(), data.active[curKind()]
  pending[kind .. name .. r.key] = { kind = kind, name = name, key = r.key, value = r.entry.value, t = 0 }
  st.dirty = 0
end

local function nextProfile()
  local kind = curKind()
  local names = data.names[kind] or {}
  if #names < 2 then return end
  local cur = 1
  for i, n in ipairs(names) do if n == data.active[kind] then cur = i end end
  flushPending()
  local nxt = names[(cur % #names) + 1]
  data.active[kind] = nxt
  rev = rev + 1; cache = {}
  st.sel[st.kind], st.top[st.kind] = 1, 0
  sendActive(kind, nxt)
end

function C.press(b)
  if b == "b" then C.close()
  elseif b == "l1" then flushPending(); st.kind = (st.kind + #KINDS - 2) % #KINDS + 1
  elseif b == "r1" then flushPending(); st.kind = st.kind % #KINDS + 1
  elseif b == "up" then move(-1)
  elseif b == "down" then move(1)
  elseif b == "l2" then move(-VISR)
  elseif b == "r2" then move(VISR)
  elseif b == "left" then edit(-1)
  elseif b == "right" or b == "a" then edit(1)
  elseif b == "y" then nextProfile()
  elseif b == "select" then refresh()
  end
end

function C.update(dt)
  if not st then return end
  st.t = st.t + dt
  for _, p in pairs(pending) do p.t = p.t + dt end
  -- send settled edits (0.6 s without further changes), one request at a time
  if not busy then
    for k, p in pairs(pending) do
      if p.t > 0.6 then
        pending[k] = nil
        send(p.kind, p.name, p.key, p.value)
        break
      end
    end
  end
  if not busy and #queue > 0 then
    local q = table.remove(queue, 1)
    os.remove(ctx.base .. "/conf/ctl.result")
    busy = true
    os.execute("sh '" .. ctx.base .. "/tools/ctl.sh' '" .. q .. "' >/dev/null 2>&1 &")
  end
  if busy then
    local r = cfg.readFile(ctx.base .. "/conf/ctl.result")
    if r and r ~= "" then
      busy = false
      os.remove(ctx.base .. "/conf/ctl.result")
      r = r:gsub("%s+$", "")
      ctx.toast(r, r:match("^OK") and "ok" or "err")
    end
  end
  if st.refreshing and cfg.readFile(ctx.base .. "/conf/profiles.done") then
    st.refreshing = false
    if not busy and #queue == 0 and next(pending) == nil then C.load() end
  end
end

-- ------------------------------------------------------------------ drawing
local function circleBtn(lit, id, x, y, r, col, txt, t)
  local on = lit[id]
  lg.setColor(col[1], col[2], col[3], on and 0.60 or 0.12); lg.circle("fill", x, y, r)
  lg.setColor(col[1], col[2], col[3], on and 1 or 0.40); lg.setLineWidth(on and 3 or 1.5); lg.circle("line", x, y, r)
  if on then
    lg.setColor(col[1], col[2], col[3], 0.55); lg.setLineWidth(2); lg.circle("line", x, y, r + 5 + math.sin(t * 8) * 2)
  end
  if txt then
    lg.setFont(fonts.ot); lg.setColor(1, 1, 1, on and 1 or 0.6)
    lg.printf(txt, x - r, y - fonts.ot:getHeight() / 2, r * 2, "center")
  end
  lg.setLineWidth(1)
end

local function padBtn(lit, id, x, y, w, h, txt, col, t)
  local on = lit[id]
  lg.setColor(col[1], col[2], col[3], on and 0.60 or 0.12); lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
  lg.setColor(col[1], col[2], col[3], on and 1 or 0.40); lg.setLineWidth(on and 3 or 1.5); lg.rectangle("line", x, y, w, h, h / 2, h / 2)
  if on then
    lg.setColor(col[1], col[2], col[3], 0.55); lg.setLineWidth(2)
    lg.rectangle("line", x - 4 - math.sin(t * 8) * 1.5, y - 4, w + 8 + math.sin(t * 8) * 3, h + 8, h / 2 + 3, h / 2 + 3)
  end
  if txt then
    lg.setFont(fonts.ot); lg.setColor(1, 1, 1, on and 1 or 0.6)
    lg.printf(txt, x, y + h / 2 - fonts.ot:getHeight() / 2, w, "center")
  end
  lg.setLineWidth(1)
end

local function drawPad(lit, t)
  local th = ui.th
  local px, py = 8, 70
  ui.plate(px, py, 300, 276, th.line, { depth = 6 })
  local dim = th.dim
  padBtn(lit, "LT", px + 26, py + 14, 80, 16, "LT", th.wii, t)
  padBtn(lit, "RT", px + 194, py + 14, 80, 16, "RT", th.wii, t)
  padBtn(lit, "LB", px + 20, py + 36, 92, 18, "LB", th.gc, t)
  padBtn(lit, "RB", px + 188, py + 36, 92, 18, "RB", th.gc, t)
  local bc = ui.mix(th.panel, { 0, 0, 0 }, 0.45)
  lg.setColor(bc[1], bc[2], bc[3], 1)
  lg.polygon("fill", px + 20, py + 62, px + 280, py + 62, px + 292, py + 130, px + 262, py + 240, px + 38, py + 240, px + 8, py + 130)
  lg.setColor(dim[1], dim[2], dim[3], 0.55); lg.setLineWidth(1.5)
  lg.polygon("line", px + 20, py + 62, px + 280, py + 62, px + 292, py + 130, px + 262, py + 240, px + 38, py + 240, px + 8, py + 130)
  -- left stick
  local lsx, lsy = px + 72, py + 112
  circleBtn(lit, "LS", lsx, lsy, 30, th.text, "L", t)
  -- d-pad
  local dx, dy = px + 116, py + 188
  local on = lit.DPAD
  lg.setColor(on and th.fav[1] or dim[1], on and th.fav[2] or dim[2], on and th.fav[3] or dim[3], on and 0.9 or 0.45)
  lg.rectangle("fill", dx - 8, dy - 28, 16, 56, 3, 3); lg.rectangle("fill", dx - 28, dy - 8, 56, 16, 3, 3)
  if on then lg.setColor(th.fav[1], th.fav[2], th.fav[3], 0.5); lg.circle("line", dx, dy, 36 + math.sin(t * 8) * 2) end
  -- face buttons (Xbox layout)
  local fx, fy = px + 232, py + 112
  circleBtn(lit, "A", fx, fy + 26, 15, { 0.35, 0.90, 0.45 }, "A", t)
  circleBtn(lit, "B", fx + 26, fy, 15, { 0.95, 0.38, 0.38 }, "B", t)
  circleBtn(lit, "X", fx - 26, fy, 15, { 0.38, 0.66, 1.00 }, "X", t)
  circleBtn(lit, "Y", fx, fy - 26, 15, { 1.00, 0.80, 0.28 }, "Y", t)
  -- right stick
  circleBtn(lit, "RS", px + 190, py + 188, 26, th.text, "R", t)
  -- center buttons
  padBtn(lit, "BACK", px + 106, py + 96, 30, 14, nil, th.dim, t)
  padBtn(lit, "START", px + 148, py + 96, 30, 14, nil, th.dim, t)
  circleBtn(lit, "MODE", px + 135, py + 74, 11, th.gc, nil, t)
  ui.textf("BACK", px + 101, py + 112, 40, "center", fonts.xs, th.dim, 0.8)
  ui.textf("START", px + 141, py + 112, 44, "center", fonts.xs, th.dim, 0.8)
  ui.textf("virtual Xbox pad seen by Dolphin", px, py + 250, 300, "center", fonts.xs, th.dim, 0.9)
end

local function drawFooterBand()
  local th = ui.th
  lg.setColor(th.panel[1], th.panel[2], th.panel[3], 1); lg.rectangle("fill", 0, 428, W, 52)
  lg.setColor(th.line[1], th.line[2], th.line[3], 0.7); lg.rectangle("fill", 0, 428, W, 2)
end

function C.draw(t)
  if not st then return end
  local th = ui.th
  local kind = curKind()
  local acc = th.gc
  ui.bg(t, cfg.ui.anim)
  -- header with tabs
  lg.setColor(th.panel[1], th.panel[2], th.panel[3], 1); lg.rectangle("fill", 0, 0, W, 62)
  lg.setColor(acc[1], acc[2], acc[3], 0.8); lg.rectangle("fill", 0, 61, W, 2)
  ui.cube3d(34, 31, 13, t * 1.4, 0.55, acc, 1)
  ui.text("CONTROLS", 62, 14, fonts.ol, th.text, 1)
  local x = 270
  for i, k in ipairs(KINDS) do
    local on = (i == st.kind)
    local iconW = 14
    local w = iconW + fonts.os:getWidth(KIND_TITLES[k]) + 22
    local face = ui.mix(th.panel, acc, on and 0.6 or 0.12)
    lg.setColor(face[1], face[2], face[3], 1); lg.polygon("fill", x + 8, 16, x + w, 16, x + w - 8, 46, x, 46)
    local hi = ui.mix(acc, { 1, 1, 1 }, 0.5)
    lg.setColor(hi[1], hi[2], hi[3], on and 1 or 0.4); lg.setLineWidth(1.5)
    lg.polygon("line", x + 8, 16, x + w, 16, x + w - 8, 46, x, 46); lg.setLineWidth(1)
    ui.icon(KIND_ICONS[k] or "dot", x + 16, 31, 7, on and { 1, 1, 1 } or th.dim, 1)
    ui.text(KIND_TITLES[k], x + 16 + iconW, 23, fonts.os, on and { 1, 1, 1 } or th.dim, 1)
    x = x + w + 4
  end

  local rows = rowsFor(kind)
  local k = st.kind
  local selRow = rows[st.sel[k]]
  local lit = selRow and elementsOf(selRow.entry.value) or {}
  drawPad(lit, t)

  -- right: profile + list
  local name = data.active[kind]
  if not name then
    ui.plate(316, 70, 316, 276, th.line, { depth = 6 })
    ui.textf("NO PROFILE DATA YET", 316, 150, 316, "center", fonts.om, th.text, 1)
    ui.textf(st.refreshing and "loading from the PC..." or "Sync with the PC (SELECT)\nor check the host and token", 330, 190, 288, "center", fonts.s, th.dim, 1)
  else
    ui.chip(name, 318, 70, acc, 1, fonts.ot)
    local n, idx = #(data.names[kind] or {}), 1
    for i, nm in ipairs(data.names[kind] or {}) do if nm == name then idx = i end end
    ui.text(n > 1 and ("profile " .. idx .. "/" .. n) or "profile", 318 + fonts.ot:getWidth(name) + 40, 74, fonts.xs, th.dim, 1)
    for i = st.top[k] + 1, math.min(#rows, st.top[k] + VISR) do
      local r = rows[i]
      local y = LISTY + (i - st.top[k] - 1) * ROWH
      local on = (i == st.sel[k])
      local o = on and -2 or 0
      if on then ui.plate(316 + o, y + o, 306, ROWH - 6, acc, { depth = 4, sel = true, glow = 0.12 })
      else ui.plate(316, y, 306, ROWH - 6, th.line, { depth = 2, alpha = 0.7 }) end
      local cy = y + (ROWH - 6) / 2 + o
      ui.text(ui.fit(r.label, fonts.os, 124), 330 + o, cy - fonts.os:getHeight() / 2, fonts.os, on and th.text or th.dim, 1)
      local vt = ui.fit(pretty(r.entry.value), fonts.s, 150)
      local col = r.choices and (on and acc or th.text) or th.dim
      ui.textf(vt, 456 + o, cy - fonts.s:getHeight() / 2, 154, "right", fonts.s, col, 1)
      if on and r.choices then
        local nud = math.sin(t * 8) * 2
        ui.icon("back", 448 - nud + o, cy, 5, acc, 1)
      end
    end
    if #rows > VISR then
      local bh = ROWH * VISR - 8
      lg.setColor(1, 1, 1, 0.10); lg.rectangle("fill", W - 10, LISTY, 5, bh, 2, 2)
      local th_ = math.max(18, bh * VISR / #rows)
      lg.setColor(acc[1], acc[2], acc[3], 0.9)
      lg.rectangle("fill", W - 10, LISTY + (bh - th_) * (st.top[k] / math.max(1, #rows - VISR)), 5, th_, 2, 2)
    end
  end

  -- info plate
  ui.plate(8, 352, W - 22, 66, th.line, { depth = 5 })
  if selRow then
    ui.icon(selRow.choices and "gear" or "info", 34, 385, 10, selRow.choices and acc or th.dim, 1)
    ui.text(ui.fit(selRow.key, fonts.s, 560), 56, 358, fonts.s, th.text, 1)
    local hint = selRow.choices and "LEFT / RIGHT changes it - sent to the PC right away" or "Read-only here: edit axes and numbers on the PC"
    if busy then hint = "saving on the PC..." elseif st.refreshing then hint = "refreshing from the PC..." end
    ui.text(hint, 56, 382, fonts.s, th.dim, 1)
  else
    ui.text("Nothing to show", 56, 372, fonts.s, th.dim, 1)
  end
  drawFooterBand()
  ui.footer({ { k = { "L1", "R1" }, p = "swap" }, { k = { "DPADV" }, p = "updown" }, { k = { "DPADH" }, p = "gear" },
    { k = { "Y" }, p = "list" }, { k = { "SELECT" }, p = "sync" }, { k = { "B" }, p = "back" } })
end

return C
