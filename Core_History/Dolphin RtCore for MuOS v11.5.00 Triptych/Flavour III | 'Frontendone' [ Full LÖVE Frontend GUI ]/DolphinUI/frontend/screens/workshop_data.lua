-- screens/workshop_data.lua — Data Gathering hub.
-- Logger and Debugger are read from Logger.ini once per enter/toggle.
-- The per-frame draw only reads from the cached booleans.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")
local BI      = require("ui.button_icons")
local PM      = require("profile_manager")
local Notify  = require("notify")

local S = {}
local W, H = 640, 480
S.sel = 1

-- Cached logger/debugger state, refreshed on enter and after toggles.
S._logger_on   = false
S._debugger_on = false
S._report_n    = 0

local ITEMS = {
  { key = "logger",   label = "Logger",
    icon = "logging",  color = {0.96, 0.77, 0.26} },
  { key = "debugger", label = "Debugger",
    icon = "debugger", color = {0.90, 0.30, 0.30} },
  { key = "report",   label = "Test Report",
    icon = "save",     color = {0.30, 0.80, 0.60} },
}

local LOGGER_INI = "dolphin-emu/Config/Logger.ini"

-- ── Logger / Debugger state readers ─────────────────────────
local function read_logger_ini()
  local out = {}
  local f = io.open(LOGGER_INI, "r")
  if not f then return out end
  local section = nil
  for line in f:lines() do
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then
      section = s
    else
      local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
      if k and section then
        k = k:match("^%s*(.-)%s*$")
        v = v:match("^%s*(.-)%s*$")
        out[section] = out[section] or {}
        out[section][k] = v
      end
    end
  end
  f:close()
  return out
end

local function is_logger_enabled()
  local data = read_logger_ini()
  return (data.Options or {}).WriteToFile == "True"
end

local function is_debugger_enabled()
  local data = read_logger_ini()
  return (tonumber((data.Options or {}).Verbosity) or 0) >= 5
end

local function refresh_cache()
  S._logger_on   = is_logger_enabled()
  S._debugger_on = is_debugger_enabled()
  local ok, RS = pcall(require, "report_store")
  S._report_n = ok and RS and #RS.list() or 0
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  S.sel = 1
  refresh_cache()
end

function S.re_enter() refresh_cache() end

local function move(delta)
  local n = #ITEMS
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
  end
end

local function activate()
  local it = ITEMS[S.sel]
  SFX.play("menu_select")

  if it.key == "logger" then
    local target = S._logger_on and "Disabled" or "Verbose"
    if PM.apply("logging", target) then
      Notify.show(S._logger_on and "info" or "success",
        S._logger_on and "Logger disabled" or "Logger enabled")
      S._logger_on = not S._logger_on
    else
      Notify.show("error", "Logger profile missing: " .. target)
    end

  elseif it.key == "debugger" then
    local verb = S._debugger_on and "4" or "5"
    local data = read_logger_ini()
    if not data.Options then
      Notify.show("error", "Logger.ini missing")
      return
    end
    -- Rewrite [Options] Verbosity in place, preserving other sections.
    local lines = {}
    local f = io.open(LOGGER_INI, "r")
    if not f then
      Notify.show("error", "Logger.ini missing")
      return
    end
    local in_options = false
    local saw_verbosity = false
    for line in f:lines() do
      local stripped = line:match("^%s*(.-)%s*$")
      if stripped:match("^%[Options%]$") then
        in_options = true
        table.insert(lines, line)
      elseif stripped:match("^%[") then
        if in_options and not saw_verbosity then
          table.insert(lines, "Verbosity = " .. verb)
          saw_verbosity = true
        end
        in_options = false
        table.insert(lines, line)
      elseif in_options and stripped:match("^Verbosity%s*=") then
        table.insert(lines, "Verbosity = " .. verb)
        saw_verbosity = true
      else
        table.insert(lines, line)
      end
    end
    f:close()
    if in_options and not saw_verbosity then
      table.insert(lines, "Verbosity = " .. verb)
    end
    local w = io.open(LOGGER_INI .. ".tmp", "w")
    if w then
      for _, l in ipairs(lines) do w:write(l .. "\n") end
      w:close()
      os.remove(LOGGER_INI)
      os.rename(LOGGER_INI .. ".tmp", LOGGER_INI)
      Notify.show(S._debugger_on and "info" or "success",
        S._debugger_on and "Debugger disabled" or "Debugger enabled")
      S._debugger_on = not S._debugger_on
    else
      Notify.show("error", "Cannot write Logger.ini")
    end

  elseif it.key == "report" then
    State.go("report_window")
  end
end

function S.pad(b) if b == IM.A then activate() end end
function S.hat(dir)
  if dir == "up" then move(-1)
  elseif dir == "down" then move(1) end
end
function S.key(k)
  if k == "up" then move(-1)
  elseif k == "down" then move(1)
  elseif k == "return" or k == "space" then activate() end
end

-- ── Draw ────────────────────────────────────────────────────
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("DATA GATHERING", "logging")

  local y = 90
  local t = State.t_ui or 0
  for i, it in ipairs(ITEMS) do
    local focused = (i == S.sel)
    local x, w, h = 40, W - 80, 66
    local c = it.color
    local status = ""

    if     it.key == "logger"   then status = S._logger_on   and "ON" or "OFF"
    elseif it.key == "debugger" then status = S._debugger_on and "ON" or "OFF"
    elseif it.key == "report"   then status = S._report_n .. " saved" end

    if focused then
      local pulse = 0.5 + 0.5 * math.sin(t * 4)
      D.glow(x + w/2, y + h/2, 70, c, 0.7 + pulse * 0.25)
    end
    love.graphics.setColor(focused and c[1]*0.32 or c[1]*0.12,
                           focused and c[2]*0.32 or c[2]*0.12,
                           focused and c[3]*0.32 or c[3]*0.12, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
    love.graphics.rectangle("fill", x, y, 3, h)

    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h, { jitter = focused and 1.2 or 0.8,
        thickness = focused and 2.5 or 1.5, seed = i * 11 })
    if focused then D.corner_brackets(x, y, w, h, c, 12) end

    Icons.draw(it.icon, x + 18, y + 20, 26, c)

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 15))
    love.graphics.print(it.label, x + 58, y + 12)

    local st_col = (status == "ON" or status:match("saved"))
      and {0.30, 0.80, 0.40} or {0.55, 0.55, 0.62}
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    local stw = love.graphics.getFont():getWidth(status) + 14
    love.graphics.setColor(st_col[1], st_col[2], st_col[3], 0.85)
    love.graphics.rectangle("fill", x + 58, y + 38, stw, 16, 8, 8)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(status, x + 58, y + 41, stw, "center")

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print("// " .. (it.key == "report" and "generate" or "toggle"),
        x + 58 + stw + 10, y + 41)

    if focused then
      local badge_size = 14
      local font = A.font(th.font_body, 9)
      local label = (it.key == "report" and "Open" or "Toggle")
      local tw = font:getWidth(label)
      local sx = x + w - badge_size - 4 - tw - 12
      BI.draw(th, "a", sx, y + h - 20, badge_size)
      love.graphics.setColor(th.text_dim)
      love.graphics.setFont(font)
      love.graphics.print(label, sx + badge_size + 4, y + h - 17)
    end

    y = y + h + 8
  end

  BI.draw_hint_centered("[↑↓] Nav   [A] Toggle   [B] Back",
      W, H - 22, A.font(th.font_body, 12), th)
end

return S