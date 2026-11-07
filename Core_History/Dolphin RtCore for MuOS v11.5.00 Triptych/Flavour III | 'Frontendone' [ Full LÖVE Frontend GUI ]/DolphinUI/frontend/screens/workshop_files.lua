-- frontend/screens/workshop_files.lua — universal INI editor.
--
-- v0.7.0 — terminal-editor redesign
--   * Entire body rendered in JetBrains Mono: line numbers on the
--     left, `key = value` layout, values syntax-highlighted by type
--     (True green, False red, numbers yellow, strings white).
--   * Section headers use a procedural fold marker (▶/▼ drawn as
--     polygons, no Unicode) and a colored hairline.
--   * Focused row has a left rail in the section color, a subtle
--     glow, and a right-side "edit" chevron (drawn, not printed).
--   * Status bar at the bottom of the body shows the file path,
--     line count, hidden-row count, and a pulsing "MODIFIED" pill
--     when there are unsaved changes.
--   * Guide popup restyled as a "cheat sheet": monospace, sections
--     for DESCRIPTION / WHY / VALUES, recommended value highlighted.
--   * All UI glyphs go through ui/glyph.lua — no character codes
--     that could be missing from a font.
--
-- Two operating modes:
--   * LIVE mode  (S.profile_dir == nil)
--       Base directory: dolphin-emu/Config/
--       [X] opens the "save as new profile" dialog. Live files are
--       never written by this screen.
--   * PROFILE mode  (S.profile_dir ~= nil)
--       Base directory: the given profile directory.
--       [X] writes the file back to that profile.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")
local BI      = require("ui.button_icons")
local Modal   = require("modal")
local Notify  = require("notify")
local GP      = require("guide_parser")
local GL      = require("ui.glyph")
local PMerger = require("profile_merger")

local S = {}
local W, H = 640, 480

-- ── Layout ─────────────────────────────────────────────────
local TOP_Y       = Header.height() + 26      -- below file tabs
local BOTTOM_Y    = H - 34                    -- above footer
local SEC_H       = 24
local OPT_H       = 22
local STATUS_H    = 24

local MONO_BASE   = "assets/fonts/JetBrainsMono-Regular.ttf"
local MONO_BOLD   = "assets/fonts/JetBrainsMono-Bold.ttf"

-- ── Guide lookup ───────────────────────────────────────────
local GUIDE_FOR = {
  ["Dolphin.ini"] = "data/guide/config_dolphinini.txt",
  ["GFX.ini"]     = "data/guide/config_gfxini.txt",
}

local LIVE_SNAPSHOT = {
  "Dolphin.ini", "GFX.ini",
  "GCPadNew.ini", "WiimoteNew.ini",
  "Hotkeys.ini", "Logger.ini",
}

-- ── State ──────────────────────────────────────────────────
S.mode        = "list"
S.file_idx    = 1
S.sel         = 1
S.scroll      = 0
S.expanded    = {}
S.show_all    = false
S.rows        = {}

S.sections      = {}
S.section_order = {}
S.guide         = nil
S.dirty         = false
S._hidden       = {}

S.guide_t     = 0
S.guide_target = nil
S.guide_value_sel = 1

S.save        = nil
S.input       = nil

S.profile_dir  = nil
S.profile_name = nil

local FILES = {}

-- ── Small helpers ──────────────────────────────────────────
local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function base_dir()
  return S.profile_dir or "dolphin-emu/Config"
end

local function current_file()
  return FILES[S.file_idx]
end

local function current_is_metadata()
  local f = current_file()
  return f and f.is_meta == true
end

local function is_metadata_file(name)
  return name:match("_data%.ini$") ~= nil
end

-- ── Input routing helpers ──────────────────────────────────
local function refresh_raw_input()
  State.raw_input = (S.dirty == true)
                 or (S.mode ~= "list")
                 or (S.input ~= nil)
end

local function set_dirty(v)
  v = (v == true)
  if S.dirty == v then return end
  S.dirty = v
  refresh_raw_input()
end

local function set_mode(m)
  if S.mode == m then return end
  S.mode = m
  refresh_raw_input()
end

local function set_input(i)
  S.input = i
  refresh_raw_input()
end

-- ── File list ──────────────────────────────────────────────
local function rebuild_file_list()
  FILES = {}
  local base = base_dir()
  local h = io.popen('ls -1 ' .. shq(base) .. '/*.ini 2>/dev/null')
  if h then
    for line in h:lines() do
      local name = line:match("([^/]+)$")
      if name and name:sub(1, 1) ~= "." then
        table.insert(FILES, {
          key     = name,
          guide   = GUIDE_FOR[name],
          is_meta = is_metadata_file(name),
        })
      end
    end
    h:close()
  end
  table.sort(FILES, function(a, b)
    if a.is_meta ~= b.is_meta then return not a.is_meta end
    return a.key:lower() < b.key:lower()
  end)
  if #FILES == 0 then
    FILES = {
      { key = "Dolphin.ini", guide = GUIDE_FOR["Dolphin.ini"] },
      { key = "GFX.ini",     guide = GUIDE_FOR["GFX.ini"]     },
    }
  end
end

-- ── File I/O ───────────────────────────────────────────────
local function read_ini(path)
  local parsed = PMerger.parse_ini(path)
  if not parsed then
    return { data = {}, order = {} }, {}
  end
  local order = {}
  for sec, _ in pairs(parsed.data) do table.insert(order, sec) end
  table.sort(order)
  return parsed, order
end

local function write_ini(path, sections, order)
  local f = io.open(path, "w")
  if not f then return false end
  for _, sec in ipairs(order) do
    local opts = sections[sec]
    if opts and opts.order and #opts.order > 0 then
      f:write("[" .. sec .. "]\n")
      for _, k in ipairs(opts.order) do
        local v = opts.options[k]
        if v then f:write(k .. " = " .. v .. "\n") end
      end
      f:write("\n")
    end
  end
  f:close()
  return true
