-- frontend/key_bindings.lua — keyboard action bindings.
-- Maps a physical LÖVE key name (e.g. "w", "up", "f1") to a logical
-- action. Actions have a `raw_target` — the LÖVE key name the screen
-- layer expects — so translating is transparent: main.lua calls
-- KB.translate(key), screens never know about remapping.
--
-- Persistence: data/keybindings.json (atomic write via sh.atomic_write)
local json = require("json")
local sh   = require("sh")

local M = {}
local PATH = "data/keybindings.json"

-- Actions catalogue. Each entry:
--   id          — stable identifier used in json
--   label       — human label (shown in the UI)
--   raw_target  — the raw key name that screens understand
--   pad_equiv   — pad button name (for gamepad view)
--   default_key — the default physical key
local ACTIONS = {
  { id = "navigate_up",    label = "Navigate Up",     raw_target = "up",     pad_equiv = "dpad",   default_key = "up" },
  { id = "navigate_down",  label = "Navigate Down",   raw_target = "down",   pad_equiv = "dpad",   default_key = "down" },
  { id = "navigate_left",  label = "Navigate Left",   raw_target = "left",   pad_equiv = "dpad",   default_key = "left" },
  { id = "navigate_right", label = "Navigate Right",  raw_target = "right",  pad_equiv = "dpad",   default_key = "right" },
  { id = "confirm",        label = "Confirm / Select",raw_target = "return", pad_equiv = "a",      default_key = "return" },
  { id = "back",           label = "Back / Cancel",   raw_target = "escape", pad_equiv = "b",      default_key = "escape" },
  { id = "action_x",       label = "X Action",        raw_target = "x",      pad_equiv = "x",      default_key = "x" },
  { id = "action_y",       label = "Y Action",        raw_target = "y",      pad_equiv = "y",      default_key = "y" },
  { id = "page_prev",      label = "Previous Page",   raw_target = "q",      pad_equiv = "l1",     default_key = "q" },
  { id = "page_next",      label = "Next Page",       raw_target = "e",      pad_equiv = "r1",     default_key = "e" },
  { id = "quick",          label = "Quick Action",    raw_target = "f",      pad_equiv = "start",  default_key = "f" },
  { id = "flip_theme",     label = "Flip Theme",      raw_target = "tab",    pad_equiv = "select", default_key = "tab" },
  { id = "menu",           label = "Menu Overlay",    raw_target = "m",      pad_equiv = "menu",   default_key = "m" },
}

local by_id = {}
for _, a in ipairs(ACTIONS) do by_id[a.id] = a end

-- Runtime bindings: id -> physical key name
local bindings = {}

-- ── Persistence ──────────────────────────────────────────────
local function load()
  local f = io.open(PATH, "r")
  if not f then
    bindings = {}
    return
  end
  local c = f:read("*a"); f:close()
  local ok, data = pcall(json.decode, c)
  if ok and type(data) == "table" then
    bindings = data
  else
    bindings = {}
  end
end

-- Atomic: write to .tmp, then rename (with FAT32 cp fallback inside
-- sh.atomic_write). Previously this wrote directly to PATH, so a
-- crash/power loss mid-write would leave a truncated JSON and the
-- user would silently lose every custom binding.
local function save()
  sh.atomic_write(PATH, json.encode(bindings))
end

-- ── Public API ───────────────────────────────────────────────
function M.init()
  load()
  -- fill defaults for any action without a binding
  for _, a in ipairs(ACTIONS) do
    if not bindings[a.id] then bindings[a.id] = a.default_key end
  end
end

function M.actions()  return ACTIONS end
function M.action(id) return by_id[id] end

function M.get(id)
  return bindings[id] or (by_id[id] and by_id[id].default_key) or nil
end

function M.set(id, key)
  if not by_id[id] then return false end
  -- If another action already uses this key, unbind it (avoid duplicates)
  for other_id, k in pairs(bindings) do
    if k == key and other_id ~= id then
      bindings[other_id] = nil
    end
  end
  bindings[id] = key
  save()
  return true
end

function M.reset(id)
  if not by_id[id] then return false end
  bindings[id] = by_id[id].default_key
  save()
  return true
end

function M.reset_all()
  bindings = {}
  for _, a in ipairs(ACTIONS) do bindings[a.id] = a.default_key end
  save()
end

-- Given a raw LÖVE key, return the raw target the screen should see.
-- If the key is not bound to any action, returns it unchanged.
function M.translate(key)
  for id, k in pairs(bindings) do
    if k == key then
      local action = by_id[id]
      if action and action.raw_target then return action.raw_target end
    end
  end
  return key
end

return M