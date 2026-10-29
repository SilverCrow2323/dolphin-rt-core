-- screens/boot.lua — cyberpunk boot animation.
--
-- v0.8.0 — random splash
--   * The splash image is now picked at random from a pool
--     (splash_gc.png, splash_wii.png, splash_rtcore.png), so every
--     launch shows a different visual INDEPENDENT of the active
--     theme. Previously the splash came from `State.theme.boot_splash`
--     and therefore always matched the theme the user had last set,
--     which killed the surprise.
--   * The boot SOUND still follows the active theme (gamecube_startup
--     vs wii_startup) — only the visual is randomised.
--   * Variant (power_on / radial / stream / glitch) remains random.

local A     = require("assets")
local SFX   = require("sfx")
local State = require("state")
local D     = require("ui.draw")
local Store = require("settings_store")
local IM    = require("input_map")

local S = {
  t              = 0,
  dur            = 3.2,
  variant        = nil,
  splash_path    = nil,
  boot_sound     = nil,
  played_sfx     = false,
  skippable      = false,
  _reveal_done   = false,
  _finished      = false,
}

local W, H = 640, 480
local SKIP_AFTER = 0.5

local VARIANTS = {
  { name = "power_on", dur = 3.2 },
  { name = "radial",   dur = 3.2 },
  { name = "stream",   dur = 3.0 },
  { name = "glitch",   dur = 3.0 },
}

-- Splash pool: picked at random on every enter(). The path is
-- independent from State.theme: the user sees a different intro each
-- boot regardless of the currently selected theme.
local SPLASH_POOL = {
  "assets/images/boot/splash_gc.png",
  "assets/images/boot/splash_wii.png",
  "assets/images/boot/splash_rtcore.png",
}

local function pick_variant()
  return VARIANTS[math.random(1, #VARIANTS)]
end

local function pick_splash()
  return SPLASH_POOL[math.random(1, #SPLASH_POOL)]
end

local function enter_menu()
  if State.go_root then
    State.go_root("menu")
    return
  end
  State.history = {}
  State.go("menu")
end

function S.enter()
  S.t            = 0
  S.played_sfx   = false
  S.skippable    = false
  S._reveal_done = false
  S._finished    = false

  S.variant     = pick_variant()
  S.splash_path = pick_splash()

  -- Sound still follows the active theme (coherence with the theme
  -- the user is currently in). Only the visual is randomised.
  S.boot_sound = (State.theme and State.theme.boot_sound)
                 or "gamecube_startup"

  local cfg = Store.data()
  if cfg.advanced and cfg.advanced.boot_animation == false then
    S.dur = 0.1
  else
    S.dur = S.variant.dur
  end

  State.raw_input = true
end

function S.leave()
  State.raw_input = false
end

function S.update(dt)
  if S._finished then return end
  S.t = S.t + dt

  if S.t > SKIP_AFTER then S.skippable = true end

  if not S.played_sfx and S.t > 0.05 then
    S.played_sfx = true
    if S.boot_sound then pcall(SFX.play, S.boot_sound) end
  end

  if not S._reveal_done and S.t > S.dur * 0.55 then
    S._reveal_done = true
  end

  if S.t >= S.dur then
    S._finished = true
    enter_menu()
  end
end

function S._skip()
  if S._finished then return end
  if not S.skippable then return end
  S._finished = true
  SFX.play("menu_select")
  enter_menu()
end

function S.pad(_)  S._skip() end
function S.hat(_)  S._skip() end
function S.key(_)  S._skip() end

-- ── Splash overlay (uses the random path picked at enter) ────
local function draw_theme_splash(alpha)
  if alpha <= 0 then return end
  if not S.splash_path then return end
  local img = A.image(S.splash_path)
  if not img then return end

  local iw, ih = img:getWidth(), img:getHeight()
  local scale  = math.max(W / iw, H / ih)
  local dw, dh = iw * scale, ih * scale
  local dx, dy = (W - dw) / 2, (H - dh) / 2

  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(img, dx, dy, 0, scale, scale)

  love.graphics.setColor(0, 0, 0, 0.55 * alpha)
  love.graphics.rectangle("fill", 0, 0, W, H)
end

local function draw_text_block(alpha)
  local th = State.theme

  love.graphics.setFont(A.font(th.font_title, 34))
  love.graphics.setColor(th.text[1], th.text[2], th.text[3], alpha)
  love.graphics.printf("DOLPHIN RT:CORE", 0, H / 2 + 70, W, "center")

  local dw = 260
  local dx = (W - dw) / 2
  local dy = H / 2 + 118
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], alpha * 0.7)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(dx, dy, dx + dw, dy)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], alpha * 0.95)
  love.graphics.printf("F R O N T E N D O N E", 0, dy + 8, W, "center")

  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.setColor(th.text_dim[1], th.text_dim[2], th.text_dim[3],
    alpha * 0.6)
  love.graphics.printf("SPDW FACTORY LAB", 0, H - 40, W, "center")
