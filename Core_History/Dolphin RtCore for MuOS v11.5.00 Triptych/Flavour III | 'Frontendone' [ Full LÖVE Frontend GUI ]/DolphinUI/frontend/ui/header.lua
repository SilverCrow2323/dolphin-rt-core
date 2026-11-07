-- frontend/ui/header.lua
-- Theme-aware top bar: title image OR icon+text + center widget +
-- status icons.
--
-- v0.6.0
--   * When a title image (screen logo) is provided AND resolves to a
--     real PNG, the leading icon is NOT drawn. The logo carries the
--     visual identity of the screen, and doubling it with an icon
--     looked redundant. On screens without a logo, the icon is drawn
--     larger (28 px) next to the plain-text title.
--   * Header height raised from 52 to 58 px so the title images have
--     room to breathe. Title image cap raised from 48 to 52 px.
--   * Header title text uses A.title_font() so non-ASCII title
--     literals do not fall back to a missing-glyph box.
--
-- Screens that hardcode a Y offset right below the header may need a
-- small bump; see comments at the call sites.

local A     = require("assets")
local D     = require("ui.draw")
local Icons = require("ui.icons")
local State = require("state")
local GL    = require("ui.glyph")

local Header = {}
local W, H = 640, 480
local H_H = 78

local TITLE_IMG_H = 52
local TITLE_IMG_X = 46

local SWITCH_LOGOS = {
  gc  = "assets/images/gc/logo.png",
  wii = "assets/images/wii/logo.png",
}

local SW_H  = 38
local SEG_W = 74
local SW_PAD = 2

local BRAND_SIZE = 34
local BRAND_ORBIT_R = 32
local BRAND_ORBIT_OMEGA = 0.62

local BRANDED_SCREENS = {
  settings          = true,
  settings_app      = true,
  settings_keymap   = true,
  frontendone       = true,
  rom_paths         = true,
  workshop          = true,
  workshop_profiles = true,
  workshop_data     = true,
  workshop_files    = true,
  workshop_mods     = true,
  workshop_controller = true,
  workshop_hotkeys  = true,
  workshop_gamesets = true,
  workshop_rollback = true,
  workshop_diff     = true,
  workshop_import   = true,
  workshop_snapshots = true,
  workshop_hotkey_edit = true,
  ethostore         = true,
  enhancer_boot     = true,
  homebrew_hub      = true,
  homebrew          = true,
  report_window     = true,
  about             = true,
  manual            = true,
  input_debug       = true,
  input_center      = true,
  external_input_station = true,
  config_choice     = true,
  config_wizard     = true,
}

-- ══════════════════════════════════════════════════════════════
--  Palette resolver
-- ══════════════════════════════════════════════════════════════
local function header_palette(th)
  local is_wii = (State.theme_name == "wii")
  if is_wii then
    return {
      bg        = th.header_bg        or {0.00, 0.62, 0.90},
      bg_alt    = th.header_bg_alt    or {0.00, 0.55, 0.83},
      text      = th.header_text      or {1.00, 1.00, 1.00},
      text_dim  = th.header_text_dim  or {0.82, 0.90, 0.98},
      line      = th.header_line      or {0.00, 0.48, 0.75},
      accent    = th.accent,
      is_wii    = true,
    }
  end
  return {
    bg        = {0, 0, 0, 0.55},
    bg_alt    = {0, 0, 0, 0.55},
    text      = th.text,
    text_dim  = th.text_dim,
    line      = th.accent,
    accent    = th.accent,
    is_wii    = false,
  }
end

-- ══════════════════════════════════════════════════════════════
--  Status polling (battery / wifi)
-- ══════════════════════════════════════════════════════════════
local STATUS_TTL = 8

local function now_t()
  if love and love.timer then return love.timer.getTime() end
  return os.time()
end

