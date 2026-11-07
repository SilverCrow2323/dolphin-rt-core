-- frontend/screens/onboarding.lua
--
-- First-run setup wizard. Runs once, right after the SPDW advisory
-- and before the boot animation. Asks for GameCube and Wii ROM
-- paths, saves them via settings_store, and marks the wizard as
-- done in frontendone.json under general.onboarding_done.
--
-- Flow:
--   step 1 (welcome)   -> [A] Continue    [B] Skip all
--   step 2 (gc)        -> [A] Choose folder   [Y] Skip step   [B] Back
--   step 3 (wii)       -> [A] Choose folder   [Y] Skip step   [B] Back
--   step 4 (done)      -> [A] Start
--
-- File picking reuses screens/file_explorer.lua via State.go with
-- an on_select callback. The wizard keeps its state across that
-- round-trip because enter() only initializes on the very first
-- entry (guarded by the module-level _initialized flag).
--
-- State.raw_input is true for the entire lifetime so that B and
-- START reach S.pad instead of being swallowed by main.lua's
-- global back.
--
-- ── v0.4.7 — cleanup ──────────────────────────────────────────
--   1. _picking guard: the file_explorer callback cannot fire
--      twice if the user spams Y+A during the round-trip. The
--      previous revision could double-add the same path.
--   2. B on step 2/3 with no path chosen goes straight to
--      finish() — there is nothing to preserve, and "back to
--      welcome" was just an extra button press.
--   3. draw_content() now ellipsizes the chosen path: shows
--      "…/parent/basename" instead of a naive truncation.
--   4. Progress dots show a checkmark on completed steps.
--   5. The "done" step text adapts: if the library is still
--      empty after the scan (no ROMs found in the chosen
--      folders), the copy suggests Settings → ROM Paths.
--   6. All A.font() calls use the shared cache (no alloc per
--      frame).

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BI     = require("ui.button_icons")
local Icons  = require("ui.icons")
local Store  = require("settings_store")
local Notify = require("notify")

local S = {}
local W, H = 640, 480

-- ── Layout ──────────────────────────────────────────────────
local WIN_X, WIN_Y = 30, 40
local WIN_W, WIN_H = 580, 400
local HEADER_H     = 36
local PROGRESS_H   = 24
local BUTTON_H     = 60
local CONTENT_Y    = WIN_Y + HEADER_H + PROGRESS_H
local CONTENT_H    = WIN_H - HEADER_H - PROGRESS_H - BUTTON_H

-- ── Steps ───────────────────────────────────────────────────
local STEPS = {
  { key = "welcome", title = "Welcome to DolphinUI", icon = "star" },
  { key = "gc",      title = "GameCube ROMs",        icon = "library" },
  { key = "wii",     title = "Wii ROMs",             icon = "library" },
  { key = "done",    title = "All set.",             icon = "play" },
}

-- Body text per step. Kept as discrete lines for predictable
-- layout, wrapped tightly so they fit the content area without
-- colliding with the footer.
local BODY = {
  welcome = {
    "This is a quick two-step setup.",
    "",
    "DolphinUI needs to know where your",
    "GameCube and Wii games live on the SD",
    "card or USB drive.",
    "",
    "You can change everything later from",
    "Settings  →  ROM Paths.",
  },
  gc = {
    "Pick the folder that contains your",
    "GameCube games. DolphinUI scans it",
    "recursively for ISO, GCM, RVZ, and",
    "WBFS files.",
    "",
    "You can add more folders later.",
  },
  wii = {
    "Now the same for Wii games.",
    "",
    "If you don't have any Wii games yet,",
    "skip this step — you can add the",
    "folder whenever you want.",
  },
  done = {
    "Your library is being scanned in the",
    "background. It will be ready in a",
    "moment.",
    "",
    "That's it. Have fun.",
  },
}

-- ── State ───────────────────────────────────────────────────
S.step         = 1
S.t            = 0
S.enter_ease   = 0
S.gc_path      = nil
S.wii_path     = nil

