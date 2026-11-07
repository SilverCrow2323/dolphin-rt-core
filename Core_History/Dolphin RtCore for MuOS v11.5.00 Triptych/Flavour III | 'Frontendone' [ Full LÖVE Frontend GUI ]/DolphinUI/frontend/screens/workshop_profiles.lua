-- screens/workshop_profiles.lua — Rt:Core profiles editor.
--
-- v0.8.0 — expanded-panel layout fix
--   * Panel height when a profile is expanded now reserves +30 px for
--     the tag pills instead of +20. With the old value, a long
--     description plus 2-3 tags pushed the tag row past the bottom
--     border of the expanded card (visible in the v0.7.x screenshots).
--   * Description baseline offset from +6 to +8; tags baseline from
--     "+8 + N*14" to "+12 + N*16" — matches the new line-height.
--   * All strings translated to English.
--
-- Drift detection is computed once in enter() / re_enter().
-- State.raw_input is held true for the whole lifetime.

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
local PM     = require("profile_manager")
local Notify = require("notify")
local Modal  = require("modal")

local S = {}
local W, H = 640, 480

S.sel       = 1
S.list      = {}
S.groups    = {}
S.expanded  = false
S.confirm   = nil
S._drift    = nil

-- ── Category palette ────────────────────────────────────────
local TYPE_COLORS = {
  ["Balanced"]      = {0.55, 0.35, 0.95},
  ["Performance"]   = {0.90, 0.35, 0.55},
  ["Accuracy"]      = {0.30, 0.85, 0.40},
  ["Minoru's Hint"] = {0.96, 0.77, 0.26},
  ["Fix"]           = {0.20, 0.72, 0.98},
  ["Custom"]        = {0.96, 0.55, 0.26},
}

local function type_color(t)
  return TYPE_COLORS[t] or {0.55, 0.55, 0.65}
end

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function safe_name(name)
  if type(name) ~= "string" then return nil end
  if name == "" then return nil end
  if name:find("[/\\]") then return nil end
  if name:find("%.%.") then return nil end
  if name:sub(1, 1) == "." then return nil end
  return name
end

local function parse_hex(c, fb)
  if not c or c == "" then return fb end
  local r, g, b = c:match("#(%x%x)(%x%x)(%x%x)")
  if r then
    return { tonumber(r, 16) / 255,
             tonumber(g, 16) / 255,
             tonumber(b, 16) / 255 }
  end
  return fb
end