end

-- ── Variant: POWER-ON ───────────────────────────────────────
local function draw_power_on()
  local th = State.theme
  local t = S.t

  if t < 0.5 then
    local p = t / 0.5
    local lh = p * H
    love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
    love.graphics.rectangle("fill", 0, H / 2 - lh / 2, W, lh)
    D.scanlines(W, H, 0.3)
    return
  end

  if t < 1.1 then
    local p = (t - 0.5) / 0.6
    for i = 1, 80 do
      local yy = math.random() * H
      local a  = 0.05 + math.random() * 0.15
      love.graphics.setColor(0.8, 0.9, 1.0, a * (1 - p))
      love.graphics.rectangle("fill", 0, yy, W, 1 + math.random() * 2)
    end
    love.graphics.setColor(0.1, 0.15, 0.25, 0.3 * (1 - p))
    love.graphics.rectangle("fill", 0, 0, W, H)
    D.scanlines(W, H, 0.15)
    return
  end

  love.graphics.setColor(0.02, 0.02, 0.04)
  love.graphics.rectangle("fill", 0, 0, W, H)

  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.04)
  for x = 0, W, 32 do love.graphics.line(x, 0, x, H) end
  for y = 0, H, 32 do love.graphics.line(0, y, W, y) end

  local reveal = math.min(1, math.max(0, (t - 1.1) / 1.2))
  local cx, cy = W / 2, H / 2 - 60

  draw_theme_splash(reveal * 0.85)
  D.glow(cx, cy, 100 * (0.8 + 0.2 * reveal), th.accent, reveal)

  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], reveal)
  love.graphics.setLineWidth(1.5)
  for i = 1, 12 do
    local ang = (i / 12) * math.pi * 2
    love.graphics.line(
      cx + math.cos(ang) * 80, cy + math.sin(ang) * 80,
      cx + math.cos(ang) * 84, cy + math.sin(ang) * 84)
  end
  love.graphics.setLineWidth(1)

  if reveal > 0.25 then
    local img = A.image(th.boot_icon)
    if img then
      local size = 110
      love.graphics.setColor(1, 1, 1, reveal)
      love.graphics.draw(img,
        cx - size / 2, cy - size / 2, 0,
        size / img:getWidth(), size / img:getHeight())
    end
  end

  draw_text_block(reveal)
  D.scanlines(W, H, 0.08)
  D.vignette(W, H, 0.7)
end

-- ── Variant: GLITCH ─────────────────────────────────────────
local function draw_glitch()
  local th = State.theme
  local t = S.t

  love.graphics.clear(0.02, 0.02, 0.04)

  local intensity = (t < 1.4) and 1.0 or (1 - math.min(1, (t - 1.4) / 1.4))
  for i = 1, 14 do
    local y  = math.random() * H
    local h  = 1 + math.random() * 6
    local dx = (math.random() - 0.5) * 40 * intensity
    local col = { th.accent[1], th.accent[2], th.accent[3] }
    if math.random() < 0.15 then col = { 0.9, 0.2, 0.4 } end
    love.graphics.setColor(col[1], col[2], col[3], 0.55 * intensity)
    love.graphics.rectangle("fill", dx, y, W, h)
  end

  for i = 1, 4 do
    local y = math.random() * H
    love.graphics.setColor(1, 0.2, 0.4, 0.15 * intensity)
    love.graphics.rectangle("fill", -3, y, W, 2)
    love.graphics.setColor(0.2, 0.9, 1, 0.15 * intensity)
    love.graphics.rectangle("fill", 3, y, W, 2)
  end

  local reveal = math.min(1, math.max(0, (t - 1.4) / 1.2))
  draw_theme_splash(reveal * 0.85)
  draw_text_block(reveal)

  D.scanlines(W, H, 0.12 + 0.15 * intensity)
  D.vignette(W, H, 0.75)
