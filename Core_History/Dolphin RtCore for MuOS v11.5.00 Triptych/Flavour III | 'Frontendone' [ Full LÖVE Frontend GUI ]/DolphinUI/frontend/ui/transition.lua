-- ui/transition.lua — screen transitions with callback at midpoint.

local SFX = require("sfx")
local State = require("state")

local T = {
  active = false, t = 0, dur = 0.6,
  style = "fade", cb = nil, switched = false,
}

function T.change(style, cb)
  if T.active then return end
  T.active = true
  T.t = 0
  T.style = style or "fade"
  T.cb = cb
  T.switched = false
  T.dur = 0.55
  if style == "glitch" then SFX.play("menu_flip")
  elseif style == "zoom" then SFX.play("menu_pagescroll")
  elseif style == "slide" then SFX.play("menu_pagescroll")
  else SFX.play("menu_select") end
end

function T.update(dt)
  if not T.active then return end
  T.t = T.t + dt
  if not T.switched and T.t >= T.dur / 2 then
    T.switched = true
    local c = T.cb; T.cb = nil
    if c then c() end
  end
  if T.t >= T.dur then
    T.active = false
    T.t = T.dur
  end
end

function T.draw(w, h)
  if not T.active then return end
  local p = T.t / T.dur
  local th = State.theme

  -- phase goes 0 → 1 → 0
  local phase = p < 0.5 and (p * 2) or (2 - p * 2)

  if T.style == "fade" then
    love.graphics.setColor(0, 0, 0, phase)
    love.graphics.rectangle("fill", 0, 0, w, h)

  elseif T.style == "slide" then
    local offset = phase * w
    love.graphics.setColor(0.02, 0.02, 0.04, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.9)
    love.graphics.rectangle("fill", -offset + w, 0, w, h)
    love.graphics.setColor(0, 0, 0, 0.5 * (1 - phase))
    love.graphics.rectangle("fill", 0, 0, w, h)

  elseif T.style == "glitch" then
    for i = 1, 16 do
      local yy = math.random() * h
      local hh = 2 + math.random() * 12
      local dx = (math.random() * 20 - 10) * phase
      love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.5 * phase)
      love.graphics.rectangle("fill", dx, yy, w, hh)
    end
    love.graphics.setColor(0.05, 0.0, 0.1, 0.9 * phase)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local cx = w * p
    love.graphics.setColor(1, 1, 1, 0.15 * phase)
    love.graphics.rectangle("fill", cx - 2, 0, 4, h)

  elseif T.style == "zoom" then
    -- Expanding ring: the black disc grows to cover the screen, then
    -- shrinks back. No fullscreen rectangle on top — that killed the
    -- effect in the previous version.
    local r = phase * (h * 0.9)
    love.graphics.setColor(0, 0, 0, 0.92 * phase)
    love.graphics.circle("fill", w/2, h/2, r)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.7 * phase)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", w/2, h/2, r)
    love.graphics.setLineWidth(1)
    -- Background outside the disc: also dark to avoid a visible flash
    love.graphics.setColor(0, 0, 0, 0.92 * phase)
    love.graphics.rectangle("fill", 0, 0, w, h)
    -- Redraw the disc on top so it reads as "circle, not full black"
    love.graphics.setColor(0, 0, 0, 0.02)
    love.graphics.circle("fill", w/2, h/2, r)

  elseif T.style == "wipe" then
    local diag = w + h
    local d = phase * diag
    love.graphics.setColor(0.02, 0.02, 0.04, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.9)
    love.graphics.polygon("fill",
      -10, h + 10,
      -10 + d, h + 10,
      -10 + d - h, -10,
      -10 - h, -10)
    love.graphics.setColor(0, 0, 0, 0.4 * (1 - phase))
    love.graphics.rectangle("fill", 0, 0, w, h)

  elseif T.style == "particles" then
    love.graphics.setColor(0, 0, 0, 0.85 * phase)
    love.graphics.rectangle("fill", 0, 0, w, h)
    -- Local RNG: don't touch global math.random state
    local seed = 42
    local function lrand()
      seed = (seed * 1103515245 + 12345) % 2147483648
      return seed / 2147483648
    end
    for i = 1, 60 do
      local ang = (i / 60) * math.pi * 2
      local r = (1 - phase) * h * 0.8 + 20
      local px = w/2 + math.cos(ang) * r
      local py = h/2 + math.sin(ang) * r
      love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.8 * phase)
      love.graphics.circle("fill", px, py, 2 + lrand() * 2)
    end
  end
end

function T.busy() return T.active end

return T