local function rebuild()
  local raw = PM.list("rtcoreprofile")
  local by_type = {}
  local order = {}
  for _, item in ipairs(raw) do
    local t = (item.meta.Profile and item.meta.Profile.Type) or "Other"
    if not by_type[t] then
      by_type[t] = {}
      table.insert(order, t)
    end
    table.insert(by_type[t], item)
  end
  S.list = {}; S.groups = {}
  for _, t in ipairs(order) do
    table.insert(S.groups, { name = t, items = by_type[t] })
    for _, item in ipairs(by_type[t]) do
      table.insert(S.list, item)
    end
  end
  S.sel = math.max(1, math.min(#S.list, S.sel))
end

local function refresh_drift()
  local ok, d = pcall(PM.detect_drift, "rtcoreprofile")
  S._drift = ok and d or { saved = false }
end

local function focused() return S.list[S.sel] end

local function is_locked(item)
  if not item or not item.meta.Runtime then return false end
  local v = item.meta.Runtime.Locked
  return v == "True" or v == "true" or v == "1"
end

local function is_active(item)
  return item and item.name == (PM.active_profile("rtcoreprofile") or "")
end

local function next_custom_name()
  local n = 1
  while n < 1000 do
    local name = string.format("Custom%03d", n)
    local f = io.open("workshop/rtcoreprofile/" .. name ..
                      "/rtprofile_data.ini", "r")
    if not f then return name end
    f:close()
    n = n + 1
  end
  return nil
end

local function copy_profile_to_custom(src_dir, new_name)
  if not src_dir or src_dir == "" then return false end
  local safe = safe_name(new_name)
  if not safe then return false end
  if src_dir:find("%.%.") or src_dir:sub(1, 1) == "/" then return false end

  local dst_dir = "workshop/rtcoreprofile/" .. safe
  local chk = io.open(dst_dir .. "/rtprofile_data.ini", "r")
  if chk then chk:close(); return false end

  os.execute("mkdir -p " .. shq(dst_dir))
  os.execute("cp -r " .. shq(src_dir) .. "/. " .. shq(dst_dir) .. "/")

  local old_name = "?"
  local PMerger = require("profile_merger")
  local parsed = PMerger.parse_ini(src_dir .. "/rtprofile_data.ini")
  if parsed and parsed.data.Profile and parsed.data.Profile.Name then
    old_name = parsed.data.Profile.Name
  end

  local mf = io.open(dst_dir .. "/rtprofile_data.ini", "w")
  if not mf then return false end
  mf:write("[Profile]\n")
  mf:write("Name        = " .. safe .. "\n")
  mf:write("Type        = Custom\n")
  mf:write("Description = Copy of " .. old_name .. "\n")
  mf:write("Author      = DolphinUI Editor\n")
  mf:write("Version     = 1.0.0\n")
  mf:write("Date        = " .. os.date("%Y-%m-%d") .. "\n\n")
  mf:write("[UI]\n")
  mf:write("Color       = #4FA8C7\n")
  mf:write("BorderStyle = rounded\n")
  mf:write("Icon        = balanced\n")
  mf:write("Order       = 200\n")
  mf:write("Tags        = custom, copy\n\n")
  mf:write("[Runtime]\n")
  mf:write("RequiresBase = Default\n")
  mf:write("Locked       = False\n")
  mf:close()
  return true
end

local function do_apply(item)
  if not item then return end
  local name = safe_name(item.name)
  if not name then
    Notify.show("error", "Invalid profile name"); return
  end
  if PM.apply("rtcoreprofile", name) then
    PM.set_active("rtcoreprofile", name)
    refresh_drift()
  end
end

local function do_delete(item)
  if not item then return end
  if is_locked(item) then
    Notify.show("warning", "Locked profile — cannot delete"); return
  end
  local name = safe_name(item.name)
  if not name then
    Notify.show("error", "Invalid profile name"); return
  end
  local dir = item.dir
  if not dir:find("^workshop/rtcoreprofile/") then
    Notify.show("error", "Refusing to delete outside workshop/"); return
  end
  os.execute("rm -rf " .. shq(dir))
  Notify.show("info", "Deleted: " .. name)
  rebuild()
  refresh_drift()
end

local function close_confirm()
  S.confirm = nil
  SFX.play("menu_back")
end

local function do_edit(item, new_name)
  local dir = "workshop/rtcoreprofile/" .. new_name
  local f = io.open(dir .. "/rtprofile_data.ini", "r")
  if not f then
    Notify.show("error", "Profile dir missing: " .. dir)
    return
  end
  f:close()
  State.go("workshop_files", {
    profile_dir  = dir,
    profile_name = new_name,
  })
end

function S.enter()
  S.sel = 1
  S.expanded = false
  S.confirm = nil
  rebuild()
  refresh_drift()
  State.raw_input = true
end

function S.leave()
  State.raw_input = false
end

function S.re_enter()
  State.raw_input = true
  rebuild()
  refresh_drift()
end

local function move(delta)
  if S.confirm then return end
  local n = #S.list
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni; S.expanded = false; SFX.play("menu_move")
  end
end

local function request_apply()
  local item = focused()
  if not item then return end
  S.confirm = { action = "apply", item = item }
  SFX.play("menu_select")
end

local function request_delete()
  local item = focused()
  if not item then return end
  if is_locked(item) then
    Notify.show("warning", "Locked profile")
    return
  end
  S.confirm = { action = "delete", item = item }
  SFX.play("menu_select")
end

local function request_edit()
  local item = focused()
  if not item then return end

  if is_locked(item) then
    local new_name = next_custom_name()
    if not new_name then
      Notify.show("error", "No free Custom slot (Custom001..Custom999)")
      return
    end
    Modal.show("Built-in profile",
      "This profile is locked and cannot be edited directly.\n\n" ..
      "A copy will be created as \"" .. new_name .. "\" and the " ..
      "editor will open on the copy.",
      {
        accept_label = "Copy & Edit",
        cancel_label = "Cancel",
        color = {0.20, 0.72, 0.98},
        on_accept = function()
          if copy_profile_to_custom(item.dir, new_name) then
            rebuild()
            refresh_drift()
            do_edit(item, new_name)
          else
            Notify.show("error", "Copy failed")
          end
        end,
      })
    return
  end

  SFX.play("menu_select")
  do_edit(item, item.name)
end

local function open_diff()
  local item = focused()
  if item then
    State.go("workshop_diff", { kind = "rtcoreprofile", name = item.name })
  end
end

function S.pad(b)
  if S.confirm then
    if b == IM.A then
      local c = S.confirm
      S.confirm = nil
      if c.action == "apply" then do_apply(c.item)
      elseif c.action == "delete" then do_delete(c.item) end
    elseif b == IM.B then
      close_confirm()
    end
    return
  end
  if     b == IM.A      then request_apply()
  elseif b == IM.X      then request_delete()
  elseif b == IM.Y      then request_edit()
  elseif b == IM.START  then
    S.expanded = not S.expanded; SFX.play("menu_toggleoption")
  elseif b == IM.SELECT then open_diff()
  elseif b == IM.B      then
    State.raw_input = false
    State.back()
  end
end

function S.hat(dir)
  if S.confirm then return end
  if     dir == "up"   then move(-1)
  elseif dir == "down" then move(1) end
end

function S.key(k)
  if S.confirm then
    if k == "return" or k == "space" then
      local c = S.confirm
      S.confirm = nil
      if c.action == "apply" then do_apply(c.item)
      elseif c.action == "delete" then do_delete(c.item) end
    elseif k == "escape" then
      close_confirm()
    end
    return
  end
  if     k == "up"    then move(-1)
  elseif k == "down"  then move(1)
  elseif k == "return" or k == "space" then request_apply()
  elseif k == "x"     then request_delete()
  elseif k == "y"     then request_edit()
  elseif k == "tab"   then
    S.expanded = not S.expanded; SFX.play("menu_toggleoption")
  elseif k == "escape" then
    State.raw_input = false
    State.back()
  end
end

-- ── Rendering ───────────────────────────────────────────────

local function draw_category_ribbon(th)
  local y = Header.height() + 4
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, y, W, 26)
  love.graphics.setColor(0.30, 0.30, 0.35, 0.5)
  love.graphics.rectangle("fill", 0, y + 25, W, 1)

  local counts = {}
  for _, item in ipairs(S.list) do
    local t = (item.meta.Profile and item.meta.Profile.Type) or "Other"
    counts[t] = (counts[t] or 0) + 1
  end

  local order = {}
  for t in pairs(counts) do table.insert(order, t) end
  table.sort(order)

  local x = 14
  local font = A.font(th.font_body_bold, 10)
  love.graphics.setFont(font)

  for _, t in ipairs(order) do
    local c = type_color(t)
    local label = t .. " " .. counts[t]
    local w = font:getWidth(label) + 16
    if x + w > W - 14 then break end

    love.graphics.setColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.95)
    love.graphics.rectangle("fill", x, y + 5, w, 16, 8, 8)
    love.graphics.setColor(c[1], c[2], c[3], 0.9)
    love.graphics.rectangle("line", x, y + 5, w, 16, 8, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + 8, w, "center")

    x = x + w + 6
  end
