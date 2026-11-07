-- frontend/screens/workshop.lua — SPDW Underground
--
-- v0.7.0 — full redesign
--   * Four "areas" (Config Bench / The Forge / Data Vault / Intel
--     Room), presented as glowing booths in a cel-shaded 2.5D
--     underground workshop.
--   * Camera slides horizontally between areas; the active booth
--     lights up and opens an animated items panel with each entry's
--     own road-sign marker.
--   * Item rows use a hexagonal / triangular / circular / arrow
--     "sign" drawn procedurally (no Unicode, no font dependency).
--   * Focused item expands with a spring, glow, animated cursor.
--   * Badge counts pulse on change, same as the previous layout.
--   * Environment (back wall, pipes, distant neon, ceiling, floor
--     grid) is pre-rendered ONCE to a canvas, so per-frame cost is
--     just the booths + panel + HUD.
--
-- Navigation
--   D-pad L/R   or L1/R1   change area
--   D-pad U/D              change item inside the current area
--   A                      enter the focused item
--   B                      leave the workshop
--   SELECT                 flip theme (only when the header shows
--                          the switch — Workshop is branded, so
--                          SELECT is a no-op here per v0.5.2)

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local Icons  = require("ui.icons")
local BI     = require("ui.button_icons")
local GL     = require("ui.glyph")

local PM = require("profile_manager")
local BM = require("backup_manager")
local SM = require("snapshot_manager")
local RS = require("report_store")

local S = {}
local W, H = 640, 480

-- Layout
local TOP        = Header.height() + 4         -- 62
local BOTTOM     = H - 28
local BOOTH_W    = 340
local BOOTH_H    = 210
local AREA_SPACE = 420                          -- world units between booths

-- State
S.area       = 1
S.cam        = 1                                -- lerped toward S.area
S.sel        = 1
S.panel_open = 0                                -- 0..1 animated
S.enter_t    = 0
S._areas     = nil
S._env       = nil                              -- environment canvas

-- Badge pulse
local _badge_prev  = {}
local _badge_pulse = {}

-- ── Area / item catalogue ──────────────────────────────────
-- Colours are per-area (used for the booth body, neon sign, and
-- focused card border). Each item carries its own sign_col and a
-- sign_shape ("hex" | "tri" | "circ" | "arrow") for the road-sign
-- marker on the left of its row.

