-- ui/screens/diagnostics.lua — session log viewer + log categories + settings.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local Notify   = require("ui.notify")
local Modal    = require("ui.modal")
local Settings = require("core.settings")
local sh       = require("core.sh")
local NexusDiagnostics = require("core.nexus_diagnostics")

local S = {}
S.mode = "list"
S.list = K.List(K.MARGIN, 180, K.W - K.MARGIN * 2 - 14, K.BOT - 180, 46)
S.settings_list = K.List(K.MARGIN, 110, K.W - K.MARGIN * 2 - 14, K.BOT - 110, 46)
S.session_lines = {}
S.viewer = nil
S.nexus_report = nil
S.nexus_lines = {}
S.nexus_top = 0

local CATS = {
  { id = "ui",      label = "UI Log",      icon = "list",    color = K.ACC.gc,    pattern = "data/logs/ui.log*" },
  { id = "dolphin", label = "Dolphin Log", icon = "gamepad", color = K.ACC.wii,   pattern = "data/logs/dolphin_*.log" },
  { id = "launch",  label = "Launch Log",  icon = "play",    color = K.ACC.boost, pattern = "data/logs/launch_*.log" },
  { id = "crash",   label = "Crash Log",   icon = "bomb",    color = K.C.bad,     pattern = "data/logs/crash_*.log" },
}

local function count_files(pattern)
  local h = io.popen("ls -1 " .. pattern .. " 2>/dev/null | wc -l")
  if not h then return 0 end
  local n = tonumber(h:read("*a")) or 0; h:close(); return n
end

local function total_size(pattern)
  local h = io.popen("du -cb " .. pattern .. " 2>/dev/null | tail -1 | cut -f1")
  if not h then return 0 end
  local n = tonumber(h:read("*a")) or 0; h:close(); return n
end

local function human_size(b)
  if b < 1024 then return b .. " B" end
  if b < 1048576 then return string.format("%.1f KB", b/1024) end
  return string.format("%.1f MB", b/1048576)
end