end

local function load_file(idx)
  if idx < 1 or idx > #FILES then idx = 1 end
  local f = FILES[idx]
  if not f then return end
  S.file_idx = idx
  S.guide = f.guide and GP.parse(f.guide) or nil

  local parsed, order = read_ini(base_dir() .. "/" .. f.key)
  S.sections = {}
  S.section_order = {}

  if S.guide then
    for _, sec in ipairs(S.guide.section_order) do
      S.sections[sec] = { order = {}, options = {} }
      table.insert(S.section_order, sec)
    end
  end

  for _, sec in ipairs(order) do
    if not S.sections[sec] then
      S.sections[sec] = { order = {}, options = {} }
      table.insert(S.section_order, sec)
    end
    for k, v in pairs(parsed.data[sec]) do
      if not S.sections[sec].options[k] then
        table.insert(S.sections[sec].order, k)
      end
      S.sections[sec].options[k] = v
    end
    table.sort(S.sections[sec].order)
  end

  S._hidden = {}
  if S.guide then
    for _, sec in ipairs(S.guide.section_order) do
      S._hidden[sec] = {}
      for _, k in ipairs(S.guide.sections[sec].order) do
        if not (S.sections[sec] and S.sections[sec].options[k]) then
          table.insert(S._hidden[sec], k)
        end
      end
    end
  end

  set_dirty(false)
  S.sel = 1
  S.scroll = 0
  S.expanded = {}
  for _, sec in ipairs(S.section_order) do
    S.expanded[sec] = (sec == S.section_order[1])
  end
end

local function rebuild_rows()
  S.rows = {}
  for _, sec in ipairs(S.section_order) do
    table.insert(S.rows, { kind = "section", section = sec })
    if S.expanded[sec] then
      local real = S.sections[sec] and S.sections[sec].order or {}
      for _, k in ipairs(real) do
        table.insert(S.rows,
          { kind = "option", section = sec, key = k, hidden = false })
      end
      if S.show_all and S._hidden[sec] then
        for _, k in ipairs(S._hidden[sec]) do
          table.insert(S.rows,
            { kind = "option", section = sec, key = k, hidden = true })
        end
      end
    end
  end
end

-- ── Lifecycle ──────────────────────────────────────────────
function S.enter(params)
  params = params or {}
  S.profile_dir  = params.profile_dir
  S.profile_name = params.profile_name

  rebuild_file_list()

  local idx = 1
  if params.file then
    for i, f in ipairs(FILES) do
      if f.key == params.file then idx = i break end
    end
  end
  load_file(idx)
  rebuild_rows()
  set_mode("list")
  set_input(nil)
  S.save = nil
  S.guide_target = nil
  S.guide_t = 0
  set_dirty(false)
  refresh_raw_input()
end

function S.leave()
  set_input(nil)
  State.raw_input = false
end

function S.re_enter()
  if not S.dirty then
    rebuild_file_list()
    load_file(S.file_idx)
    rebuild_rows()
  end
  refresh_raw_input()
end

-- ── Scroll ─────────────────────────────────────────────────
local function ensure_visible()
  local vis_h = BOTTOM_Y - TOP_Y - STATUS_H
  local y = 0
  for i = 1, S.sel do
    local row = S.rows[i]
    if not row then break end
    local h = (row.kind == "section") and SEC_H or OPT_H
    if i == S.sel then
      if y < S.scroll then S.scroll = y
      elseif y + h > S.scroll + vis_h then S.scroll = y + h - vis_h end
      break
    end
    y = y + h
  end
  local total_h = 0
  for _, row in ipairs(S.rows) do
    total_h = total_h + ((row.kind == "section") and SEC_H or OPT_H)
  end
  local max_s = math.max(0, total_h - vis_h)
  S.scroll = math.max(0, math.min(max_s, S.scroll))
end

-- ── Navigation ─────────────────────────────────────────────
local function move(delta)
  local n = #S.rows
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then S.sel = ni; SFX.play("menu_move"); ensure_visible() end
end

local function toggle_section(sec)
  S.expanded[sec] = not S.expanded[sec]
  SFX.play("menu_toggleoption")
  rebuild_rows()
  ensure_visible()
end

