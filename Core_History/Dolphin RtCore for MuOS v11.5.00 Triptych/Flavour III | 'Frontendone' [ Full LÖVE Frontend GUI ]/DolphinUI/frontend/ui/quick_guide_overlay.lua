-- frontend/ui/quick_guide_overlay.lua
-- Multi-tab context overlay, opened with L2.
--
-- ── v0.7.0 — multi-tab ───────────────────────────────────────
--   * Non più solo "hints": ora è un vero overlay multi-tab.
--     Tab:
--       1. REFERENCE — hints globali + per-screen
--       2. NETWORK   — probe live (iface, IP, SSID, segnale, DNS)
--       3. SYSTEM    — batteria, uptime, mem, kernel, governor
--       4. ABOUT     — versione app, git, credits rapidi
--   * L1/R1 cambi tab. D-pad ↑↓ scroll nel tab corrente.
--     L2 o B o qualsiasi tasto (eccetto L1/R1/↑↓) chiude.
--   * Visual: same CRT-monitor slide-in design; ora con tab bar
--     in alto e LED strip che cambia colore in base al tab.
--
-- Trigger: main.lua apre su L2 quando non c'è un capture_mode attivo.

local A     = require("assets")
local SFX   = require("sfx")
local State = require("state")
local IM    = require("input_map")
local D     = require("ui.draw")
local GL    = require("ui.glyph")

local M = {}
local W, H = 640, 480

M._open     = false
M._enter_t  = 0
M._tab      = 1
M._scroll   = 0

-- Palette per tab (LED strip)
local TAB_COLORS = {
  {0.30, 0.85, 0.40},   -- REFERENCE — verde
  {0.20, 0.72, 0.98},   -- NETWORK   — blu
  {0.96, 0.77, 0.26},   -- SYSTEM    — ambra
  {0.55, 0.35, 0.95},   -- ABOUT     — viola
}
local TAB_NAMES = { "REFERENCE", "NETWORK", "SYSTEM", "ABOUT" }
local NUM_TABS  = 4

function M.is_open() return M._open end

function M.open()
  M._open    = true
  M._enter_t = 0
  M._tab     = 1
  M._scroll  = 0
  SFX.play("menu_select")
end

function M.close()
  M._open = false
  SFX.play("menu_back")
end

function M.toggle()
  if M._open then M.close() else M.open() end
end

function M.update(dt)
  if M._open then M._enter_t = M._enter_t + dt end
end

-- ── Input ────────────────────────────────────────────────────
function M.pad(b)
  if not M._open then return end

  if b == IM.L1 then
    M._tab = ((M._tab - 2) % NUM_TABS) + 1
    M._scroll = 0
    SFX.play("menu_pagescroll")
  elseif b == IM.R1 then
    M._tab = (M._tab % NUM_TABS) + 1
    M._scroll = 0
    SFX.play("menu_pagescroll")
  elseif b == IM.B then
    M.close()
  else
    -- qualsiasi altro bottone chiude
    M.close()
  end
end

function M.hat(dir)
  if not M._open then return end
  if     dir == "up"    then M._scroll = math.max(0, M._scroll - 24)
  elseif dir == "down"  then M._scroll = M._scroll + 24
  elseif dir == "left"  then
    M._tab = ((M._tab - 2) % NUM_TABS) + 1
    M._scroll = 0
    SFX.play("menu_pagescroll")
  elseif dir == "right" then
    M._tab = (M._tab % NUM_TABS) + 1
    M._scroll = 0
    SFX.play("menu_pagescroll")
  end
end

function M.key(k)
  if not M._open then return end
  if     k == "up"    then M._scroll = math.max(0, M._scroll - 24)
  elseif k == "down"  then M._scroll = M._scroll + 24
  elseif k == "left"  or k == "q" then
    M._tab = ((M._tab - 2) % NUM_TABS) + 1; M._scroll = 0
  elseif k == "right" or k == "e" then
    M._tab = (M._tab % NUM_TABS) + 1; M._scroll = 0
  else M.close() end
end

-- ══════════════════════════════════════════════════════════════
--  NETWORK PROBE
-- ══════════════════════════════════════════════════════════════
local NET_TTL = 5.0
local _net, _net_t = nil, -999

