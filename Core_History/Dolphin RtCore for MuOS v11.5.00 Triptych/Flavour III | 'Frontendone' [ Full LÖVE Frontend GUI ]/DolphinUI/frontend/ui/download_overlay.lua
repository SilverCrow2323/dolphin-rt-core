-- frontend/ui/download_overlay.lua
-- Download queue overlay with three pages, opened with R2.
--
-- ── v0.5.2 — install target layout fix ───────────────────────
--   * The install-target sub-overlay used to draw the option label
--     and the target path on the same 40px row, at y+4 and y+19
--     respectively. With a mono path font the two lines overlapped
--     (visible in v0.5.1 screenshots: "Install" sat on top of
--     "codes"). Rows are now 48px tall, label on row 1, path on
--     row 2, no overlap possible.
--   * Panel height formula updated: 80 + N*48 + 60.
--   * All strings translated to English.
--
-- v0.5.1 — icon footers
--   * Footers use procedural button badges via the shared hint
--     pipeline.
--
-- v0.4.x
--   * Persistence of scroll position on close.
--   * Mini bar drawn by main.lua when overlay is closed.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BI     = require("ui.button_icons")
local DL     = require("downloader")
local Notify = require("notify")

local M = {}

local NET_TTL = 5.0

local function now_t()
  if love and love.timer then return love.timer.getTime() end
  return os.time()
end

-- ── State ───────────────────────────────────────────────────
M._open          = false
M._page          = 1
M._sel           = 1
M._scroll        = 0
M._net           = nil
M._net_t         = -999
M._target_choice = nil
M._enter_t       = 0
M._eta_ref       = {}

local PAGE_COUNT = 3
local PAGE_NAMES = { "QUEUE", "DETAIL", "BATCH" }

function M.is_open() return M._open end

function M.open()
  M._open          = true
  M._page          = 1
  M._sel           = 1
  M._scroll        = 0
  M._target_choice = nil
  M._net_t         = -999
  M._enter_t       = 0
  M._eta_ref       = {}
  SFX.play("livemenu_open")
end

function M.close()
  M._open          = false
  M._target_choice = nil
  SFX.play("menu_back")
end

function M.toggle()
  if M._open then M.close() else M.open() end
end

-- ── Network probe ───────────────────────────────────────────
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
      if     q >= 60 then bars = 3
      elseif q >= 40 then bars = 2
      elseif q > 0   then bars = 1 end
      break
    end
  end
  f:close()
  return bars
end

local function probe_network()
  local info = { online = false, iface = nil, ip = nil,
                 ssid = nil, signal = 0, wireless = false }
  local iface = find_active_iface()
  if not iface then return info end
  info.online   = true
  info.iface    = iface
  info.ip       = iface_ip(iface)
  info.wireless = iface_is_wireless(iface)
  if info.wireless then
    info.ssid   = iface_ssid(iface)
    info.signal = iface_signal(iface)
  end
  return info
end

local function get_network()
  local t = now_t()
  if M._net and (t - M._net_t) < NET_TTL then return M._net end
  M._net   = probe_network()
  M._net_t = t
  return M._net
end

-- ── List helpers ────────────────────────────────────────────
local function list() return DL.list() end

local function move(delta)
  local n = #list()
  if n == 0 then return end
  local ni = math.max(1, math.min(n, M._sel + delta))
  if ni ~= M._sel then
    M._sel = ni
    SFX.play("menu_move")
    M._eta_ref = {}
  end
end

local function open_install_choices()
  local e = list()[M._sel]
  if not e or e.status ~= "awaiting_install" then return end
  local opts = DL.install_choices(e)
  if #opts == 0 then
    Notify.show("warning", "No install target available")
    return
  end
  M._target_choice = { entry = e, options = opts, sel = 1 }
  SFX.play("menu_select")
end

local function close_install_choices()
  M._target_choice = nil
  SFX.play("menu_back")
end

local function confirm_choice()
  local tc = M._target_choice
  if not tc then return end
  local opt = tc.options[tc.sel]
  if not opt then return end
  DL.confirm_install(tc.entry.item_id, opt.path)
  SFX.play("menu_toggleoption")
  M._target_choice = nil
end