local function next_file(delta)
  if #FILES < 2 then return end
  local ni = ((S.file_idx - 1 + delta) % #FILES) + 1
  if ni ~= S.file_idx then
    load_file(ni)
    rebuild_rows()
    SFX.play("menu_pagescroll")
  end
end

-- ── Value editing ──────────────────────────────────────────
local function cycle_value(row, dir)
  local sec = S.sections[row.section]
  if not sec then return end

  if row.hidden then
    table.insert(sec.order, row.key)
    table.sort(sec.order)
    local go = S.guide and S.guide.sections[row.section]
        and S.guide.sections[row.section].options[row.key]
    local rec = go and go.recommend or nil
    S.sections[row.section].options[row.key] = rec or "False"
    set_dirty(true)
    SFX.play("menu_toggleoption")
    rebuild_rows()
    return
  end

  local cur = sec.options[row.key] or ""
  local guide_opt = S.guide and S.guide.sections[row.section]
      and S.guide.sections[row.section].options[row.key]
  local params = guide_opt and guide_opt.params or ""

  if params:match("%f[%w]True%f[%W]") and params:match("%f[%w]False%f[%W]") then
    sec.options[row.key] = (cur == "True") and "False" or "True"
    set_dirty(true)
    SFX.play("menu_toggleoption")
    return
  end

  local vals = GP.extract_values(params)
  if #vals > 0 then
    local idx = 1
    for i, v in ipairs(vals) do if v.value == cur then idx = i break end end
    idx = ((idx - 1 + dir) % #vals) + 1
    sec.options[row.key] = vals[idx].value
    set_dirty(true)
    SFX.play("menu_toggleoption")
    return
  end

  set_input({
    target = { section = row.section, key = row.key },
    buffer = cur,
    label  = row.key,
  })
  SFX.play("menu_select")
end

-- ── Save as new profile ────────────────────────────────────
local function next_custom_index()
  local n = 1
  while n < 1000 do
    local dir = string.format("workshop/rtcoreprofile/Custom%03d", n)
    local f = io.open(dir .. "/rtprofile_data.ini", "r")
    if not f then return n end
    f:close()
    n = n + 1
  end
  return nil
end

local function open_save_dialog()
  local idx = next_custom_index()
  if not idx then
    Notify.show("error", "No free Custom slot")
    return
  end
  local f = FILES[S.file_idx]
  S.save = {
    name        = string.format("Custom%03d", idx),
    description = "Custom profile from " .. f.key,
    type        = 1,
    field       = 1,
  }
  set_mode("save")
  SFX.play("menu_select")
end

local SAVE_TYPES = { "Balanced", "Performance", "Compatibility", "Experimental" }

local function commit_save_as_profile()
  local name = S.save.name
  if name == "" then Notify.show("error", "Name required"); return end
  name = name:gsub("[^%w_%-%s%.]", "")
  name = name:gsub("%.%.", "")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then Notify.show("error", "Invalid name"); return end

  local dir = "workshop/rtcoreprofile/" .. name
  local chk = io.open(dir .. "/rtprofile_data.ini", "r")
  if chk then
    chk:close()
    Notify.show("error", "Profile already exists: " .. name)
    return
  end
  os.execute("mkdir -p " .. shq(dir))

  local live = "dolphin-emu/Config"
  for _, fname in ipairs(LIVE_SNAPSHOT) do
    local src = live .. "/" .. fname
    local sf = io.open(src, "rb")
    if sf then
      sf:close()
      os.execute("cp " .. shq(src) .. " " .. shq(dir .. "/" .. fname))
    end
  end

  write_ini(dir .. "/" .. FILES[S.file_idx].key,
            S.sections, S.section_order)

  local mf = io.open(dir .. "/rtprofile_data.ini", "w")
  if mf then
    mf:write("[Profile]\n")
    mf:write("Name        = " .. name .. "\n")
    mf:write("Type        = " .. SAVE_TYPES[S.save.type] .. "\n")
    mf:write("Description = " .. S.save.description .. "\n")
    mf:write("Author      = DolphinUI Editor\n")
    mf:write("Version     = 1.0.0\n")
    mf:write("Date        = " .. os.date("%Y-%m-%d") .. "\n\n")
    mf:write("[UI]\n")
    mf:write("Color       = #4FA8C7\n")
    mf:write("BorderStyle = rounded\n")
    mf:write("Icon        = balanced\n")
    mf:write("Order       = 200\n")
    mf:write("Tags        = custom, editor\n\n")
    mf:write("[Runtime]\n")
    mf:write("RequiresBase = Default\n")
    mf:write("Locked       = False\n")
    mf:close()
  end
  Notify.show("success", "Saved profile: " .. name)
  set_dirty(false)
  set_mode("list")
  S.save = nil
end

local function commit_profile_save()
  if not S.profile_dir then return end
  if current_is_metadata() then
    Notify.show("warning", "Metadata files are not edited here")
    return
  end
  local f = FILES[S.file_idx]
  local path = S.profile_dir .. "/" .. f.key
  if write_ini(path, S.sections, S.section_order) then
    set_dirty(false)
    Notify.show("success", "Saved: " .. f.key)
    SFX.play("menu_select")
  else
    Notify.show("error", "Write failed: " .. path)
  end
end

-- ── Guide popup ────────────────────────────────────────────
local function open_guide()
  local row = S.rows[S.sel]
  if not row or row.kind ~= "option" then return end
  if not S.guide then
    Notify.show("info", "No guide available for " .. FILES[S.file_idx].key)
    return
  end
  local go = S.guide.sections[row.section]
      and S.guide.sections[row.section].options[row.key]
  if not go then
    Notify.show("info", "No guide entry for " .. row.key)
    return
  end
  S.guide_target = { section = row.section, key = row.key }
  S.guide_t = 0
  set_mode("guide")
  local vals = go and GP.extract_values(go.params) or {}
  S.guide_value_sel = 1
  local cur = S.sections[row.section].options[row.key]
  for i, v in ipairs(vals) do
    if v.value == cur then S.guide_value_sel = i break end
  end
  SFX.play("menu_select")
end

local function close_guide()
  set_mode("list")
  S.guide_target = nil
  SFX.play("menu_back")
end

local function guide_apply(dir)
  local t = S.guide_target
  if not t then return end
  local go = S.guide and S.guide.sections[t.section]
      and S.guide.sections[t.section].options[t.key]
  local vals = go and GP.extract_values(go.params) or {}
  if #vals > 0 then
    S.guide_value_sel = math.max(1, math.min(#vals, S.guide_value_sel + dir))
    S.sections[t.section].options[t.key] = vals[S.guide_value_sel].value
    set_dirty(true)
    SFX.play("menu_toggleoption")
  else
    cycle_value({ section = t.section, key = t.key, hidden = false }, dir)
  end
end

-- ── Dirty exit prompt ──────────────────────────────────────
local function prompt_exit()
  if S.dirty then
    local hint = S.profile_dir
      and "Press [X] to save to this profile, or Discard."
      or  "Press [X] to save as a new profile, or Discard."
    Modal.show("Unsaved changes",
      "This file has unsaved modifications.\n\n" .. hint,
      {
        accept_label = "Discard",
        cancel_label = "Stay",
        color = {0.96, 0.77, 0.26},
        on_accept = function()
          set_dirty(false)
          State.raw_input = false
          State.back()
        end,
      })
  else
    State.raw_input = false
    State.back()
  end
end

-- ── Input ──────────────────────────────────────────────────
function S.pad(b)
  if S.input then
    if b == IM.A then
      if S.input.target.save_field then
        if S.input.target.save_field == 1 then S.save.name = S.input.buffer
        else S.save.description = S.input.buffer end
      else
        S.sections[S.input.target.section].options[S.input.target.key] =
          S.input.buffer
        set_dirty(true)
      end
      set_input(nil)
      SFX.play("menu_select")
    elseif b == IM.B then
      set_input(nil)
      SFX.play("menu_back")
    end
    return
  end

  if S.mode == "save" then
    if b == IM.A then
      if S.save.field == 4 then commit_save_as_profile()
      elseif S.save.field == 3 then
        S.save.type = (S.save.type % #SAVE_TYPES) + 1
        SFX.play("menu_toggleoption")
      else
        set_input({
          target = { save_field = S.save.field },
          buffer = (S.save.field == 1) and S.save.name or S.save.description,
          label  = (S.save.field == 1) and "Profile name" or "Description",
        })
        SFX.play("menu_select")
      end
    elseif b == IM.B then
      set_mode("list")
      S.save = nil
      SFX.play("menu_back")
    end
    return
  end

  if S.mode == "guide" then
    if b == IM.A then guide_apply(1)
    elseif b == IM.X then guide_apply(-1)
    elseif b == IM.B then close_guide() end
    return
  end

  if b == IM.A then
    local row = S.rows[S.sel]
    if row and row.kind == "section" then
      toggle_section(row.section)
    elseif row then
      cycle_value(row, 1)
    end
  elseif b == IM.B then
    prompt_exit()
  elseif b == IM.X then
    if current_is_metadata() then
      Notify.show("warning", "Metadata files are not edited here")
    elseif S.profile_dir then
      commit_profile_save()
    else
      open_save_dialog()
    end
  elseif b == IM.Y then open_guide()
  elseif b == IM.START then
    S.show_all = not S.show_all
    SFX.play("menu_pagescroll")
    rebuild_rows()
    ensure_visible()
  elseif b == IM.L1 then next_file(-1)
  elseif b == IM.R1 then next_file(1)
  end
end

function S.hat(dir)
  if S.mode ~= "list" then return end
  if dir == "up" then move(-1)
  elseif dir == "down" then move(1)
  elseif dir == "left" then
    local row = S.rows[S.sel]
    if row and row.kind == "section" then
      S.expanded[row.section] = false
      rebuild_rows()
    end
  elseif dir == "right" then
    local row = S.rows[S.sel]
    if row and row.kind == "section" then
      S.expanded[row.section] = true
      rebuild_rows()
    end
  end
end

function S.key(k)
  if S.input then
    if k == "backspace" then
      S.input.buffer = S.input.buffer:sub(1, -2)
    elseif k == "return" then
      if S.input.target.save_field then
        if S.input.target.save_field == 1 then S.save.name = S.input.buffer
        else S.save.description = S.input.buffer end
      else
        S.sections[S.input.target.section].options[S.input.target.key] =
          S.input.buffer
        set_dirty(true)
      end
      set_input(nil)
      SFX.play("menu_select")
    elseif k == "escape" then
      set_input(nil)
    elseif #k == 1 and k:match("[%w_%-%s%./:]") then
      S.input.buffer = S.input.buffer .. k
    end
    return
  end

  if S.mode == "save" then
    if k == "up"   then S.save.field = math.max(1, S.save.field - 1) end
    if k == "down" then S.save.field = math.min(4, S.save.field + 1) end
    if k == "return" or k == "space" then S.pad(IM.A) end
    if k == "escape" then set_mode("list"); S.save = nil end
    return
  end

  if S.mode == "guide" then
    if k == "left"  then guide_apply(-1)
    elseif k == "right" then guide_apply(1)
    elseif k == "return" or k == "space" then guide_apply(1)
    elseif k == "escape" then close_guide() end
    return
  end

  if k == "up" then move(-1)
  elseif k == "down" then move(1)
  elseif k == "left" then S.hat("left")
  elseif k == "right" then S.hat("right")
  elseif k == "return" or k == "space" then S.pad(IM.A)
  elseif k == "x" then
    if current_is_metadata() then
      Notify.show("warning", "Metadata files are not edited here")
    elseif S.profile_dir then commit_profile_save() else open_save_dialog() end
  elseif k == "y" then open_guide()
  elseif k == "tab" then
    S.show_all = not S.show_all
    rebuild_rows()
    ensure_visible()
  elseif k == "q" then next_file(-1)
  elseif k == "e" then next_file(1)
  elseif k == "escape" then prompt_exit()
  end
end

function S.update(dt)
  if S.mode == "guide" then S.guide_t = S.guide_t + dt end
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: file tabs (mono)
-- ══════════════════════════════════════════════════════════════
local function draw_file_tabs(th)
  local tab_y = Header.height()
  local tab_h = 24

  -- Bar
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, tab_y, W, tab_h)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", 0, tab_y + tab_h - 1, W, 1)

  local fx = 10
  for i, f in ipairs(FILES) do
    local active = (i == S.file_idx)
    local font = A.font(MONO_BOLD, 10)
    love.graphics.setFont(font)
    local label = f.key
    if f.is_meta then label = label .. " *" end
    local w = font:getWidth(label) + 16

    -- Tab background
    if active then
      love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.85)
    else
      love.graphics.setColor(0.10, 0.12, 0.16, 0.85)
    end
    love.graphics.rectangle("fill", fx, tab_y + 4, w, tab_h - 6, 3, 3)

    if active then
      love.graphics.setColor(1, 1, 1, 0.55)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", fx + 0.5, tab_y + 4.5,
        w - 1, tab_h - 7, 3, 3)
      love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(active and {1, 1, 1} or {0.65, 0.70, 0.78})
    love.graphics.printf(label, fx, tab_y + 9, w, "center")

    fx = fx + w + 4
    if fx > W - 60 then break end
  end

  -- Right-side dirty indicator
  if S.dirty then
    local t = State.t_ui or 0
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    love.graphics.setColor(0.96, 0.77, 0.26, 0.55 + pulse * 0.45)
    love.graphics.circle("fill", W - 16, tab_y + 12, 4)
  end

  -- Show-all pill
  if S.show_all then
    local font = A.font(MONO_BOLD, 9)
    love.graphics.setFont(font)
    local txt = "ALL"
    local tw = font:getWidth(txt) + 12
    local px = W - tw - (S.dirty and 32 or 14)
    love.graphics.setColor(0.96, 0.77, 0.26, 0.85)
    love.graphics.rectangle("fill", px, tab_y + 6, tw, 12, 6, 6)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(txt, px, tab_y + 8, tw, "center")
  end
end

-- ── Context banner ─────────────────────────────────────────
local function draw_context_banner(th)
  local y = Header.height() + 24
  local h = 22
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, y, W, h)

  local ctx_color, ctx_label
  if S.profile_dir then
    ctx_color = {0.20, 0.72, 0.98}
    ctx_label = "PROFILE  ·  " .. (S.profile_name or "?")
  else
    ctx_color = {0.96, 0.77, 0.26}
    ctx_label = "LIVE CONFIG  ·  dolphin-emu/Config/"
  end

  love.graphics.setColor(ctx_color[1], ctx_color[2], ctx_color[3], 0.85)
  love.graphics.rectangle("fill", 0, y + h - 1, W, 1)

  -- Small procedural bullet
  GL.diamond(14, y + h / 2, 4, ctx_color, 0.9)

  love.graphics.setColor(ctx_color)
  love.graphics.setFont(A.font(MONO_BOLD, 10))
  love.graphics.print(ctx_label, 24, y + 6)

  love.graphics.setColor(0.60, 0.65, 0.75)
  love.graphics.setFont(A.font(MONO_BASE, 9))
  local hint
  if current_is_metadata() then
    hint = "read-only"
  elseif S.profile_dir then
    hint = "[X] Save to profile"
  else
    hint = "[X] Save as new profile"
  end
  love.graphics.printf(hint, 0, y + 7, W - 14, "right")
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: body rows
-- ══════════════════════════════════════════════════════════════
local function get_option(section, key, hidden)
  if hidden then
    local g = S.guide and S.guide.sections[section]
        and S.guide.sections[section].options[key]
    return g and (g.recommend or g.value) or ""
  end
  return S.sections[section] and S.sections[section].options[key] or ""
end

-- Classify the value so we can color it.
local function classify_value(v)
  if v == nil then return "empty" end
  if v == "" then return "empty" end
  if v == "True" or v == "true"   then return "true"  end
  if v == "False" or v == "false" then return "false" end
  if tonumber(v) then return "number" end
  if v:match('^".*"$') or v:match("^'.*'$") then return "string" end
  return "text"
end

local function value_color(kind, th)
  if kind == "true"   then return {0.30, 0.85, 0.40} end
  if kind == "false"  then return {0.90, 0.35, 0.35} end
  if kind == "number" then return {0.96, 0.82, 0.22} end
  if kind == "string" then return {0.90, 0.90, 0.95} end
  if kind == "empty"  then return {0.45, 0.48, 0.55} end
  return th.text or {0.90, 0.94, 0.98}
end

-- Compute the total line count for the current file (for the status
-- bar). This is the number of rows visible when all sections are
-- expanded and show_all is on.
local function total_line_count()
  local n = 0
  for _, sec in ipairs(S.section_order) do
    n = n + 1  -- section header
    n = n + (S.sections[sec] and #S.sections[sec].order or 0)
    if S._hidden[sec] then n = n + #S._hidden[sec] end
  end
  return n
end

-- ── Section header row ─────────────────────────────────────
local function draw_section_header(th, row, focused, y)
  local sec = row.section
  local expanded = S.expanded[sec]
  local x, w = 12, W - 24
  local h = SEC_H

  -- Focus highlight
  if focused then
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.14)
    love.graphics.rectangle("fill", x, y + 1, w, h - 2, 3, 3)
    love.graphics.setColor(th.focus)
    love.graphics.rectangle("fill", x, y + 1, 3, h - 2, 1, 1)
  end

  -- Fold marker (procedural)
  local mk_x = x + 14
  local mk_y = y + h / 2
  if expanded then
    GL.triangle_down(mk_x, mk_y, 5, th.accent, 1)
  else
    GL.triangle_right(mk_x, mk_y, 5, th.accent, 1)
  end

  -- Section name — mono bold
  love.graphics.setColor(th.accent)
  love.graphics.setFont(A.font(MONO_BOLD, 11))
  local label = "[" .. sec .. "]"
  love.graphics.print(label, x + 28, y + 5)

  -- Option count on the right
  local n = S.sections[sec] and #S.sections[sec].order or 0
  local badge = tostring(n)
  love.graphics.setFont(A.font(MONO_BOLD, 9))
  local font = love.graphics.getFont()
  local bw = font:getWidth(badge) + 12
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.55)
  love.graphics.rectangle("fill", x + w - bw - 6, y + 5, bw, 14, 7, 7)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.printf(badge, x + w - bw - 6, y + 6, bw, "center")

  -- Guide availability diamond
  if S.guide and S.guide.sections[sec]
     and S.guide.sections[sec].desc
     and S.guide.sections[sec].desc ~= "" then
    love.graphics.setColor(0.20, 0.72, 0.98, 0.65)
    GL.diamond(x + w - bw - 22, y + h / 2, 4, {0.20, 0.72, 0.98}, 0.75)
  end

  -- Hairline below (subtle)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.15)
  love.graphics.rectangle("fill", x, y + h - 1, w, 1)