end

local function draw_drift_banner(th)
  local drift = S._drift or { saved = false }
  local active = PM.active_profile("rtcoreprofile") or "—"

  local y = Header.height() + 34
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, y, W, 22)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", 0, y + 21, W, 1)

  local t = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 4)
  local dot_col = drift.saved and {0.30, 0.80, 0.40} or {0.90, 0.30, 0.30}
  GL.dot(14, y + 11, 3.5, dot_col, 0.6 + pulse * 0.4)

  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.setColor(0.60, 0.60, 0.70)
  love.graphics.print("ACTIVE:", 24, y + 5)

  love.graphics.setColor(0.30, 0.80, 0.40)
  love.graphics.print(active, 78, y + 5)

  local sx = W - 14
  local label = drift.saved and "SAVED" or "UNSAVED"
  local col = drift.saved and {0.30, 0.80, 0.40} or {0.90, 0.30, 0.30}
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  local tw = love.graphics.getFont():getWidth(label)
  love.graphics.setColor(col)
  love.graphics.print(label, sx - tw, y + 6)

  if drift.saved and drift.profile then
    love.graphics.setColor(0.55, 0.55, 0.65)
    love.graphics.setFont(A.font(th.font_body, 9))
    local sub = "(" .. drift.profile .. ")"
    local sw = love.graphics.getFont():getWidth(sub)
    love.graphics.print(sub, sx - tw - sw - 8, y + 7)
  end
end