local function move_target(delta)
  local tc = M._target_choice
  if not tc then return end
  local ni = math.max(1, math.min(#tc.options, tc.sel + delta))
  if ni ~= tc.sel then
    tc.sel = ni
    SFX.play("menu_move")
  end
end

-- ── Per-entry actions ───────────────────────────────────────
local function delete_focused()
  local e = list()[M._sel]
  if not e then return end
  if (e.status == "done") and not e.archive_cleaned then
    DL.cleanup_archive(e.item_id)
    Notify.show("info", "Archive deleted")
    return
  end
  if e.status == "done" or e.status == "error" or e.status == "cancelled" then
    DL.remove(e.item_id)
    SFX.play("menu_back")
    M._sel = math.max(1, M._sel - 1)
    return
  end
  if e.status == "downloading" or e.status == "extracting" then
    DL.cancel(e.item_id)
    Notify.show("info", "Cancelled")
  end
end

local function retry_focused()
  local e = list()[M._sel]
  if not e then return end
  if e.status ~= "error" then return end
  if DL.retry then
    DL.retry(e.item_id)
  else
    local snapshot = {
      id = e.item_id, name = e.name, version = e.version,
      download_url = e.url, icon_url = e.icon_url, size_mb = e.size_mb,
      install_paths = e.install_paths, install_path = e.install_path,
      extract_into = e.extract_into, extract_contains = e.extract_contains,
    }
    DL.remove(e.item_id)
    DL.enqueue(snapshot, { target_kind = e.target_kind })
  end
  Notify.show("info", "Retrying: " .. (e.name or "?"))
  M._sel = math.max(1, M._sel - 1)
  SFX.play("menu_toggleoption")
end

-- ── Batch operations ────────────────────────────────────────
local function batch_cancel_all()
  local n = 0
  for _, e in ipairs(list()) do
    if e.status == "downloading" or e.status == "extracting"
       or e.status == "queued" then
      DL.cancel(e.item_id)
      n = n + 1
    end
  end
  Notify.show(n > 0 and "info" or "warning",
    n > 0 and ("Cancelled " .. n .. " download(s)") or "Nothing active")
  SFX.play("menu_back")
end

local function batch_cleanup_archives()
  local n = 0
  for _, e in ipairs(list()) do
    if e.status == "done" and not e.archive_cleaned then
      DL.cleanup_archive(e.item_id)
      n = n + 1
    end
  end
  Notify.show(n > 0 and "info" or "warning",
    n > 0 and ("Cleaned " .. n .. " archive(s)") or "No archives to clean")
  SFX.play("menu_toggleoption")
end

local function batch_retry_failed()
  local n = 0
  for _, e in ipairs(list()) do
    if e.status == "error" then
      local snapshot = {
        id = e.item_id, name = e.name, version = e.version,
        download_url = e.url, icon_url = e.icon_url, size_mb = e.size_mb,
        install_paths = e.install_paths, install_path = e.install_path,
        extract_into = e.extract_into, extract_contains = e.extract_contains,
      }
      local target_kind = e.target_kind
      DL.remove(e.item_id)
      DL.enqueue(snapshot, { target_kind = target_kind })
      n = n + 1
    end
  end
  Notify.show(n > 0 and "info" or "warning",
    n > 0 and ("Retrying " .. n .. " failed") or "No failed downloads")
  SFX.play("menu_toggleoption")
end

local function batch_clear_completed()
  local n = 0
  if DL.clear_finished then
    n = DL.clear_finished()
  else
    for i = #list(), 1, -1 do
      local e = list()[i]
      if e.status == "done" or e.status == "cancelled" then
        DL.remove(e.item_id)
        n = n + 1
      end
    end
  end
  Notify.show(n > 0 and "info" or "warning",
    n > 0 and ("Cleared " .. n .. " entr(ies)") or "Nothing to clear")
  M._sel = 1
  SFX.play("menu_back")
end

-- ── Input API ───────────────────────────────────────────────
local function cycle_page(delta)
  M._page = ((M._page - 1 + delta) % PAGE_COUNT) + 1
  M._sel  = 1
  M._scroll = 0
  SFX.play("menu_pagescroll")
end

function M.pad(b)
  if not M._open then return end

  if M._target_choice then
    if     b == IM.A then confirm_choice()
    elseif b == IM.B then close_install_choices() end
    return
  end

  if b == IM.L1 then cycle_page(-1); return end
  if b == IM.R1 then cycle_page(1); return end

  if M._page == 1 then
    if     b == IM.A then open_install_choices()
    elseif b == IM.X then delete_focused()
    elseif b == IM.B then M.close() end
  elseif M._page == 2 then
    local e = list()[M._sel]
    if not e then return end
    if b == IM.A then
      if e.status == "awaiting_install" then
        M._page = 1
        open_install_choices()
      end
    elseif b == IM.X then
      retry_focused()
    elseif b == IM.Y then
      if (e.status == "done") and not e.archive_cleaned then
        DL.cleanup_archive(e.item_id)
        Notify.show("info", "Archive deleted")
      end
    elseif b == IM.B then M.close() end
  elseif M._page == 3 then
    if     b == IM.A     then batch_cancel_all()
    elseif b == IM.X     then batch_cleanup_archives()
    elseif b == IM.Y     then batch_retry_failed()
    elseif b == IM.START then batch_clear_completed()
    elseif b == IM.B     then M.close() end
  end
end

function M.hat(dir)
  if not M._open then return end
  if M._target_choice then
    if     dir == "up"   then move_target(-1)
    elseif dir == "down" then move_target(1) end
    return
  end
  if M._page == 1 or M._page == 2 then
    if     dir == "up"   then move(-1)
    elseif dir == "down" then move(1) end
  end
end

function M.key(k)
  if not M._open then return end
  if M._target_choice then
    if     k == "up"    then move_target(-1)
    elseif k == "down"  then move_target(1)
    elseif k == "return" or k == "space" then confirm_choice()
    elseif k == "escape" then close_install_choices() end
    return
  end
  if     k == "q" then cycle_page(-1); return end
  if     k == "e" then cycle_page(1); return end
  if     k == "up"    then M.hat("up")
  elseif k == "down"  then M.hat("down")
  elseif k == "return" or k == "space" then M.pad(IM.A)
  elseif k == "x"     then M.pad(IM.X)
  elseif k == "y"     then M.pad(IM.Y)
  elseif k == "escape" then M.close() end
end

function M.update(dt)
  if not M._open then return end
  M._enter_t = M._enter_t + dt
  get_network()
end

-- ══════════════════════════════════════════════════════════════
--  Mini bar (drawn by main.lua after Notify.draw)
-- ══════════════════════════════════════════════════════════════
function M.draw_mini_bar(w, h)
  if M._open then return end

  local queue = list()
  local active = nil
  for _, e in ipairs(queue) do
    if e.status == "downloading" then active = e; break end
  end
  if not active then return end

  local th = State.theme
  local x  = 20
  local y  = h - 88
  local bw = w - 40
  local bh = 36

  love.graphics.setColor(0.03, 0.04, 0.08, 0.92)
  love.graphics.rectangle("fill", x, y, bw, bh, 6, 6)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.45)
  D.rough_rect(x, y, bw, bh, { jitter = 0.5, thickness = 1.2, seed = 71 })

  local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 6)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.30 + pulse * 0.55)
  love.graphics.circle("fill", x + 12, y + 12, 5)
  love.graphics.setColor(0.45, 0.88, 1.00, 1)
  love.graphics.circle("fill", x + 12, y + 12, 2.5)

  local ring_r  = 12
  local ring_cx = x + bw - ring_r - 10
  local ring_cy = y + bh / 2

  local total = active.size_mb or 0
  local done  = (active.progress_bytes or 0) / (1024 * 1024)
  local p     = (total > 0) and math.min(1, done / total) or 0

  local name = active.name or "?"
  local max_name_w = bw - 26 - (ring_r * 2 + 20) - 60
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  while love.graphics.getFont():getWidth(name .. "…") > max_name_w
        and #name > 4 do
    name = name:sub(1, -2)
  end
  love.graphics.setColor(0.85, 0.90, 0.95)
  love.graphics.print(name, x + 24, y + 6)

  love.graphics.setColor(0.30, 0.85, 0.40)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  local ptxt = ("%d%%"):format(math.floor(p * 100))
  local ptw = love.graphics.getFont():getWidth(ptxt)
  love.graphics.print(ptxt, ring_cx - ptw - 10, y + 5)

  local bar_x = x + 8
  local bar_y = y + 22
  local bar_w = bw - (ring_r * 2 + 26) - 12
  local bar_h = 8

  love.graphics.setColor(0.15, 0.18, 0.24, 1)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 4, 4)

  if p > 0 then
    love.graphics.setColor(0.30, 0.85, 0.40, 1)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * p, bar_h, 4, 4)
    love.graphics.setColor(0.70, 1.0, 0.75, 0.85)
    love.graphics.rectangle("fill",
      bar_x + bar_w * p - 2, bar_y, 2, bar_h, 1, 1)
  end

  love.graphics.setColor(0.15, 0.18, 0.24, 1)
  love.graphics.setLineWidth(2.5)
  love.graphics.circle("line", ring_cx, ring_cy, ring_r)

  if p > 0 then
    love.graphics.setColor(0.30, 0.85, 0.40, 1)
    love.graphics.setLineWidth(2.5)
    love.graphics.arc("line", "open", ring_cx, ring_cy, ring_r,
      -math.pi / 2, -math.pi / 2 + 2 * math.pi * p)
  end
  love.graphics.setLineWidth(1)