local function read_line(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local v = f:read("*l"); f:close()
  return v
end

local _bat_v,  _bat_t  = nil, -1000
local _wifi_v, _wifi_t = 0, -1000
local _iface, _iface_done = nil, false

local function find_iface()
  if _iface_done then return _iface end
  _iface_done = true
  local p = io.popen("ls /sys/class/net/ 2>/dev/null")
  if p then
    for name in p:lines() do
      if name:match("^wl") then _iface = name; break end
    end
    p:close()
  end
  return _iface
end

local function read_battery()
  local t = now_t()
  if t - _bat_t < STATUS_TTL then return _bat_v end
  _bat_t = t
  _bat_v = nil
  for _, p in ipairs({
    "/sys/class/power_supply/battery/capacity",
    "/sys/class/power_supply/BAT0/capacity",
  }) do
    local v = tonumber(read_line(p))
    if v then _bat_v = v; break end
  end
  return _bat_v
end

local function read_wifi()
  local t = now_t()
  if t - _wifi_t < STATUS_TTL then return _wifi_v end
  _wifi_t = t
  _wifi_v = 0
  local iface = find_iface()
  if not iface then return 0 end
  if read_line("/sys/class/net/" .. iface .. "/carrier") ~= "1" then
    return 0
  end
  _wifi_v = 2
  local f = io.open("/proc/net/wireless", "r")
  if f then
    for line in f:lines() do
      local q = line:match("^%s*" .. iface .. ":%s+%d+%s+(%d+)")
      if q then
        q = tonumber(q) or 0
        if     q >= 50 then _wifi_v = 3
        elseif q >= 25 then _wifi_v = 2
        else                _wifi_v = 1 end
        break
      end
    end
    f:close()
  end
  return _wifi_v
end

local _th_global = nil
local function th_global() return _th_global end

local function draw_status_icons(pal)
  local x = W - 20
  if State.update_available then
    Icons.draw("update", x - 14, 18, 20,
      pal.is_wii and {1.00, 0.92, 0.70} or {0.96, 0.77, 0.26})
    x = x - 32
  end

  local bars = read_wifi()
  for i = 1, 3 do
    local h = 4 + i * 4
    local on = i <= bars
    local tc = on and pal.text
      or { pal.text_dim[1], pal.text_dim[2], pal.text_dim[3], 0.35 }
    love.graphics.setColor(tc)
    love.graphics.rectangle("fill", x - 40 + i * 6, 32 - h, 4, h)
  end
  x = x - 50

  local bat = read_battery()
  love.graphics.setColor(pal.text)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", x - 26, 20, 22, 14, 2, 2)
  love.graphics.rectangle("fill", x - 4, 24, 3, 6)
  if bat then
    local fillw = 18 * (bat / 100)
    local bc
    if pal.is_wii then
      bc = (bat > 30) and {1, 1, 1} or {1.0, 0.75, 0.75}
    else
      bc = (bat > 30) and {0.3, 0.8, 0.4} or {0.9, 0.3, 0.3}
    end
    love.graphics.setColor(bc)
    love.graphics.rectangle("fill", x - 25, 21, fillw, 12, 1, 1)
    love.graphics.setColor(pal.text_dim)
    local th = th_global()
    love.graphics.setFont(A.font(th and th.font_body
      or "assets/fonts/Oxanium-Regular.ttf", 9))
    love.graphics.print(("%d%%"):format(bat), x - 26, 36)
  end
  love.graphics.setLineWidth(1)
end

-- ══════════════════════════════════════════════════════════════
--  Theme switch
-- ══════════════════════════════════════════════════════════════
local function draw_segment_content(seg_x, seg_y, seg_w, seg_h, label,
                                    logo_path, active, pal)
  local box_w = seg_w - SW_PAD * 2
  local box_h = seg_h - SW_PAD * 2
  local bx = seg_x + SW_PAD
  local by = seg_y + SW_PAD

  if logo_path then
    local img = A.image(logo_path)
    if img then
      local iw, ih = img:getWidth(), img:getHeight()
      local scale = math.min(box_w / iw, box_h / ih) * 0.96
      local dw, dh = iw * scale, ih * scale
      local dx = bx + (box_w - dw) / 2
      local dy = by + (box_h - dh) / 2

      if pal.is_wii then
        love.graphics.setColor(1, 1, 1, active and 1 or 0.55)
      else
        love.graphics.setColor(1, 1, 1, active and 1 or 0.72)
      end
      love.graphics.draw(img, dx, dy, 0, scale, scale)
      return
    end
  end

  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 13))
  if pal.is_wii then
    love.graphics.setColor(active and {0.00, 0.42, 0.68, 0.95}
                                 or {1, 1, 1, 0.85})
  else
    love.graphics.setColor(active and {0.02, 0.02, 0.05, 0.95}
                                 or {0.85, 0.85, 0.90, 1})
  end
  love.graphics.printf(label, seg_x, seg_y + (seg_h - 14) / 2, seg_w,
    "center")
