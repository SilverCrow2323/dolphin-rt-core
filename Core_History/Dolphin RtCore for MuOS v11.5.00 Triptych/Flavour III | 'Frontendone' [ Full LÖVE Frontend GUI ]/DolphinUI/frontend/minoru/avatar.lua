-- frontend/minoru/avatar.lua
-- Minoru⁶ canonical renderer.
--
-- Composes:
--   * cel-shaded sphere body (2-tone: highlight band + shadow band)
--   * rigged arms with 5 joints per side (shoulder/elbow/wrist/d0/d1)
--     and jointed two-digit hands
--   * simple 2.5D depth layering: back arms → sphere → front arms
--   * emotional visor (visor.lua) with animated oscilloscope line
--   * irregular "hand-drawn" outlines that boil at ~8 Hz
--
-- Public API is unchanged from the previous version so no external
-- screen needs editing:
--   A = Avatar.new()
--   A:set_state("idle"|"talk"|"think"|"work"|"walk")
--   A:set_emotion("standard"|"sarcastic"|"angry"|"apprehension"|"paradox"|"perplexed")
--   A:set_facing("l"|"r")
--   A:walk_to(x, speed)
--   A:update(dt)
--   A:draw(x, y, size, tint)

local Shading = require("minoru.shading")
local Rig     = require("minoru.rig")
local Visor   = require("minoru.visor")

local Avatar = {}
Avatar.__index = Avatar

-- ── Palette ──────────────────────────────────────────────────
local CEL = {
  body_fill      = {0.235, 0.255, 0.285},
  body_high      = {0.345, 0.365, 0.395},
  body_shadow    = {0.115, 0.130, 0.145},
  body_rim       = {0.42, 0.44, 0.48},
  outline        = {0.02, 0.02, 0.03},
  limb_fill      = {0.315, 0.335, 0.375},
  limb_high      = {0.455, 0.475, 0.510},
  limb_shadow    = {0.135, 0.150, 0.170},
  joint_fill     = {0.250, 0.270, 0.310},
  joint_high     = {0.420, 0.440, 0.480},
  joint_shadow   = {0.110, 0.120, 0.140},
  hand_fill      = {0.290, 0.310, 0.350},
  hand_high      = {0.430, 0.450, 0.490},
  hand_shadow    = {0.120, 0.130, 0.150},
}

-- ── Constructor ──────────────────────────────────────────────
function Avatar.new()
  local self = setmetatable({}, Avatar)
  self.state      = "idle"
  self.emotion    = "standard"
  self.state_t    = 0
  self.emotion_t  = 0
  self.facing     = 1
  self.x          = 0
  self.target_x   = nil
  self.walk_speed = 80
  self.bob_phase  = 0
  self.rig        = Rig.new()
  return self
end

-- ── Public API ───────────────────────────────────────────────
local STATE_TO_POSE = {
  idle  = "idle",
  talk  = "talk",
  think = "think",
  work  = "work",
  walk  = "idle",   -- legs animate the walking; arms stay neutral
}

function Avatar:set_state(name)
  if self.state == name then return end
  self.state   = name
  self.state_t = 0
  local pose = STATE_TO_POSE[name] or "idle"
  self.rig:set_pose(pose)
end

function Avatar:set_emotion(name)
  if self.emotion == name then return end
  self.emotion   = name
  self.emotion_t = 0
end

function Avatar:set_facing(dir)
  if     dir == "l" then self.facing = -1
  elseif dir == "r" then self.facing =  1
  end
end

function Avatar:walk_to(x, speed)
  self.target_x   = x
  self.walk_speed = speed or self.walk_speed
  if x < self.x - 1 then self.facing = -1
  elseif x > self.x + 1 then self.facing = 1 end
  self:set_state("walk")
end

function Avatar:is_walking()
  return self.state == "walk" and self.target_x ~= nil
end

-- Direct rig access for external animation systems.
function Avatar:rig_ref()
  return self.rig
end

-- ── Update ───────────────────────────────────────────────────
function Avatar:update(dt)
  self.state_t   = self.state_t   + dt
  self.emotion_t = self.emotion_t + dt
  self.bob_phase = self.bob_phase + dt

  Shading.update(dt)
  self.rig:update(dt)

  if self.state == "walk" and self.target_x then
    local dx = self.target_x - self.x
    local step = self.walk_speed * dt
    if math.abs(dx) <= step then
      self.x        = self.target_x
      self.target_x = nil
      self:set_state("idle")
    else
      self.x = self.x + (dx > 0 and step or -step)
    end
  end
end