end

-- ── Option row ─────────────────────────────────────────────
local function draw_option_row(th, row, focused, y)
  local section = row.section
  local key     = row.key
  local hidden  = row.hidden
  local value   = get_option(section, key, hidden)
  local x, w = 12, W - 24
  local h = OPT_H

  -- Focus highlight
  if focused then
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.13)
    love.graphics.rectangle("fill", x + 6, y, w - 6, h - 1, 3, 3)
    love.graphics.setColor(th.focus)
    love.graphics.rectangle("fill", x + 6, y, 3, h - 1, 1, 1)
  end

  -- Line number (dim, right-aligned in a fixed 4-char column)
  local row_index = 0
  -- Cheap: we store a running index during draw. Fallback: use
  -- S.sel-independent counting; here we approximate with S.scroll
  -- + visible offset. For a faithful line number, we precompute it
  -- in rebuild_rows().
  row_index = row._idx or 0
  love.graphics.setColor(0.32, 0.36, 0.45)
  love.graphics.setFont(A.font(MONO_BASE, 9))
  love.graphics.printf(string.format("%3d", row_index),
    x + 8, y + h / 2 - 6, 26, "right")

  -- Key (cyan, mono)
  local key_col = hidden and {0.45, 0.48, 0.58} or {0.35, 0.78, 0.95}
  love.graphics.setColor(key_col)
  love.graphics.setFont(A.font(MONO_BASE, 11))
  local key_x = x + 42
  love.graphics.print(key, key_x, y + 5)

  -- " = " (dim)
  local key_w = love.graphics.getFont():getWidth(key)
  local eq_x = key_x + math.max(key_w, 176)
  love.graphics.setColor(0.45, 0.48, 0.55)
  love.graphics.print("=", eq_x, y + 5)

  -- Value (colored by type)
  local kind = classify_value(value)
  local vcol = value_color(kind, th)
  love.graphics.setColor(vcol)
  love.graphics.setFont(A.font(MONO_BASE, 11))
  local display = value
  if display == "" then display = '""' end
  if #display > 32 then display = display:sub(1, 31) .. "…" end
  love.graphics.print(display, eq_x + 14, y + 5)

  -- Right side pill / indicator
  if hidden then
    local txt = "hidden"
    love.graphics.setFont(A.font(MONO_BOLD, 9))
    local font = love.graphics.getFont()
    local tw = font:getWidth(txt) + 14
    love.graphics.setColor(0.96, 0.77, 0.26, focused and 0.9 or 0.5)
    love.graphics.rectangle("fill", x + w - tw - 12, y + 3, tw, h - 8, 6, 6)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(txt, x + w - tw - 12, y + 5, tw, "center")
  elseif focused then
    -- Edit affordance: small chevron pair
    GL.chevrons(x + w - 22, y + h / 2, 4, th.focus, 0.85)
  else
    -- Bool indicator: a small status dot
    if kind == "true" then
      GL.dot(x + w - 14, y + h / 2, 3, vcol, 0.75)
    elseif kind == "false" then
      GL.ring(x + w - 14, y + h / 2, 3, vcol, 0.75, 1.2)
    end
  end
