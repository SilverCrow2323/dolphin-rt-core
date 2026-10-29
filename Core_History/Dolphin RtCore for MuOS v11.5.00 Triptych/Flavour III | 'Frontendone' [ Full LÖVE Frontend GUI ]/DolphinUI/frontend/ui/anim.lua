-- frontend/ui/anim.lua — easing + tween tracker
local A = {}

A.ease = {
  linear    = function(t) return t end,
  in_quad   = function(t) return t * t end,
  out_quad  = function(t) return 1 - (1 - t) * (1 - t) end,
  in_out    = function(t) return t < 0.5 and 2*t*t or 1 - (-2*t+2)^2 / 2 end,
  out_cubic = function(t) return 1 - (1 - t)^3 end,
  in_cubic  = function(t) return t^3 end,
  out_back  = function(t)
    local c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
  end,
  out_elastic = function(t)
    if t == 0 or t == 1 then return t end
    local c4 = (2 * math.pi) / 3
    return 2^(-10*t) * math.sin((t*10 - 0.75) * c4) + 1
  end,
}

local Anim = {}
Anim.__index = Anim
function A.new() return setmetatable({ _tweens = {} }, Anim) end
function Anim:tween(key, from, to, dur, ease)
  self._tweens[key] = { t = 0, dur = dur, from = from, to = to, ease = ease or A.ease.out_cubic }
end
function Anim:update(dt)
  for _, tw in pairs(self._tweens) do tw.t = math.min(tw.dur, tw.t + dt) end
end
function Anim:get(key, default)
  local tw = self._tweens[key]
  if not tw then return default end
  local p = tw.t / tw.dur
  return tw.from + (tw.to - tw.from) * tw.ease(p)
end
function Anim:done(key)
  local tw = self._tweens[key]
  return tw and tw.t >= tw.dur
end

return A
