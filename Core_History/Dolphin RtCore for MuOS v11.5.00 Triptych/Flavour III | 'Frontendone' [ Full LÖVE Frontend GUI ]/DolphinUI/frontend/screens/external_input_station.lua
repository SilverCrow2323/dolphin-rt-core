-- frontend/screens/external_input_station.lua
-- BURST LINK — the external controller pairing station.
--
-- v2.2 — winged slot layout, engraved panels, cable runs
--   * Slots are now 3 per side (6 total: USB 1-3 left, BT 1-3 right),
--     arranged on an arc that bulges outward — "wings".
--   * Each slot is drawn as a dug-out recessed panel with a beveled
--     top-left shadow and a bottom-right highlight.
--   * The inner edge of each slot carries a small metal hanger with
--     two coloured cables running toward the burst-link hexagon.
--   * Left (USB) slots have engraved light-grey labels inside.
--   * The BURST LINK hexagon sits lower and horizontally centred.
--
-- All dialogue and avatar animation is owned by the Minoru engine.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local Header = require("ui.header")
local BI     = require("ui.button_icons")
local Notify = require("notify")
local json   = require("json")
local sh     = require("sh")
local Minoru = require("minoru")

local S = {}
local W, H = 640, 480

-- ── Layout ──────────────────────────────────────────────────
local TOP         = Header.height()          -- 58
local FOOTER_H    = 28
local MINORU_H    = 210
local STATION_TOP = TOP + 4                  -- 62
local STATION_BOT = H - FOOTER_H - MINORU_H  -- 242

-- Slot geometry
local SLOT_W      = 155
local SLOT_H      = 30
local SLOT_COUNT  = 3        -- per side

-- Left slots (USB): middle slot pushes further left for the wing curve
local LEFT_SLOTS = {
  { x = 30, y = STATION_TOP + 12 },
  { x =  8, y = STATION_TOP + 52 },
  { x = 30, y = STATION_TOP + 92 },
}

-- Right slots (BT): mirror of the left
local RIGHT_SLOTS = {
  { x = W - 30 - SLOT_W, y = STATION_TOP + 12 },
  { x = W -  8 - SLOT_W, y = STATION_TOP + 52 },
  { x = W - 30 - SLOT_W, y = STATION_TOP + 92 },
}

-- BURST LINK hexagon: centered horizontally, low in the station area
local BL_CX = W / 2
local BL_CY = STATION_BOT - 42
local BL_R  = 40

-- ── Palette ─────────────────────────────────────────────────
local COL = {
  metal      = {0.32, 0.34, 0.40},
  metal_hi   = {0.55, 0.58, 0.66},
  metal_lo   = {0.16, 0.17, 0.21},
  amber      = {0.96, 0.70, 0.20},
  amber_hi   = {1.00, 0.88, 0.55},
  blue       = {0.22, 0.62, 0.98},
  blue_hi    = {0.55, 0.85, 1.00},
  purple     = {0.62, 0.35, 0.98},
  purple_hi  = {0.85, 0.65, 1.00},
  green      = {0.30, 0.85, 0.40},
  red        = {0.90, 0.30, 0.30},
  text       = {0.90, 0.94, 0.98},
  text_dim   = {0.55, 0.60, 0.70},
  slot_dark  = {0.03, 0.04, 0.06},
  slot_edge  = {0.08, 0.09, 0.12},
  cable_a    = {0.82, 0.20, 0.20},   -- red
  cable_b    = {0.20, 0.22, 0.26},   -- dark grey
  engraved   = {0.78, 0.82, 0.86},   -- light gray for USB labels
}

-- ── Runtime state ───────────────────────────────────────────
S.placed          = {}
S.selected_slot   = 0
S.actions_slot    = nil
S.confirm_slot    = nil
S.phase           = "crypt"
S.phase_t         = 0
S.method          = nil
S.choice_sel      = 1
S.battle_log      = {}
S.battle_devices  = {}
S.battle_device_sel = 1
S.battle_progress = 0
S.input           = nil
S.enter_t         = 0
S.returning       = false

S.minoru          = nil

local CRYPT_DUR   = 2.6
local SCAN_DUR    = 2.4

-- ── Persistence ─────────────────────────────────────────────
local function load_persist()
  S.placed = {}
  local f = io.open("data/external_input.json", "r")
  if not f then return end
  local c = f:read("*a"); f:close()
  local ok, d = pcall(json.decode, c)
  if ok and type(d) == "table" and type(d.devices) == "table" then
    for _, dev in ipairs(d.devices) do
      local slot = tonumber(dev.slot) or 1
      if slot >= 1 and slot <= SLOT_COUNT * 2 then
        table.insert(S.placed, {
          slot = slot,
          kind = dev.kind or "usb",
          user = dev.user_name or "?",
          real = dev.real_name or "?",
          id   = dev.id or "",
        })
      end
    end
  end
end

local function save_persist()
  local out = { devices = {} }
  for _, p in ipairs(S.placed) do
    table.insert(out.devices, {
      slot      = p.slot,
      kind      = p.kind,
      user_name = p.user,
      real_name = p.real,
      id        = p.id,
      ts        = os.time(),
    })
  end
  sh.atomic_write("data/external_input.json", json.encode(out))
end

-- ── Slot queries ────────────────────────────────────────────
local function slot_position(slot)
  if slot >= 1 and slot <= SLOT_COUNT then
    return LEFT_SLOTS[slot]
  elseif slot >= SLOT_COUNT + 1 and slot <= SLOT_COUNT * 2 then
    return RIGHT_SLOTS[slot - SLOT_COUNT]
  end
  return nil