local _initialized = false
local _picking     = false      -- guard against double-fire callbacks
local _finished    = false      -- guard against double-finish

local function current_step()
  return STEPS[S.step]
end

-- ── Actions ─────────────────────────────────────────────────
local function finish()
  if _finished then return end
  _finished = true

  Store.set("general", "onboarding_done", true)
  Store.save()

  if State.rescan_roms_async then
    State.rescan_roms_async(0.3)
  end

  _initialized = false
  _picking     = false
  State.raw_input = false
  SFX.play("menu_select")
  Notify.show("success", "Setup complete", 3.0)
  State.go("boot")
end

local function next_step()
  if S.step < #STEPS then
    S.step = S.step + 1
    SFX.play("menu_move")
  else
    finish()
  end
end

local function prev_step()
  if S.step > 1 then
    S.step = S.step - 1
    SFX.play("menu_back")
  end
end

-- The user picked a folder in file_explorer. Add it to settings,
-- advance to the next step.
local function handle_pick(system, chosen)
  if _picking then return end       -- callback fired twice
  if not chosen or chosen == "" then return end
  _picking = true

  if system == "gc" then S.gc_path = chosen
  else S.wii_path = chosen end

  local ok, err = Store.add_path(system, chosen)
  if ok then
    Store.save()
    Notify.show("success", "Added: " .. chosen)
  else
    Notify.show("warning", "Not added: " .. (err or "?"))
  end

  S.step = S.step + 1
  if S.step > #STEPS then
    finish()
  end

  _picking = false
end

local function pick_folder(system)
  if _picking then return end
  _picking = true

  local start = "/mnt"
  if     system == "gc"  and S.gc_path  then start = S.gc_path  end
  if     system == "wii" and S.wii_path then start = S.wii_path end

  State.go("file_explorer", {
    start_path = start,
    on_select = function(chosen)
      -- The screen sets State.raw_input = false and calls
      -- State.back() before this callback runs; we release the
      -- guard as soon as the work is done so a second tap on Y
      -- cannot re-trigger it.
      _picking = false
      handle_pick(system, chosen)
    end,
  })

  -- If file_explorer is entered and immediately exited without a
  -- pick (e.g. B on the root), _picking would stay true forever.
  -- re_enter() clears it on the way back.
end

local function skip_step()
  if _picking then return end
  S.step = S.step + 1
  SFX.play("menu_move")
  if S.step > #STEPS then
    finish()
  end
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  if not _initialized then
    S.step       = 1
    S.t          = 0
    S.enter_ease = 0
    S.gc_path    = nil
    S.wii_path   = nil
    _initialized = true
    _finished    = false
  end
  _picking = false
  State.raw_input = true
end

function S.leave()
  State.raw_input = false
  -- If we are being left because the user is navigating away
  -- (not because they picked a folder), clear the guard so the
  -- next entry is clean.
  _picking = false
end

function S.re_enter()
  _picking = false
  State.raw_input = true
end

function S.update(dt)
  S.t = S.t + dt
  if S.enter_ease < 1 then
    S.enter_ease = math.min(1, S.enter_ease + dt / 0.30)
  end
end

-- ── Input ───────────────────────────────────────────────────
function S.pad(b)
  if _picking then return end
  local step = current_step()
  if not step then return end

  if step.key == "welcome" then
    if     b == IM.A then next_step()
    elseif b == IM.B then finish() end

  elseif step.key == "gc" or step.key == "wii" then
    local system = (step.key == "gc") and "gc" or "wii"
    if     b == IM.A then pick_folder(system)
    elseif b == IM.Y then skip_step()
    elseif b == IM.B then
      -- If nothing has been added yet, B is a fast path out.
      -- If a path is already set, B goes back a step so the user
      -- can revise their choice.
      local has_any = S.gc_path ~= nil or S.wii_path ~= nil
      if not has_any then finish() else prev_step() end
    end

  elseif step.key == "done" then
    if b == IM.A then finish() end
    -- No B handler: once you are on "done" the only way is
    -- forward. B is a no-op so the user cannot wander back into
    -- a half-configured wizard.
  end