local function build_areas()
  local rtc_n = #PM.list("rtcoreprofile")
  local ctl_n = #PM.list("controller")
  local gs_n  = #PM.list("gamesettings")
  local hk_n  = #PM.list("hotkeys")
  local bk_n  = #BM.list()
  local sn_n  = #SM.list()
  local rp_n  = #RS.list()

  local function fmt(n, s)
    if n == 0 then return "—" end
    return tostring(n) .. " " .. s
  end

  return {
    {
      key      = "config",
      label    = "CONFIG BENCH",
      subtitle = "profiles · controller · gamesets",
      icon     = "settings",
      color    = {0.62, 0.35, 0.98},
      color_hi = {0.85, 0.65, 1.00},
      items = {
        { key = "rtcore", label = "Rt:Core Profiles",
          desc = "Apply, edit, inspect profiles",
          badge = fmt(rtc_n, "profiles"),
          icon  = "balanced", sign = "hex",
          sign_col = {0.62, 0.35, 0.98},
          target = "workshop_profiles" },
        { key = "ctrl", label = "Controller Profiles",
          desc = "GameCube & Wii layouts",
          badge = fmt(ctl_n, "profiles"),
          icon  = "controller", sign = "tri",
          sign_col = {0.20, 0.72, 0.98},
          target = "workshop_controller" },
        { key = "gameset", label = "GameSettings",
          desc = "Per-game overrides",
          badge = fmt(gs_n, "overrides"),
          icon  = "save", sign = "circ",
          sign_col = {0.30, 0.85, 0.40},
          target = "workshop_gamesets" },
        { key = "hotkeys", label = "Hotkeys",
          desc = "Bindings and shortcut profiles",
          badge = fmt(hk_n, "profiles"),
          icon  = "hotkeys", sign = "arrow",
          sign_col = {0.96, 0.77, 0.26},
          target = "workshop_hotkeys" },
        { key = "wizard", label = "Config Wizard",
          desc = "Guided profile builder, step by step",
          badge = "guided",
          icon  = "advanced", sign = "hex",
          sign_col = {0.20, 0.72, 0.98},
          target = "config_choice" },
        { key = "import", label = "Import",
          desc = "From games_data.json / muOS ext",
          badge = "external",
          icon  = "external", sign = "tri",
          sign_col = {0.30, 0.85, 0.40},
          target = "workshop_import" },
      },
    },
    {
      key      = "forge",
      label    = "THE FORGE",
      subtitle = "compare · recover · snapshot",
      icon     = "save",
      color    = {0.96, 0.62, 0.20},
      color_hi = {1.00, 0.85, 0.55},
      items = {
        { key = "diff", label = "Diff Viewer",
          desc = "Compare profile vs base",
          badge = "compare",
          icon  = "info", sign = "hex",
          sign_col = {0.20, 0.72, 0.98},
          target = "workshop_diff" },
        { key = "rollback", label = "Rollback",
          desc = "Restore recent config backups",
          badge = fmt(bk_n, "backups"),
          icon  = "save", sign = "arrow",
          sign_col = {0.96, 0.77, 0.26},
          target = "workshop_rollback" },
        { key = "snapshots", label = "Snapshots",
          desc = "Full configuration snapshots",
          badge = fmt(sn_n, "saved"),
          icon  = "save", sign = "circ",
          sign_col = {0.96, 0.62, 0.20},
          target = "workshop_snapshots" },
      },
    },
    {
      key      = "vault",
      label    = "DATA VAULT",
      subtitle = "logging · configs · mods",
      icon     = "library",
      color    = {0.20, 0.72, 0.98},
      color_hi = {0.55, 0.88, 1.00},
      items = {
        { key = "logging", label = "Logger & Debugger",
          desc = "File logging and debug traces",
          badge = "logging",
          icon  = "logging", sign = "circ",
          sign_col = {0.62, 0.35, 0.98},
          target = "workshop_data" },
        { key = "files", label = "Config Files",
          desc = "View & edit Dolphin INIs",
          badge = "editor",
          icon  = "library", sign = "hex",
          sign_col = {0.30, 0.85, 0.40},
          target = "workshop_files" },
        { key = "mods", label = "Graphic Mods",
          desc = "Manage installed mod packs",
          badge = "engine",
          icon  = "enhancer", sign = "tri",
          sign_col = {0.20, 0.72, 0.98},
          target = "workshop_mods" },
      },
    },
    {
      key      = "intel",
      label    = "INTEL ROOM",
      subtitle = "field reports & sharing",
      icon     = "save",
      color    = {0.30, 0.85, 0.40},
      color_hi = {0.60, 1.00, 0.70},
      items = {
        { key = "report", label = "Test Report",
          desc = "Document sessions, share results",
          badge = fmt(rp_n, "saved"),
          icon  = "save", sign = "arrow",
          sign_col = {0.30, 0.85, 0.40},
          target = "report_window" },
      },
    },
  }
end

local function current_area()
  return (S._areas or {})[S.area]
end

local function current_item()
  local a = current_area()
  if not a then return nil end
  return a.items[S.sel]
end