end

local function draw_theme_switch(pal)
  local cx = W / 2
  local sw_w = SEG_W * 2
  local sw_h = SW_H
  local sx = cx - sw_w / 2
  local sy = (H_H - sw_h) / 2

  if pal.is_wii then
    love.graphics.setColor(0.00, 0.45, 0.72, 0.60)
    love.graphics.rectangle("fill", sx, sy, sw_w, sw_h, sw_h / 2)

    local idx = (State.theme_name == "wii") and 2 or 1
    local selx = sx + (idx - 1) * SEG_W
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.rectangle("fill", selx + 2, sy + 2,
      SEG_W - 4, sw_h - 4, (sw_h - 4) / 2)

    love.graphics.setColor(0.00, 0.32, 0.55, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.arc("line", "open",
      selx + SEG_W / 2, sy + sw_h - 3,
      (sw_h - 4) / 2, 0, math.pi)

    local labels = { "GC", "WII" }
    for i, label in ipairs(labels) do
      local lx = sx + (i - 1) * SEG_W
      local logo_path = SWITCH_LOGOS[i == 1 and "gc" or "wii"]
      draw_segment_content(lx, sy, SEG_W, sw_h, label, logo_path, i == idx, pal)
    end

    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", sx, sy, sw_w, sw_h, sw_h / 2)
    love.graphics.setLineWidth(1)
    return
  end

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", sx - 1, sy - 1, sw_w + 2, sw_h + 2,
    sw_h / 2 + 2)
  love.graphics.setColor(0.08, 0.09, 0.12, 0.95)
  love.graphics.rectangle("fill", sx, sy, sw_w, sw_h, sw_h / 2)

  local idx = (State.theme_name == "wii") and 2 or 1
  local seg_colors = {
    { 0.55, 0.35, 0.95 },
    { 0.00, 0.63, 0.91 },
  }

  local c = seg_colors[idx]
  local selx = sx + (idx - 1) * SEG_W
  love.graphics.setColor(c[1], c[2], c[3], 0.98)
  love.graphics.rectangle("fill", selx + 2, sy + 2,
    SEG_W - 4, sw_h - 4, (sw_h - 4) / 2)

  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.rectangle("fill", selx + 6, sy + 4,
    SEG_W - 12, (sw_h - 8) * 0.45,
    (sw_h - 8) * 0.45, (sw_h - 8) * 0.45)

  local labels = { "GC", "WII" }
  for i, label in ipairs(labels) do
    local lx = sx + (i - 1) * SEG_W
    local logo_path = SWITCH_LOGOS[i == 1 and "gc" or "wii"]
    draw_segment_content(lx, sy, SEG_W, sw_h, label, logo_path, i == idx, pal)
  end

  love.graphics.setColor(pal.accent[1], pal.accent[2], pal.accent[3], 0.55)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", sx, sy, sw_w, sw_h, sw_h / 2)
  love.graphics.setLineWidth(1)
end

-- ══════════════════════════════════════════════════════════════
--  Brand icon (administrative screens)
-- ══════════════════════════════════════════════════════════════
local function draw_brand_icon(pal)
  local cx, cy = W / 2, H_H / 2
  local t = State.t_ui or 0
  local is_wii = pal.is_wii

  local glow = is_wii and {1.00, 1.00, 1.00} or {0.55, 0.35, 0.95}
  local pulse = 0.5 + 0.5 * math.sin(t * 1.3)
  local glow_amp = is_wii and 0.24 or 0.16
  for i = 4, 1, -1 do
    local r = 22 + i * 5
    local a = (glow_amp * (0.5 + 0.5 * pulse)) * (5 - i) / 4
    love.graphics.setColor(glow[1], glow[2], glow[3], a)
    love.graphics.circle("fill", cx, cy, r)
  end

  local img = A.image("assets/images/dolphinrt_icon.png")
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local s = BRAND_SIZE / math.max(iw, ih)
    local dw, dh = iw * s, ih * s
    love.graphics.setColor(1, 1, 1, 0.97)
    love.graphics.draw(img, cx - dw / 2, cy - dh / 2, 0, s, s)
  end

  local a = t * BRAND_ORBIT_OMEGA
  local c_gc  = is_wii and {1.00, 1.00, 1.00} or {0.65, 0.45, 1.00}
  local c_wii = is_wii and {0.85, 0.95, 1.00} or {0.30, 0.78, 1.00}

  local function particle(angle, col)
    local px = cx + math.cos(angle) * BRAND_ORBIT_R
    local py = cy + math.sin(angle) * BRAND_ORBIT_R
    love.graphics.setColor(col[1], col[2], col[3], is_wii and 0.30 or 0.22)
    love.graphics.circle("fill", px, py, 4.2)
    love.graphics.setColor(col[1], col[2], col[3], is_wii and 1.0 or 0.95)
    love.graphics.circle("fill", px, py, 2.0)
  end
  particle(a,           c_gc)
  particle(a + math.pi, c_wii)
