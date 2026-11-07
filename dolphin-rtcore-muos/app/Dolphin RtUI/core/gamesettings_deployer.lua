-- gamesettings_deployer.lua — STUB intenzionale (non spedito nella release).
-- Il deploy reale dei GameSettings bundled non e' implementato; senza questo
-- file il boot salta silenziosamente la fase (pcall in boot_initializer).
local M = {}
function M.start() end
function M.poll() return true, { deployed = 0 } end
return M
