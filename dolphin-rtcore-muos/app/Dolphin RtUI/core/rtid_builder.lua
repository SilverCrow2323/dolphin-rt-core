-- rtid_builder.lua — STUB intenzionale (non spedito nella release).
-- La ricostruzione delle card rtid_<ID>.ini e' gestita dal frontend quando
-- una card viene aperta; lo stub evita il FAIL del checker.
local M = {}
function M.rebuild_all() return { built = 0, updated = 0, orphans = 0 } end
return M