end

-- ══════════════════════════════════════════════════════════════
--  Rendering helpers
-- ══════════════════════════════════════════════════════════════
local function status_color(status)
  if status == "queued"           then return {0.55, 0.60, 0.72} end
  if status == "downloading"      then return {0.20, 0.72, 0.98} end
  if status == "awaiting_install" then return {0.96, 0.77, 0.26} end
  if status == "extracting"       then return {0.90, 0.60, 0.20} end
  if status == "done"             then return {0.30, 0.80, 0.40} end
  if status == "error"            then return {0.90, 0.30, 0.30} end
  if status == "cancelled"        then return {0.55, 0.55, 0.62} end
  return {0.55, 0.55, 0.62}
end

local function status_label(status)
  if status == "queued"           then return "QUEUED"           end
  if status == "downloading"      then return "DOWNLOADING"      end
  if status == "awaiting_install" then return "READY TO INSTALL" end
  if status == "extracting"       then return "EXTRACTING"       end
  if status == "done"             then return "DONE"             end
  if status == "error"            then return "ERROR"            end
  if status == "cancelled"        then return "CANCELLED"        end
  return status:upper()
end

local function fmt_mb(mb)
  if not mb or mb <= 0 then return "?" end
  if mb < 1 then return ("%d KB"):format(math.floor(mb * 1024)) end
  if mb < 1024 then return ("%.1f MB"):format(mb) end
  return ("%.2f GB"):format(mb / 1024)