end

-- ── Body + scrollbar + status ──────────────────────────────
local function draw_rows(th)
  local top = TOP_Y
  local bottom = BOTTOM_Y - STATUS_H
  love.graphics.setScissor(0, top, W, bottom - top)

  local y = top - S.scroll
  for i, row in ipairs(S.rows) do
    local h = (row.kind == "section") and SEC_H or OPT_H
    if y + h > top - 40 and y < bottom + 40 then
      if row.kind == "section" then
        draw_section_header(th, row, i == S.sel, y)
      else
        draw_option_row(th, row, i == S.sel, y)
      end
    end
    y = y + h
  end

  love.graphics.setScissor()

  -- Scrollbar
  local total_h = 0
  for _, row in ipairs(S.rows) do
    total_h = total_h + ((row.kind == "section") and SEC_H or OPT_H)
  end
  local vis_h = bottom - top
  if total_h > vis_h then
    local rail_x = W - 5
    love.graphics.setColor(0.20, 0.22, 0.28, 0.6)
    love.graphics.rectangle("fill", rail_x, top, 3, vis_h, 1, 1)
    local ratio = vis_h / total_h
    local bar_h = math.max(20, vis_h * ratio)
    local span  = total_h - vis_h
    local bar_y = top + (span > 0 and (S.scroll / span) * (vis_h - bar_h)
      or 0)
    love.graphics.setColor(th.accent)
    love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
  end