end

-- ── Variant: RADIAL ─────────────────────────────────────────
local function draw_radial()
  local th = State.theme
  local t = S.t

  love.graphics.clear(0.01, 0.02, 0.03)

  love.graphics.setColor(0.2, 0.85, 1.0, 0.05)
  for y = 0, H, 3 do love.graphics.line(0, y, W, y) end

  local cx, cy = W / 2, H / 2 - 50
  local p = math.min(1, t / (S.dur * 0.7))

  for i = 1, 5 do
    local r = (30 + i * 24) * p
    love.graphics.setColor(0.2, 0.85, 1.0, (0.35 - i * 0.05) * p)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)
  end

  love.graphics.setColor(0.2, 0.85, 1.0, 0.9 * p)
  love.graphics.circle("fill", cx, cy, 6 + 4 * math.sin(t * 8))

  for i = 1, 16 do
    local ang = (i / 16) * math.pi * 2 + t * 0.6
    local r1 = 100
    local r2 = 108 + 6 * math.sin(t * 6 + i)
    love.graphics.setColor(0.2, 0.85, 1.0, 0.7 * p)
    love.graphics.setLineWidth(2)
    love.graphics.line(
      cx + math.cos(ang) * r1, cy + math.sin(ang) * r1,
      cx + math.cos(ang) * r2, cy + math.sin(ang) * r2)
  end

  local reveal = math.min(1, math.max(0, (t - S.dur * 0.5) / (S.dur * 0.4)))
  draw_theme_splash(reveal * 0.85)
  draw_text_block(reveal)
  D.vignette(W, H, 0.75)
end

-- ── Variant: STREAM ─────────────────────────────────────────
local stream_state = nil
local function stream_init()
  if stream_state then return end
  stream_state = {}
  local cols = math.floor(W / 14) + 1
  for i = 1, cols do
    stream_state[i] = {
      x     = (i - 1) * 14,
      head  = -math.random() * H,
      speed = 120 + math.random() * 180,
      len   = 8 + math.random(0, 10),
    }
  end
end

local function draw_stream()
  local th = State.theme
  stream_init()
  local t = S.t
  local dt = love.timer.getDelta()

  love.graphics.clear(0.01, 0.02, 0.02)

  local font = A.font("assets/fonts/Oxanium-Regular.ttf", 11)
  love.graphics.setFont(font)

  for _, c in ipairs(stream_state) do
    c.head = c.head + c.speed * dt
    if c.head - c.len * 14 > H then c.head = -math.random() * 100 end
    for i = 0, c.len - 1 do
      local y = c.head - i * 14
      if y >= 0 and y <= H then
        local alpha = (1 - i / c.len) * 0.9
        if i == 0 then
          love.graphics.setColor(0.85, 1.0, 0.85, alpha)
        else
          love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3],
            alpha * 0.6)
        end
        local ch = string.char(33 + math.random(0, 93))
        love.graphics.print(ch, c.x, y)
      end
    end
  end

  local reveal = math.min(1, math.max(0, (t - S.dur * 0.45) / (S.dur * 0.4)))
  draw_theme_splash(reveal * 0.75)

  if reveal > 0 then
    love.graphics.setColor(0, 0, 0, 0.55 * reveal)
    love.graphics.rectangle("fill", 0, H / 2 + 50, W, 190)
  end
  draw_text_block(reveal)
  D.vignette(W, H, 0.8)
end

function S.draw()
  if not S.variant then draw_power_on(); return end
  local name = S.variant.name
  if     name == "power_on" then draw_power_on()
  elseif name == "glitch"   then draw_glitch()
  elseif name == "radial"   then draw_radial()
  elseif name == "stream"   then draw_stream() end

  if S.skippable and not S._finished then
    local th = State.theme
    local alpha = 0.35 + 0.25 * math.sin(S.t * 4)
    love.graphics.setColor(th.text_dim[1], th.text_dim[2], th.text_dim[3],
      alpha)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.printf("Press any button to skip", 0, H - 20, W, "center")
  end
end

return S