end

local function entry_for_slot(n)
  for _, p in ipairs(S.placed) do
    if p.slot == n then return p end
  end
  return nil
end

local function is_slot_occupied(n)
  return entry_for_slot(n) ~= nil
end

local function next_free_slot_for_kind(kind)
  local base, top = 1, SLOT_COUNT
  if kind == "bt" then base, top = SLOT_COUNT + 1, SLOT_COUNT * 2 end
  for i = base, top do
    if not is_slot_occupied(i) then return i end
  end
  return nil
end

-- ── Device discovery ────────────────────────────────────────
local function enumerate_usb_joysticks()
  local out = {}
  if not (love.joystick and love.joystick.getJoysticks) then return out end
  local ok, list = pcall(love.joystick.getJoysticks)
  if not ok or not list then return out end
  for i, j in ipairs(list) do
    local name, guid = "Unknown USB device", "?"
    pcall(function() name = j:getName() end)
    pcall(function() guid = j:getGUID() end)
    table.insert(out, { kind = "usb", user = name, real = name, id = guid })
  end
  return out
end

local function enumerate_bt_devices()
  local out = {}
  local h = io.popen("timeout 3 bluetoothctl devices 2>/dev/null")
  if h then
    for line in h:lines() do
      local mac, name = line:match("^Device%s+(%S+)%s+(.+)$")
      if mac then
        table.insert(out, { kind = "bt", user = name, real = name, id = mac })
      end
    end
    h:close()
  end
  return out
end

-- ── Burst link flow ─────────────────────────────────────────
local function start_burst_link()
  if not S.minoru then return end
  S.minoru:observe("pair_attempt")
  S.minoru:say("ext_pair_attempt")
  S.phase   = "burst_choice"
  S.phase_t = 0
  S.choice_sel = 1
  SFX.play("menu_flip")
end

local function choose_method()
  S.method = (S.choice_sel == 1) and "bt" or "usb"
  SFX.play("menu_select")

  S.minoru:observe("pair_choice", { meta = { method = S.method } })
  S.minoru:say("ext_pair_choice")

  if math.random() < 0.45 then
    local pick = math.random(1, 2)
    if pick == 1 and S.method == "bt" then
      S.minoru:say("canon_tenret")
    elseif pick == 2 then
      S.minoru:say("canon_crosswilson")
    end
  end

  S.phase   = "burst_scan"
  S.phase_t = 0
  S.battle_progress = 0
  S.battle_log = {}
  S.battle_devices = {}

  table.insert(S.battle_log, {
    t = 0.0,
    text = S.method == "bt"
      and "> burst link: initializing bluetooth stack"
      or  "> burst link: initializing usb host",
  })
  table.insert(S.battle_log, {
    t = 0.4,
    text = S.method == "bt"
      and "> scanning for discoverable devices..."
      or  "> probing HID class devices...",
  })

  S.minoru:observe("pair_scan_start")

  if S.method == "bt" then
    S.battle_devices = enumerate_bt_devices()
  else
    S.battle_devices = enumerate_usb_joysticks()
  end

  SFX.play("dead_space_locator")
end

local function finish_scan()
  local count = #S.battle_devices
  S.minoru:observe("pair_scan_complete", { meta = { count = count } })

  if count == 0 then
    S.phase = "burst_fail"
    S.phase_t = 0
    S.minoru:observe("pair_failure")
    S.minoru:say("ext_pair_failure")
    SFX.play("error")
  else
    S.phase = "burst_pick"
    S.phase_t = 0
    S.battle_device_sel = 1
    S.minoru:say("ext_pair_found")
  end
end

local function update_scan(dt)
  S.phase_t         = S.phase_t + dt
  S.battle_progress = math.min(1, S.battle_progress + dt / SCAN_DUR)
  for _, l in ipairs(S.battle_log) do
    if not l.revealed and l.t <= S.phase_t then
      l.revealed = true
    end
  end
  if S.battle_progress >= 1 then finish_scan() end
end

-- ── Device placement ────────────────────────────────────────
local function open_name_input(device, ctx, slot)
  S.input = {
    buffer = (ctx == "edit" and entry_for_slot(slot).user)
             or device.real:sub(1, 24),
    target = device,
    ctx    = ctx or "new",
    slot   = slot,
    label  = (ctx == "edit") and "New display name" or "Display name",
  }
  SFX.play("menu_select")
end

local function place_device(device, user_name, target_slot)
  local slot = target_slot or next_free_slot_for_kind(device.kind)
  if not slot then
    local side = (device.kind == "bt") and "Bluetooth" or "USB"
    Notify.show("warning", "No free " .. side .. " slot")
    S.minoru:observe("pair_failure", { meta = { reason = "no_free_slot" } })
    S.minoru:say("ext_pair_failure")
    return
  end

  table.insert(S.placed, {
    slot = slot,
    kind = device.kind,
    user = (user_name and user_name ~= "") and user_name or device.real,
    real = device.real,
    id   = device.id,
  })
  save_persist()

  S.selected_slot = slot
  S.phase = "station"
  S.phase_t = 0
  SFX.play("newupdate")

  S.minoru:observe("pair_success", { meta = { slot = slot } })
  S.minoru:say("ext_pair_success")

  if math.random() < 0.20 then
    S.minoru:say("canon_friendship")
  end
end

