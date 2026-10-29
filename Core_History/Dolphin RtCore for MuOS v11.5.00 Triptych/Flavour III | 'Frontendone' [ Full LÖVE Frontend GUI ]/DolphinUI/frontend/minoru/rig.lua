-- frontend/minoru/rig.lua
-- Joint-based skeleton for Minoru's arms, hands and legs.
--
-- Every limb is a chain of joints. Each joint has:
--   * a local angle (relative to its parent)
--   * a target angle (interpolated toward, ~8 Hz "settle" rate)
--
-- Segment lengths are stored as multiples of the sphere radius,
-- so the rig scales with the avatar.
--
-- Bones are drawn with irregular_segment() from shading.lua, so
-- limbs share the cel-shaded outline look.
--
-- Depth: each arm has a `depth` value 0..1 (0 = behind the sphere,
-- 1 = in front). The avatar renders back arms first, sphere, then
-- front arms. Simple 2.5D layering.

local Shading = require("minoru.shading")

local Rig = {}
Rig.__index = Rig

-- ── Pose catalogue ───────────────────────────────────────────
-- Each pose is a set of target angles per joint. Values in degrees.
local POSES = {
  idle = {
    L_shoulder =  65, L_elbow =  40, L_wrist =  10,
    R_shoulder = -65, R_elbow =  40, R_wrist =  10,
    L_d0 = 12, L_d1 = -8,
    R_d0 = 12, R_d1 = -8,
    L_depth = 0.35, R_depth = 0.35,
  },
  talk = {
    L_shoulder =  70, L_elbow =  55, L_wrist =  15,
    R_shoulder = -80, R_elbow =  70, R_wrist =  20,
    L_d0 = 25, L_d1 = -10,
    R_d0 = -15, R_d1 = 20,
    L_depth = 0.30, R_depth = 0.85,
  },
  think = {
    L_shoulder = 100, L_elbow =  90, L_wrist =  30,
    R_shoulder = -60, R_elbow =  30, R_wrist =  10,
    L_d0 = 15, L_d1 = -5,
    R_d0 = 15, R_d1 = -5,
    L_depth = 0.45, R_depth = 0.35,
  },
  work = {
    L_shoulder =  50, L_elbow =  60, L_wrist =  30,
    R_shoulder = -50, R_elbow =  60, R_wrist =  30,
    L_d0 = 30, L_d1 = -25,
    R_d0 = 30, R_d1 = -25,
    L_depth = 0.80, R_depth = 0.85,
  },
  wave = {
    L_shoulder =  30, L_elbow =  20, L_wrist =   5,
    R_shoulder = -110, R_elbow =  50, R_wrist =  25,
    L_d0 = 15, L_d1 = -5,
    R_d0 = -25, R_d1 = 35,
    L_depth = 0.35, R_depth = 0.95,
  },
  point = {
    L_shoulder =  70, L_elbow =  40, L_wrist =  10,
    R_shoulder = -85, R_elbow =  15, R_wrist =   5,
    L_d0 = 15, L_d1 = -5,
    R_d0 =  5, R_d1 =  5,
    L_depth = 0.35, R_depth = 0.85,
  },
}

-- ── Constructor ──────────────────────────────────────────────
function Rig.new()
  local self = setmetatable({}, Rig)
  self.pose       = "idle"
  self.pose_t     = 0

  -- Segment lengths as multiples of sphere radius
  self.upper_len = 0.75
  self.fore_len  = 0.70
  self.digit_len = 0.42

  -- Joint state: current angle + target angle (both degrees)
  self.joints = {}
  for _, side in ipairs({ "L", "R" }) do
    self.joints[side] = {
      shoulder = { a = 0, t = 0 },
      elbow    = { a = 0, t = 0 },
      wrist    = { a = 0, t = 0 },
      d0       = { a = 0, t = 0 },
      d1       = { a = 0, t = 0 },
      depth    = 0.35,
    }
  end

  -- Idle sway oscillator
  self._sway_t = 0
  self._sway_amp = 3.5

  self:set_pose("idle", true)
  return self
end