-- One profile card. Returns the vertical space consumed.
local function draw_profile_row(item, i, focused_flag, y, th)
  local t = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 4 + i * 0.15)

  local typ = (item.meta.Profile and item.meta.Profile.Type) or "Other"
  local c = type_color(typ)

  local ini_c = item.meta.UI and item.meta.UI.Color
  if ini_c then
    local parsed = parse_hex(ini_c, nil)
    if parsed then c = parsed end
  end

  local x = 20
  local w = W - 40
  local h = 46

  if focused_flag then D.glow(x + w/2, y + h/2, 45 + pulse * 15, c, 0.9) end

  -- Card background
  love.graphics.setColor(
      focused_flag and c[1] * 0.28 or c[1] * 0.10,
      focused_flag and c[2] * 0.28 or c[2] * 0.10,
      focused_flag and c[3] * 0.28 or c[3] * 0.10, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)

  -- Left rail
  love.graphics.setColor(c[1], c[2], c[3], focused_flag and 1 or 0.7)
  love.graphics.rectangle("fill", x, y, 5, h)

  -- Border
  love.graphics.setColor(c)
  D.rough_rect(x, y, w, h,
    { jitter = focused_flag and 1.1 or 0.7,
      thickness = focused_flag and 2.5 or 1.4, seed = i * 11 })
  if focused_flag then
    D.corner_brackets(x, y, w, h, c, 12)
  end

  -- Icon
  local icon_key = (item.meta.UI and item.meta.UI.Icon) or "balanced"
  Icons.draw(icon_key, x + 12, y + 14, 20,
    focused_flag and {1, 1, 1} or c)

  -- Name
  love.graphics.setColor(focused_flag and {1, 1, 1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 12))
  love.graphics.print(item.name, x + 40, y + 4)

  -- Type pill
  local pill_font = A.font(th.font_body_bold, 8)
  love.graphics.setFont(pill_font)
  local pill_label = typ:upper()
  local pill_w = pill_font:getWidth(pill_label) + 12
  love.graphics.setColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 0.95)
  love.graphics.rectangle("fill", x + 40, y + 22, pill_w, 13, 6, 6)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(pill_label, x + 40, y + 24, pill_w, "center")

  -- Active badge with procedural dot
  if is_active(item) then
    local badge = "ACTIVE"
    local font = A.font(th.font_body_bold, 9)
    love.graphics.setFont(font)
    local tw = font:getWidth(badge)
    local bw = tw + 26  -- extra room for the dot
    local bx = x + w - bw - 10
    love.graphics.setColor(0.30, 0.80, 0.40, 0.9)
    love.graphics.rectangle("fill", bx, y + 6, bw, 15, 8, 8)
    GL.dot(bx + 10, y + 13.5, 3, {0, 0, 0}, 0.9)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(badge, bx + 16, y + 7, bw - 18, "center")
  end

  -- Lock / editable badge with procedural glyphs
  local lock_col = is_locked(item) and {0.55, 0.55, 0.65} or {0.20, 0.72, 0.98}
  local lock_label = is_locked(item) and "LOCKED" or "EDITABLE"
  local lb_font = A.font(th.font_body_bold, 8)
  love.graphics.setFont(lb_font)
  local lb_w = lb_font:getWidth(lock_label) + 22
  local lbx = x + w - lb_w - 10
  love.graphics.setColor(lock_col[1], lock_col[2], lock_col[3], 0.4)
  love.graphics.rectangle("fill", lbx, y + 26, lb_w, 13, 6, 6)
  -- Glyph
  if is_locked(item) then
    GL.square(lbx + 8, y + 32.5, 3, lock_col, 0.95)
  else
    GL.pencil(lbx + 8, y + 32.5, 5, lock_col, 0.95)
  end
  love.graphics.setColor(math.min(1, lock_col[1] + 0.3),
    math.min(1, lock_col[2] + 0.3),
    math.min(1, lock_col[3] + 0.3), 0.95)
  love.graphics.printf(lock_label, lbx + 14, y + 27, lb_w - 16, "center")

  -- Expanded info panel
  if focused_flag and S.expanded then
    local prof = item.meta.Profile or {}
    local desc = prof.Description or ""
    local tags = (item.meta.UI and item.meta.UI.Tags) or ""

    local fnt = A.font(th.font_body, 10)
    local _, wrapped = fnt:getWrap(desc, w - 24)
    -- +30 (was +20) when tags are present: the tag pills row needs a
    -- full 18-px band plus 6 px of breathing room below the description.
    -- With the old value a long description plus 3+ tags pushed the
    -- pill row past the bottom of the expanded card.
    local bh = 18 + #wrapped * 16 + (tags ~= "" and 30 or 6)

    local by = y + h + 2
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, by, w, bh, 2, 2)
    love.graphics.setColor(c[1], c[2], c[3], 0.55)
    D.rough_rect(x, by, w, bh,
      { jitter = 0.6, thickness = 1.2, seed = i * 19 })

    love.graphics.setColor(th.text)
    love.graphics.setFont(fnt)
    love.graphics.printf(desc, x + 12, by + 8, w - 24, "left")

    if tags ~= "" then
      local ty = by + 12 + #wrapped * 16
      local tx = x + 12
      local tf = A.font(th.font_body_bold, 8)
      for tag in tags:gmatch("[^,]+") do
        tag = tag:match("^%s*(.-)%s*$")
        if tag ~= "" then
          local tw = tf:getWidth(tag) + 12
          love.graphics.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.95)
          love.graphics.rectangle("fill", tx, ty, tw, 14, 7, 7)
          love.graphics.setColor(1, 1, 1)
          love.graphics.setFont(tf)
          love.graphics.printf(tag, tx, ty + 2, tw, "center")
          tx = tx + tw + 4
          if tx > x + w - 60 then break end
        end
      end
    end

    return h + bh + 4
  end

  return h + 5