end

local function fmt_eta(seconds)
  if not seconds or seconds <= 0 or seconds > 3600 * 24 then return "—" end
  local s = math.floor(seconds)
  if s < 60 then return ("%ds"):format(s) end
  if s < 3600 then return ("%dm %ds"):format(math.floor(s / 60), s % 60) end
  return ("%dh %dm"):format(math.floor(s / 3600), math.floor((s % 3600) / 60))
end

local function estimate_eta(e)
  local total = (e.size_mb or 0) * 1024 * 1024
  local done  = e.progress_bytes or 0
  if total <= 0 or done <= 0 then return nil end

  local t = now_t()
  local ref = M._eta_ref[e.item_id]
  if not ref then
    M._eta_ref[e.item_id] = { bytes = done, t = t }
    return nil
  end
  if t - ref.t < 1.0 then return nil end
  local dbytes = done - ref.bytes
  local dt     = t - ref.t
  if dbytes <= 0 or dt <= 0 then
    M._eta_ref[e.item_id] = { bytes = done, t = t }
    return nil
  end
  local rate = dbytes / dt
  M._eta_ref[e.item_id] = { bytes = done, t = t }
  return (total - done) / rate
end

local function draw_overlay_hints(str, px, py, pw, font, th)
  local items = {}
  for _, tk in ipairs(BI.parse_hint(str)) do
    if tk.key then
      local mapped = tk.key:upper()
      local aliases = {
        ["↑↓"] = "dpad", ["←→"] = "dpad",
        ["↑"] = "dpad", ["↓"] = "dpad",
        ["←"] = "dpad", ["→"] = "dpad",
      }
      mapped = aliases[tk.key] or mapped:lower()
      items[#items + 1] = { key = mapped, label = tk.label }
    elseif tk.label and tk.label ~= "" then
      items[#items + 1] = { label = tk.label }
    end
  end
  if #items == 0 then return end

  local badge_size, inner_pad, gap = 18, 6, 10
  local total = 0
  local widths = {}
  for i, it in ipairs(items) do
    local w = 0
    if it.key then
      w = badge_size
      if it.label and it.label ~= "" then
        w = w + inner_pad + font:getWidth(it.label)
      end
    else
      w = font:getWidth(it.label or "")
    end
    widths[i] = w
    total = total + w + (i < #items and gap or 0)
  end

  local x = math.floor(px + (pw - total) / 2)
  for i, it in ipairs(items) do
    if it.key then
      BI.draw(th, it.key, x, py + 1, badge_size)
      x = x + badge_size
      if it.label and it.label ~= "" then
        love.graphics.setFont(font)
        love.graphics.setColor(th.text_dim)
        love.graphics.print(it.label, x + inner_pad,
          py + math.floor((badge_size - font:getHeight()) / 2) + 1)
        x = x + inner_pad + font:getWidth(it.label)
      end
    else
      love.graphics.setFont(font)
      love.graphics.setColor(th.text_dim)
      love.graphics.print(it.label, x, py + 2)
      x = x + font:getWidth(it.label)
    end
    if i < #items then x = x + gap end
  end
end

-- ══════════════════════════════════════════════════════════════
--  Network probe panel
-- ══════════════════════════════════════════════════════════════
local function draw_net_probe(x, y, w, h, th)
  local net = get_network()

  love.graphics.setColor(0.04, 0.05, 0.09, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)

  local accent = net.online and {0.30, 0.85, 0.40} or {0.90, 0.25, 0.25}
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.55)
  D.rough_rect(x, y, w, h, { jitter = 0.7, thickness = 1.4, seed = 77 })

  love.graphics.setColor(0.20, 0.72, 0.98, 0.85)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print("NETWORK PROBE", x + 12, y + 8)

  local led_x = x + w - 18
  local led_y = y + 14
  local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 5)
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.35 + pulse * 0.35)
  love.graphics.circle("fill", led_x, led_y, 8)
  love.graphics.setColor(accent[1], accent[2], accent[3], 1)
  love.graphics.circle("fill", led_x, led_y, 4)

  local state_txt
  if net.online then
    state_txt = "ONLINE  ·  " .. (net.iface or "?") ..
                (net.ip and ("  ·  " .. net.ip) or "")
  else
    state_txt = "OFFLINE"
  end
  love.graphics.setColor(net.online and {0.85, 0.95, 0.88}
                                 or {0.95, 0.75, 0.75})
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.print(state_txt, x + 12, y + 26)

  if net.online and net.wireless then
    if net.ssid and net.ssid ~= "" then
      love.graphics.setColor(0.75, 0.82, 0.92)
      love.graphics.setFont(A.font(th.font_body, 10))
      love.graphics.print("SSID: " .. net.ssid, x + 12, y + 44)
    end

    local bx = x + w - 78
    local by = y + 48
    for i = 1, 4 do
      local bh = 4 + i * 3
      local on = i <= net.signal
      local bc = on and {0.30, 0.85, 0.40} or {0.25, 0.28, 0.32}
      love.graphics.setColor(bc[1], bc[2], bc[3], 1)
      love.graphics.rectangle("fill", bx + (i-1) * 7, by + (16 - bh), 5, bh,
        1, 1)
    end
    love.graphics.setColor(0.60, 0.68, 0.80)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.printf(("signal %d/4"):format(net.signal),
      x + w - 100, y + h - 18, 90, "right")
  elseif not net.online then
    love.graphics.setColor(0.75, 0.55, 0.55)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print("Check Wi-Fi in muOS settings", x + 12, y + 44)
  end
