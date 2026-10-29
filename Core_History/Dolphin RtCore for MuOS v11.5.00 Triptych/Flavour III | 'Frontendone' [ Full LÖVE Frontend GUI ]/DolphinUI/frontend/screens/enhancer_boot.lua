-- screens/enhancer_boot.lua — Rt:Enhancer Dock boot transition.
--
-- Timeline:
--   0.00 – 0.40  glitch burst
--   0.40 – 1.00  RIG marker + title reveal
--   1.00 – 1.80  terminal log lines appear one by one
--   1.80 – 2.50  FUSION: ghost dashboard materializes behind, log lines
--                drift toward dashboard borders and dissolve into them
--   2.50         → State.go("ethostore")
--
-- Session gating:
--   This screen runs ONCE PER APP SESSION. main.lua's State.go() checks
--   State.enhancer_boot_done and redirects enhancer_boot → ethostore if
--   the animation already ran. The check inside S.enter() is a safety
--   net for direct calls (tests, debug screens).
--
-- v0.4.4 — Skip flag
--   * advanced.enhancer_boot_animation (default true) disables the
--     whole intro. When false, S.enter() marks the intro as done and
--     forwards to ethostore immediately, so the user never sees the
--     cinematic. This is the same behaviour main.lua's redirect_by_flags
--     applies; the check here catches direct State.go() calls from
--     internal screens (e.g. a shortcut in the Workshop).
--
-- Audio:
--   * dead_space_ui_sound_1  plays on enter (the "RIG online" chime)
--   * dead_space_menu_sound  plays exactly ONCE, when the first log line
--     appears. It is NOT played per-line: that produced a continuous
--     "pop pop pop pop pop" during the log cascade which sounded broken.
--   * Any input after 0.4s skips to ethostore and marks the flag.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local D = require("ui.draw")

local S = {
  t = 0,
  dur = 1.8,
  fade_dur = 0.7,
  log_lines = {},
  done = false,
  _first_line_sfx = false,
}

local W, H = 640, 480

local LOG_TEXTS = {
  "USG ISHIMURA :: RIG ONLINE",
  "BIOS CHECK ................ OK",
  "LOADING SHOP INDEX ........ OK",
  "SYNC GITHUB API ........... OK",
  "DECOMPRESSING RIG MANIFEST  OK",
  "SCANNING AVAILABLE MODULES  OK",
  "RT:ENHANCEMENT HUB :: READY",
}

function S.enter()
  -- Flag gate: user disabled the intro. Mark as done and forward.
  local Store = require("settings_store")
  if Store.get("advanced", "enhancer_boot_animation") == false then
    print("[enhancer_boot] skipped (advanced.enhancer_boot_animation = false)")
    State.enhancer_boot_done = true
    State.raw_input = false
    State.go("ethostore")
    return
  end

  -- Safety net: the animation already played this session. main.lua
  -- already redirects, but a direct State.go("enhancer_boot") from a
  -- debug screen would otherwise re-run the whole sequence.
  if State.enhancer_boot_done then
    State.go("ethostore")
    return
  end

  S.t = 0
  S.log_lines = {}
  S.done = false
  S._first_line_sfx = false
  SFX.play("dead_space_ui_sound_1")
end

local function go_store()
  State.enhancer_boot_done = true
  State.go("ethostore")
end