end

local function draw_status_bar(th)
  local y = BOTTOM_Y - STATUS_H
  local h = STATUS_H

  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, y, W, h)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", 0, y, W, 1)

  -- Left: file path
  local path = base_dir() .. "/" .. (current_file() and current_file().key or "?")
  love.graphics.setColor(0.60, 0.68, 0.80)
  love.graphics.setFont(A.font(MONO_BASE, 9))
  local disp = path
  if #disp > 46 then disp = "…" .. disp:sub(-44) end
  love.graphics.print(disp, 10, y + 8)

  -- Center: line count
  local line_count = total_line_count()
  love.graphics.setColor(0.45, 0.50, 0.60)
  love.graphics.printf(("%d lines"):format(line_count),
    0, y + 8, W - 10, "right")

  -- Right side: MODIFIED pill
  if S.dirty then
    local t = State.t_ui or 0
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    local txt = "MODIFIED"
    local font = A.font(MONO_BOLD, 9)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt) + 18
    local px = W - tw - 80
    love.graphics.setColor(0.96, 0.77, 0.26, 0.55 + pulse * 0.45)
    love.graphics.rectangle("fill", px, y + 5, tw, 14, 7, 7)
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.printf(txt, px, y + 7, tw, "center")
  end
end

-- ══════════════════════════════════════════════════════════════
--  Guide popup (cheat sheet)
-- ══════════════════════════════════════════════════════════════
local function draw_guide_popup(th)
  if S.mode ~= "guide" or not S.guide_target then return end
  local t = S.guide_target
  local go = S.guide and S.guide.sections[t.section]
      and S.guide.sections[t.section].options[t.key]

  local ease = math.min(1, S.guide_t / 0.18)
  ease = 1 - (1 - ease) ^ 3

  love.graphics.setColor(0, 0, 0, 0.78 * ease)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 560, 400
  local bx = (W - bw) / 2
  local by = (H - bh) / 2 + (1 - ease) * 30

  love.graphics.setColor(0.04, 0.05, 0.09, 0.99 * ease)
  love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.9 * ease)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
  love.graphics.setLineWidth(1)
  D.corner_brackets(bx, by, bw, bh, th.focus, 16)

  -- Header
  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.18 * ease)
  love.graphics.rectangle("fill", bx, by, bw, 36, 8, 8)
  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(MONO_BOLD, 11))
  love.graphics.print("GUIDE  ·  " .. t.section, bx + 16, by + 10)
  love.graphics.setColor(0.65, 0.70, 0.82)
  love.graphics.printf("[" .. t.key .. "]",
    0, by + 11, bx + bw - 16, "right")

  local body_y = by + 54

  -- Recommended pill (colored block)
  if go and go.recommend and go.recommend ~= "" then
    local rec_col = {0.30, 0.85, 0.40}
    love.graphics.setColor(rec_col[1], rec_col[2], rec_col[3], 0.14)
    love.graphics.rectangle("fill", bx + 16, body_y - 4, bw - 32, 26, 5, 5)

    -- Star procedurally
    GL.diamond(bx + 30, body_y + 9, 6, rec_col, 0.9)
    love.graphics.setColor(rec_col)
    love.graphics.setFont(A.font(MONO_BOLD, 11))
    love.graphics.print("RECOMMENDED", bx + 44, body_y + 2)

    love.graphics.setColor(rec_col)
    love.graphics.setFont(A.font(MONO_BOLD, 11))
    love.graphics.printf(go.recommend, 0, body_y + 2, bx + bw - 22, "right")
    body_y = body_y + 34
  end

  -- Description
  local desc = (go and go.desc) or ""
  if desc ~= "" then
    love.graphics.setColor(0.55, 0.60, 0.75)
    love.graphics.setFont(A.font(MONO_BOLD, 9))
    love.graphics.print("DESCRIPTION", bx + 20, body_y)
    body_y = body_y + 14

    love.graphics.setColor(0.88, 0.90, 0.95)
    love.graphics.setFont(A.font(MONO_BASE, 10))
    love.graphics.printf(desc, bx + 20, body_y, bw - 40, "left")
    local _, wrapped = love.graphics.getFont():getWrap(desc, bw - 40)
    body_y = body_y + #wrapped * 14 + 12
  end

  -- Why
  if go and go.why and go.why ~= "" then
    love.graphics.setColor(0.96, 0.77, 0.26)
    love.graphics.setFont(A.font(MONO_BOLD, 9))
    love.graphics.print("WHY", bx + 20, body_y)
    body_y = body_y + 14

    love.graphics.setColor(0.85, 0.88, 0.94)
    love.graphics.setFont(A.font(MONO_BASE, 10))
    love.graphics.printf(go.why, bx + 20, body_y, bw - 40, "left")
    local _, w2 = love.graphics.getFont():getWrap(go.why, bw - 40)
    body_y = body_y + #w2 * 14 + 12
  end

  -- Values (list)
  local vals = go and GP.extract_values(go.params) or {}
  if #vals > 0 then
    love.graphics.setColor(th.focus)
    love.graphics.setFont(A.font(MONO_BOLD, 9))
    love.graphics.print("VALUES", bx + 20, body_y)
    body_y = body_y + 14

    local cur = S.sections[t.section] and S.sections[t.section].options[t.key]
    for i, v in ipairs(vals) do
      local focused = (i == S.guide_value_sel)
      local is_cur  = (v.value == cur)
      local is_rec  = (go and go.recommend and v.value == go.recommend)
      local row_x = bx + 26
      local row_w = bw - 52
      if focused then
        love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.14)
        love.graphics.rectangle("fill", row_x, body_y - 2, row_w, 20, 3, 3)
      end

      love.graphics.setColor(is_cur and {0.30, 0.85, 0.40}
                                    or (focused and {1,1,1} or th.text))
      love.graphics.setFont(A.font(MONO_BOLD, 10))
      love.graphics.print(v.value, row_x + 8, body_y)

      love.graphics.setColor(0.60, 0.65, 0.75)
      love.graphics.setFont(A.font(MONO_BASE, 9))
      love.graphics.print(v.desc or "", row_x + 110, body_y + 1)

      if is_rec then
        GL.diamond(row_x + row_w - 30, body_y + 9, 5, {0.30, 0.85, 0.40}, 1)
      end
      if is_cur then
        GL.dot(row_x + row_w - 12, body_y + 9, 3.5, {0.30, 0.85, 0.40}, 1)
      end
      body_y = body_y + 22
    end
  end

  -- Footer
  local footer_y = by + bh - 30
  love.graphics.setColor(0, 0, 0, 0.45 * ease)
  love.graphics.rectangle("fill", bx, footer_y, bw, 30, 8, 8)
  BI.draw_hint_centered("[A] Set   [X] Cycle back   [B] Close",
    W, footer_y + 8, A.font(th.font_body, 11), th)
