-- tools/smoke_test.lua — run with: xvfb-run -a love . --smoke
-- Exercise every declared screen, including modules that failed to register.
local failures, passed = 0, 0

local function run()
  local UI = require("ui")
  local manifest = UI.screen_manifest()
  os.execute("mkdir -p data/logs 2>/dev/null")
  local out, open_err = io.open("data/logs/smoke.txt", "w")
  if not out then
    print("[smoke] cannot write data/logs/smoke.txt: " .. tostring(open_err))
    love.event.quit(1)
    return
  end

  out:write("Dolphin Rt:UI screen smoke test ", os.date("%Y-%m-%d %H:%M:%S"), "\n")
  for _, entry in ipairs(manifest) do
    local name = entry.id
    local ok, err = pcall(function()
      if not UI.catalog then error("UI catalog API unavailable") end
      local catalog = UI.catalog()
      local found = false
      for _, screen in ipairs(catalog.screens or {}) do
        if screen.id == name then found = true; break end
      end
      if not found then error("screen module failed to register: " .. tostring(entry.module)) end
      if UI.go_instant(name, {}) == false then error("navigation rejected screen: " .. name) end
      UI.update(0.1)
      UI.draw()
    end)
    if ok then
      passed = passed + 1
      out:write("  [OK]   ", name, "\n")
    else
      failures = failures + 1
      out:write("  [FAIL] ", name, ": ", tostring(err), "\n")
    end
  end

  out:write(("\nRESULT: %d/%d OK, %d FAIL\n"):format(passed, #manifest, failures))
  out:close()
  print(("smoke: %d/%d OK, %d FAIL"):format(passed, #manifest, failures))
  love.event.quit(failures == 0 and #manifest > 0 and 0 or 1)
end

local original_update = love.update or function() end
love.update = function(dt)
  love.update = original_update
  local ok, err = pcall(run)
  if not ok then
    print("[smoke] fatal: " .. tostring(err))
    love.event.quit(1)
  end
end
