-- core/region_utils.lua — GameID → region mapping (piccolo, idempotente).
local M = {}

local MAP = {
    E = "NTSC-U", P = "PAL", J = "NTSC-J", K = "NTSC-K",
    W = "NTSC-TW", D = "PAL-DE", F = "PAL-FR",
    I = "PAL-IT", S = "PAL-ES", X = "PAL-NL", H = "PAL-NL",
}

function M.from_gameid(id)
    if not id or #id < 4 then return nil end
    return MAP[id:sub(4, 4)] or ""
end

function M.label_from_gameid(id)
    return M.from_gameid(id) or "?"
end

return M