end

-- ══════════════════════════════════════════════════════════════
--  Page tabs
-- ══════════════════════════════════════════════════════════════
local function draw_page_tabs(th, px, py, pw)
  local x = px + 16
  local y = py + 8
  for i, name in ipairs(PAGE_NAMES) do
    local font = A.font(th.font_body_bold, 10)
    love.graphics.setFont(font)
    local w = font:getWidth(name) + 20
    local active = (i == M._page)
    love.graphics.setColor(
      active and th.focus[1]*0.35 or 0.08,
      active and th.focus[2]*0.35 or 0.09,
      active and th.focus[3]*0.35 or 0.12, 0.95)
    love.graphics.rectangle("fill", x, y, w, 18, 3, 3)
    love.graphics.setColor(active and {1,1,1} or th.text_dim)
    love.graphics.printf(name, x, y + 3, w, "center")
    if active then
      love.graphics.setColor(th.focus)
      D.rough_rect(x, y, w, 18,
        { jitter = 0.5, thickness = 1.4, seed = i * 7 })
    end
    x = x + w + 4
  end

  draw_overlay_hints("[L1/R1] Page   [B] Close",
    px + pw - 220, py + 12, 220,
    A.font(th.font_body, 9), th)
end

-- ══════════════════════════════════════════════════════════════
--  Page 1: QUEUE
-- ══════════════════════════════════════════════════════════════
local function draw_row(e, i, focused, y, x, w, h, th)
  local c = status_color(e.status)

  if focused then
    love.graphics.setColor(c[1], c[2], c[3], 0.15)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(c)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(c)
  love.graphics.circle("fill", x + 14, y + h/2, 4)

  love.graphics.setColor(focused and {1, 1, 1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 12))
  local name = e.name or "?"
  if #name > 40 then name = name:sub(1, 38) .. "…" end
  love.graphics.print(name, x + 26, y + 5)

  local slabel = status_label(e.status)
  love.graphics.setFont(A.font(th.font_body_bold, 8))
  local slw = love.graphics.getFont():getWidth(slabel) + 12
  love.graphics.setColor(c[1], c[2], c[3], 0.85)
  love.graphics.rectangle("fill", x + w - slw - 8, y + 4, slw, 14, 7, 7)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.printf(slabel, x + w - slw - 8, y + 6, slw, "center")

  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.setColor(th.text_dim)
  local info = ""
  if e.status == "downloading" then
    local mb_done  = (e.progress_bytes or 0) / (1024 * 1024)
    local mb_total = e.size_mb or 0
    info = ("%.1f / %.1f MB"):format(mb_done, mb_total)
  elseif e.status == "awaiting_install" then
    info = "Downloaded — [A] to install"
  elseif e.status == "extracting" then
    info = "Extracting archive…"
  elseif e.status == "done" then
    info = e.skipped_install and "Downloaded only"
      or (e.archive_cleaned and "Installed · archive cleaned"
                            or "Installed · [X] delete archive")
  elseif e.status == "error" then
    info = "Error: " .. (e.error or "?")
  elseif e.status == "queued" then
    info = "Waiting in queue…"
  elseif e.status == "cancelled" then
    info = "Cancelled — [X] to remove"
  end
  love.graphics.print(info, x + 26, y + 22)

  if e.status == "downloading" then
    local bar_x, bar_y = x + 26, y + h - 10
    local bar_w = w - 40
    love.graphics.setColor(0.15, 0.18, 0.25, 1)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, 4, 2, 2)
    local p = 0
    if e.size_mb and e.size_mb > 0 then
      p = math.min(1, ((e.progress_bytes or 0) /
        (1024 * 1024)) / e.size_mb)
    end
    love.graphics.setColor(c)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * p, 4, 2, 2)
  end