local function commit_name()
  if not S.input then return end
  local ctx  = S.input.ctx or "new"
  local dev  = S.input.target
  local nm   = S.input.buffer
  local slot = S.input.slot
  S.input = nil

  if ctx == "edit" then
    local entry = entry_for_slot(slot)
    if entry then
      entry.user = (nm ~= "") and nm or entry.real
      save_persist()
      S.minoru:observe("device_renamed", { meta = { slot = slot } })
      S.minoru:say("ext_device_renamed")
      SFX.play("menu_select")
    end
    S.selected_slot = slot
  else
    place_device(dev, nm, slot)
  end
end

local function remove_device_by_slot(slot)
  for i, p in ipairs(S.placed) do
    if p.slot == slot then
      table.remove(S.placed, i)
      save_persist()
      SFX.play("menu_back")
      S.minoru:observe("device_removed", { meta = { slot = slot } })
      S.minoru:say("ext_device_removed")
      return true
    end
  end
  return false
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  load_persist()

  S.returning     = false
  S.phase         = "crypt"
  S.phase_t       = 0
  S.method        = nil
  S.choice_sel    = 1
  S.selected_slot = 0
  S.actions_slot  = nil
  S.confirm_slot  = nil
  S.input         = nil
  S.battle_devices = {}
  S.battle_log     = {}
  S.enter_t        = 0

  S.minoru = Minoru.new({
    screen  = "external_input_station",
    form    = "desk_lamp",
    anchors = { left = 200, center = 320, right = 420 },
  })

  State.raw_input = true
  SFX.play("dead_space_menu_sound")
end

function S.leave()
  State.raw_input = false
  if S.minoru then
    S.minoru:say("farewell", { silent = true })
    S.minoru:flush()
    S.minoru = nil
  end
end

function S.re_enter()
  State.raw_input = true
  S.returning = true
  S.phase     = "station"
  S.phase_t   = 0
  S.selected_slot = 0
  S.actions_slot  = nil
  S.confirm_slot  = nil
  S.input         = nil

  if S.minoru then
    S.minoru:say("greeting")
    if math.random() < 0.35 then
      S.minoru:say("canon_tease_pips")
    end
  end
end

-- ── Update ──────────────────────────────────────────────────
function S.update(dt)
  S.enter_t = S.enter_t + dt
  S.phase_t = S.phase_t + dt

  if S.minoru then S.minoru:update(dt) end

  if S.phase == "crypt" then
    if S.phase_t >= CRYPT_DUR then
      S.phase = "station"
      S.phase_t = 0
      if S.minoru and not S.returning then
        S.minoru:say("ext_intro")
        S.minoru:say("ext_taunt")
      end
    end
  elseif S.phase == "burst_scan" then
    update_scan(dt)
  end
end

-- ── Input ───────────────────────────────────────────────────
local function idle_move(dir)
  if dir == "up" or dir == "down" then
    if S.selected_slot == 0 then return end
    local is_left = S.selected_slot <= SLOT_COUNT
    local base = is_left and 1 or (SLOT_COUNT + 1)
    local idx = S.selected_slot - base + 1
    idx = idx + (dir == "up" and -1 or 1)
    idx = math.max(1, math.min(SLOT_COUNT, idx))
    S.selected_slot = base + idx - 1
    SFX.play("menu_move")
  elseif dir == "left" then
    if S.selected_slot == 0 then
      S.selected_slot = 1; SFX.play("menu_move")
    elseif S.selected_slot > SLOT_COUNT then
      S.selected_slot = 0; SFX.play("menu_move")
    end
  elseif dir == "right" then
    if S.selected_slot == 0 then
      S.selected_slot = SLOT_COUNT + 1; SFX.play("menu_move")
    elseif S.selected_slot <= SLOT_COUNT and S.selected_slot >= 1 then
      S.selected_slot = 0; SFX.play("menu_move")
    end
  end
end

local function idle_activate()
  if S.selected_slot == 0 then
    start_burst_link()
    return
  end
  if is_slot_occupied(S.selected_slot) then
    S.actions_slot = S.selected_slot
    if S.minoru then S.minoru:say("ext_actions_open") end
    SFX.play("menu_select")
  else
    S.minoru:observe("slot_empty_press",
      { meta = { slot = S.selected_slot } })
    S.minoru:say("ext_slot_empty")
    SFX.play("menu_back")
  end
end