-- ── Pose switching ───────────────────────────────────────────
function Rig:set_pose(name, instant)
  local p = POSES[name]
  if not p then return end
  self.pose = name
  self.pose_t = 0
  for _, side in ipairs({ "L", "R" }) do
    local j = self.joints[side]
    j.shoulder.t = p[side .. "_shoulder"] or 0
    j.elbow.t    = p[side .. "_elbow"]    or 0
    j.wrist.t    = p[side .. "_wrist"]    or 0
    j.d0.t       = p[side .. "_d0"]       or 0
    j.d1.t       = p[side .. "_d1"]       or 0
    j.depth      = p[side .. "_depth"]    or 0.35
    if instant then
      j.shoulder.a = j.shoulder.t
      j.elbow.a    = j.elbow.t
      j.wrist.a    = j.wrist.t
      j.d0.a       = j.d0.t
      j.d1.a       = j.d1.t
    end
  end
end

-- ── Update ───────────────────────────────────────────────────
function Rig:update(dt)
  self.pose_t = self.pose_t + dt
  self._sway_t = self._sway_t + dt

  -- Lerp all joints toward their targets.
  local k = math.min(1, dt * 6)
  for _, side in ipairs({ "L", "R" }) do
    local j = self.joints[side]
    for _, joint in ipairs({ "shoulder", "elbow", "wrist", "d0", "d1" }) do
      local jj = j[joint]
      jj.a = jj.a + (jj.t - jj.a) * k
    end
  end
end

-- ── Pose-specific modulations ────────────────────────────────
-- Small procedural overlays added at draw time: a talk gesture
-- adds a sine to one wrist, "work" makes digits tap, etc.
local function modulate(self, side)
  local j = self.joints[side]
  local out = {
    shoulder = j.shoulder.a,
    elbow    = j.elbow.a,
    wrist    = j.wrist.a,
    d0       = j.d0.a,
    d1       = j.d1.a,
  }

  local t = self.pose_t
  if self.pose == "talk" then
    -- Right arm gestures while talking.
    if side == "R" then
      out.shoulder = out.shoulder + math.sin(t * 4) * 5
      out.elbow    = out.elbow    + math.sin(t * 3.5) * 8
      out.wrist    = out.wrist    + math.sin(t * 6) * 6
    end
  elseif self.pose == "think" then
    if side == "L" then
      out.elbow = out.elbow + math.sin(t * 1.8) * 3
    end
  elseif self.pose == "work" then
    if side == "L" or side == "R" then
      local tap = math.abs(math.sin(t * 8)) * 12
      out.d0 = out.d0 - tap
      out.d1 = out.d1 + tap
    end
  elseif self.pose == "wave" then
    if side == "R" then
      out.wrist = out.wrist + math.sin(t * 8) * 25
    end
  elseif self.pose == "idle" then
    out.shoulder = out.shoulder + math.sin(self._sway_t * 1.4 +
      (side == "L" and 0 or math.pi)) * self._sway_amp
  end

  return out
end

-- ── World-space joint positions ─────────────────────────────
-- Returns a table { shoulder={x,y}, elbow=…, wrist=…, tip={x,y},
-- d0_end=…, d1_end=… } in world coordinates, given the sphere's
-- world position and radius.
function Rig:compute(side, sphere_cx, sphere_cy, r)
  local m = modulate(self, side)
  local sign = (side == "L") and -1 or 1

  -- Shoulder anchor on the sphere's equator.
  local sh_x = sphere_cx + sign * (r * 0.98)
  local sh_y = sphere_cy + r * 0.10

  -- Rotate outward, then down.
  -- We treat 0° as "pointing outward horizontally" and add the
  -- joint angles on top.
  local base_angle = (side == "L") and math.pi or 0
  if side == "R" then base_angle = 0 end

  local function step(x, y, angle_deg, len)
    local a = angle_deg * math.pi / 180 + base_angle
    return x + math.cos(a) * len, y + math.sin(a) * len, a
  end

  local upper_len = self.upper_len * r
  local fore_len  = self.fore_len  * r
  local digit_len = self.digit_len * r

  -- Elbow: from shoulder, angle = base + shoulder
  local ex, ey, ea = step(sh_x, sh_y, m.shoulder, upper_len)
  -- Wrist: from elbow, angle = base + elbow
  local wx, wy, wa = step(ex, ey, m.elbow, fore_len)

  -- Hand tip (small extension past the wrist).
  local hx, hy = step(wx, wy, m.wrist, r * 0.18)

  -- Two digits from the hand tip.
  local d0x, d0y = step(hx, hy, m.wrist + m.d0, digit_len)
  local d1x, d1y = step(hx, hy, m.wrist + m.d1, digit_len)

  return {
    shoulder = { x = sh_x, y = sh_y },
    elbow    = { x = ex,   y = ey   },
    wrist    = { x = wx,   y = wy   },
    tip      = { x = hx,   y = hy   },
    d0_end   = { x = d0x,  y = d0y  },
    d1_end   = { x = d1x,  y = d1y  },
  }