local function popen_first(cmd)
  local h = io.popen("timeout 2 " .. cmd .. " 2>/dev/null")
  if not h then return nil end
  local v = h:read("*l")
  h:close()
  if v and v ~= "" then return v end
  return nil
end

local function find_active_iface()
  local h = io.popen("timeout 1 ls /sys/class/net/ 2>/dev/null")
  if not h then return nil end
  local candidates = {}
  for name in h:lines() do
    if name ~= "" and name ~= "lo" then
      candidates[#candidates + 1] = name
    end
  end
  h:close()
  for _, iface in ipairs(candidates) do
    local f = io.open("/sys/class/net/" .. iface .. "/carrier", "r")
    if f then
      local v = f:read("*l"); f:close()
      if v == "1" then return iface end
    end
  end
  return nil
end

local function iface_ip(iface)
  local v = popen_first("ip -4 -o addr show " .. iface ..
    " | awk '{print $4}' | cut -d/ -f1")
  if not v then
    v = popen_first("ifconfig " .. iface ..
      " | grep -oP 'inet \\K[\\d.]+'")
  end
  return v
end

local function iface_is_wireless(iface)
  return iface:match("^wl") ~= nil
end

local function iface_ssid(iface)
  local v = popen_first("iwgetid " .. iface .. " -r")
  if v then return v end
  v = popen_first("iw dev " .. iface .. " link | awk '/SSID/ {print $2}'")
  return v
end

local function iface_signal(iface)
  local f = io.open("/proc/net/wireless", "r")
  if not f then return 0 end
  local bars = 0
  for line in f:lines() do
    local q = line:match("^%s*" .. iface .. ":%s+%d+%s+([%d%.]+)")
    if q then
      q = tonumber(q) or 0
      if     q >= 60 then bars = 4
      elseif q >= 40 then bars = 3
      elseif q >= 25 then bars = 2
      elseif q > 0   then bars = 1 end
      break
    end
  end
  f:close()
  return bars
end

local function iface_mac(iface)
  local f = io.open("/sys/class/net/" .. iface .. "/address", "r")
  if not f then return nil end
  local v = f:read("*l"); f:close()
  return v
end

local function probe_network()
  local info = {
    online = false, iface = nil, ip = nil,
    ssid = nil, signal = 0, wireless = false,
    mac = nil, gw = nil, dns = nil,
    iface_count = 0,
  }

  local iface = find_active_iface()
  if not iface then return info end
  info.online   = true
  info.iface    = iface
  info.ip       = iface_ip(iface)
  info.wireless = iface_is_wireless(iface)
  info.mac      = iface_mac(iface)
  if info.wireless then
    info.ssid   = iface_ssid(iface)
    info.signal = iface_signal(iface)
  end
  info.gw  = popen_first("ip route | awk '/default/ {print $3; exit}'")
  info.dns = popen_first("cat /etc/resolv.conf 2>/dev/null | awk '/nameserver/ {print $2; exit}'")

  -- Conta interfacce attive
  local h = io.popen("ls /sys/class/net/ 2>/dev/null")
  if h then
    local n = 0
    for name in h:lines() do
      if name ~= "" and name ~= "lo" then
        local f = io.open("/sys/class/net/" .. name .. "/carrier", "r")
        if f then
          local c = f:read("*l"); f:close()
          if c == "1" then n = n + 1 end
        end
      end
    end
    h:close()
    info.iface_count = n
  end

  return info
end

local function get_network()
  local t = (love and love.timer and love.timer.getTime()) or os.time()
  if _net and (t - _net_t) < NET_TTL then return _net end
  _net   = probe_network()
  _net_t = t
  return _net
end

-- ══════════════════════════════════════════════════════════════
--  SYSTEM PROBE
-- ══════════════════════════════════════════════════════════════
local SYS_TTL = 5.0
local _sys, _sys_t = nil, -999

local function read_file(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local v = f:read("*a"); f:close()
  return v
end

local function read_int(p)
  local v = read_file(p)
  if not v then return nil end
  return tonumber(v:match("^%s*(%d+)"))
end

local function probe_system()
  local info = {}

  -- Batteria
  for _, p in ipairs({
    "/sys/class/power_supply/battery/capacity",
    "/sys/class/power_supply/BAT0/capacity",
  }) do
    local v = read_int(p)
    if v then info.battery = v; break end
  end

  -- Uptime
  local up = read_file("/proc/uptime")
  if up then
    local secs = tonumber(up:match("^(%d+)"))
    if secs then
      info.uptime_s = secs
      local d = math.floor(secs / 86400)
      local h = math.floor((secs % 86400) / 3600)
      local m = math.floor((secs % 3600) / 60)
      if d > 0 then
        info.uptime = string.format("%dg %02dh %02dm", d, h, m)
      else
        info.uptime = string.format("%02dh %02dm", h, m)
      end
    end
  end

  -- Memoria
  local meminfo = read_file("/proc/meminfo")
  if meminfo then
    local total = tonumber(meminfo:match("MemTotal:%s+(%d+)"))
    local avail = tonumber(meminfo:match("MemAvailable:%s+(%d+)"))
    if total then
      info.mem_total_kb = total
      info.mem_used_kb  = total - (avail or 0)
      info.mem_pct      = math.floor(info.mem_used_kb * 100 / total)
    end
  end

  -- Kernel
  local ver = read_file("/proc/version")
  if ver then
    local k = ver:match("^Linux version ([^%s]+)")
    info.kernel = k
  end

  -- Governor CPU
  local gov = read_file("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
  if gov then info.governor = gov:match("^%s*(.-)%s*$") end

  -- Temperature (varie fonti)
  local tz = read_int("/sys/class/thermal/thermal_zone0/temp")
  if tz then info.temp_c = tz / 1000 end

  -- Device name
  local dev = read_file("/proc/device-tree/model")
  if dev then
    info.model = dev:gsub("%z", ""):match("^%s*(.-)%s*$")
  end

  -- Running processes (top 3)
  local ps = popen_first("ps -eo comm,pcpu --sort=-pcpu 2>/dev/null | sed -n '2,4p'")
  if ps then info.top_ps = ps end

  return info
end

local function get_system()
  local t = (love and love.timer and love.timer.getTime()) or os.time()
  if _sys and (t - _sys_t) < SYS_TTL then return _sys end
  _sys   = probe_system()
  _sys_t = t
  return _sys
end

-- ══════════════════════════════════════════════════════════════
--  CONTENT
-- ══════════════════════════════════════════════════════════════
local GLOBAL_HINTS = {
  { "r2",  "Apri download manager" },
  { "l2",  "Chiudi questa guida" },
  { "combostartselect", "Force quit frontend (tieni premuto A 1.5s)" },
}

local SCREEN_HINTS = {
  menu = {
    { "dpad",   "Naviga pannelli" },
    { "a",      "Entra" },
    { "select", "Cambia tema GC ↔ Wii" },
  },
  library = {
    { "dpad",   "Naviga griglia" },
    { "a",      "Apri dettagli" },
    { "y",      "Cicla filtro (AUTO / GC / WII / ALL)" },
    { "l1",     "Pagina precedente" },
    { "r1",     "Pagina successiva" },
    { "start",  "Quick launch" },
  },
  compatibility = {
    { "dpad",   "Naviga / Pagina" },
    { "select", "Flip sistema (GC ↔ Wii)" },
    { "start",  "Cambia modalità (SYSTEM ↔ LETTER)" },
    { "x",      "Cerca" },
    { "a",      "Dettagli" },
    { "l1",     "Lettera precedente (in mode LETTER)" },
    { "r1",     "Lettera successiva" },
  },
  game_detail = {
    { "l1",     "Tab precedente" },
    { "r1",     "Tab successivo" },
    { "up",     "Riga precedente" },
    { "down",   "Riga successiva" },
    { "left",   "Collassa" },
    { "right",  "Espandi" },
    { "a",      "Toggle / Cicla" },
    { "x",      "Cicla indietro" },
  },
  workshop = {
    { "l1",     "Area precedente" },
    { "r1",     "Area successiva" },
    { "dpad",   "Naviga item" },
    { "a",      "Entra" },
  },
  ethostore = {
    { "dpad",   "Naviga item" },
    { "a",      "Accoda download" },
    { "l1",     "Filtro categoria -" },
    { "r1",     "Filtro categoria +" },
    { "x",      "Apri download manager" },
  },
  settings = {
    { "dpad",   "Naviga" },
    { "a",      "Entra / Toggle" },
  },
  config_wizard = {
    { "up",     "Opzione precedente" },
    { "down",   "Opzione successiva" },
    { "a",      "Seleziona / Avanti" },
    { "b",      "Indietro di un passo" },
    { "x",      "Modifica nome (nel save step)" },
    { "y",      "Modifica descrizione" },
  },
  input_debug = {
    { "a",      "Avvia analisi / Conferma" },
    { "start",  "Salta step di analisi" },
    { "b",      "Indietro" },
  },
  external_input_station = {
    { "dpad",   "Naviga slot / scelta" },
    { "a",      "Azione / Burst Link" },
    { "y",      "Rinomina device" },
    { "x",      "Rimuovi device" },
    { "b",      "Indietro" },
  },
  library = {
    { "dpad",   "Naviga" },
    { "a",      "Dettagli" },
    { "y",      "Filtro" },
    { "start",  "Quick launch" },
    { "l1",     "Pagina -" },
    { "r1",     "Pagina +" },
  },
}

local FALLBACK_HINTS = {
  { "dpad", "Naviga" },
  { "a",    "Seleziona" },
  { "b",    "Indietro" },
}

local function get_screen_hints(screen)
  return SCREEN_HINTS[screen] or FALLBACK_HINTS
end

-- ══════════════════════════════════════════════════════════════
--  RENDERING
-- ══════════════════════════════════════════════════════════════
local PANEL_W  = 500
local PANEL_H  = 400
local PANEL_Y  = (H - PANEL_H) / 2
local PANEL_X  = 20
local BRACKET_W = 22

local function draw_screw(cx, cy, r)
  love.graphics.setColor(0.45, 0.46, 0.52, 1)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0.28, 0.29, 0.34, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", cx, cy, r)

  local hex = {}
  for i = 0, 5 do
    local a = math.pi / 3 * i + math.pi / 6
    hex[i*2+1] = cx + math.cos(a) * (r - 3)
    hex[i*2+2] = cy + math.sin(a) * (r - 3)
  end
  love.graphics.setColor(0.18, 0.19, 0.23, 1)
  love.graphics.polygon("fill", hex)

  love.graphics.setColor(0.55, 0.56, 0.62, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.line(cx - r + 3, cy, cx + r - 3, cy)
  love.graphics.line(cx, cy - r + 3, cx, cy + r - 3)
end

local function draw_cable(pin_x, pin_y, t)
  local col_dark  = {0.14, 0.15, 0.20}
  local col_metal = {0.35, 0.36, 0.42}
  local col_shine = {0.62, 0.63, 0.70}

  local loops = 4
  for i = 1, loops do
    local r = 16 - (i - 1) * 2.5
    local phase = t * 0.15 + i * 0.7
    love.graphics.setColor(col_dark)
    love.graphics.setLineWidth(3.5)
    love.graphics.arc("line", "open", pin_x, pin_y, r, phase, phase + math.pi * 1.4)
    love.graphics.setColor(col_metal)
    love.graphics.setLineWidth(2.0)
    love.graphics.arc("line", "open", pin_x, pin_y, r, phase, phase + math.pi * 1.4)
  end
  love.graphics.setColor(col_dark)
  love.graphics.setLineWidth(3.5)
  love.graphics.line(pin_x - 18, pin_y + 4, -20, pin_y + 30)
  love.graphics.setColor(col_metal)
  love.graphics.setLineWidth(2.0)
  love.graphics.line(pin_x - 18, pin_y + 4, -20, pin_y + 30)
  love.graphics.setColor(col_shine[1], col_shine[2], col_shine[3], 0.35)
  love.graphics.setLineWidth(1)
  love.graphics.line(pin_x - 18, pin_y + 4, -20, pin_y + 30)
  love.graphics.setLineWidth(1)
end

local function draw_hint_row(th, key, label, x, y, col)
  local BI = require("ui.button_icons")
  local icon_size = 18
  BI.draw(th, key, x, y, icon_size)

  love.graphics.setColor(0.82, 0.86, 0.94)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.print(label, x + icon_size + 10, y + 2)
end

-- ── Tab rendering ──────────────────────────────────────────

local function draw_reference_tab(th, x, y, w, h, scroll)
  love.graphics.setScissor(x, y, w, h)
  local cy = y - scroll

  love.graphics.setColor(0.30, 0.85, 0.40)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("GLOBAL", x + 8, cy)
  love.graphics.setColor(0.30, 0.85, 0.40, 0.35)
  love.graphics.rectangle("fill", x + 8, cy + 16, w - 16, 1)
  cy = cy + 24

  for _, hint in ipairs(GLOBAL_HINTS) do
    draw_hint_row(th, hint[1], hint[2], x + 8, cy, {0.55, 0.75, 0.95})
    cy = cy + 24
  end

  cy = cy + 12

  local screen_name = State.screen or "?"
  love.graphics.setColor(0.20, 0.72, 0.98)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("SCHERMATA CORRENTE  ·  " .. screen_name:upper(), x + 8, cy)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.35)
  love.graphics.rectangle("fill", x + 8, cy + 16, w - 16, 1)
  cy = cy + 24

  for _, hint in ipairs(get_screen_hints(screen_name)) do
    if cy + 22 > y + h + 40 then
      love.graphics.setColor(0.55, 0.65, 0.75)
      love.graphics.setFont(A.font(th.font_body, 10))
      love.graphics.print("… e altri", x + 8, cy)
      break
    end
    draw_hint_row(th, hint[1], hint[2], x + 8, cy, {0.35, 0.78, 0.98})
    cy = cy + 24
  end

  love.graphics.setScissor()
  return cy - (y - scroll)
end

local function draw_net_tab(th, x, y, w, h, scroll)
  love.graphics.setScissor(x, y, w, h)
  local cy = y - scroll

  local net = get_network()
  local accent = net.online and {0.30, 0.85, 0.40} or {0.90, 0.25, 0.25}

  -- Header con LED
  love.graphics.setColor(0.05, 0.06, 0.09, 0.9)
  love.graphics.rectangle("fill", x + 8, cy, w - 16, 60, 4, 4)
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.55)
  D.rough_rect(x + 8, cy, w - 16, 60, { jitter = 0.6, thickness = 1.4, seed = 71 })

  -- LED pulsante
  local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 5)
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.35 + pulse * 0.35)
  love.graphics.circle("fill", x + 32, cy + 30, 12)
  love.graphics.setColor(accent[1], accent[2], accent[3], 1)
  love.graphics.circle("fill", x + 32, cy + 30, 6)

  love.graphics.setColor(accent)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.print(net.online and "ONLINE" or "OFFLINE", x + 56, cy + 10)

  love.graphics.setColor(0.55, 0.62, 0.78)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.print(
    net.online and ((net.iface or "?") ..
      (net.iface_count > 1 and ("  +" .. (net.iface_count - 1) .. " altre") or ""))
      or "nessuna interfaccia attiva",
    x + 56, cy + 30)

  cy = cy + 72

  -- Dettagli
  local function row(label, value, col)
    love.graphics.setColor(0.55, 0.62, 0.78)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(label, x + 16, cy)
    love.graphics.setColor(col or th.text)
    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
    love.graphics.print(tostring(value or "—"), x + 150, cy)
    cy = cy + 16
  end

  row("Interfaccia",  net.iface)
  row("Indirizzo IP", net.ip)
  row("Gateway",      net.gw)
  row("DNS",          net.dns)
  row("MAC",          net.mac)

  if net.wireless then
    cy = cy + 6
    love.graphics.setColor(0.20, 0.72, 0.98)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print("WIFI", x + 16, cy)
    love.graphics.setColor(0.20, 0.72, 0.98, 0.35)
    love.graphics.rectangle("fill", x + 16, cy + 14, w - 32, 1)
    cy = cy + 22

    row("SSID", net.ssid)

    -- Barre segnale
    love.graphics.setColor(0.55, 0.62, 0.78)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print("Segnale", x + 16, cy)
    local bx = x + 150
    for i = 1, 4 do
      local bh = 4 + i * 3
      local on = i <= (net.signal or 0)
      local bc = on and accent or {0.25, 0.28, 0.32}
      love.graphics.setColor(bc[1], bc[2], bc[3], 1)
      love.graphics.rectangle("fill", bx + (i - 1) * 8, cy + (16 - bh), 5, bh, 1, 1)
    end
    love.graphics.setColor(accent)
    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
    love.graphics.print(("%d/4"):format(net.signal or 0), bx + 40, cy + 1)
    cy = cy + 22
  end

  love.graphics.setScissor()
  return cy - (y - scroll)