function S.pad(b)
  if S.phase == "crypt" then
    if S.phase_t > 0.4 then
      S.phase = "station"
      S.phase_t = 0
      if S.minoru then
        S.minoru:say("ext_intro")
        S.minoru:say("ext_taunt")
      end
      SFX.play("menu_select")
    end
    return
  end

  if S.input then
    if b == IM.A then commit_name()
    elseif b == IM.B then
      local ctx = S.input.ctx
      local slot = S.input.slot
      S.input = nil
      S.selected_slot = slot or 0
      if ctx == "new" then S.phase = "burst_pick" end
      SFX.play("menu_back")
    end
    return
  end

  if S.confirm_slot then
    if b == IM.A then
      remove_device_by_slot(S.confirm_slot)
      S.confirm_slot = nil
    elseif b == IM.B then
      S.confirm_slot = nil
      SFX.play("menu_back")
    end
    return
  end

  if S.actions_slot then
    local entry = entry_for_slot(S.actions_slot)
    if not entry then S.actions_slot = nil; return end
    if b == IM.A then
      local slot = S.actions_slot
      S.actions_slot = nil
      open_name_input({
        kind = entry.kind, real = entry.real, id = entry.id,
      }, "edit", slot)
    elseif b == IM.X then
      S.confirm_slot = S.actions_slot
      S.actions_slot = nil
      SFX.play("menu_select")
    elseif b == IM.B then
      S.actions_slot = nil
      SFX.play("menu_back")
    end
    return
  end

  if S.phase == "station" then
    if b == IM.A then idle_activate()
    elseif b == IM.Y then
      if S.selected_slot > 0 and is_slot_occupied(S.selected_slot) then
        local e = entry_for_slot(S.selected_slot)
        open_name_input({
          kind = e.kind, real = e.real, id = e.id,
        }, "edit", S.selected_slot)
      end
    elseif b == IM.X then
      if S.selected_slot > 0 and is_slot_occupied(S.selected_slot) then
        S.confirm_slot = S.selected_slot
        SFX.play("menu_select")
      end
    elseif b == IM.B then
      State.raw_input = false
      State.back()
    end

  elseif S.phase == "burst_choice" then
    if b == IM.A then choose_method()
    elseif b == IM.B then
      S.phase = "station"
      S.phase_t = 0
      SFX.play("menu_back")
    end

  elseif S.phase == "burst_scan" then
    if b == IM.B then
      S.phase = "station"
      S.phase_t = 0
      SFX.play("menu_back")
    end

  elseif S.phase == "burst_pick" then
    if b == IM.A then
      local dev = S.battle_devices[S.battle_device_sel]
      if dev then
        SFX.play("menu_select")
        open_name_input(dev, "new", nil)
      end
    elseif b == IM.B then
      S.phase = "station"
      S.phase_t = 0
      SFX.play("menu_back")
    end

  elseif S.phase == "burst_fail" then
    if b == IM.A then start_burst_link()
    elseif b == IM.B then
      S.phase = "station"
      S.phase_t = 0
      SFX.play("menu_back")
    end
  end
end

function S.hat(dir)
  if S.phase == "station" then
    idle_move(dir)
  elseif S.phase == "burst_choice" then
    if     dir == "up"   then S.choice_sel = 1; SFX.play("menu_move")
    elseif dir == "down" then S.choice_sel = 2; SFX.play("menu_move") end
  elseif S.phase == "burst_pick" then
    if     dir == "up"   then
      S.battle_device_sel = math.max(1, S.battle_device_sel - 1)
      SFX.play("menu_move")
    elseif dir == "down" then
      S.battle_device_sel = math.min(#S.battle_devices,
        S.battle_device_sel + 1)
      SFX.play("menu_move")
    end
  end
end

function S.key(k)
  if S.input then
    if k == "backspace" then
      S.input.buffer = S.input.buffer:sub(1, -2)
    elseif k == "return" then
      commit_name()
    elseif k == "escape" then
      local ctx = S.input.ctx
      local slot = S.input.slot
      S.input = nil
      S.selected_slot = slot or 0
      if ctx == "new" then S.phase = "burst_pick" end
    elseif #k == 1 and k:match("[%w_%-%s%.]") then
      if #S.input.buffer < 32 then
        S.input.buffer = S.input.buffer .. k
      end
    end
    return
  end
  if     k == "up"    then S.hat("up")
  elseif k == "down"  then S.hat("down")
  elseif k == "left"  then S.hat("left")
  elseif k == "right" then S.hat("right")
  elseif k == "return" or k == "space" then S.pad(IM.A)
  elseif k == "x" then S.pad(IM.X)
  elseif k == "y" then S.pad(IM.Y)
  elseif k == "escape" then S.pad(IM.B) end
end

-- ══════════════════════════════════════════════════════════════
--  Rendering helpers
-- ══════════════════════════════════════════════════════════════

-- Dug-out recessed panel. Top-left inner shadow, bottom-right
-- inner highlight, dark surround — reads as carved into the wall.
local function draw_dug_panel(x, y, w, h, accent)
  -- Outer dark surround
  love.graphics.setColor(0.05, 0.06, 0.08, 1)
  love.graphics.rectangle("fill", x, y, w, h, 3, 3)

  -- Inner recess
  love.graphics.setColor(COL.slot_dark)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 2, 2)

  -- Top + left inner shadow
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.setLineWidth(1)
  love.graphics.line(x + 3, y + 3, x + w - 3, y + 3)
  love.graphics.line(x + 3, y + 3, x + 3, y + h - 3)

  -- Bottom + right inner highlight (accent tinted)
  love.graphics.setColor(accent[1] * 0.55, accent[2] * 0.55,
    accent[3] * 0.55, 0.85)
  love.graphics.line(x + 3, y + h - 3, x + w - 3, y + h - 3)
  love.graphics.line(x + w - 3, y + 3, x + w - 3, y + h - 3)

  -- Accent hairline
  love.graphics.setColor(accent[1] * 0.45, accent[2] * 0.45,
    accent[3] * 0.45, 0.55)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)
  love.graphics.setLineWidth(1)
end

-- Engraved text: light stroke above, dark shadow below.
local function draw_engraved_text(font, text, x, y, color)
  love.graphics.setFont(font)
  -- Dark shadow (offset down-right)
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.print(text, x + 1, y + 1)
  -- Light face
  love.graphics.setColor(color)
  love.graphics.print(text, x, y)
end