end

-- ══════════════════════════════════════════════════════════════
--  Title
-- ══════════════════════════════════════════════════════════════

-- Try to load the title image for a given key. Returns the image and
-- a flag: ok=true means a real PNG resolved.
local function resolve_title_image(key)
  if not key then return nil, false end
  local path = "assets/images/menu/screen_titles/" .. key .. ".png"
  local img = A.image(path)
  return img, img ~= nil
end

local function draw_title_image(img, th, pal)
  local iw = img:getWidth()
  local ih = img:getHeight()
  local h  = TITLE_IMG_H
  local w  = h * (iw / ih)
  local MAX_W = 240
  if w > MAX_W then
    w = MAX_W
    h = w * (ih / iw)
  end
  local y = math.floor((H_H - h) / 2)
  if pal.is_wii then
    love.graphics.setColor(1, 1, 1, 0.98)
  else
    love.graphics.setColor(1, 1, 1, 1)
  end
  love.graphics.draw(img, TITLE_IMG_X, y, 0, w / iw, h / ih)
end

local function draw_title_text(th, pal, title, icon_key, has_image)
  -- When a real PNG title image exists, we do NOT draw the leading
  -- icon: the logo already carries the identity of the screen.
  -- Otherwise, the icon is drawn LARGE (28 px) at 18,15 and the text
  -- title uses the theme title font (with the ASCII fallback).
  local x = 20
  if not has_image then
    Icons.draw(icon_key or "library", 16, (H_H - 28) / 2, 28, pal.text)
    x = 16 + 28 + 10
  end

  if has_image then return end
  love.graphics.setFont(A.title_font(title or "", 19))
  love.graphics.setColor(pal.text)
  love.graphics.print(title or "", x, math.floor((H_H - 20) / 2))
end

-- ══════════════════════════════════════════════════════════════
--  Public: draw
-- ══════════════════════════════════════════════════════════════
function Header.draw(title, icon_key, title_image_key)
  local th = State.theme
  _th_global = th
  local pal = header_palette(th)

  -- Background
  if pal.is_wii then
    local top    = pal.bg
    local bottom = pal.bg_alt
    local bands  = 5
    for i = 0, bands - 1 do
      local p = i / (bands - 1)
      love.graphics.setColor(
        top[1] + (bottom[1] - top[1]) * p,
        top[2] + (bottom[2] - top[2]) * p,
        top[3] + (bottom[3] - top[3]) * p,
        1)
      love.graphics.rectangle("fill", 0,
        math.floor(i * H_H / bands), W, math.ceil(H_H / bands) + 1)
    end
  else
    love.graphics.setColor(pal.bg)
    love.graphics.rectangle("fill", 0, 0, W, H_H)
  end

  -- Bottom border
  love.graphics.setColor(pal.line)
  if pal.is_wii then
    love.graphics.rectangle("fill", 0, H_H - 2, W, 2)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", 0, H_H - 3, W, 1)
  else
    D.rough_rect(0, 0, W, H_H,
      { jitter = 0.8, thickness = 2, seed = 42, steps = 40 })
  end

  -- Resolve the title image first. If it exists, skip the leading
  -- icon (see draw_title_text).
  local title_img, has_image = resolve_title_image(title_image_key)

  if has_image then
    draw_title_image(title_img, th, pal)
  else
    draw_title_text(th, pal, title, icon_key, false)
  end

  -- Center widget
  if BRANDED_SCREENS[State.screen] then
    draw_brand_icon(pal)
  else
    draw_theme_switch(pal)
  end

  -- Status icons
  draw_status_icons(pal)
end

function Header.height() return H_H end

return Header