end

local function draw_system_tab(th, x, y, w, h, scroll)
  love.graphics.setScissor(x, y, w, h)
  local cy = y - scroll

  local sys = get_system()

  love.graphics.setColor(0.96, 0.77, 0.26)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("HARDWARE", x + 8, cy)
  love.graphics.setColor(0.96, 0.77, 0.26, 0.35)
  love.graphics.rectangle("fill", x + 8, cy + 16, w - 16, 1)
  cy = cy + 24

  local function row(label, value, col, size)
    love.graphics.setColor(0.55, 0.62, 0.78)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(label, x + 16, cy)
    love.graphics.setColor(col or th.text)
    love.graphics.setFont(A.font(
      "assets/fonts/JetBrainsMono-Regular.ttf", size or 10))
    local v = tostring(value or "—")
    if #v > 40 then v = v:sub(1, 38) .. "…" end
    love.graphics.print(v, x + 150, cy)
    cy = cy + 16
  end

  row("Modello", sys.model)
  row("Kernel",  sys.kernel)
  row("Uptime",  sys.uptime)
  row("Governor", sys.governor)

  if sys.temp_c then
    local tc = sys.temp_c
    local tc_col = tc < 50 and {0.30, 0.85, 0.40}
                or tc < 65 and {0.96, 0.77, 0.26}
                             or {0.90, 0.30, 0.30}
    row("Temperatura", string.format("%.1f °C", tc), tc_col)
  end

  if sys.battery then
    local b = sys.battery
    local bc = b > 30 and {0.30, 0.85, 0.40} or {0.90, 0.30, 0.30}
    love.graphics.setColor(0.55, 0.62, 0.78)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print("Batteria", x + 16, cy)
    love.graphics.setColor(0.15, 0.18, 0.24, 1)
    love.graphics.rectangle("fill", x + 150, cy + 2, 120, 10, 2, 2)
    love.graphics.setColor(bc)
    love.graphics.rectangle("fill", x + 150, cy + 2, 120 * b / 100, 10, 2, 2)
    love.graphics.setColor(bc)
    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 9))
    love.graphics.print(("%d%%"):format(b), x + 280, cy + 1)
    cy = cy + 22
  end

  if sys.mem_total_kb then
    cy = cy + 8
    love.graphics.setColor(0.96, 0.77, 0.26)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print("MEMORIA", x + 8, cy)
    love.graphics.setColor(0.96, 0.77, 0.26, 0.35)
    love.graphics.rectangle("fill", x + 8, cy + 16, w - 16, 1)
    cy = cy + 24

    local total_mb = math.floor(sys.mem_total_kb / 1024)
    local used_mb  = math.floor(sys.mem_used_kb / 1024)
    row("Totale",    total_mb .. " MB")
    row("Utilizzata", used_mb .. " MB (" .. sys.mem_pct .. "%)")

    -- Barra memoria
    love.graphics.setColor(0.15, 0.18, 0.24, 1)
    love.graphics.rectangle("fill", x + 16, cy, w - 32, 8, 2, 2)
    local mcol = sys.mem_pct < 70 and {0.30, 0.85, 0.40}
               or sys.mem_pct < 85 and {0.96, 0.77, 0.26}
                                     or {0.90, 0.30, 0.30}
    love.graphics.setColor(mcol)
    love.graphics.rectangle("fill", x + 16, cy, (w - 32) * sys.mem_pct / 100, 8, 2, 2)
    cy = cy + 20
  end

  if sys.top_ps and sys.top_ps ~= "" then
    cy = cy + 8
    love.graphics.setColor(0.96, 0.77, 0.26)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print("PROCESSI TOP", x + 8, cy)
    love.graphics.setColor(0.96, 0.77, 0.26, 0.35)
    love.graphics.rectangle("fill", x + 8, cy + 16, w - 16, 1)
    cy = cy + 22

    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 9))
    love.graphics.setColor(0.75, 0.82, 0.92)
    for line in sys.top_ps:gmatch("[^\n]+") do
      love.graphics.print(line, x + 16, cy)
      cy = cy + 14
    end
  end

  love.graphics.setScissor()
  return cy - (y - scroll)
