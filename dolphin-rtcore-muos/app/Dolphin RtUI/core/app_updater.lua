-- app_updater.lua — STUB intenzionale (non spedito nella release).
-- boot_initializer usa pcall(require, "core.app_updater"): senza questo file
-- il boot salta silenziosamente l'update check. Lo stub evita il FAIL del
-- checker e rende esplicito che la feature e' disattivata.
local M = {}
function M.check_async(_cb) end
function M.poll() return true end
function M.latest() return nil end
return M