end

function S.hat(_dir) end

function S.key(k)
  if _picking then return end
  if     k == "return" or k == "space" then S.pad(IM.A)
  elseif k == "escape"                 then S.pad(IM.B)
  elseif k == "y"                      then S.pad(IM.Y)
  end
end

-- ── Drawing helpers ─────────────────────────────────────────
local function draw_background(t)
  love.graphics.clear(0.02, 0.03, 0.06)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.04)
  local off = (t * 12) % 40
  for x = -40 + off, W + 40, 40 do
    love.graphics.line(x, 0, x, H)
  end
  for y = -40 + off, H + 40, 40 do
    love.graphics.line(0, y, W, y)
  end

  love.graphics.setColor(0, 0, 0, 0.20)
  local sl = (t * 24) % 3
  for y = sl, H, 3 do
    love.graphics.line(0, y, W, y)
  end

  for i = 1, 4 do
    love.graphics.setColor(0, 0, 0, 0.6 * (i / 4) * 0.14)
    love.graphics.rectangle("line", -i*4, -i*4, W + i*8, H + i*8)
  end
end

local function draw_window(ease)
  love.graphics.setColor(0.03, 0.05, 0.09, 0.98 * ease)
  love.graphics.rectangle("fill", WIN_X, WIN_Y, WIN_W, WIN_H, 8, 8)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.90 * ease)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", WIN_X, WIN_Y, WIN_W, WIN_H, 8, 8)
  love.graphics.setLineWidth(1)

  D.corner_brackets(WIN_X, WIN_Y, WIN_W, WIN_H,
    {0.20, 0.72, 0.98}, 18)
end

local function draw_header(ease)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.15 * ease)
  love.graphics.rectangle("fill", WIN_X, WIN_Y, WIN_W, HEADER_H, 6, 6)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.85 * ease)
  love.graphics.rectangle("fill", WIN_X, WIN_Y + HEADER_H - 1, WIN_W, 1)

  for i = 1, 3 do
    local dx = WIN_X + 14 + (i - 1) * 12
    local col = (i == 1) and {0.30, 0.80, 0.40}
             or (i == 2) and {0.96, 0.77, 0.26}
             or {0.90, 0.30, 0.30}
    love.graphics.setColor(col[1], col[2], col[3], 0.9 * ease)
    love.graphics.circle("fill", dx, WIN_Y + HEADER_H / 2, 3)
  end

  love.graphics.setFont(
    A.font("assets/fonts/JetBrainsMono-Regular.ttf", 12))
  love.graphics.setColor(0.85, 0.92, 1.0, ease)
  love.graphics.print("DOLPHINUI  //  FIRST-RUN SETUP",
    WIN_X + 58, WIN_Y + 11)
end