end

local function draw_about_tab(th, x, y, w, h, scroll)
  love.graphics.setScissor(x, y, w, h)
  local cy = y - scroll

  love.graphics.setColor(0.55, 0.35, 0.95)
  love.graphics.setFont(A.font(th.font_title, 22))
  love.graphics.print("DolphinUI", x + 8, cy)
  cy = cy + 30

  love.graphics.setColor(0.85, 0.88, 0.94)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.print("Frontend dual-face per Dolphin Rt:Core", x + 8, cy)
  cy = cy + 14
  love.graphics.print("su muOS / Anbernic H700", x + 8, cy)
  cy = cy + 22

  love.graphics.setColor(0.55, 0.35, 0.95, 0.35)
  love.graphics.rectangle("fill", x + 8, cy, w - 16, 1)
  cy = cy + 16

  local function row(label, value)
    love.graphics.setColor(0.55, 0.62, 0.78)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(label, x + 16, cy)
    love.graphics.setColor(0.85, 0.90, 0.96)
    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
    local v = tostring(value or "—")
    if #v > 38 then v = v:sub(1, 36) .. "…" end
    love.graphics.print(v, x + 110, cy)
    cy = cy + 16
  end

  row("Versione", "v0.5.3")
  row("Build",    "FrontendONE")
  row("Runtime",  "LÖVE 11.5 / LuaJIT")
  row("Autore",   "sirpips")
  row("Lab",      "SPDW Factory")

  cy = cy + 10
  love.graphics.setColor(0.55, 0.35, 0.95)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("LINK", x + 8, cy)
  love.graphics.setColor(0.55, 0.35, 0.95, 0.35)
  love.graphics.rectangle("fill", x + 8, cy + 16, w - 16, 1)
  cy = cy + 24

  love.graphics.setColor(0.45, 0.78, 0.95)
  love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
  love.graphics.print("github.com/SilverCrow2323", x + 16, cy)
  cy = cy + 14
  love.graphics.print("github.com/SilverCrow2323/Dolphin-Core-for-MuOS",
    x + 16, cy)
  cy = cy + 24

  love.graphics.setColor(0.55, 0.62, 0.78)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.print("Premi [B] o [L2] per chiudere.", x + 16, cy)

  love.graphics.setScissor()
  return cy - (y - scroll)
