-- app_updater.lua — intentionally disabled in the current muOS release.
-- The boot coordinator checks this flag and reports the update check as disabled
-- instead of presenting the no-op stub as a successful update check.
local M = { available = false, reason = "application updater is not shipped" }
function M.check_async(_cb) end
function M.poll() return true end
function M.latest() return nil end
return M
