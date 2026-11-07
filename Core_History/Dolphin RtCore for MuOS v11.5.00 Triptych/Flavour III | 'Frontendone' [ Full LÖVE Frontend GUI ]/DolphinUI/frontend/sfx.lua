-- frontend/sfx.lua — sound helper
--
-- v0.4.2 — REWORK
--   * The old cache poisoned itself: a single failed newSource() at
--     preload time stored `false` permanently. A sound that failed once
--     during love.load never played again for the rest of the session.
--     Failed loads are now retried on the next play, with a one-shot
--     warning to the console so the failure is visible.
--   * Fallback chain: a missing sound name is remapped to an existing
--     one (re_menu_2 -> menu_move). A screen that calls a not-yet-shipped
--     sound no longer goes silent — it plays the fallback instead.
--     This is a stop-gap: the correct fix is to ship the sound. But it
--     means no screen is silent during dev or on a stripped build.
--   * Per-sound debounce (45 ms default) prevents a fast D-pad scroll
--     from retriggering the tick dozens of times per second. On muOS,
--     the OpenAL mixer can glitch when dozens of sources start in the
--     same tick; this caps it at ~22 plays/sec per logical name.
--   * No clone churn: Source:play() on a static source that is already
--     playing restarts it. That gives the "menu tick interrupts the
--     previous tick" behaviour we want, and avoids spawning a new clone
--     for every scroll event.
--   * Optional second argument to play(): { volume, loop }.
--   * M.exists(name) and M.diagnose() for debugging on device.

local M = { sources = {}, volume = 0.7, muted = false }

local PREFIX = "assets/sfx/"
local EXTS   = { ".ogg", ".wav", ".mp3" }

-- Missing-name fallback chain. Followed transitively; cycles broken by
-- the seen[] set. Add here when a screen wants a sound that is not yet
-- shipped, then remove the entry once the file is in assets/sfx/.
local FALLBACK = {
  re_menu_2 = "menu_move",
}

-- 45 ms = ~22 plays per second per logical sound. Below the threshold
-- where the tick stutters on a fast scroll.
local DEBOUNCE  = 0.045
local _last_play = {}
local _warned    = {}

local function now()
  if love and love.timer then return love.timer.getTime() end
  return os.time()
end

local function log_once(key, msg)
  if _warned[key] then return end
  _warned[key] = true
  print("[sfx] " .. msg)
end

-- resolve(name) -> Source | nil
-- Walks the FALLBACK chain, tries each extension in order. A failed
-- load is NOT cached: the next play() will retry it. That is the whole
-- point of this revision.
local function resolve(name)
  local seen = {}
  while name and not seen[name] do
    seen[name] = true
    for _, ext in ipairs(EXTS) do
      local path = PREFIX .. name .. ext
      local cached = M.sources[path]
      if cached == nil then
        local ok, src = pcall(love.audio.newSource, path, "static")
        if ok and src then
          M.sources[path] = src
        else
          -- Deliberately leave nil (not false): retry next call.
          log_once(path, "cannot load " .. path ..
            (ok and "" or (" (" .. tostring(src) .. ")")))
        end
      end
      if M.sources[path] then return M.sources[path], name end
    end
    name = FALLBACK[name]
  end
  return nil
end

function M.preload(names)
  for _, n in ipairs(names) do resolve(n) end
end

function M.play(name, opts)
  if M.muted or not name then return false end
  opts = opts or {}

  local t = now()
  local last = _last_play[name]
  if last and (t - last) < DEBOUNCE then return false end
  _last_play[name] = t

  local src = resolve(name)
  if not src then return false end

  local vol = opts.volume or M.volume
  src:setVolume(math.max(0, math.min(1, vol)))
  src:setLooping(opts.loop == true)
  -- A static Source that is already playing is restarted by play().
  -- That is exactly the "tick interrupts the previous tick" behaviour
  -- we want for menu navigation.
  src:play()
  return true
end

function M.exists(name)
  return resolve(name) ~= nil
end

-- Call from love.load (or from input_debug) to print a full inventory of
-- which sounds resolve on the current device. On hardware there is no
-- interactive console, so this is the fastest way to see what is
-- missing. It prints to stdout, which mux_launch.sh redirects to
-- data/logs/dolphinui.log.
function M.diagnose()
  print("── SFX diagnostic ──")
  local names = {
    "menu_move", "menu_select", "menu_back", "menu_flip",
    "menu_pagescroll", "menu_toggleoption",
    "ethostore_move", "notif_general", "livemenu_open",
    "gamecube_startup", "wii_startup", "gba_startup",
    "dead_space_ui_sound_1", "dead_space_menu_sound", "dead_space_locator",
    "error", "newupdate", "hb_bootsound",
    "re_menu_2",   -- shows whether the fallback is active
  }
  for _, n in ipairs(names) do
    local src, resolved = resolve(n)
    if src then
      local path = resolved == n and n or (n .. " -> " .. resolved)
      print(string.format("  %-28s OK", path))
    else
      print(string.format("  %-28s MISSING", n))
    end
  end
  print("── end ──")
end

-- Stop all currently-loaded sources. Called from love.quit() to avoid a
-- tail of ghost sounds when the process is torn down.
function M.stop_all()
  for _, s in pairs(M.sources) do
    if type(s) == "userdata" then
      pcall(function() s:stop() end)
    end
  end
end

return M