end

local function draw_group_header(grp, y, th)
  local c = type_color(grp.name)
  local t = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 2 + y * 0.01)

  GL.dot(26, y + 10, 5, c, 0.30 + pulse * 0.40)
  GL.dot(26, y + 10, 2.5, c, 1)

  love.graphics.setColor(c)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  local label = grp.name:upper() .. "  ·  " .. #grp.items
  love.graphics.print(label, 38, y + 4)

  local lw = love.graphics.getFont():getWidth(label)
  local lx = 38 + lw + 12
  local lr = W - 20
  if lr - lx > 8 then
    love.graphics.setColor(c[1], c[2], c[3], 0.20)
    love.graphics.line(lx, y + 10, lr, y + 10)
    love.graphics.setColor(c[1], c[2], c[3], 0.55)
    love.graphics.rectangle("fill", lx, y + 9, 4, 2)
  end
end

local function draw_list(th)
  if #S.list == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No Rt:Core profiles found.\n\nExpected location:\n" ..
      "workshop/rtcoreprofile/",
      0, H / 2 - 20, W, "center")
    return
  end

  local y = Header.height() + 66
  local idx = 0
  for _, grp in ipairs(S.groups) do
    if y + 22 < H - 30 then
      draw_group_header(grp, y, th)
    end
    y = y + 22
    for _, item in ipairs(grp.items) do
      idx = idx + 1
      local focused_flag = (idx == S.sel)
      if y + 46 > Header.height() + 60 and y < H - 30 then
        y = y + draw_profile_row(item, idx, focused_flag, y, th)
      else
        y = y + 51
      end
    end
  end
end

local function draw_confirm(th)
  if not S.confirm then return end
  local c = S.confirm
  local item = c.item

  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 420, 168
  local bx, by = (W - bw) / 2, (H - bh) / 2

  local col = (c.action == "delete")
      and {0.90, 0.30, 0.30} or {0.30, 0.80, 0.40}

  love.graphics.setColor(0.08, 0.08, 0.12, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(col)
  D.rough_rect(bx, by, bw, bh,
    { jitter = 1.5, thickness = 2.5, seed = 77, cut = 18 })
  D.corner_brackets(bx, by, bw, bh, col, 14)

  love.graphics.setColor(col[1], col[2], col[3], 0.12)
  love.graphics.rectangle("fill", bx, by, bw, 28, 6, 6)
  love.graphics.setColor(col)
  love.graphics.setFont(A.font(th.font_title, 14))
  local title = (c.action == "delete") and "DELETE PROFILE?" or "APPLY PROFILE?"
  love.graphics.printf(title, bx, by + 8, bw, "center")

  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.printf(
    item.meta.Profile and item.meta.Profile.Name or item.name,
    bx, by + 54, bw, "center")

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  local msg = (c.action == "delete")
      and "This will permanently remove the profile directory."
      or  "Applies the profile to dolphin-emu/Config/.\n" ..
          "An automatic backup is created first."
  love.graphics.printf(msg, bx + 20, by + 84, bw - 40, "center")

  love.graphics.setColor(col)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.printf("[A] Confirm   [B] Cancel",
    bx, by + bh - 26, bw, "center")
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("RT:CORE PROFILES", "settings")

  draw_category_ribbon(th)
  draw_drift_banner(th)
  draw_list(th)

  BI.draw_footer(th, {
    { key = "dpad",   label = "Nav" },
    { key = "a",      label = "Apply" },
    { key = "y",      label = "Edit" },
    { key = "x",      label = "Delete" },
    { key = "start",  label = "Info" },
    { key = "select", label = "Diff" },
    { key = "b",      label = "Back" },
  }, W, H - 22, A.font(th.font_body, 11))

  draw_confirm(th)
end

return S