-- Metal hanger bracket attached to a slot's inner edge.
-- side = "left" (hanger on right edge) or "right" (on left edge).
local function draw_hanger(slot_x, slot_y, side)
  local cy = slot_y + SLOT_H / 2
  local bw = 10
  local bh = 22

  local hx
  if side == "left" then
    -- hanger sits just outside the right edge of the slot
    hx = slot_x + SLOT_W
  else
    -- hanger sits just outside the left edge of the slot
    hx = slot_x - bw
  end
  local hy = cy - bh / 2

  -- Bracket body
  love.graphics.setColor(COL.metal_lo)
  love.graphics.rectangle("fill", hx, hy, bw, bh, 2, 2)
  love.graphics.setColor(COL.metal)
  love.graphics.rectangle("fill", hx + 1, hy + 1, bw - 2, bh - 2, 2, 2)

  -- Top highlight
  love.graphics.setColor(COL.metal_hi[1], COL.metal_hi[2],
    COL.metal_hi[3], 0.6)
  love.graphics.rectangle("fill", hx + 2, hy + 2, bw - 4, 2)

  -- Bolt
  love.graphics.setColor(COL.metal_hi)
  love.graphics.circle("fill", hx + bw / 2, cy, 2)
  love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
  love.graphics.circle("line", hx + bw / 2, cy, 2)

  -- Return anchor points for the two cables
  return hx + bw / 2, hy + 6, hy + bh - 6
end

-- Draw one of the cables from the hanger toward a target.
local function draw_cable(x1, y1, cx, cy, x2, y2, color, thickness)
  local segs = 20
  local pts = {}
  for i = 0, segs do
    local t = i / segs
    local u = 1 - t
    local x = u*u*x1 + 2*u*t*cx + t*t*x2
    local y = u*u*y1 + 2*u*t*cy + t*t*y2
    pts[#pts + 1] = x
    pts[#pts + 1] = y
  end

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.setLineWidth((thickness or 3) + 1.5)
  love.graphics.line(pts)

  -- Body
  love.graphics.setColor(color)
  love.graphics.setLineWidth(thickness or 3)
  love.graphics.line(pts)

  -- Highlight
  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.setLineWidth(1)
  love.graphics.line(pts)

  love.graphics.setLineWidth(1)
end

local function draw_slot(slot_idx, x, y, occupied, entry, focused)
  local is_left = slot_idx <= SLOT_COUNT
  local accent  = is_left and COL.amber or COL.blue

  -- Focus glow behind
  if focused then
    local t = State.t_ui or 0
    local pulse = 0.5 + 0.5 * math.sin(t * 5)
    D.glow(x + SLOT_W / 2, y + SLOT_H / 2, SLOT_W * 0.55, accent,
      0.55 + pulse * 0.30)
  end

  draw_dug_panel(x, y, SLOT_W, SLOT_H, accent)

  if not occupied then
    -- Engraved label inside the slot
    local font = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10)
    local label = is_left
      and ("USB " .. slot_idx)
      or  ("BT " .. (slot_idx - SLOT_COUNT))
    local label_col = is_left and COL.engraved or accent
    draw_engraved_text(font, label, x + 10, y + SLOT_H / 2 - 6, label_col)
  else
    -- Device info
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(
      "assets/fonts/Oxanium-Bold.ttf", 10))
    local uname = entry.user
    if #uname > 20 then uname = uname:sub(1, 19) .. "…" end
    love.graphics.print(uname, x + 10, y + 4)

    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.setFont(A.font(
      "assets/fonts/JetBrainsMono-Regular.ttf", 8))
    local rname = entry.real
    if #rname > 26 then rname = rname:sub(1, 25) .. "…" end
    love.graphics.print(rname, x + 10, y + 17)
  end

  -- Focus highlight
  if focused then
    local t = State.t_ui or 0
    local pulse = 0.5 + 0.5 * math.sin(t * 5)
    love.graphics.setColor(1, 1, 1, 0.55 + pulse * 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x - 1, y - 1, SLOT_W + 2, SLOT_H + 2, 4, 4)
    love.graphics.setLineWidth(1)
  end
end

-- Draw all slots + hangers + cables.
-- Cables are drawn AFTER the slots, so they visibly emerge from
-- the hanger and run toward the burst-link hexagon.
local function draw_slots_with_cables()
  -- First pass: slot bodies + hangers
  local cable_anchors = {}

  for i = 1, SLOT_COUNT do
    local pos = LEFT_SLOTS[i]
    local entry = entry_for_slot(i)
    draw_slot(i, pos.x, pos.y, entry ~= nil, entry,
      S.selected_slot == i)
    local hx, y_a, y_b = draw_hanger(pos.x, pos.y, "left")
    cable_anchors[#cable_anchors + 1] = {
      hx = hx, y_a = y_a, y_b = y_b, side = "left", idx = i,
    }
  end

  for i = 1, SLOT_COUNT do
    local slot_idx = i + SLOT_COUNT
    local pos = RIGHT_SLOTS[i]
    local entry = entry_for_slot(slot_idx)
    draw_slot(slot_idx, pos.x, pos.y, entry ~= nil, entry,
      S.selected_slot == slot_idx)
    local hx, y_a, y_b = draw_hanger(pos.x, pos.y, "right")
    cable_anchors[#cable_anchors + 1] = {
      hx = hx, y_a = y_a, y_b = y_b, side = "right", idx = slot_idx,
    }
  end

  -- Second pass: cables from each hanger to the burst-link hexagon.
  -- Two cables per hanger. Left: red + dark grey. Right: blue + dark grey.
  for _, a in ipairs(cable_anchors) do
    -- Target: a point on the top of the burst hexagon
    local target_x = BL_CX + (a.side == "left" and -10 or 10)
    local target_y = BL_CY - BL_R + 4

    -- Control point: pull the curve downward and inward
    local ctrl_x = (a.hx + target_x) / 2
    local ctrl_y = math.max(a.y_a, a.y_b) + 30

    local c1 = (a.side == "left") and COL.cable_a or COL.blue
    local c2 = COL.cable_b

    draw_cable(a.hx, a.y_a, ctrl_x, ctrl_y - 6, target_x, target_y, c1, 3)
    draw_cable(a.hx, a.y_b, ctrl_x + 4, ctrl_y + 6, target_x, target_y + 2,
      c2, 3)
  end
