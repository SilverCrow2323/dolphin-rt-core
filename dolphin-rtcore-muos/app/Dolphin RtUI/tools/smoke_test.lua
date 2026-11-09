-- tools/smoke_test.lua — esegui con:  xvfb-run -a love . --smoke
-- Apre ogni schermata registrata, chiama enter/update(0.1)/draw una volta,
-- e scrive l'esito in data/logs/smoke.txt. Non modifica nulla.
local SCREENS = {
  "boot","library","game","cheats","hotkeys","settings","rt_editor",
  "folders","about","diagnostics","controller_map","controller_profiles",
  "triage","rt_profiles","gameset_browser","keymap","gameset_explorer",
  "compat_list","cheatdb","mods","stream_library","stream_settings",
}
local failures, ok = {}, 0
local function run()
  local UI = require("ui")
  local out = io.open("data/logs/smoke.txt","w")
  out:write("smoke test ", os.date("%Y-%m-%d %H:%M:%S"), "\n")
  for _, name in ipairs(SCREENS) do
    local ok2, err = pcall(function()
      UI.go_instant(name, {})
      UI.update(0.1)
      UI.draw()
    end)
    if ok2 then ok = ok + 1; out:write("  [OK]   ", name, "\n")
    else failures[#failures+1] = name; out:write("  [FAIL] ", name, ": ", tostring(err), "\n") end
  end
  out:write(("\nRESULT: %d/%d OK, %d FAIL\n"):format(ok, #SCREENS, #failures))
  out:close()
  print(("smoke: %d/%d OK, %d FAIL"):format(ok, #SCREENS, #failures))
  love.event.quit(#failures == 0 and 0 or 1)
end
-- installa un hook: alla prima love.update chiama run()
local _orig_update = love.update or function() end
love.update = function(dt)
  love.update = _orig_update
  pcall(run)
end
