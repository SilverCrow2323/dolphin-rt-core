local State    = require("core.state")
local Events   = require("core.events")
local Paths    = require("core.paths")
local Settings = require("core.settings")
local Library  = require("core.library")

local M = {}

local BootInitializer = nil
pcall(function() BootInitializer = require("core.boot_initializer") end)

function M.init()
  Paths.init()
  State.init()
  Events.init()
  Settings.init()
  -- Persist user theme choice across boots.
  State.theme_name = Settings.get("theme") or "gc"
  -- Deferred: Hub must exist first
  if BootInitializer then pcall(function() BootInitializer.start() end) end
  require("core.app_input").init()
  -- library is scanned on demand by screens
  M.settings = Settings
  M.library  = Library
end

function M.update(dt)
  State.update(dt)
  if BootInitializer then pcall(function() BootInitializer.update(dt) end) end
end

function M.shutdown()
  -- nothing to clean yet
end

return M