end

local function draw_burst_link()
  local focused = (S.selected_slot == 0)
  local t = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 3)
  local c = COL.purple
  local ch = COL.purple_hi

  if focused then
    D.glow(BL_CX, BL_CY, BL_R * 1.9 + pulse * 20, c, 0.85)
    love.graphics.setColor(c[1], c[2], c[3], 0.30 + pulse * 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", BL_CX, BL_CY, BL_R + 12)
    love.graphics.setLineWidth(1)
  end

  -- Hexagon
  local hex = {}
  for i = 0, 5 do
    local a = -math.pi / 2 + i * math.pi / 3
    hex[#hex + 1] = BL_CX + math.cos(a) * BL_R
    hex[#hex + 1] = BL_CY + math.sin(a) * BL_R
  end

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.push()
  love.graphics.translate(2, 3)
  love.graphics.polygon("fill", hex)
  love.graphics.pop()

  love.graphics.setColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1)
  love.graphics.polygon("fill", hex)
  love.graphics.setColor(c[1] * 0.28, c[2] * 0.28, c[3] * 0.28, 1)
  love.graphics.circle("fill", BL_CX, BL_CY, BL_R - 8)

  -- Outline
  love.graphics.setColor(ch)
  love.graphics.setLineWidth(focused and 3 or 2.4)
  love.graphics.polygon("line", hex)
  love.graphics.setLineWidth(1)

  -- Top highlight
  love.graphics.setColor(1, 1, 1, 0.14)
  love.graphics.arc("fill", "pie", BL_CX, BL_CY, BL_R - 10,
    -math.pi * 0.85, -math.pi * 0.15)

  -- Label
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 13))
  love.graphics.printf("BURST", BL_CX - BL_R, BL_CY - 11, BL_R * 2, "center")
  love.graphics.printf("LINK!", BL_CX - BL_R, BL_CY + 2, BL_R * 2, "center")

  -- Blinking LED
  local blink = 0.5 + 0.5 * math.sin(t * 5)
  love.graphics.setColor(ch[1], ch[2], ch[3], 0.5 + blink * 0.5)
  love.graphics.circle("fill", BL_CX, BL_CY - BL_R + 8, 2.5)
end

-- ── Burst-link sub-screens (unchanged logic, compact art) ───
local function draw_burst_choice()
  local cx = W / 2
  local by = STATION_TOP + 40
  local bw = 460
  local bh = 54
  local gap = 12

  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, STATION_TOP, W,
    STATION_BOT - STATION_TOP)

  love.graphics.setColor(0.04, 0.05, 0.09, 0.98)
  love.graphics.rectangle("fill", cx - bw/2, by - 34, bw,
    bh * 2 + gap + 48, 8, 8)
  love.graphics.setColor(COL.purple)
  D.rough_rect(cx - bw/2, by - 34, bw, bh * 2 + gap + 48,
    { jitter = 0.8, thickness = 1.6, seed = 45 })

  love.graphics.setColor(COL.purple_hi)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 13))
  love.graphics.printf("LINK CHANNEL", cx - bw/2, by - 24, bw, "center")

  local options = {
    { label = "Via BLUETOOTH", color = COL.blue,  },
    { label = "Via USB",       color = COL.amber, },
  }

  for i, opt in ipairs(options) do
    local c = opt.color
    local x = cx - bw/2 + 24
    local y = by + 8 + (i - 1) * (bh + gap)
    local w = bw - 48
    local focused = (i == S.choice_sel)
    if focused then D.glow(cx, y + bh/2, 100, c, 0.85) end
    love.graphics.setColor(
      focused and c[1]*0.35 or 0.06,
      focused and c[2]*0.35 or 0.07,
      focused and c[3]*0.35 or 0.10, 0.98)
    love.graphics.rectangle("fill", x, y, w, bh, 5, 5)
    love.graphics.setColor(c)
    D.rough_rect(x, y, w, bh,
      { jitter = 0.8, thickness = focused and 2.2 or 1.3, seed = i * 11 })

    love.graphics.setColor(focused and {1, 1, 1} or COL.text)
    love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 13))
    love.graphics.printf(opt.label, x, y + 18, w, "center")
  end
end