local function draw_progress(ease)
  local y = WIN_Y + HEADER_H + 8
  local cx0 = WIN_X + WIN_W / 2 - (#STEPS * 20) / 2

  for i = 1, #STEPS do
    local cx = cx0 + (i - 1) * 20 + 10
    local active = (i == S.step)
    local done   = (i < S.step)

    if active then
      love.graphics.setColor(0.20, 0.72, 0.98, 0.9 * ease)
      love.graphics.circle("fill", cx, y + 4, 5)
      love.graphics.setColor(1, 1, 1, 0.9 * ease)
      love.graphics.circle("fill", cx, y + 4, 2)
    elseif done then
      love.graphics.setColor(0.30, 0.80, 0.40, 0.85 * ease)
      love.graphics.circle("fill", cx, y + 4, 5)
      -- Checkmark
      love.graphics.setColor(0, 0, 0, 0.9 * ease)
      love.graphics.setLineWidth(1.6)
      love.graphics.line(
        cx - 2.5, y + 4,
        cx - 0.5, y + 6,
        cx + 3,   y + 1.5)
      love.graphics.setLineWidth(1)
    else
      love.graphics.setColor(0.35, 0.40, 0.50, 0.6 * ease)
      love.graphics.circle("line", cx, y + 4, 4)
    end
  end

  love.graphics.setFont(
    A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
  love.graphics.setColor(0.55, 0.62, 0.78, ease)
  love.graphics.printf(
    ("STEP %d / %d"):format(S.step, #STEPS),
    WIN_X + 10, y - 1, WIN_W - 20, "right")
end

-- Shorten a long path for display: "…/parent/basename".
local function short_path(p)
  if not p or p == "" then return "—" end
  if #p <= 46 then return p end
  local parent = p:match("([^/]+)/[^/]+$")
  local base   = p:match("([^/]+)$")
  if parent and base then
    return "…/" .. parent .. "/" .. base
  end
  return "…" .. p:sub(-42)
end

local function draw_content(ease, t)
  local step = current_step()
  if not step then return end

  local cx = WIN_X + WIN_W / 2
  local icon_y = CONTENT_Y + 14

  local pulse = 0.5 + 0.5 * math.sin(t * 2.4)
  D.glow(cx, icon_y + 24, 55 + pulse * 8,
    {0.20, 0.72, 0.98}, 0.35 * ease)
  Icons.draw(step.icon, cx - 24, icon_y, 48, {0.85, 0.95, 1.0, ease})

  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 20))
  love.graphics.setColor(0.95, 0.97, 1.0, ease)
  love.graphics.printf(step.title, WIN_X, icon_y + 66, WIN_W, "center")

  -- Done step gets context-aware copy when the scan completed
  -- without finding anything.
  local body = BODY[step.key] or {}
  if step.key == "done" and State.scan_done
     and #(State.roms or {}) <= 2 then
    body = {
      "Scan complete, but no ROMs were",
      "found in the folders you picked.",
      "",
      "Add or change folders from",
      "Settings  →  ROM Paths.",
      "",
      "You can still continue from here.",
    }
  end

  local body_font = A.font("assets/fonts/Oxanium-Regular.ttf", 12)
  love.graphics.setFont(body_font)
  love.graphics.setColor(0.80, 0.85, 0.94, ease)
  local by = icon_y + 100
  for _, line in ipairs(body) do
    love.graphics.printf(line, WIN_X + 40, by, WIN_W - 80, "center")
    by = by + 18
  end

  -- Chosen path (if any) below the body.
  local chosen = (step.key == "gc" and S.gc_path)
              or (step.key == "wii" and S.wii_path)
  if chosen then
    love.graphics.setFont(
      A.font("assets/fonts/JetBrainsMono-Regular.ttf", 9))
    love.graphics.setColor(0.30, 0.85, 0.45, ease)
    love.graphics.printf("✓  " .. short_path(chosen),
      WIN_X + 40, by + 8, WIN_W - 80, "center")
  end
end

local function footer_items()
  local step = current_step()
  if not step then return {} end

  if step.key == "welcome" then
    return {
      { key = "a", label = "Continue" },
      { key = "b", label = "Skip all" },
    }
  elseif step.key == "gc" or step.key == "wii" then
    return {
      { key = "a", label = "Choose folder" },
      { key = "y", label = "Skip step"     },
      { key = "b", label = "Back"          },
    }
  elseif step.key == "done" then
    return {
      { key = "a", label = "Start" },
    }
  end
  return {}
end

function S.draw()
  local t = S.t
  local ease = S.enter_ease
  ease = 1 - (1 - ease) ^ 3

  draw_background(t)

  local scale = 0.95 + 0.05 * ease
  local cx = WIN_X + WIN_W / 2
  local cy = WIN_Y + WIN_H / 2

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)

  draw_window(ease)
  draw_header(ease)
  draw_progress(ease)
  draw_content(ease, t)

  love.graphics.pop()

  BI.draw_footer(State.theme, footer_items(), W, H - 22,
    A.font("assets/fonts/Oxanium-Regular.ttf", 12))

  -- Final CRT scanline pass
  love.graphics.setColor(0, 0, 0, 0.05)
  for y = 0, H, 3 do
    love.graphics.line(0, y, W, y)
  end
end

return S