-- ── Environment canvas (pre-rendered backdrop) ─────────────
local function build_environment()
  local c = love.graphics.newCanvas(W, H)
  local prev = love.graphics.getCanvas()
  love.graphics.setCanvas(c)
  love.graphics.clear(0.02, 0.03, 0.05)

  -- Sky / upper wall gradient: dark cyan to deep violet
  for i = 0, H - 1 do
    local p = i / H
    love.graphics.setColor(
      0.03 + p * 0.02,
      0.05 + p * 0.02,
      0.09 + p * 0.04, 1)
    love.graphics.rectangle("fill", 0, i, W, 1)
  end

  -- Distant neon signs (behind everything): blurry colored rectangles
  local neons = {
    { x = 40,  y = 100, w = 60, h = 12, col = {0.90, 0.20, 0.55} },
    { x = 540, y = 130, w = 70, h = 10, col = {0.20, 0.80, 1.00} },
    { x = 120, y = 200, w = 40, h = 8,  col = {1.00, 0.80, 0.20} },
    { x = 480, y = 220, w = 50, h = 10, col = {0.55, 0.35, 1.00} },
    { x = 300, y = 90,  w = 90, h = 8,  col = {0.30, 0.90, 0.60} },
  }
  for _, n in ipairs(neons) do
    for i = 4, 1, -1 do
      love.graphics.setColor(n.col[1], n.col[2], n.col[3], 0.05 * (5 - i))
      love.graphics.rectangle("fill",
        n.x - i * 3, n.y - i * 2, n.w + i * 6, n.h + i * 4, 3, 3)
    end
    love.graphics.setColor(n.col[1], n.col[2], n.col[3], 0.55)
    love.graphics.rectangle("fill", n.x, n.y, n.w, n.h, 2, 2)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", n.x + 4, n.y + 4, n.w - 8, 1)
  end

  -- Silhouetted pipes along the ceiling
  local function pipe(y, thickness, color)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", 0, y, W, thickness)
    love.graphics.setColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1)
    love.graphics.rectangle("fill", 0, y + thickness - 2, W, 2)
    -- Segmented joints every 60px
    for x = 30, W, 60 do
      love.graphics.setColor(0.35, 0.38, 0.45, 1)
      love.graphics.rectangle("fill", x, y - 2, 4, thickness + 4)
      love.graphics.setColor(0.55, 0.58, 0.66, 1)
      love.graphics.rectangle("fill", x, y - 2, 1, thickness + 4)
    end
  end
  pipe(TOP + 2, 8, {0.22, 0.24, 0.30})
  pipe(TOP + 14, 5, {0.18, 0.20, 0.26})
  pipe(H - 40, 6, {0.20, 0.22, 0.28})

  -- Hanging cables
  love.graphics.setColor(0.08, 0.09, 0.12, 1)
  love.graphics.setLineWidth(2)
  for x = 60, W - 60, 90 do
    local sag = 25 + (x % 40)
    for s = 0, 20 do
      local t1 = s / 20
      local t2 = (s + 1) / 20
      local x1 = x + t1 * 30
      local y1 = TOP + 20 + math.sin(t1 * math.pi) * sag
      local x2 = x + t2 * 30
      local y2 = TOP + 20 + math.sin(t2 * math.pi) * sag
      love.graphics.line(x1, y1, x2, y2)
    end
  end
  love.graphics.setLineWidth(1)

  -- Back wall panels (industrial grid)
  love.graphics.setColor(0.14, 0.15, 0.20, 0.55)
  for x = 0, W, 80 do
    love.graphics.rectangle("line", x, TOP + 40, 80, 140)
  end
  love.graphics.setColor(0.10, 0.11, 0.15, 0.7)
  for x = 0, W, 80 do
    for y = TOP + 40, TOP + 180, 40 do
      love.graphics.rectangle("line", x, y, 80, 40)
    end
  end

  -- Floor: receding perspective grid
  -- Vanishing point at horizon (H/2 + 20). Floor from there down.
  local VP_Y = H / 2 + 10
  love.graphics.setColor(0.15, 0.18, 0.26, 0.6)
  love.graphics.setLineWidth(1)
  -- Horizontal lines (getting denser toward horizon)
  for i = 0, 20 do
    local p = i / 20
    local yy = VP_Y + (H - VP_Y) * (p ^ 1.8)
    love.graphics.line(0, yy, W, yy)
  end
  -- Vertical lines converging to vanishing point
  local VP_X = W / 2
  for x = -200, W + 200, 60 do
    love.graphics.line(x, H, VP_X, VP_Y)
  end
  love.graphics.setLineWidth(1)

  -- Darkening overlay toward edges (vignette-ish)
  for i = 1, 5 do
    love.graphics.setColor(0, 0, 0, 0.06 * (i / 5))
    love.graphics.rectangle("line",
      -i * 8, TOP - i * 8,
      W + i * 16, H - TOP + i * 16)
  end

  love.graphics.setCanvas(prev)
  return c
end

