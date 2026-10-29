-- frontend/screens/ethostore.lua
-- Rt:Enhancer Dock — storefront for Rt:Resources, muOS tools and
-- homebrew packages. Items come from data/rtenhancerhub.json,
-- populated by boot_downloader.lua at startup.
--
-- Layout:
--   * Top: hero dashboard with 4 category stat tiles.
--   * Middle: latest release panel (from GitHub, via Rt:Enhancer JSON).
--   * Bottom: item grid, grouped by category. A on an item
--     enqueues it in the persistent download queue
--     (frontend/downloader.lua), then switches to the queue overlay.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local Icons  = require("ui.icons")
local BI     = require("ui.button_icons")
local Notify = require("notify")
local DL     = require("downloader")

local S = {}
local W, H = 640, 480

-- ── Category catalogue ─────────────────────────────────────────
local DASH_STATS = {
  { key = "rt_resources", icon = "enhancer",   color = {0.20, 0.72, 0.98}, label = "RT RESOURCES"  },
  { key = "muos_tools",   icon = "advanced",   color = {0.96, 0.77, 0.26}, label = "MUOS TOOLS"    },
  { key = "homebrew",     icon = "homebrew",   color = {0.30, 0.85, 0.40}, label = "HOMEBREW"      },
  { key = "configs",      icon = "settings",   color = {0.55, 0.35, 0.95}, label = "CONFIG PACKS"  },
}

-- ── Runtime state ──────────────────────────────────────────────
S.sel           = 1
S.scroll        = 0
S._cat_counts   = {}
S._items        = {}
S._filter       = 1          -- 1 = ALL, otherwise index into DASH_STATS
S._dashboard    = 1          -- 1 = dashboard focus, 2 = item list focus
S.latest_release = nil
S._fetch_pending = false
S._enter_t      = 0