-- ── Draw ─────────────────────────────────────────────────────
function Avatar:draw(x, y, size, _tint)
  -- Optional sprite override path (unchanged from before).
  local MAssets = require("minoru.assets")
  local sprite_path = MAssets.body[self.state]
  local A = require("assets")
  local sprite = sprite_path and A.image(sprite_path)
  if sprite then
    local iw, ih = sprite:getWidth(), sprite:getHeight()
    local sc = math.min(size / iw, size / ih)
    local dw, dh = iw * sc, ih * sc
    local bob = math.sin(self.bob_phase * 2.0) * 2.0
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprite,
      x + (size - dw) / 2, y + (size - dh) / 2 + bob,
      0, sc, sc)
    return
  end

  -- ── Procedural path ──────────────────────────────────────
  local sphere_r = size * 0.36
  local cx       = x + size / 2
  local cy       = y + size * 0.36
  local bob      = 0
  if     self.state == "talk"  then
    bob = math.sin(self.bob_phase * 4.5) * 3.0
  elseif self.state == "walk"  then
    bob = math.sin(self.bob_phase * 6.0) * 1.4
  elseif self.state == "think" then
    bob = math.sin(self.bob_phase * 1.8) * 1.6
  elseif self.state == "work"  then
    bob = math.sin(self.bob_phase * 1.2) * 0.8
  else
    bob = math.sin(self.bob_phase * 2.0) * 2.0
  end
  cy = cy + bob

  -- Depth sorting: back arm first, then body, then front arm.
  local Ldepth = self.rig:depth_of("L")
  local Rdepth = self.rig:depth_of("R")

  local draw_L_first = Ldepth < Rdepth

  local layer_arm = {
    fill       = CEL.limb_fill,
    highlight  = CEL.limb_high,
    shadow     = CEL.limb_shadow,
    stroke     = CEL.outline,
    stroke_w   = math.max(2, sphere_r * 0.075),
  }

  -- Ground shadow beneath everything
  self:_draw_ground_shadow(cx, cy + sphere_r * 1.45, sphere_r)

  -- Draw back arm
  if draw_L_first then
    self.rig:draw_arm("L", cx, cy, sphere_r, layer_arm)
  else
    self.rig:draw_arm("R", cx, cy, sphere_r, layer_arm)
  end

  -- Body (sphere + visor)
  self:_draw_sphere(cx, cy, sphere_r)
  Visor.draw(cx, cy + sphere_r * 0.05, sphere_r * 0.66,
    self.emotion, self.emotion_t)

  -- Draw front arm (on top of the body)
  if draw_L_first then
    self.rig:draw_arm("R", cx, cy, sphere_r, layer_arm)
  else
    self.rig:draw_arm("L", cx, cy, sphere_r, layer_arm)
  end
end

-- ── Sphere body with cel-shading ─────────────────────────────
function Avatar:_draw_sphere(cx, cy, r)
  local stroke_w = math.max(2.5, r * 0.075)

  -- ── Base fill (irregular outline, cel-flat colour) ───────
  local pts = Shading.irregular_circle_pts(cx, cy, r, 500, 1.6, 32)
  love.graphics.setColor(CEL.body_fill)
  love.graphics.polygon("fill", pts)

  -- ── Cel-shaded shading bands (clipped to the circle) ─────
  -- Bottom shadow band — flat, two-tone effect.
  Shading.clipped_band(cx, cy, r,
    cy + r * 0.28, r * 1.5, CEL.body_shadow)

  -- Top-left highlight band.
  Shading.clipped_arc_highlight(cx, cy, r, CEL.body_high)

  -- ── Outer rim light (right edge) ─────────────────────────
  love.graphics.setColor(CEL.body_rim[1], CEL.body_rim[2],
    CEL.body_rim[3], 0.35)
  love.graphics.setLineWidth(math.max(1.2, r * 0.05))
  love.graphics.arc("line", "open", cx, cy, r * 0.94,
    math.rad(-40), math.rad(50))
  love.graphics.setLineWidth(1)

  -- ── Outline (irregular, thick, black) ────────────────────
  local outline_pts = Shading.irregular_circle_pts(cx, cy, r, 501, 1.8, 32)
  love.graphics.setColor(CEL.outline)
  love.graphics.setLineWidth(stroke_w)
  love.graphics.polygon("line", outline_pts)
  love.graphics.setLineWidth(1)
end

-- ── Ground shadow ────────────────────────────────────────────
function Avatar:_draw_ground_shadow(cx, cy, r)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.ellipse("fill", cx, cy, r * 0.9, r * 0.14)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.ellipse("fill", cx, cy, r * 1.15, r * 0.18)
end

return Avatar