local function draw_burst_scan()
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, STATION_TOP, W,
    STATION_BOT - STATION_TOP)

  local bx = 60
  local by = STATION_TOP + 20
  local bw = W - 120
  local bh = STATION_BOT - by - 20

  love.graphics.setColor(0.04, 0.05, 0.09, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(COL.purple)
  D.rough_rect(bx, by, bw, bh,
    { jitter = 0.8, thickness = 1.6, seed = 33 })

  -- Progress bar
  local px = bx + 12
  local py = by + 34
  local pw = bw - 24
  love.graphics.setColor(0.10, 0.12, 0.16, 1)
  love.graphics.rectangle("fill", px, py, pw, 12, 4, 4)
  love.graphics.setColor(COL.purple)
  love.graphics.rectangle("fill", px, py, pw * S.battle_progress, 12, 4, 4)

  -- Log
  local ly = py + 26
  love.graphics.setFont(A.font(
    "assets/fonts/JetBrainsMono-Regular.ttf", 10))
  for _, l in ipairs(S.battle_log) do
    if l.revealed then
      love.graphics.setColor(0.30, 0.85, 0.75)
      love.graphics.print(l.text, bx + 14, ly)
      ly = ly + 14
    end
  end
end

local function draw_burst_pick()
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, STATION_TOP, W,
    STATION_BOT - STATION_TOP)

  local bx = 60
  local by = STATION_TOP + 20
  local bw = W - 120
  local bh = STATION_BOT - by - 20

  love.graphics.setColor(0.04, 0.05, 0.09, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(COL.green)
  D.rough_rect(bx, by, bw, bh,
    { jitter = 0.8, thickness = 1.6, seed = 33 })

  love.graphics.setColor(COL.green)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 11))
  love.graphics.print("LINK READY  ·  SELECT TARGET", bx + 12, by + 8)

  local ly = by + 30
  local row_h = 26
  for i, d in ipairs(S.battle_devices) do
    local focused = (i == S.battle_device_sel)
    if focused then
      love.graphics.setColor(COL.green[1], COL.green[2], COL.green[3], 0.18)
      love.graphics.rectangle("fill", bx + 8, ly - 2, bw - 16, row_h - 2, 3, 3)
      love.graphics.setColor(COL.green)
      love.graphics.rectangle("fill", bx + 8, ly - 2, 3, row_h - 2, 1, 1)
    end
    love.graphics.setColor(focused and {1, 1, 1} or COL.text)
    love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 11))
    love.graphics.print(d.user, bx + 22, ly + 1)

    love.graphics.setColor(d.kind == "bt" and COL.blue or COL.amber)
    love.graphics.setFont(A.font(
      "assets/fonts/JetBrainsMono-Regular.ttf", 8))
    love.graphics.print(d.kind:upper() .. "  " .. d.id, bx + 22, ly + 13)

    ly = ly + row_h
    if ly > by + bh - 26 then break end
  end
end

local function draw_burst_fail()
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, STATION_TOP, W,
    STATION_BOT - STATION_TOP)

  local bw, bh = 460, 140
  local bx = (W - bw) / 2
  local by = STATION_TOP + 30

  love.graphics.setColor(0.04, 0.05, 0.09, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(COL.red)
  D.rough_rect(bx, by, bw, bh,
    { jitter = 0.8, thickness = 2, seed = 3 })

  love.graphics.setColor(COL.red)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 18))
  love.graphics.printf("LINK FAILED", bx, by + 22, bw, "center")

  love.graphics.setColor(COL.text)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 11))
  love.graphics.printf(
    S.method == "bt"
      and "No Bluetooth device responded."
      or  "No USB HID device was found.",
    bx + 20, by + 62, bw - 40, "center")

  love.graphics.setColor(COL.text_dim)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 10))
  love.graphics.printf("[A] Retry   [B] Close",
    bx, by + bh - 30, bw, "center")
end

local function draw_name_input()
  if not S.input then return end
  local bw, bh = 460, 140
  local bx = (W - bw) / 2
  local by = (H - bh) / 2

  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, W, H)

  love.graphics.setColor(0.05, 0.06, 0.10, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(COL.purple_hi)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(COL.text_dim)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 11))
  love.graphics.print(S.input.label or "Value", bx + 20, by + 16)

  love.graphics.setFont(A.font(
    "assets/fonts/Oxanium-Regular.ttf", 10))
  love.graphics.printf("Real device: " .. S.input.target.real,
    bx + 20, by + 32, bw - 40, "left")

  love.graphics.setColor(COL.purple[1], COL.purple[2], COL.purple[3], 0.15)
  love.graphics.rectangle("fill", bx + 16, by + 54, bw - 32, 36, 4, 4)
  love.graphics.setColor(COL.text)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 14))
  local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
  love.graphics.print(S.input.buffer .. cursor, bx + 28, by + 62)

  BI.draw_hint_centered("[Enter] OK   [Esc] Cancel",
    W, by + bh + 8, A.font(State.theme.font_body, 11), State.theme)
end