local function read_tail(path, n)
  local lines = {}
  local h = io.popen("tail -n " .. n .. " " .. sh.shq(path) .. " 2>/dev/null")
  if not h then return lines end
  for l in h:lines() do lines[#lines+1] = l end
  h:close(); return lines
end

local function read_full(path)
  local lines = {}
  local f = io.open(path, "r")
  if not f then return lines end
  for l in f:lines() do lines[#lines+1] = l end
  f:close(); return lines
end

local function clear_cat(cat)
  os.execute("rm -f " .. cat.pattern .. " 2>/dev/null")
  SFX.play("menu_back")
  Notify.show("success", cat.label .. " cleared")
end

local function auto_clear()
  if Settings.get("log_auto_clear") == false then return end
  local days = Settings.get("log_retention_days") or 7
  os.execute(string.format("find data/logs -name '*.log' -mtime +%d -delete 2>/dev/null", days))
end

local function build_list()
  auto_clear()
  local rows = {}
  for _, c in ipairs(CATS) do
    rows[#rows+1] = { cat = c, files = count_files(c.pattern), size = total_size(c.pattern) }
  end
  S.list:set(rows, false)
  S.list.sel = 1
end

local LOG_LEVELS = { "off", "error", "info", "verbose" }
local RET_DAYS   = { 1, 3, 7, 30 }
local MAX_KB     = { 256, 512, 1024, 2048 }

local function build_settings()
  local rows = {
    { kind="choice", label="Log level", icon="info", values=LOG_LEVELS,
      get = function() return Settings.get("log_level") or "info" end,
      set = function(v) Settings.set("log_level", v) end },
    { kind="choice", label="Retention", icon="trash", values=RET_DAYS,
      fmt = function(v) return v .. (v==1 and " day" or " days") end,
      get = function() return Settings.get("log_retention_days") or 7 end,
      set = function(v) Settings.set("log_retention_days", v) end },
    { kind="choice", label="Max file size", icon="list", values=MAX_KB,
      fmt = function(v) return v >= 1024 and (math.floor(v/1024) .. " MB") or (v .. " KB") end,
      get = function() return Settings.get("log_max_kb") or 512 end,
      set = function(v) Settings.set("log_max_kb", v) end },
    { kind="toggle", label="Auto-clear on open", icon="trash",
      get = function() local v = Settings.get("log_auto_clear"); if v == nil then return true end; return v end,
      set = function(v) Settings.set("log_auto_clear", v) end },
  }
  S.settings_list:set(rows, false)
  S.settings_list.sel = 1
end

local function refresh_nexus_report()
  local ok, UI = pcall(require, "ui")
  local catalog = ok and UI and UI.catalog and UI.catalog() or {}
  S.nexus_report = NexusDiagnostics.inspect(catalog)
  S.nexus_lines = {}
  for line in NexusDiagnostics.format(S.nexus_report):gmatch("[^\\n]+") do
    S.nexus_lines[#S.nexus_lines + 1] = line
  end
  for _, screen in ipairs(S.nexus_report.screens) do
    S.nexus_lines[#S.nexus_lines + 1] = string.format(
      "SCREEN  %-22s %s", screen.id,
      screen.has_navigation_action and "ROUTE OK" or "MISSING ROUTE")
  end
  for _, action in ipairs(S.nexus_report.actions) do
    local target = action.screen and (" -> " .. action.screen) or ""
    S.nexus_lines[#S.nexus_lines + 1] = "ACTION  " .. action.id .. target
  end
  S.nexus_top = 0
end

local function export_nexus_report()
  if not S.nexus_report then refresh_nexus_report() end
  local f = io.open("data/logs/nexus_report.txt", "w")
  if not f then
    Notify.show("error", "Cannot write NEXUS report")
    return
  end
  f:write(NexusDiagnostics.format(S.nexus_report), "\\n\\n")
  for _, line in ipairs(S.nexus_lines) do f:write(line, "\\n") end
  f:close()
  Notify.show("success", "NEXUS report saved")
end

function S.enter(params)
  S.mode = "list"
  S.viewer = nil
  S.nexus_report = nil
  auto_clear()
  build_list()
  build_settings()
  S.session_lines = read_tail("data/logs/ui.log", 6)
  K.set_accent("teal")
end

function S.update(dt)
  S.list:update(dt)
  S.settings_list:update(dt)
end

local function open_viewer(cat)
  local files = {}
  local h = io.popen("ls -1t " .. cat.pattern .. " 2>/dev/null")
  if h then
    for l in h:lines() do files[#files+1] = l end
    h:close()
  end
  if #files == 0 then
    Notify.show("info", "No " .. cat.label .. " files yet")
    return
  end
  local path = files[1]
  local lines = read_full(path)
  S.viewer = { cat = cat, path = path, lines = lines,
               top = math.max(0, #lines - 18), total = #files }
  SFX.play("menu_select")
end

local function step_choice(row, d)
  local i = 1
  for n, v in ipairs(row.values) do if v == row.get() then i = n end end
  row.set(row.values[((i - 1 + d) % #row.values) + 1])
  SFX.play("menu_move")
end

function S.pad(b)
  if S.mode == "nexus" then
    local max_top = math.max(0, #S.nexus_lines - 22)
    if b == "UP" then S.nexus_top = math.max(0, S.nexus_top - 1)
    elseif b == "DOWN" then S.nexus_top = math.min(max_top, S.nexus_top + 1)
    elseif b == "L2" or b == "LEFT" then S.nexus_top = math.max(0, S.nexus_top - 12)
    elseif b == "R2" or b == "RIGHT" then S.nexus_top = math.min(max_top, S.nexus_top + 12)
    elseif b == "A" then refresh_nexus_report(); Notify.show("success", "NEXUS check refreshed")
    elseif b == "X" then export_nexus_report()
    elseif b == "B" or b == "L1" or b == "R1" then S.mode = "list"; SFX.play("menu_back") end
    return
  end

  -- viewer
  if S.viewer then
    local v = S.viewer
    local maxTop = math.max(0, #v.lines - 18)
    if b == "UP" then v.top = math.max(0, v.top - 1)
    elseif b == "DOWN" then v.top = math.min(maxTop, v.top + 1)
    elseif b == "L2" or b == "LEFT" then v.top = math.max(0, v.top - 15)
    elseif b == "R2" or b == "RIGHT" then v.top = math.min(maxTop, v.top + 15)
    elseif b == "X" then
      Modal.show("Clear " .. v.cat.label .. "?",
        "Delete all " .. v.cat.label .. " files (" .. v.total .. ")?",
        { accept_label = "Delete", cancel_label = "Cancel", color = K.C.bad,
          on_accept = function() clear_cat(v.cat); S.viewer = nil; build_list() end })
    elseif b == "B" or b == "A" then
      S.viewer = nil
    end
    return
  end

  -- settings
  if S.mode == "settings" then
    local row = S.settings_list:cur()
    if b == "UP" then if S.settings_list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.settings_list:move(1) then SFX.play("menu_move") end
    elseif b == "LEFT" and row then
      if row.kind == "choice" then step_choice(row, -1)
      elseif row.kind == "toggle" then row.set(false); SFX.play("menu_toggleoption") end
    elseif b == "RIGHT" and row then
      if row.kind == "choice" then step_choice(row, 1)
      elseif row.kind == "toggle" then row.set(true); SFX.play("menu_toggleoption") end
    elseif b == "A" and row then
      if row.kind == "choice" then step_choice(row, 1)
      elseif row.kind == "toggle" then row.set(not row.get()); SFX.play("menu_toggleoption") end
    elseif b == "B" or b == "START" then S.mode = "list"; SFX.play("menu_back") end
    return
  end

  -- list
  local row = S.list:cur()
  if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
  elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
  elseif b == "A" and row then open_viewer(row.cat)
  elseif b == "X" and row then
    Modal.show("Clear " .. row.cat.label .. "?",
      "Delete all " .. row.cat.label .. " files?",
      { accept_label = "Delete", cancel_label = "Cancel", color = K.C.bad,
        on_accept = function() clear_cat(row.cat); build_list() end })
  elseif b == "Y" then S.mode = "settings"; SFX.play("menu_flip")
  elseif b == "START" then
    Modal.show("Clear all logs?", "Delete every log file?",
      { accept_label = "Delete all", cancel_label = "Cancel", color = K.C.bad,
        on_accept = function()
          os.execute("rm -f data/logs/*.log data/logs/*.log.1 2>/dev/null")
          Notify.show("success", "All logs cleared")
          build_list()
        end })
  elseif b == "B" then require("ui").back() end
end

local function draw_header()
  local m = K.MARGIN
  K.color(K.acc, 0.16)
  love.graphics.circle("fill", m + 26, 40, 26)
  K.color(K.acc, 1)
  love.graphics.setLineWidth(1.6)
  love.graphics.circle("line", m + 26, 40, 26)
  love.graphics.setLineWidth(1)
  K.draw_tool_icon("info", m + 26, 40, 26, K.acc, 1)
  K.text("title", "Diagnostics", m + 60, 14, K.C.text)
  K.text("small", "Session log · categories · cleanup", m + 60, 46, K.C.dim)
  K.color(K.acc, 1)
  love.graphics.rectangle("fill", m + 60, 68, 56, 3)
  K.color(K.C.line, 0.5)
  love.graphics.rectangle("fill", m + 116, 69, K.W - m*2 - 116, 1)
end

local function draw_session_box()
  local m = K.MARGIN
  local y, h = 80, 88
  K.panel(m, y, K.W - m*2, h, { cut = 6 })
  K.draw_tool_icon("file", m + 22, y + 14, 14, K.acc, 1)
  K.text("key", "SESSION LOG", m + 36, y + 6, K.acc)
  K.color(K.C.line, 0.5)
  love.graphics.rectangle("fill", m + 8, y + 24, K.W - m*2 - 16, 1)
  local lf = "mono"
  local ly = y + 30
  if #S.session_lines == 0 then
    K.text("small", "(empty — nothing logged yet)", m + 14, ly, K.C.faint)
    return
  end
  for _, line in ipairs(S.session_lines) do
    if ly > y + h - 12 then break end
    local col = K.C.dim
    if line:match("ERROR") or line:match("FAIL") or line:match("err") then col = K.C.bad
    elseif line:match("OK ") or line:match("success") then col = K.C.ok end
    K.text(lf, K.clip(lf, line, K.W - m*2 - 30), m + 14, ly, col, 0.9)
    ly = ly + 12
  end
end

local function draw_cat_row(row, x, y, w, h, focused)
  local c = row.cat
  K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
  K.draw_tool_icon(c.icon, x + 26, y + h/2, 20, c.color, 1)
  K.text("body", c.label, x + 46, y + h/2 - 11, focused and K.C.text or K.C.dim)
  local ntxt = row.files .. " file" .. (row.files == 1 and "" or "s")
  local sz = human_size(row.size)
  local meta = ntxt .. "  ·  " .. sz
  K.text("small", meta, x + w - K.width("small", meta) - 14, y + h/2 - 9, K.C.faint)
end

local function draw_settings()
  local m = K.MARGIN
  K.text("h", "Log Settings", m, 80, K.C.text)
  K.text("small", "Changes apply to ui.log and auto-clear on open", m, 104, K.C.faint)
  S.settings_list:draw(function(row, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if row.icon and K.draw_tool_icon then
      K.draw_tool_icon(row.icon, x + 26, y + h/2, 20, focused and K.acc or K.C.dim, focused and 1 or 0.75)
    end
    K.text("body", row.label, x + 46, y + h/2 - 11, focused and K.C.text or K.C.dim)
    local right = x + w - 14
    if row.kind == "toggle" then
      K.switch(right - 38, y + h/2, row.get(), focused)
    else
      local v = row.get()
      local vt = row.fmt and row.fmt(v) or tostring(v):upper()
      local lw = K.width("value", vt)
      K.text("value", vt, right - lw, y + h/2 - 10, focused and K.acc or K.C.text)
      if focused then
        K.text("body", "<", right - lw - 14, y + h/2 - 11, K.C.faint)
        K.text("body", ">", right + 2, y + h/2 - 11, K.C.faint)
      end
    end
  end)
end

local function draw_viewer()
  local v = S.viewer
  local m = K.MARGIN
  K.draw_tool_icon(v.cat.icon, m + 22, 90, 20, v.cat.color, 1)
  K.text("h", v.cat.label, m + 46, 78, v.cat.color)
  K.text("small", ("%d file(s) — showing latest: %s  ·  %d lines")
         :format(v.total, v.path:match("([^/]+)$") or "?", #v.lines),
         m, 104, K.C.faint)
  local box_y = 124
  local box_h = K.BOT - box_y - 12
  K.panel(m, box_y, K.W - m*2, box_h, { cut = 6 })
  local lf = "mono"
  local lines_per = math.floor((box_h - 20) / 12)
  for i = 0, lines_per - 1 do
    local idx = v.top + i + 1
    if idx > #v.lines then break end
    K.text(lf, K.clip(lf, v.lines[idx], K.W - m*2 - 24), m + 12, box_y + 10 + i*12, K.C.dim, 0.9)
  end
end

local function draw_nexus_report()
  local m = K.MARGIN
  local report = S.nexus_report or {}
  local status = report.ok and "REGISTRY HEALTHY" or "ISSUES DETECTED"
  local status_color = report.ok and K.C.ok or K.C.bad
  K.text("h", "NEXUS Registry", m, 82, K.C.text)
  K.text("small", status, m, 108, status_color)
  K.text("small", string.format("%d screens  ·  %d actions  ·  %d issues",
    report.screen_count or 0, report.action_count or 0, #(report.issues or {})),
    m + 170, 108, K.C.faint)
  local y, h = 134, K.BOT - 146
  K.panel(m, y, K.W - m * 2, h, { cut = 6 })
  local line_h = 13
  local visible = math.floor((h - 18) / line_h)
  for i = 1, visible do
    local line = S.nexus_lines[S.nexus_top + i]
    if not line then break end
    local color = K.C.dim
    if line:match("MISSING") or line:match("unknown_action") or line:match("missing_navigation") then
      color = K.C.bad
    elseif line:match("PASS") or line:match("ROUTE OK") then color = K.C.ok end
    K.text("mono", K.clip("mono", line, K.W - m * 2 - 24),
      m + 12, y + 9 + (i - 1) * line_h, color, 0.9)
  end
end

function S.draw()
  K.bg_workshop(K.t or 0)
  draw_header()
  if S.viewer then draw_viewer()
  elseif S.mode == "settings" then draw_settings()
  else
    draw_session_box()
    S.list:draw(draw_cat_row)
  end
  K.footer({
    { key = "A", label = S.mode == "nexus" and "Refresh" or (S.viewer and "Close" or (S.mode == "settings" and "Change" or "Open")) },
    { key = "X", label = S.mode == "nexus" and "Export report" or "Clear" },
    { key = "Y", label = S.mode == "nexus" and "NEXUS" or "Settings" },\n    { key = "L1/R1", label = "NEXUS report" },
    { key = "START", label = "Clear all" },
    { key = "B", label = "Back" },
  })
end

return S