-- ── Item catalogue from State.enhancer_hub ────────────────────
local function rebuild_items()
  S._items = {}
  S._cat_counts = { rt_resources = 0, muos_tools = 0, homebrew = 0, configs = 0 }

  local raw = State.enhancer_hub or {}
  for _, it in ipairs(raw) do
    if type(it) == "table" and it.id and it.name then
      S._cat_counts[it.category] = (S._cat_counts[it.category] or 0) + 1
      if S._filter == 1 or DASH_STATS[S._filter] and
         DASH_STATS[S._filter].key == it.category then
        S._items[#S._items + 1] = it
      end
    end
  end

  table.sort(S._items, function(a, b)
    return (a.name or ""):lower() < (b.name or ""):lower()
  end)
  S.sel = math.max(1, math.min(#S._items, S.sel))
end

-- ── Latest-release fetch (async, file-marker based) ──────────
local RELEASE_MARK = "/tmp/dolphinui_ethostore_rel.done"
local RELEASE_OUT  = "/tmp/dolphinui_ethostore_rel.json"

local function fetch_latest_release()
  if S._fetch_pending then return end
  S._fetch_pending = true
  os.remove(RELEASE_MARK)
  os.remove(RELEASE_OUT)

  local url = "https://api.github.com/repos/SilverCrow2323/" ..
              "Dolphin-Core-for-MuOS/releases/latest"

  local body = table.concat({
    "{ curl -fsSL --connect-timeout 6 --max-time 15 -o " ..
      "'" .. RELEASE_OUT .. "' '" .. url .. "' 2>/dev/null; }",
    "echo $? > '" .. RELEASE_MARK .. "'",
  }, "\n")

  local f = io.open("/tmp/dolphinui_ethostore_rel.sh", "w")
  if not f then return end
  f:write("#!/bin/sh\n" .. body .. "\n")
  f:close()
  os.execute("chmod +x /tmp/dolphinui_ethostore_rel.sh")
  os.execute("setsid sh /tmp/dolphinui_ethostore_rel.sh </dev/null " ..
             ">/dev/null 2>&1 &")
end

local function poll_latest_release()
  if not S._fetch_pending then return end
  local mf = io.open(RELEASE_MARK, "r")
  if not mf then return end
  local rc = tonumber(mf:read("*a")) or 1
  mf:close()
  os.remove(RELEASE_MARK)
  S._fetch_pending = false

  if rc ~= 0 then return end
  local of = io.open(RELEASE_OUT, "r")
  if not of then return end
  local content = of:read("*a"); of:close()
  os.remove(RELEASE_OUT)

  local ok, json = pcall(require, "json")
  if not ok then return end
  local ok2, decoded = pcall(json.decode, content)
  if ok2 and type(decoded) == "table" and decoded.tag_name then
    S.latest_release = decoded
  end
end

-- ── Lifecycle ─────────────────────────────────────────────────
function S.enter()
  S.sel           = 1
  S.scroll        = 0
  S._filter       = 1
  S._dashboard    = 1
  S._enter_t      = 0
  rebuild_items()
  if not S.latest_release then
    fetch_latest_release()
  end
end

function S.leave()
  State.raw_input = false
end

function S.re_enter()
  rebuild_items()
end

-- ── Navigation ────────────────────────────────────────────────
local function move_item(delta)
  local n = #S._items
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
    -- keep focused row visible
    local row_h = 30
    local vis_h = H - 300
    local top   = (S.sel - 1) * row_h
    if top < S.scroll then S.scroll = top
    elseif top + row_h > S.scroll + vis_h then
      S.scroll = top + row_h - vis_h
    end
  end
end

local function cycle_filter(delta)
  local n = #DASH_STATS + 1
  S._filter = ((S._filter - 1 + delta) % n) + 1
  S.sel = 1
  S.scroll = 0
  rebuild_items()
  SFX.play("menu_pagescroll")
end

-- ── Enqueue action ────────────────────────────────────────────
local function enqueue_focused()
  local it = S._items[S.sel]
  if not it then return end
  local ok, err = DL.enqueue(it, {})
  if ok then
    Notify.show("success", "Queued: " .. (it.name or "?"))
    SFX.play("menu_select")
  elseif err == "already queued" then
    Notify.show("info", "Already in queue: " .. (it.name or "?"))
  else
    Notify.show("warning", "Cannot queue: " .. tostring(err or "?"))
  end
end

-- ── Input ─────────────────────────────────────────────────────
function S.pad(b)
  if b == IM.A then
    enqueue_focused()
  elseif b == IM.R1 then
    S.latest_release = nil
    fetch_latest_release()
    SFX.play("menu_pagescroll")
  elseif b == IM.L1 then
    cycle_filter(-1)
  elseif b == IM.R1 then
    cycle_filter(1)
  elseif b == IM.X then
    -- open the download manager overlay
    local DLOverlay = require("ui.download_overlay")
    if DLOverlay and DLOverlay.open then DLOverlay.open() end
  end
end

function S.hat(dir)
  if     dir == "up"   then move_item(-1)
  elseif dir == "down" then move_item(1)
  elseif dir == "left" then cycle_filter(-1)
  elseif dir == "right"then cycle_filter(1) end
end

function S.key(k)
  if     k == "up"    then move_item(-1)
  elseif k == "down"  then move_item(1)
  elseif k == "left"  then cycle_filter(-1)
  elseif k == "right" then cycle_filter(1)
  elseif k == "return" or k == "space" then enqueue_focused()
  elseif k == "r" then
    S.latest_release = nil
    fetch_latest_release()
  end
end

function S.update(dt)
  S._enter_t = (S._enter_t or 0) + dt
  poll_latest_release()
end

-- ── Rendering helpers ─────────────────────────────────────────
local function draw_press_a_retry(th, x, y)
  local font = A.font(th.font_body, 10)
  love.graphics.setFont(font)
  local pre   = "Press"
  local post  = "to retry"
  local pre_w = font:getWidth(pre)
  local a_sz  = 16

  love.graphics.setColor(0.55, 0.68, 0.82)
  love.graphics.print(pre, x, y + 2)
  BI.draw(th, "a", x + pre_w + 6, y - 1, a_sz)
  love.graphics.setFont(font)
  love.graphics.setColor(0.55, 0.68, 0.82)
  love.graphics.print(post, x + pre_w + 6 + a_sz + 6, y + 2)
end

local function draw_dashboard(th)
  local t = State.t_ui or 0
  local px, py, pw, ph = 22, 88, W - 44, 226

  love.graphics.setColor(0.02, 0.04, 0.07, 0.88)
  love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)

  D.glow(px + pw / 2, py + ph / 2, 220, {0.20, 0.72, 0.98}, 0.18)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.85)
  D.rough_rect(px, py, pw, ph, { jitter = 1.2, thickness = 2, seed = 91 })
  D.corner_brackets(px, py, pw, ph, {0.20, 0.72, 0.98}, 22)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.13)
  love.graphics.rectangle("fill", px, py, pw, 42, 8, 8)

  love.graphics.setFont(A.font(th.font_title, 15))
  love.graphics.setColor(0.90, 0.97, 1.0)
  love.graphics.print("RT:ENHANCER DOCK", px + 20, py + 10)

  local tp    = love.graphics.getFont():getWidth("RT:ENHANCER DOCK")
  local pulse = 0.5 + 0.5 * math.sin(t * 4)
  love.graphics.setColor(0.30, 0.90, 0.60, 0.5 + pulse * 0.5)
  love.graphics.circle("fill", px + 26 + tp, py + 21, 3.5)

  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.setColor(0.55, 0.72, 0.88)
  love.graphics.print("MODULE DELIVERY SYSTEM", px + 20, py + 32)

  -- Category stat tiles
  local sy  = py + 54
  local gap = 8
  local sw  = (pw - 40 - 3 * gap) / 4
  local sh  = 56
  for i, st in ipairs(DASH_STATS) do
    local sx = px + 20 + (i - 1) * (sw + gap)
    local c  = st.color
    local val = S._cat_counts[st.key] or 0

    love.graphics.setColor(c[1] * 0.14, c[2] * 0.14, c[3] * 0.14, 1)
    love.graphics.rectangle("fill", sx, sy, sw, sh, 6, 6)

    love.graphics.setColor(c[1], c[2], c[3], 0.85)
    love.graphics.rectangle("fill", sx, sy, sw, 3, 3, 3)

    love.graphics.setColor(c[1], c[2], c[3], 0.55)
    D.rough_rect(sx, sy, sw, sh,
      { jitter = 0.7, thickness = 1.3, seed = i * 11 })

    Icons.draw(st.icon, sx + 8, sy + 10, 16, c)

    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.setFont(A.font(th.font_body_bold, 24))
    love.graphics.printf(tostring(val), sx + 30, sy + 6, sw - 34, "left")

    love.graphics.setColor(0.65, 0.70, 0.80)
    love.graphics.setFont(A.font(th.font_body_bold, 9))
    love.graphics.printf(st.label, sx + 8, sy + sh - 18, sw - 16, "left")

    local fp = 0.5 + 0.5 * math.sin(t * 2 + i * 0.7)
    love.graphics.setColor(c[1], c[2], c[3], 0.15 + fp * 0.20)
    love.graphics.rectangle("fill", sx + 8, sy + sh - 5, (sw - 16) * fp, 1.5)
  end

  -- Latest release panel
  local ry = sy + sh + 4
  local rh = ph - (ry - py) - 8
  love.graphics.setColor(0.03, 0.05, 0.09, 0.95)
  love.graphics.rectangle("fill", px + 20, ry, pw - 40, rh, 6, 6)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.42)
  D.rough_rect(px + 20, ry, pw - 40, rh,
    { jitter = 0.6, thickness = 1.3, seed = 55 })

  love.graphics.setColor(0.20, 0.72, 0.98, 0.95)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("> LATEST RELEASE", px + 32, ry + 10)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.28)
  love.graphics.line(px + 32, ry + 26, px + pw - 32, ry + 26)

  local r = S.latest_release
  if r then
    local vtxt = r.tag_name or r.name or "?"
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    local vw = love.graphics.getFont():getWidth(vtxt) + 22
    love.graphics.setColor(0.20, 0.72, 0.98, 0.85)
    love.graphics.rectangle("fill", px + 32, ry + 36, vw, 22, 11, 11)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(vtxt, px + 32, ry + 41, vw, "center")

    love.graphics.setColor(0.55, 0.68, 0.82)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("published " ..
      tostring(r.published_at or "?"):sub(1, 10),
      px + 32 + vw + 12, ry + 42)

    love.graphics.setColor(0.86, 0.91, 0.96)
    love.graphics.setFont(A.font(th.font_body, 11))
    local body = tostring(r.body or ""):gsub("\r", ""):gsub("\n\n+", "\n")
    love.graphics.setScissor(px + 20, ry, pw - 40, rh)
    love.graphics.printf(body, px + 32, ry + 68, pw - 64, "left")
    love.graphics.setScissor()
  else
    local sp = t * 4
    love.graphics.setColor(0.20, 0.72, 0.98, 0.9)
    love.graphics.setLineWidth(2.2)
    love.graphics.arc("line", "open",
      px + 46, ry + 54, 12, sp, sp + 4.5)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.75, 0.85, 0.95)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.print("Fetching latest release from GitHub…",
      px + 76, ry + 48)

    draw_press_a_retry(th, px + 76, ry + 68)
  end