end

-- ══════════════════════════════════════════════════════════════
--  Save dialog (mono)
-- ══════════════════════════════════════════════════════════════
local function draw_save_dialog(th)
  if S.mode ~= "save" then return end
  local s = S.save
  if not s then return end

  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 500, 260
  local bx = (W - bw) / 2
  local by = (H - bh) / 2

  love.graphics.setColor(0.05, 0.06, 0.10, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
  love.graphics.setColor(0.30, 0.85, 0.40)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
  love.graphics.setLineWidth(1)
  D.corner_brackets(bx, by, bw, bh, {0.30, 0.85, 0.40}, 16)

  love.graphics.setColor(0.30, 0.85, 0.40, 0.15)
  love.graphics.rectangle("fill", bx, by, bw, 36, 8, 8)
  love.graphics.setColor(0.30, 0.85, 0.40)
  love.graphics.setFont(A.font(MONO_BOLD, 12))
  love.graphics.printf("SAVE AS NEW PROFILE", bx, by + 12, bw, "center")

  local y = by + 56
  local fields = {
    { label = "Name",         value = s.name,        field = 1 },
    { label = "Description",  value = s.description, field = 2 },
    { label = "Type",         value = SAVE_TYPES[s.type], field = 3 },
    { label = "Action",       value = "▶ Commit",     field = 4 },
  }

  for _, f in ipairs(fields) do
    local focused = (s.field == f.field)
    if focused then
      love.graphics.setColor(0.30, 0.85, 0.40, 0.14)
      love.graphics.rectangle("fill", bx + 16, y - 4, bw - 32, 30, 4, 4)
      love.graphics.setColor(0.30, 0.85, 0.40)
      love.graphics.rectangle("fill", bx + 16, y - 4, 3, 30, 1, 1)
    end

    love.graphics.setColor(0.60, 0.65, 0.75)
    love.graphics.setFont(A.font(MONO_BOLD, 10))
    love.graphics.print(f.label, bx + 32, y + 4)

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(MONO_BASE, 11))
    local v = f.value
    if #v > 40 then v = v:sub(1, 38) .. "…" end
    love.graphics.print(v, bx + 160, y + 4)

    y = y + 36
  end

  BI.draw_hint_centered("[↑↓] Field   [A] Edit/Confirm   [B] Cancel",
    W, by + bh - 26, A.font(th.font_body, 11), th)