function S.update(dt)
  S.t = S.t + dt

  -- Progressive log lines, faster cadence.
  local step = 0.14
  local start = 0.95
  local target = math.max(0, math.floor((S.t - start) / step) + 1)
  if target > #LOG_TEXTS then target = #LOG_TEXTS end

  if #S.log_lines < target then
    while #S.log_lines < target do
      table.insert(S.log_lines, LOG_TEXTS[#S.log_lines + 1])
    end
    -- Play the "log started" chime exactly once, when the first line
    -- appears. Subsequent lines are silent.
    if not S._first_line_sfx then
      S._first_line_sfx = true
      SFX.play("dead_space_menu_sound")
    end
  end

  if S.t >= S.dur + S.fade_dur then
    go_store()
  end
end

function S._skip()
  if S.t > 0.4 and not S.done then
    S.done = true
    SFX.play("menu_select")
    go_store()
  end
end

function S.pad(_) S._skip() end
function S.hat(_) S._skip() end
function S.key(_) S._skip() end

-- ── Background: global scanlines ────────────────────────────
local function draw_scanlines()
  love.graphics.setColor(0, 0.8, 1.0, 0.04)
  for y = 0, H, 3 do
    love.graphics.line(0, y, W, y)
  end
end

-- ── Phase 1: glitch burst ───────────────────────────────────
local function draw_phase_glitch(p)
  for i = 1, 14 do
    local y = math.random() * H
    local h = 1 + math.random() * 6
    love.graphics.setColor(0.2, 0.85, 1.0, 0.35 * (1 - p))
    love.graphics.rectangle("fill", -10 + math.random() * 20, y, W, h)
  end
  local bar_h = p * H * 0.6
  love.graphics.setColor(0.2, 0.85, 1.0, 0.05 + 0.05 * (1 - p))
  love.graphics.rectangle("fill", 0, H / 2 - bar_h / 2, W, bar_h)
end

-- ── Phase 2: RIG marker + title ─────────────────────────────
local function draw_phase_rig(t)
  local p = (t - 0.4) / 0.6
  local alpha = math.min(1, p * 2)
  if p > 0.85 then alpha = alpha * (1 - (p - 0.85) / 0.15) end

  local cx, cy = W / 2, H / 2 - 30

  for i = 1, 4 do
    local r = (30 + i * 22) * math.min(1, p * 1.5)
    love.graphics.setColor(0.2, 0.85, 1.0, (0.3 - i * 0.05) * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)
  end

  love.graphics.setColor(0.2, 0.85, 1.0, 0.9 * alpha)
  love.graphics.circle("fill", cx, cy, 6 + 4 * math.sin(t * 8))

  for i = 1, 16 do
    local ang = (i / 16) * math.pi * 2 + t * 0.6
    local r1 = 90
    local r2 = 100 + 6 * math.sin(t * 6 + i)
    love.graphics.setColor(0.2, 0.85, 1.0, 0.7 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(
      cx + math.cos(ang) * r1, cy + math.sin(ang) * r1,
      cx + math.cos(ang) * r2, cy + math.sin(ang) * r2)
  end

  local th = State.theme
  local title_font = A.font(th.font_title, 34)
  love.graphics.setFont(title_font)
  love.graphics.setColor(0.85, 0.97, 1.0, alpha)
  local title = "Rt:ENHANCER"
  local title_w = title_font:getWidth(title)
  local title_x = (W - title_w) / 2
  local title_y = cy + 116
  love.graphics.print(title, title_x, title_y)

  local dock_font = A.font("assets/fonts/Oxanium-Bold.ttf", 15)
  love.graphics.setFont(dock_font)
  love.graphics.setColor(0.4, 0.88, 1.0, alpha * 0.98)
  love.graphics.print("Dock", title_x + title_w - 34, title_y + 24)

  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.setColor(0.4, 0.75, 0.9, alpha * 0.8)
  love.graphics.printf("U S G   I S H I M U R A   —   D O L P H I N U I",
    0, cy + 160, W, "center")
end

-- ── Phase 3: log lines ──────────────────────────────────────
local LOG_TARGETS = {
  { x = 12,   y = 12,  w = 616, kind = "hline" },
  { x = 12,   y = 90,  w = 616, kind = "hline" },
  { x = 12,   y = 130, w = 616, kind = "hline" },
  { x = 12,   y = 260, w = 616, kind = "hline" },
  { x = 12,   y = 380, w = 616, kind = "hline" },
  { x = 12,   y = 440, w = 616, kind = "hline" },
  { x = 12,   y = 470, w = 616, kind = "hline" },
}

local function draw_phase_logs(t, fade_p)
  local base_y = 60
  local line_h = 16

  for i, line in ipairs(S.log_lines) do
    local target = LOG_TARGETS[i]
      or { x = 12, y = 450, w = 616, kind = "hline" }
    local y_start = base_y + (i - 1) * line_h
    local y = y_start + (target.y - y_start) * fade_p
    local alpha = 1 - fade_p

    if fade_p < 0.55 then
      local text_alpha = alpha * (1 - fade_p / 0.55)
      local text = "> " .. line
      love.graphics.setColor(0.15, 0.85, 0.75, text_alpha)
      love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 10))
      love.graphics.print(text, 30, y)
    end

    if fade_p > 0.35 then
      local line_alpha = math.min(1, (fade_p - 0.35) / 0.65)
      local w = target.w * line_alpha
      local x = target.x + (target.w - w) / 2
      local thickness = 2 + 2 * line_alpha
      love.graphics.setColor(0.15, 0.85, 0.75, 0.85 * line_alpha)
      love.graphics.rectangle("fill", x, y, w, thickness, 1, 1)
      love.graphics.setColor(0.15, 0.85, 0.75, 0.25 * line_alpha)
      love.graphics.rectangle("fill", x, y - 2, w, thickness + 4, 2, 2)
    end
  end
end

-- ── Ghost dashboard ─────────────────────────────────────────
local function draw_ghost_dashboard(alpha)
  if alpha <= 0 then return end

  love.graphics.setColor(0.02, 0.03, 0.05, 0.85 * alpha)
  love.graphics.rectangle("fill", 0, 0, W, H)

  love.graphics.setColor(0.05, 0.07, 0.10, 0.9 * alpha)
  love.graphics.rectangle("fill", 0, 0, W, 52)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.6 * alpha)
  love.graphics.rectangle("fill", 0, 51, W, 1)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.55 * alpha)
  love.graphics.rectangle("fill", 16, 20, 120, 12, 2, 2)

  local tab_w = 92
  for i = 1, 6 do
    love.graphics.setColor(0.10, 0.13, 0.18, 0.85 * alpha)
    love.graphics.rectangle("fill", 16 + (i - 1) * (tab_w + 6), 58,
      tab_w, 22, 3, 3)
  end

  for row = 0, 3 do
    for col = 0, 3 do
      love.graphics.setColor(0.06, 0.09, 0.13, 0.75 * alpha)
      love.graphics.rectangle("fill",
        20 + col * 155, 130 + row * 100, 145, 88, 4, 4)
    end
  end

  love.graphics.setColor(0.05, 0.07, 0.10, 0.9 * alpha)
  love.graphics.rectangle("fill", 0, H - 40, W, 40)
  love.graphics.setColor(0.20, 0.72, 0.98, 0.6 * alpha)
  love.graphics.rectangle("fill", 0, H - 40, W, 1)