-- ── Sign shapes (procedural road-sign markers) ─────────────
local SIGN_VERTS = {
  hex = (function()
    local v = {}
    for i = 0, 5 do
      local a = -math.pi / 2 + i * math.pi / 3
      v[#v + 1] = math.cos(a)
      v[#v + 1] = math.sin(a)
    end
    return v
  end)(),
  tri = (function()
    -- Equilateral-ish downward triangle
    return {
      0, -1,
      -0.9, 0.7,
      0.9, 0.7,
    }
  end)(),
  arrow = (function()
    -- Arrow pointing right
    return {
      -1, -0.6,
      0.4, -0.6,
      0.4, -0.9,
      1, 0,
      0.4, 0.9,
      0.4, 0.6,
      -1, 0.6,
    }
  end)(),
}

local function draw_road_sign(shape, cx, cy, size, color, icon_key, focused)
  local r = size * 0.5

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.push()
  love.graphics.translate(cx + 1.5, cy + 2.5)
  if shape == "circ" then
    love.graphics.circle("fill", 0, 0, r)
  else
    local v = SIGN_VERTS[shape] or SIGN_VERTS.hex
    local pts = {}
    for i = 1, #v, 2 do
      pts[#pts + 1] = v[i] * r
      pts[#pts + 1] = v[i + 1] * r
    end
    love.graphics.polygon("fill", pts)
  end
  love.graphics.pop()

  -- Body
  love.graphics.setColor(color[1] * 0.85, color[2] * 0.85, color[3] * 0.85, 1)
  if shape == "circ" then
    love.graphics.circle("fill", cx, cy, r)
  else
    local v = SIGN_VERTS[shape] or SIGN_VERTS.hex
    local pts = {}
    for i = 1, #v, 2 do
      pts[#pts + 1] = cx + v[i] * r
      pts[#pts + 1] = cy + v[i + 1] * r
    end
    love.graphics.polygon("fill", pts)
  end

  -- Top highlight (cel shading)
  love.graphics.setColor(1, 1, 1, 0.14)
  if shape == "circ" then
    love.graphics.arc("fill", "pie", cx, cy, r - 1,
      math.pi, math.pi * 2)
  else
    local v = SIGN_VERTS[shape] or SIGN_VERTS.hex
    local pts = {}
    for i = 1, #v, 2 do
      pts[#pts + 1] = cx + v[i] * (r - 1)
      pts[#pts + 1] = cy + v[i + 1] * (r - 1) - 1
    end
    love.graphics.polygon("fill", pts)
  end

  -- Border (black cel outline)
  love.graphics.setColor(0.02, 0.03, 0.05, 1)
  love.graphics.setLineWidth(2)
  if shape == "circ" then
    love.graphics.circle("line", cx, cy, r)
  else
    local v = SIGN_VERTS[shape] or SIGN_VERTS.hex
    local pts = {}
    for i = 1, #v, 2 do
      pts[#pts + 1] = cx + v[i] * r
      pts[#pts + 1] = cy + v[i + 1] * r
    end
    love.graphics.polygon("line", pts)
  end
  love.graphics.setLineWidth(1)

  -- Inner icon (small white glyph, drawn via Icons)
  if icon_key then
    local isz = size * 0.42
    Icons.draw(icon_key, cx - isz / 2, cy - isz / 2, isz, {1, 1, 1})
  end

  -- Focus pulse
  if focused then
    local t = State.t_ui or 0
    local pulse = 0.5 + 0.5 * math.sin(t * 5)
    love.graphics.setColor(1, 1, 1, 0.30 + pulse * 0.40)
    love.graphics.setLineWidth(2.5)
    if shape == "circ" then
      love.graphics.circle("line", cx, cy, r + 3)
    else
      local v = SIGN_VERTS[shape] or SIGN_VERTS.hex
      local pts = {}
      for i = 1, #v, 2 do
        pts[#pts + 1] = cx + v[i] * (r + 3)
        pts[#pts + 1] = cy + v[i + 1] * (r + 3)
      end
      love.graphics.polygon("line", pts)
    end
    love.graphics.setLineWidth(1)
  end
end

-- ── Booth rendering ────────────────────────────────────────
-- Booths are drawn in screen space with a camera offset applied.
-- The active booth is lit and slightly larger; neighbours are dim
-- and partially off-screen.
local function draw_booth(area, idx, cam_offset, active, t)
  local cx = W / 2 + (idx - cam_offset) * AREA_SPACE
  -- Skip if far off-screen
  if cx < -BOOTH_W or cx > W + BOOTH_W then return end

  local cy = H / 2 + 20
  local scale = active and 1.0 or 0.82
  local bw = BOOTH_W * scale
  local bh = BOOTH_H * scale

  -- Neon glow if active
  if active then
    local pulse = 0.5 + 0.5 * math.sin(t * 2)
    for i = 6, 1, -1 do
      love.graphics.setColor(area.color[1], area.color[2], area.color[3],
        0.05 * (i / 6) * (0.6 + pulse * 0.4))
      love.graphics.rectangle("fill",
        cx - bw / 2 - i * 6, cy - bh / 2 - i * 6,
        bw + i * 12, bh + i * 12, 8, 8)
    end
  end

  -- Booth shadow
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill",
    cx - bw / 2 + 4, cy - bh / 2 + 6, bw, bh, 6, 6)

  -- Base body (cel-flat)
  local body_col = active and {area.color[1] * 0.35, area.color[2] * 0.35,
    area.color[3] * 0.35}
    or {0.10, 0.12, 0.16}
  love.graphics.setColor(body_col[1], body_col[2], body_col[3], 1)
  love.graphics.rectangle("fill",
    cx - bw / 2, cy - bh / 2, bw, bh, 6, 6)

  -- Top highlight band (cel shading)
  love.graphics.setColor(
    math.min(1, body_col[1] + 0.15),
    math.min(1, body_col[2] + 0.15),
    math.min(1, body_col[3] + 0.15), 1)
  love.graphics.rectangle("fill",
    cx - bw / 2 + 1, cy - bh / 2 + 1, bw - 2, bh * 0.40, 5, 5)

  -- Bottom shadow band
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill",
    cx - bw / 2 + 2, cy + bh / 2 - 10, bw - 4, 8, 3, 3)

  -- Cel outline
  love.graphics.setColor(0.02, 0.03, 0.05, 1)
  love.graphics.setLineWidth(2.5)
  love.graphics.rectangle("line",
    cx - bw / 2, cy - bh / 2, bw, bh, 6, 6)
  love.graphics.setLineWidth(1)

  -- Interior "console" for active booth
  if active then
    -- A row of LEDs on top of the booth
    for i = 1, 6 do
      local lx = cx - bw / 2 + 18 + (i - 1) * 22
      local ly = cy - bh / 2 + 12
      local pulse = 0.5 + 0.5 * math.sin(t * 3 + i * 0.4)
      love.graphics.setColor(area.color_hi[1], area.color_hi[2],
        area.color_hi[3], 0.6 + pulse * 0.4)
      love.graphics.circle("fill", lx, ly, 3)
    end

    -- Ventilation slots on the front face
    love.graphics.setColor(0.05, 0.06, 0.08, 0.9)
    for i = 1, 4 do
      love.graphics.rectangle("fill",
        cx - bw / 2 + 20,
        cy - bh / 2 + 50 + (i - 1) * 14,
        bw - 40, 6, 2, 2)
    end
  end

  -- Area icon chip in the center of the booth
  local chip_size = active and 56 or 42
  local chip_cx = cx
  local chip_cy = cy - bh / 2 + 92
  if active then
    love.graphics.setColor(0.02, 0.03, 0.05, 0.85)
    love.graphics.rectangle("fill",
      chip_cx - chip_size / 2 - 4, chip_cy - chip_size / 2 - 4,
      chip_size + 8, chip_size + 8, 6, 6)
    love.graphics.setColor(area.color[1], area.color[2], area.color[3], 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line",
      chip_cx - chip_size / 2 - 4, chip_cy - chip_size / 2 - 4,
      chip_size + 8, chip_size + 8, 6, 6)
    love.graphics.setLineWidth(1)
  end
  Icons.draw(area.icon, chip_cx - chip_size / 2, chip_cy - chip_size / 2,
    chip_size, active and {1, 1, 1} or {0.55, 0.60, 0.70})

  -- Area label under the icon
  love.graphics.setColor(active and {1, 1, 1} or {0.55, 0.60, 0.70})
  love.graphics.setFont(A.font(State.theme.font_body_bold, active and 14 or 11))
  love.graphics.printf(area.label, cx - bw / 2, chip_cy + chip_size / 2 + 8,
    bw, "center")

  if active then
    love.graphics.setColor(area.color_hi[1], area.color_hi[2],
      area.color_hi[3], 0.75)
    love.graphics.setFont(A.font(State.theme.font_body, 10))
    love.graphics.printf(area.subtitle, cx - bw / 2,
      chip_cy + chip_size / 2 + 26, bw, "center")
  end

  -- Neon sign above the booth
  local sign_y = cy - bh / 2 - 30
  local sign_w = bw * 0.72
  local sign_h = 26
  local sign_x = cx - sign_w / 2
  draw_road_sign_beam(sign_x, sign_y, sign_w, sign_h, area, active, t)

  -- Index dots at the bottom (which area is this)
  local dot_y = cy + bh / 2 + 14
  local num_areas = #(S._areas or {})
  local dot_total_w = num_areas * 14
  for i = 1, num_areas do
    local dx = cx - dot_total_w / 2 + (i - 1) * 14 + 7
    if i == idx then
      love.graphics.setColor(area.color_hi[1], area.color_hi[2],
        area.color_hi[3], active and 1 or 0.6)
      love.graphics.circle("fill", dx, dot_y, 4)
    else
      love.graphics.setColor(0.35, 0.38, 0.48, active and 0.8 or 0.4)
      love.graphics.circle("fill", dx, dot_y, 2.5)
    end
  end
end

-- Neon sign beam above a booth
function draw_road_sign_beam(x, y, w, h, area, active, t)
  -- Pole
  love.graphics.setColor(0.22, 0.24, 0.30, 1)
  love.graphics.rectangle("fill", x + w / 2 - 2, y + h, 4, 12)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", x + w / 2 - 2, y + h, 4, 12)
  love.graphics.setLineWidth(1)

  -- Glow (only if active)
  if active then
    local pulse = 0.5 + 0.5 * math.sin(t * 2.5)
    for i = 4, 1, -1 do
      love.graphics.setColor(area.color[1], area.color[2], area.color[3],
        0.06 * (5 - i) * (0.5 + pulse * 0.5))
      love.graphics.rectangle("fill",
        x - i * 4, y - i * 4, w + i * 8, h + i * 8, 4, 4)
    end
  end

  -- Sign body
  local col = active and area.color or {0.15, 0.17, 0.22}
  love.graphics.setColor(col[1] * 0.85, col[2] * 0.85, col[3] * 0.85, 1)
  love.graphics.rectangle("fill", x, y, w, h, 3, 3)

  -- Top highlight
  love.graphics.setColor(1, 1, 1, active and 0.20 or 0.08)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h * 0.40, 2, 2)

  -- Outline
  love.graphics.setColor(0.02, 0.03, 0.05, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 3, 3)
  love.graphics.setLineWidth(1)

  -- Label
  love.graphics.setColor(active and {1, 1, 1} or {0.65, 0.70, 0.80})
  love.graphics.setFont(A.font(State.theme.font_body_bold, 12))
  love.graphics.printf(area.label, x, y + h / 2 - 8, w, "center")
end

-- ── Items panel (with animated open) ───────────────────────
local function draw_items_panel(area, open, t)
  if open <= 0.02 then return end

  local ease = open * open * (3 - 2 * open)  -- smoothstep
  local pw = W - 60
  local px = 30
  local py = H - 260
  local ph = 200

  -- Slide from the left + scale up from center
  local off_x = (1 - ease) * -30
  local off_y = (1 - ease) * 20

  -- Panel backing: slightly angled plane (cel)
  local x, y, w, h = px + off_x, py + off_y, pw, ph

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.65 * ease)
  love.graphics.rectangle("fill", x + 5, y + 8, w, h, 8, 8)

  -- Body
  love.graphics.setColor(0.04, 0.05, 0.09, 0.98 * ease)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)

  -- Top strip (colored)
  love.graphics.setColor(area.color[1], area.color[2], area.color[3],
    0.20 * ease)
  love.graphics.rectangle("fill", x, y, w, 30, 8, 8)

  -- Border
  love.graphics.setColor(area.color[1], area.color[2], area.color[3],
    0.75 * ease)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 8, 8)
  love.graphics.setLineWidth(1)

  -- Corner brackets
  D.corner_brackets(x, y, w, h, area.color, 14)

  -- Header text
  love.graphics.setColor(area.color_hi[1], area.color_hi[2],
    area.color_hi[3], ease)
  love.graphics.setFont(A.font(State.theme.font_body_bold, 11))
  love.graphics.print("▲ " .. area.label .. "  ·  STATION READOUT",
    x + 16, y + 10)

  -- Item count
  love.graphics.setColor(area.color[1], area.color[2], area.color[3],
    0.75 * ease)
  love.graphics.setFont(A.font(State.theme.font_body, 9))
  love.graphics.printf(string.format("%d module(s)", #area.items),
    x, y + 11, w - 16, "right")

  -- Items
  local row_h = 32
  local pad_y = 40
  for i, it in ipairs(area.items) do
    local ry = y + pad_y + (i - 1) * row_h
    if ry + row_h > y + h - 4 then break end
    local focused = (i == S.sel)

    -- Row focus background
    if focused then
      local pulse = 0.5 + 0.5 * math.sin(t * 4)
      love.graphics.setColor(area.color[1], area.color[2], area.color[3],
        (0.16 + pulse * 0.08) * ease)
      love.graphics.rectangle("fill", x + 8, ry, w - 16, row_h - 2, 4, 4)
      love.graphics.setColor(area.color[1], area.color[2], area.color[3],
        ease)
      love.graphics.rectangle("fill", x + 8, ry, 3, row_h - 2, 1, 1)
    end

    -- Road sign marker
    local sign_size = 22
    local sign_cx = x + 26
    local sign_cy = ry + row_h / 2 - 1
    draw_road_sign(it.sign or "hex", sign_cx, sign_cy, sign_size,
      it.sign_col or area.color, it.icon, focused)

    -- Label
    love.graphics.setColor(focused and {1, 1, 1} or {0.80, 0.84, 0.92})
    love.graphics.setFont(A.font(State.t_ui and
      State.theme.font_body_bold or "assets/fonts/Oxanium-Bold.ttf",
      focused and 12 or 11))
    love.graphics.print(it.label, x + 48, ry + 3)

    -- Desc (only when focused)
    if focused then
      love.graphics.setColor(it.sign_col[1], it.sign_col[2], it.sign_col[3],
        0.85 * ease)
      love.graphics.setFont(A.font(State.theme.font_body, 9))
      love.graphics.print(it.desc or "", x + 48, ry + 18)
    end

    -- Badge on the right
    if it.badge then
      local bf = A.font(State.theme.font_body_bold, 9)
      love.graphics.setFont(bf)
      local bw = bf:getWidth(it.badge) + 16
      local bx = x + w - bw - 20
      local by = ry + (row_h - 16) / 2
      local sc = it.sign_col or area.color

      local alpha = 0.85
      local pulse_t = _badge_pulse[it.key]
      if pulse_t then
        local elapsed = t - pulse_t
        if elapsed < 0.6 then
          alpha = 0.85 + 0.15 * math.sin(elapsed * 20)
        end
      end

      love.graphics.setColor(sc[1], sc[2], sc[3], alpha * ease)
      love.graphics.rectangle("fill", bx, by, bw, 16, 8, 8)
      love.graphics.setColor(0, 0, 0, 0.95 * ease)
      love.graphics.printf(it.badge, bx, by + 2, bw, "center")
    end

    -- Cursor
    if focused then
      local ax = x + 12 + math.sin(t * 6) * 2
      love.graphics.setColor(area.color_hi[1], area.color_hi[2],
        area.color_hi[3], ease)
      GL.triangle_right(ax, ry + row_h / 2 - 1, 5,
        area.color_hi, ease)
    end
  end
end

-- ── Lifecycle ──────────────────────────────────────────────
local function snapshot_badges(areas)
  local now = State.t_ui or 0
  for _, a in ipairs(areas) do
    for _, it in ipairs(a.items) do
      if it.badge then
        local prev = _badge_prev[it.key]
        if prev ~= nil and prev ~= it.badge then
          _badge_pulse[it.key] = now
        end
        _badge_prev[it.key] = it.badge
      end
    end
  end
end

function S.enter()
  S._areas = build_areas()
  S.area = 1
  S.cam = 1
  S.sel = 1
  S.panel_open = 0
  S.enter_t = 0
  snapshot_badges(S._areas)

  -- Build the environment canvas the first time
  if not S._env then
    S._env = build_environment()
  end
end

function S.leave() end

function S.re_enter()
  S._areas = build_areas()
  snapshot_badges(S._areas)
  -- Clamp
  if S.area > #S._areas then S.area = 1 end
  local a = current_area()
  if a and S.sel > #a.items then S.sel = 1 end
end

-- ── Input ──────────────────────────────────────────────────
local function change_area(delta)
  local n = #(S._areas or {})
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.area + delta))
  if ni ~= S.area then
    S.area = ni
    S.sel = 1
    S.panel_open = 0
    SFX.play("menu_pagescroll")
  end
end

local function move_item(delta)
  local a = current_area()
  if not a then return end
  local n = #a.items
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
  end
end

local function activate()
  local it = current_item()
  if not it then return end
  SFX.play("menu_select")
  if it.target == "workshop_diff" then
    local active = PM.active_profile("rtcoreprofile") or "Default"
    State.go("workshop_diff", { kind = "rtcoreprofile", name = active })
    return
  end
  State.go(it.target)
end

function S.pad(b)
  if     b == IM.L1 then change_area(-1)
  elseif b == IM.R1 then change_area(1)
  elseif b == IM.A  then activate() end
end

function S.hat(dir)
  if     dir == "left"  then change_area(-1)
  elseif dir == "right" then change_area(1)
  elseif dir == "up"    then move_item(-1)
  elseif dir == "down"  then move_item(1) end
end

function S.key(k)
  if     k == "left"  then change_area(-1)
  elseif k == "right" then change_area(1)
  elseif k == "up"    then move_item(-1)
  elseif k == "down"  then move_item(1)
  elseif k == "return" or k == "space" then activate() end
end

-- ── Update ─────────────────────────────────────────────────
function S.update(dt)
  S.enter_t = (S.enter_t or 0) + dt

  -- Camera lerp toward target area
  local target = S.area
  local k = math.min(1, dt * 8)
  S.cam = S.cam + (target - S.cam) * k

  -- Panel open: 1 when settled, 0 while transitioning
  local dist = math.abs(S.cam - S.area)
  local target_open = (dist < 0.15) and 1 or 0
  local k_open = math.min(1, dt * 6)
  S.panel_open = S.panel_open + (target_open - S.panel_open) * k_open
end

-- ── Draw ───────────────────────────────────────────────────
function S.draw()
  local th = State.theme
  local t = State.t_ui or 0

  -- Environment canvas (pre-rendered)
  if not S._env then S._env = build_environment() end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(S._env, 0, 0)

  -- Parallax shift on the back wall (subtle, driven by camera)
  local parallax = (S.cam - S.area) * 20
  love.graphics.setColor(0.20, 0.72, 0.98, 0.04)
  for i = 1, 4 do
    love.graphics.rectangle("fill",
      (i - 1) * 200 + parallax - 40, TOP + 60, 120, 100, 3, 3)
  end

  -- Draw all booths (inactive first, active on top)
  local areas = S._areas or {}
  for i, a in ipairs(areas) do
    if i ~= S.area then
      draw_booth(a, i, S.cam, false, t)
    end
  end
  if areas[S.area] then
    draw_booth(areas[S.area], S.area, S.cam, true, t)
  end

  -- Items panel
  local area = current_area()
  if area then
    draw_items_panel(area, S.panel_open, t)
  end

  -- Ambient overlay (scanlines, very subtle)
  love.graphics.setColor(0, 0, 0, 0.05)
  for yy = TOP, BOTTOM, 3 do
    love.graphics.rectangle("fill", 0, yy, W, 1)
  end

  -- Header on top
  Header.draw("WORKSHOP", "workshop", "workshop")

  -- Footer
  local footer_items
  if area and #area.items > 1 then
    footer_items = {
      { key = "l1",   label = "Prev area" },
      { key = "r1",   label = "Next area" },
      { key = "dpad", label = "Nav"       },
      { key = "a",    label = "Enter"     },
      { key = "b",    label = "Back"      },
    }
  else
    footer_items = {
      { key = "l1", label = "Prev area" },
      { key = "r1", label = "Next area" },
      { key = "a",  label = "Enter"     },
      { key = "b",  label = "Back"      },
    }
  end
  BI.draw_footer(th, footer_items, W, H - 22,
    A.font(th.font_body, 11))
end

return S