end

local function draw_page_queue(th, list_x, list_y, list_w, list_h)
  local queue = list()
  if #queue == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf(
      "No downloads in queue.\n\nTrigger one from the Rt:Enhancer Dock.",
      list_x, list_y + list_h/2 - 20, list_w, "center")
    return
  end

  local ROW_H = 46
  local y0 = (M._sel - 1) * ROW_H
  if y0 < M._scroll then M._scroll = y0
  elseif y0 + ROW_H > M._scroll + list_h then
    M._scroll = y0 + ROW_H - list_h
  end

  love.graphics.setScissor(list_x, list_y, list_w, list_h)
  local y = list_y - M._scroll
  for i, e in ipairs(queue) do
    if y + ROW_H >= list_y and y <= list_y + list_h then
      draw_row(e, i, i == M._sel, y, list_x, list_w, ROW_H - 4, th)
    end
    y = y + ROW_H
  end
  love.graphics.setScissor()
end

-- ══════════════════════════════════════════════════════════════
--  Page 2: DETAIL
-- ══════════════════════════════════════════════════════════════
local function draw_page_detail(th, x, y, w, h)
  local e = list()[M._sel]
  if not e then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf("No entry selected.", x, y + h/2 - 10, w, "center")
    return
  end

  local c = status_color(e.status)

  love.graphics.setColor(c[1] * 0.20, c[2] * 0.20, c[3] * 0.20, 1)
  love.graphics.rectangle("fill", x, y, w, 40, 6, 6)
  love.graphics.setColor(c)
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.print(e.name or "?", x + 12, y + 6)
  love.graphics.setFont(A.font(th.font_body_bold, 9))
  love.graphics.setColor(c[1], c[2], c[3], 0.9)
  love.graphics.print(status_label(e.status), x + 12, y + 24)

  y = y + 48

  local rows = {}
  rows[#rows+1] = { "URL", e.url or "?" }
  rows[#rows+1] = { "Version", e.version or "?" }
  rows[#rows+1] = { "Archive", e.archive_type or "?" }
  rows[#rows+1] = { "Size", fmt_mb(e.size_mb) }
  rows[#rows+1] = { "Target kind", e.target_kind or "(auto)" }
  if e.target_path and e.target_path ~= "" then
    rows[#rows+1] = { "Target path", e.target_path }
  end
  if e.install_path and e.install_path ~= "" then
    rows[#rows+1] = { "Install path", e.install_path }
  end
  if e.status == "downloading" then
    local done_mb = (e.progress_bytes or 0) / (1024 * 1024)
    rows[#rows+1] = { "Progress",
      ("%s / %s"):format(fmt_mb(done_mb), fmt_mb(e.size_mb)) }
    local eta = estimate_eta(e)
    rows[#rows+1] = { "ETA", fmt_eta(eta) }
  end
  if e.error and e.error ~= "" then
    rows[#rows+1] = { "Error", e.error }
  end

  local mono = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10)
  local bold = A.font(th.font_body_bold, 10)
  local label_w = 110

  for _, r in ipairs(rows) do
    love.graphics.setFont(bold)
    love.graphics.setColor(th.text_dim)
    love.graphics.print(r[1], x + 4, y)
    love.graphics.setFont(mono)
    love.graphics.setColor(th.text)
    local val = tostring(r[2])
    if #val > 62 then val = val:sub(1, 60) .. "…" end
    love.graphics.print(val, x + label_w, y)
    y = y + 16
    if y > h - 40 then break end
  end

  local actions = {}
  if e.status == "awaiting_install" then
    actions[#actions+1] = "[A] Install"
  end
  if e.status == "error" then
    actions[#actions+1] = "[X] Retry"
  end
  if e.status == "done" and not e.archive_cleaned then
    actions[#actions+1] = "[Y] Clean archive"
  end

  if #actions > 0 then
    draw_overlay_hints(table.concat(actions, "   "),
      x, h - 22, w, A.font(th.font_body, 9), th)
  end
end

-- ══════════════════════════════════════════════════════════════
--  Page 3: BATCH
-- ══════════════════════════════════════════════════════════════
local function draw_page_batch(th, x, y, w, h)
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print("BATCH OPERATIONS", x + 4, y)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", x + 4, y + 16, w - 8, 1)
  y = y + 28

  local active, done, failed, queued, cancelled, cleaned = 0, 0, 0, 0, 0, 0
  local total_bytes = 0
  for _, e in ipairs(list()) do
    if e.status == "downloading" or e.status == "extracting" then
      active = active + 1
    elseif e.status == "done" then
      done = done + 1
      if e.archive_cleaned then cleaned = cleaned + 1 end
    elseif e.status == "error" then
      failed = failed + 1
    elseif e.status == "queued" then
      queued = queued + 1
    elseif e.status == "cancelled" then
      cancelled = cancelled + 1
    end
    if e.dest and e.status == "done" and not e.archive_cleaned then
      total_bytes = total_bytes + (e.size_mb or 0) * 1024 * 1024
    end
  end

  local rows = {
    { "Active", active,   {0.20, 0.72, 0.98} },
    { "Queued", queued,   {0.55, 0.60, 0.72} },
    { "Done",   done,     {0.30, 0.80, 0.40} },
    { "Failed", failed,   {0.90, 0.30, 0.30} },
    { "Cancelled", cancelled, {0.55, 0.55, 0.62} },
  }
  for _, r in ipairs(rows) do
    love.graphics.setColor(r[3])
    love.graphics.rectangle("fill", x + 4, y + 2, 3, 14)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(r[1], x + 14, y + 2)
    love.graphics.setColor(r[3])
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    love.graphics.print(tostring(r[2]), x + 90, y + 1)
    y = y + 20
  end

  y = y + 6
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  if cleaned > 0 then
    love.graphics.print(("Archive-free: %d done entr(ies)"):format(cleaned),
      x + 4, y)
    y = y + 14
  end
  if total_bytes > 0 then
    love.graphics.print(("Reclaimable: %s"):format(fmt_mb(total_bytes / 1048576)),
      x + 4, y)
    y = y + 14
  end

  y = y + 12
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", x + 4, y, w - 8, 1)
  y = y + 12

  local actions = {
    { "[A]", "Cancel all active",       {0.90, 0.30, 0.30} },
    { "[X]", "Clean all archives",      {0.96, 0.77, 0.26} },
    { "[Y]", "Retry all failed",        {0.20, 0.72, 0.98} },
    { "[START]", "Clear completed/cancelled", {0.55, 0.60, 0.72} },
  }
  for _, a in ipairs(actions) do
    love.graphics.setColor(a[3])
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(a[1], x + 8, y)
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.print(a[2], x + 66, y)
    y = y + 22
  end
end

-- ══════════════════════════════════════════════════════════════
--  Target-choice sub-overlay
-- ══════════════════════════════════════════════════════════════
local function draw_target_choice(bx, by, bw, bh, th)
  local tc = M._target_choice
  if not tc then return end
  local e = tc.entry

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)

  love.graphics.setColor(th.focus)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx + 40, by + 30, bw - 80, bh - 80, 6, 6)
  love.graphics.setLineWidth(1)

  local px = bx + 40
  local py = by + 30
  local pw = bw - 80
  local ph = bh - 80

  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body_bold, 12))
  love.graphics.printf("INSTALL TARGET", px, py + 10, pw, "center")

  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.printf(e.name or "?", px + 20, py + 30, pw - 40, "center")

  -- +70 (was +56): the option rows now start lower so the option
  -- label has room to sit on its own row without touching the path.
  local ry = py + 70
  for i, opt in ipairs(tc.options) do
    local focused = (i == tc.sel)
    if focused then
      love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.18)
      love.graphics.rectangle("fill", px + 20, ry, pw - 40, 42, 4, 4)
      love.graphics.setColor(th.focus)
      love.graphics.rectangle("fill", px + 20, ry, 3, 42, 1, 1)
    end
    BI.draw(th, opt.key, px + 32, ry + 11, 20)
    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    -- Row 1: option label
    love.graphics.print(opt.label, px + 62, ry + 5)

    -- Row 2: target path (mono, truncated)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(
      A.font("assets/fonts/JetBrainsMono-Regular.ttf", 8))
    local path = opt.path or ""
    if #path > 46 then path = "…" .. path:sub(-44) end
    love.graphics.print(path, px + 62, ry + 24)

    ry = ry + 48
  end

  draw_overlay_hints("[↑↓] Choose   [A] Confirm   [B] Cancel",
    px, py + ph - 24, pw, A.font(th.font_body, 9), th)
end

-- ══════════════════════════════════════════════════════════════
--  Main draw
-- ══════════════════════════════════════════════════════════════
function M.draw(w, h)
  if not M._open then return end
  local th = State.theme

  local ease = math.min(1, M._enter_t / 0.18)
  ease = 1 - (1 - ease)^3

  love.graphics.setColor(0, 0, 0, 0.72 * ease)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local pw, ph = w - 40, h - 40
  local px, py = 20, 20
  local slide = (1 - ease) * 40
  py = py + slide

  love.graphics.setColor(0.05, 0.06, 0.10, 0.98)
  love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
  love.graphics.setColor(th.focus)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", px, py, pw, ph, 8, 8)
  love.graphics.setLineWidth(1)
  D.corner_brackets(px, py, pw, ph, th.focus, 16)

  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.15)
  love.graphics.rectangle("fill", px, py, pw, 32, 8, 8)

  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_title, 13))
  love.graphics.print("DOWNLOADS", px + 16, py + 8)

  draw_page_tabs(th, px, py, pw)

  local inner_x = px + 14
  local inner_y = py + 40
  local inner_w = pw - 28
  local inner_h = ph - (inner_y - py) - 34

  if M._page == 1 then
    local probe_h = 74
    draw_net_probe(inner_x, inner_y, inner_w, probe_h, th)

    local div_y = inner_y + probe_h + 8
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.28)
    love.graphics.rectangle("fill", inner_x, div_y, inner_w, 1)

    local list_x = inner_x
    local list_y = div_y + 8
    local list_w = inner_w
    local list_h = inner_y + inner_h - list_y

    draw_page_queue(th, list_x, list_y, list_w, list_h)

    draw_overlay_hints(
      "[↑↓] Navigate   [A] Install   [X] Cancel/Del   [L1/R1] Page   [B] Close",
      px, py + ph - 22, pw, A.font(th.font_body, 9), th)
  elseif M._page == 2 then
    draw_page_detail(th, inner_x, inner_y, inner_w, inner_h)
    draw_overlay_hints(
      "[↑↓] Select entry   [L1/R1] Page   [B] Close",
      px, py + ph - 22, pw, A.font(th.font_body, 9), th)
  else
    draw_page_batch(th, inner_x, inner_y, inner_w, inner_h)
    draw_overlay_hints(
      "[A/X/Y/START] Run action   [L1/R1] Page   [B] Close",
      px, py + ph - 22, pw, A.font(th.font_body, 9), th)
  end

  if M._target_choice then
    draw_target_choice(px, py, pw, ph, th)
  end
end

return M