end

-- ── Dispatcher ──────────────────────────────────────────────
function S.draw()
  local th = State.theme
  local t = S.t

  love.graphics.clear(0.01, 0.02, 0.03)
  draw_scanlines()

  if t < 0.4 then
    draw_phase_glitch(t / 0.4)
    return
  end

  if t < 1.0 then
    draw_phase_rig(t)
    return
  end

  local fade_p = 0
  if t >= S.dur then
    fade_p = math.min(1, (t - S.dur) / S.fade_dur)
  end

  if fade_p > 0 then
    draw_ghost_dashboard(fade_p)
  end

  if t >= 1.0 then
    draw_phase_logs(t, fade_p)
  end

  if fade_p < 0.4 and t < S.dur + 0.2 then
    local title_alpha = 1 - (fade_p / 0.4)
    love.graphics.setFont(A.font(th.font_title, 20))
    love.graphics.setColor(0.4, 0.88, 1.0, 0.9 * title_alpha)
    love.graphics.printf("Rt:ENHANCER DOCK", 0, 24, W, "center")
  end

  if fade_p < 0.5 then
    local progress = math.min(1, t / S.dur)
    local bar_alpha = 1 - fade_p / 0.5
    love.graphics.setColor(0.2, 0.85, 1.0, 0.15 * bar_alpha)
    love.graphics.rectangle("fill", 40, H - 40, W - 80, 4)
    love.graphics.setColor(0.2, 0.85, 1.0, 0.9 * bar_alpha)
    love.graphics.rectangle("fill", 40, H - 40, (W - 80) * progress, 4)
  end

  if t > 0.4 and t < S.dur + S.fade_dur - 0.2 then
    local alpha = 0.35 + 0.25 * math.sin(t * 4)
    love.graphics.setColor(0.55, 0.70, 0.85, alpha)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.printf("Press any button to skip", 0, H - 20, W, "center")
  end
end

return S