end

-- Item list rendered below the dashboard
local function draw_items(th)
  local top    = 318
  local bottom = H - 32
  local x      = 24
  local w      = W - 48
  local row_h  = 30

  if #S._items == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf("No items in this category.", x, top + 40, w, "center")
    return
  end

  love.graphics.setScissor(x, top, w, bottom - top)
  local y = top - S.scroll
  for i, it in ipairs(S._items) do
    local focused = (i == S.sel)
    if y + row_h > top - row_h and y < bottom + row_h then
      if focused then
        love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.18)
        love.graphics.rectangle("fill", x, y, w, row_h - 2, 4, 4)
        love.graphics.setColor(th.focus)
        love.graphics.rectangle("fill", x, y, 3, row_h - 2, 1, 1)
      end

      -- Category colour swatch
      local cc = {0.55, 0.55, 0.65}
      for _, st in ipairs(DASH_STATS) do
        if st.key == it.category then cc = st.color; break end
      end
      love.graphics.setColor(cc)
      love.graphics.circle("fill", x + 16, y + row_h / 2 - 1, 4)

      love.graphics.setColor(focused and {1, 1, 1} or th.text)
      love.graphics.setFont(A.font(th.font_body_bold, 12))
      love.graphics.print(it.name or "?", x + 32, y + 3)

      love.graphics.setColor(th.text_dim)
      love.graphics.setFont(A.font(th.font_body, 9))
      local sub = (it.subcategory or it.category or "?") ..
                  "  ·  " .. tostring(it.version or "?")
      love.graphics.print(sub, x + 32, y + 17)

      love.graphics.setColor(cc[1], cc[2], cc[3], 0.9)
      love.graphics.setFont(A.font(th.font_body_bold, 9))
      love.graphics.printf(("[A] queue"),
        x, y + 8, w - 10, "right")
    end
    y = y + row_h
  end
  love.graphics.setScissor()

  -- Scrollbar
  local total_h = #S._items * row_h
  local vis_h   = bottom - top
  if total_h > vis_h then
    local rail_x = W - 8
    love.graphics.setColor(0.30, 0.30, 0.35, 0.5)
    love.graphics.rectangle("fill", rail_x, top, 3, vis_h, 1, 1)
    local ratio = vis_h / total_h
    local bar_h = math.max(20, vis_h * ratio)
    local span  = total_h - vis_h
    local bar_y = top + (span > 0 and (S.scroll / span) *
                  (vis_h - bar_h) or 0)
    love.graphics.setColor(th.accent)
    love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
  end
end

-- ── Draw ──────────────────────────────────────────────────────
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("RT:ENHANCER DOCK", "enhancer", "rtenhancer")

  draw_dashboard(th)
  draw_items(th)

  BI.draw_footer(th, {
    { key = "dpad", label = "Navigate" },
    { key = "a",    label = "Queue"    },
    { key = "l1",   label = "Filter -" },
    { key = "r1",   label = "Filter +" },
    { key = "x",    label = "Queue UI" },
    { key = "b",    label = "Back"     },
  }, W, H - 22, A.font(th.font_body, 11))
end

return S