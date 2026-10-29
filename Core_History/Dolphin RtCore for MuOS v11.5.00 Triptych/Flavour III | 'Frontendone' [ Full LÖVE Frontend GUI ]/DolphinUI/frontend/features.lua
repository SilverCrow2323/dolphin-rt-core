-- frontend/features.lua — detect what's available on disk.

local M = {}

local function exists(p)
  local f = io.open(p, "r")
  if f then f:close(); return true end
  return false
end

function M.detect()
  return {
    hotkeys    = { available = exists("workshop/hotkeys/Default/Hotkeys.ini")
                            or exists("workshop/base/Hotkeys.ini"),
                   reason    = "Missing workshop/hotkeys/Default/Hotkeys.ini." },

    livemenu   = { available = exists("scripts/livemenu/watcher.py")
                            and exists("scripts/livemenu/overlay.py"),
                   reason    = "Missing scripts/livemenu/{watcher,overlay}.py." },

    logging    = { available = exists("workshop/logging/Verbose/Logger.ini")
                            or exists("workshop/logging/Disabled/Logger.ini"),
                   reason    = "Missing workshop/logging/Verbose/Logger.ini." },

    profile    = { available = exists("workshop/rtcoreprofile/Default/rtprofile_data.ini"),
                   reason    = "Missing workshop/rtcoreprofile/Default/rtprofile_data.ini." },

    controller = { available = exists("workshop/controller/GameCube/Default/GCPadNew.ini")
                            or exists("workshop/controller/Wii/Default/WiimoteNew.ini"),
                   reason    = "Missing workshop/controller/{GameCube,Wii}/Default/." },

    dolphin    = { available = exists("dolphin-emu/dolphin"),
                   reason    = "Missing dolphin-emu/dolphin executable." },
  }
end

return M