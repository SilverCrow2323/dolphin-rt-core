-- cheats_downloader.lua — STUB intenzionale (non spedito nella release).
-- Lo script scripts/rtcheats_sync.sh fa il download reale; questo modulo
-- (usato dal boot) e' uno stub per evitare il FAIL del checker.
local M = {}
function M.start_for(_ids) end
function M.poll() return true, nil end
return M
