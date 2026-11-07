-- core/system_detect.lua — Wii vs GameCube classifier.
--
-- Rules (in priority order):
--   1. Explicit .wbfs / .wia extension  → Wii
--   2. Explicit .gcm extension          → GC
--   3. ID prefix in R / S / W / H       → Wii
--   4. ID prefix G / D / P              → GC
--   5. Fallback                         → GC
--
-- This is the single source of truth used by both the synchronous
-- and asynchronous ROM scanners. If a specific title is misdetected,
-- patch WII_PREFIXES here — one place, everywhere fixed.

local M = {}

local WII_PREFIXES = { R = true, S = true, W = true, H = true }
local GC_PREFIXES  = { G = true, D = true, P = true }
local WII_EXTS     = { wbfs = true, wia = true }
local GC_EXTS      = { gcm = true }

local function ext_of(path)
    if type(path) ~= "string" then return nil end
    local e = path:match("%.([%w]+)$")
    if e then return e:lower() end
    return nil
end

function M.from_id(id)
    if type(id) ~= "string" or #id ~= 6 then return "GC" end
    local p = id:sub(1, 1)
    if WII_PREFIXES[p] then return "Wii" end
    if GC_PREFIXES[p]  then return "GC"  end
    return "GC"
end

-- rom = { id = "RMCE01", path = "…/game.rvz" }
function M.from_rom(rom)
    if type(rom) ~= "table" then return "GC" end
    local ext = ext_of(rom.path) or ext_of(rom.file)
    if ext and WII_EXTS[ext] then return "Wii" end
    if ext and GC_EXTS[ext]  then return "GC"  end
    return M.from_id(rom.id)
end

-- Legacy alias for older code that calls system_from_id.
M.system_from_id = M.from_id

return M