end

-- ── Drawing ──────────────────────────────────────────────────
-- Cel-shaded limb segments. Each bone is drawn as an irregular
-- segment with a top highlight and a bottom shadow line.
--
-- `layer` = { fill, highlight, shadow, stroke, stroke_w }
local function draw_limb(x1, y1, x2, y2, thickness, layer, seed)
  -- Base fill
  Shading.irregular_segment(x1, y1, x2, y2, thickness,
    layer.fill, layer.stroke, layer.stroke_w, seed)

  -- Highlight on the top half (thin parallel line offset upward)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len > 0.01 then
    local nx, ny = -dy / len, dx / len
    local off = -thickness * 0.22
    love.graphics.setColor(layer.highlight)
    love.graphics.setLineWidth(math.max(1, thickness * 0.28))
    love.graphics.line(
      x1 + nx * off, y1 + ny * off,
      x2 + nx * off, y2 + ny * off)
    -- Shadow on the bottom half
    love.graphics.setColor(layer.shadow)
    love.graphics.setLineWidth(math.max(1, thickness * 0.28))
    love.graphics.line(
      x1 - nx * off, y1 - ny * off,
      x2 - nx * off, y2 - ny * off)
    love.graphics.setLineWidth(1)
  end
end

-- Joint disc (visible at elbow, wrist). A small cel-shaded ball.
local function draw_joint(x, y, r, layer, seed)
  Shading.irregular_circle(x, y, r,
    layer.fill, layer.stroke, layer.stroke_w, seed, 0.7, 16)
  -- Top highlight arc
  love.graphics.setColor(layer.highlight)
  love.graphics.arc("fill", "pie",
    x - r * 0.20, y - r * 0.20, r * 0.85,
    math.rad(180), math.rad(320))
  -- Bottom shadow
  love.graphics.setColor(layer.shadow)
  love.graphics.arc("fill", "pie",
    x + r * 0.15, y + r * 0.15, r * 0.85,
    math.rad(0), math.rad(60))
end

function Rig:draw_arm(side, sphere_cx, sphere_cy, r, layer)
  local pts = self:compute(side, sphere_cx, sphere_cy, r)
  local base_seed = (side == "L") and 101 or 202

  local limb_thick = r * 0.155

  -- Upper arm
  draw_limb(pts.shoulder.x, pts.shoulder.y,
            pts.elbow.x,    pts.elbow.y,
            limb_thick, layer, base_seed + 1)

  -- Forearm (slightly thinner)
  draw_limb(pts.elbow.x, pts.elbow.y,
            pts.wrist.x, pts.wrist.y,
            limb_thick * 0.85, layer, base_seed + 2)

  -- Hand: palm as a small irregular disc
  draw_joint(pts.tip.x, pts.tip.y, r * 0.16, layer, base_seed + 3)

  -- Digits
  local digit_thick = r * 0.075
  draw_limb(pts.tip.x, pts.tip.y, pts.d0_end.x, pts.d0_end.y,
            digit_thick, layer, base_seed + 4)
  draw_limb(pts.tip.x, pts.tip.y, pts.d1_end.x, pts.d1_end.y,
            digit_thick, layer, base_seed + 5)

  -- Small rounded tips on the digits
  Shading.irregular_circle(pts.d0_end.x, pts.d0_end.y,
    digit_thick * 0.55, layer.fill, layer.stroke, layer.stroke_w,
    base_seed + 6, 0.4, 8)
  Shading.irregular_circle(pts.d1_end.x, pts.d1_end.y,
    digit_thick * 0.55, layer.fill, layer.stroke, layer.stroke_w,
    base_seed + 7, 0.4, 8)

  -- Elbow and wrist joints
  draw_joint(pts.elbow.x, pts.elbow.y, limb_thick * 0.60,
             layer, base_seed + 8)
  draw_joint(pts.wrist.x, pts.wrist.y, limb_thick * 0.50,
             layer, base_seed + 9)
end

-- Convenience for the avatar: get the depth of a side.
function Rig:depth_of(side)
  return self.joints[side].depth or 0.35
end

-- Query list of joints for external animation systems.
function Rig:joints_of(side)
  return self.joints[side]
end

return Rig