-- ── Crypt intro (unchanged) ────────────────────────────────
local function draw_crypt(th)
  local t = S.phase_t
  local fade = math.min(1, t / 0.7)
  love.graphics.setColor(0, 0, 0, 1 - fade * 0.92)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local wall_p = math.min(1, math.max(0, (t - 0.30) / 1.2))
  wall_p = wall_p * wall_p * (3 - 2 * wall_p)
  local wall_w = 200
  local wall_x_l = -wall_w + wall_p * wall_w
  local wall_x_r = W - wall_p * wall_w

  love.graphics.setColor(0.10, 0.10, 0.13, 0.95)
  love.graphics.rectangle("fill", wall_x_l, 0, wall_w, H)
  love.graphics.rectangle("fill", wall_x_r, 0, wall_w, H)
  love.graphics.setColor(0.16, 0.16, 0.20, 0.9)
  love.graphics.rectangle("fill", wall_x_l + wall_w - 6, 0, 6, H)
  love.graphics.rectangle("fill", wall_x_r, 0, 6, H)

  love.graphics.setColor(0.06, 0.06, 0.09, 0.9)
  for y = 0, H, 44 do
    love.graphics.rectangle("fill", wall_x_l, y, wall_w, 2)
    love.graphics.rectangle("fill", wall_x_r, y, wall_w, 2)
  end

  local torch_p = math.min(1, math.max(0, (t - 0.8) / 1.2))
  local flicker = 0.85 + 0.15 * math.sin(t * 17)
  local torch_a = torch_p * 0.45 * flicker
  local function torch(cx, cy)
    for i = 8, 1, -1 do
      love.graphics.setColor(0.95, 0.72, 0.30, torch_a * (1 - i / 9))
      love.graphics.circle("fill", cx, cy, 6 + i * 5)
    end
    love.graphics.setColor(1.0, 0.92, 0.70, torch_a * 0.9)
    love.graphics.circle("fill", cx, cy, 5)
  end
  torch(70, 70)
  torch(W - 70, 70)

  local open_p = math.min(1, math.max(0, (t - 1.2) / 1.0))
  local open_a = open_p * 0.55
  for i = 1, 6 do
    love.graphics.setColor(0.20, 0.72, 0.98, open_a * (1 - i / 7))
    love.graphics.ellipse("fill", W / 2, H - 40, 80 + i * 40, 12 + i * 4)
  end

  local title_p = math.min(1, math.max(0, (t - 1.4) / 0.9))
  title_p = title_p * title_p * (3 - 2 * title_p)
  love.graphics.setColor(0.85, 0.97, 1.0, title_p)
  love.graphics.setFont(A.font(th.font_title, 26))
  love.graphics.printf("EXTERNAL INPUT STATION", 0, H / 2 - 20, W, "center")

  local sub_p = math.min(1, math.max(0, (t - 1.8) / 0.8))
  love.graphics.setColor(0.55, 0.75, 0.90, sub_p)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 11))
  love.graphics.printf("SUBLEVEL 04  ·  BURST LINK CONTROL",
    0, H / 2 + 20, W, "center")

  D.vignette(W, H, 0.65)

  if t > 0.6 then
    local a = 0.30 + 0.25 * math.sin(t * 4)
    love.graphics.setColor(0.6, 0.75, 0.9, a)
    love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 9))
    love.graphics.printf("Press any button to skip",
      0, H - 20, W, "center")
  end
end

-- ── Main draw ───────────────────────────────────────────────
function S.draw()
  local th = State.theme
  love.graphics.clear(0.02, 0.03, 0.05)

  if S.phase == "crypt" then
    draw_crypt(th)
    return
  end

  Header.draw("EXTERNAL INPUT STATION", "external")

  -- Metal station plate background
  love.graphics.setColor(0.035, 0.040, 0.055, 1)
  love.graphics.rectangle("fill", 0, STATION_TOP,
    W, STATION_BOT - STATION_TOP)
  love.graphics.setColor(0.06, 0.07, 0.09, 0.6)
  for yy = STATION_TOP, STATION_BOT, 6 do
    love.graphics.rectangle("fill", 0, yy, W, 1)
  end

  -- Slots with hangers and cables
  draw_slots_with_cables()

  -- BURST LINK hexagon (drawn on top of cable ends)
  draw_burst_link()

  -- Overlays
  if     S.phase == "burst_choice" then draw_burst_choice()
  elseif S.phase == "burst_scan"   then draw_burst_scan()
  elseif S.phase == "burst_pick"   then draw_burst_pick()
  elseif S.phase == "burst_fail"   then draw_burst_fail() end

  if S.input then draw_name_input() end

  -- Minoru engine on the bottom band
  if S.minoru then
    S.minoru:draw(0, STATION_BOT, W, MINORU_H)
  end

  -- Idle hint
  if S.phase == "station"
     and not S.actions_slot and not S.confirm_slot and not S.input then
    love.graphics.setColor(COL.text_dim)
    love.graphics.setFont(A.font(
      "assets/fonts/Oxanium-Regular.ttf", 9))
    local hint
    if S.selected_slot == 0 then
      hint = "Press [A] on BURST LINK to begin pairing"
    elseif is_slot_occupied(S.selected_slot) then
      hint = "[A] Actions   [Y] Rename   [X] Remove"
    else
      hint = "Empty slot"
    end
    love.graphics.printf(hint, 0, STATION_BOT - 10, W, "center")
  end

  -- Footer
  if not S.actions_slot and not S.confirm_slot and not S.input then
    local items
    if S.phase == "station" then
      items = {
        { key = "dpad", label = "Select" },
        { key = "a",    label = (S.selected_slot == 0)
                              and "Burst Link" or "Actions" },
        { key = "b",    label = "Back" },
      }
    elseif S.phase == "burst_choice" then
      items = {
        { key = "dpad", label = "Choose"  },
        { key = "a",    label = "Confirm" },
        { key = "b",    label = "Back"    },
      }
    elseif S.phase == "burst_scan" then
      items = { { key = "b", label = "Abort" } }
    elseif S.phase == "burst_pick" then
      items = {
        { key = "dpad", label = "Select"  },
        { key = "a",    label = "Confirm" },
        { key = "b",    label = "Back"    },
      }
    elseif S.phase == "burst_fail" then
      items = {
        { key = "a", label = "Retry" },
        { key = "b", label = "Close" },
      }
    end
    if items then
      BI.draw_footer(th, items, W, H - 22,
        A.font(th.font_body, 10))
    end
  end
end

return S