end

-- ══════════════════════════════════════════════════════════════
--  Input overlay (mono)
-- ══════════════════════════════════════════════════════════════
local function draw_input_overlay(th)
  if not S.input then return end

  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 480, 130
  local bx = (W - bw) / 2
  local by = (H - bh) / 2

  love.graphics.setColor(0.06, 0.07, 0.10, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(th.focus)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(MONO_BOLD, 10))
  love.graphics.print(S.input.label or "Value", bx + 20, by + 16)

  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.12)
  love.graphics.rectangle("fill", bx + 16, by + 40, bw - 32, 36, 4, 4)
  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(MONO_BASE, 13))
  local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
  love.graphics.print(S.input.buffer .. cursor, bx + 28, by + 50)

  BI.draw_hint_centered("[Enter] OK   [Esc] Cancel",
    W, by + bh + 8, A.font(th.font_body, 11), th)
end

-- ══════════════════════════════════════════════════════════════
--  Precompute row line numbers when rebuilding
-- ══════════════════════════════════════════════════════════════
local _rebuild_rows_orig = rebuild_rows
rebuild_rows = function()
  _rebuild_rows_orig()
  local n = 0
  for _, row in ipairs(S.rows) do
    n = n + 1
    row._idx = n
  end
end

-- ══════════════════════════════════════════════════════════════
--  Main draw
-- ══════════════════════════════════════════════════════════════
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)

  local title = S.profile_name
      and ("EDIT  ·  " .. S.profile_name)
      or  "CONFIG FILES"
  Header.draw(title, "settings")

  draw_file_tabs(th)
  draw_context_banner(th)
  draw_rows(th)
  draw_status_bar(th)

  draw_guide_popup(th)
  draw_save_dialog(th)
  draw_input_overlay(th)

  if S.mode == "list" and not S.input then
    local is_meta = current_is_metadata()
    local items
    if S.dirty then
      items = {
        { key = "dpad",  label = "Navigate" },
        { key = "a",     label = "Toggle"   },
        { key = "y",     label = "Guide"    },
        { key = "x",     label = is_meta and "Read-only" or "Save" },
        { key = "start", label = "Show all" },
        { key = "b",     label = "Back"     },
      }
    else
      items = {
        { key = "dpad",  label = "Navigate"  },
        { key = "a",     label = "Toggle"    },
        { key = "y",     label = "Guide"     },
        { key = "start", label = "Show all"  },
        { key = "l1",    label = "Prev file" },
        { key = "r1",    label = "Next file" },
        { key = "b",     label = "Back"      },
      }
    end
    BI.draw_footer(th, items, W, H - 22, A.font(th.font_body, 12))
  end

  Modal.draw()
end

return S