end

-- ── Main draw ──────────────────────────────────────────────

function M.draw(w, h)
  if not M._open then return end
  local th = State.theme

  local ease = math.min(1, M._enter_t / 0.28)
  ease = 1 - (1 - ease) ^ 3
  local x = PANEL_X - (1 - ease) * (PANEL_W + 60)
  local y = PANEL_Y

  love.graphics.setColor(0, 0, 0, 0.35 * ease)
  love.graphics.rectangle("fill", 0, 0, W, H)

  -- Bracket metallico sinistro
  local bx = x - BRACKET_W
  love.graphics.setColor(0.20, 0.21, 0.26, ease)
  love.graphics.rectangle("fill", bx, y + 20, BRACKET_W, PANEL_H - 40, 3, 3)
  love.graphics.setColor(0.35, 0.36, 0.42, ease)
  love.graphics.rectangle("line", bx, y + 20, BRACKET_W, PANEL_H - 40, 3, 3)

  local pin_top_y = y + 50
  local pin_bot_y = y + PANEL_H - 50
  draw_cable(bx + BRACKET_W / 2, pin_top_y, M._enter_t)

  -- Corpo monitor
  love.graphics.setColor(0, 0, 0, 0.55 * ease)
  love.graphics.rectangle("fill", x + 4, y + 5, PANEL_W, PANEL_H, 10, 10)

  love.graphics.setColor(0.12, 0.13, 0.16, 0.98 * ease)
  love.graphics.rectangle("fill", x, y, PANEL_W, PANEL_H, 10, 10)

  love.graphics.setColor(0.28, 0.29, 0.34, ease)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", x + 2, y + 2, PANEL_W - 4, PANEL_H - 4, 8, 8)

  -- Glass area
  local gx, gy = x + 10, y + 68
  local gw, gh = PANEL_W - 20, PANEL_H - 78
  love.graphics.setColor(0.03, 0.05, 0.07, ease)
  love.graphics.rectangle("fill", gx, gy, gw, gh, 6, 6)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35 * ease)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", gx, gy, gw, gh, 6, 6)
  love.graphics.setLineWidth(1)

  -- Scanlines
  love.graphics.setColor(0, 0, 0, 0.10 * ease)
  for yy = gy + 2, gy + gh - 2, 3 do
    love.graphics.line(gx + 2, yy, gx + gw - 2, yy)
  end

  -- Pins
  draw_screw(bx + BRACKET_W / 2, pin_top_y, 8)
  draw_screw(bx + BRACKET_W / 2, pin_bot_y, 8)

  -- LED strip + tab bar
  local led_x = x + 20
  local led_y = y + 20
  for i = 1, NUM_TABS do
    local c = TAB_COLORS[i]
    local active = (i == M._tab)
    local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 3 + i)
    local a = active and (0.85 + pulse * 0.15) or 0.35
    love.graphics.setColor(c[1], c[2], c[3], a * ease)
    love.graphics.circle("fill", led_x + (i - 1) * 14, led_y, active and 4.5 or 3.5)
  end

  -- Title strip
  love.graphics.setColor(0.08, 0.09, 0.13, 0.9 * ease)
  love.graphics.rectangle("fill", x + 16, y + 36, PANEL_W - 32, 26, 4, 4)

  local tab_x = x + 20
  for i = 1, NUM_TABS do
    local active = (i == M._tab)
    local font = A.font(th.font_body_bold, 10)
    love.graphics.setFont(font)
    local label = TAB_NAMES[i]
    local tw = font:getWidth(label) + 16

    if active then
      local c = TAB_COLORS[i]
      love.graphics.setColor(c[1], c[2], c[3], 0.30 * ease)
      love.graphics.rectangle("fill", tab_x, y + 40, tw, 18, 9, 9)
      love.graphics.setColor(c[1], c[2], c[3], 0.95 * ease)
      love.graphics.setLineWidth(1.2)
      love.graphics.rectangle("line", tab_x, y + 40, tw, 18, 9, 9)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(1, 1, 1, ease)
    else
      love.graphics.setColor(0.55, 0.62, 0.78, 0.8 * ease)
    end
    love.graphics.printf(label, tab_x, y + 44, tw, "center")
    tab_x = tab_x + tw + 4
  end

  -- Content
  if ease < 0.6 then return end
  local alpha = math.min(1, (ease - 0.6) / 0.4)
  local cx, cy = gx + 4, gy + 4
  local cw, ch = gw - 8, gh - 8

  if     M._tab == 1 then draw_reference_tab(th, cx, cy, cw, ch, M._scroll)
  elseif M._tab == 2 then draw_net_tab(th,       cx, cy, cw, ch, M._scroll)
  elseif M._tab == 3 then draw_system_tab(th,    cx, cy, cw, ch, M._scroll)
  elseif M._tab == 4 then draw_about_tab(th,     cx, cy, cw, ch, M._scroll)
  end

  -- Footer hint
  love.graphics.setColor(0.55, 0.65, 0.78, alpha * 0.85)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("[L1/R1] Cambia tab   [D-pad ↑↓] Scroll   [B] Chiudi",
    gx, y + PANEL_H - 20, gw, "center")

  love.graphics.setColor(1, 1, 1, 0.06 * alpha)
  love.graphics.rectangle("fill", gx + 2, gy + 2, gw - 4, 2, 2, 2)
end

return M