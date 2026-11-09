-- Run with: luajit tests/test_editor_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local writes, fail_write, files = {}, false, {}
package.preload["ui.kit"] = function()
    return {
        W = 640, H = 480, MARGIN = 20, BOT = 460,
        ACC = { gc = {}, wii = {}, boost = {}, hot = {} }, C = {},
        List = function()
            local list = { items = {}, sel = 1 }
            function list:set(items) self.items = items; self.sel = 1 end
            function list:cur() return self.items[self.sel] end
            function list:update() end
            return list
        end,
        set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["ui.modal"] = function() return { show = function() end } end
package.preload["core.sh"] = function() return { mkdir_p = function() end } end
package.preload["core.ini_edit"] = function()
    return {
        read_lines = function(path) files[path] = files[path] or {}; return files[path] end,
        get = function(lines, section, key)
            local active = false
            for _, line in ipairs(lines) do
                local sec = line:match("^%[([^%]]+)%]")
                if sec then active = sec == section
                elseif active then
                    local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
                    if k and k:match("^%s*(.-)%s*$") == key then return v end
                end
            end
        end,
        set = function(lines, section, key, value)
            lines[#lines + 1] = "[" .. section .. "]"
            lines[#lines + 1] = key .. " = " .. tostring(value)
        end,
        write_lines = function(path, lines)
            if fail_write then return false end
            writes[#writes + 1] = path; files[path] = lines; return true
        end,
    }
end
package.preload["core.guide_db"] = function()
    local function item(key, kind, recommend)
        return { key = key, default = kind == "bool" and "False" or "1",
            type = { kind = kind, min = 0, max = 10 }, description = "fixture",
            recommend = recommend, muos = { rec = recommend } }
    end
    return { load = function(name)
        if name == "gfx" then
            local items = {}
            for _, k in ipairs({"InternalResolution","AspectRatio","DisableFog","FastDepthCalc",
                "ShaderCompilationMode","MSAA","MaxAnisotropy","SafeTextureCacheColorSamples","VSync"}) do
                items[k] = item(k, (k == "DisableFog" or k == "FastDepthCalc" or k == "VSync") and "bool" or "int")
            end
            return { sections = { Settings = { items = items } } }
        end
        local core = {}
        for _, k in ipairs({"CPUCore","CPUThread","Overclock","OverclockEnable","EnableIdleSkipping",
            "Framelimit","Fastmem","MMU","SyncGPU","EmulationSpeed","TimingVariance","FPRF"}) do
            core[k] = item(k, (k == "CPUThread" or k == "OverclockEnable" or k == "EnableIdleSkipping"
                or k == "Fastmem" or k == "MMU" or k == "SyncGPU" or k == "FPRF") and "bool" or "int",
                k == "CPUCore" and "3" or nil)
        end
        return { sections = { Core = { items = core },
            DSP = { items = { DSPThread = item("DSPThread","bool"), Backend = item("Backend","text") } } } }
    end }
end
package.preload["core.guide_parser"] = function() return { parse = function() return nil end } end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.rt_editor")
local actions = {}
local UI = { register_action = function(id, callback, metadata)
    if actions[id] then return false, "duplicate action" end
    actions[id] = { run = callback, metadata = metadata }; return true
end }
local ok, err = Screen.register_actions(UI)
assert(ok, err)
for _, id in ipairs({"editor.save","editor.change_selected","editor.recommend_selected","editor.switch_tab","editor.state"}) do
    assert(actions[id], "missing action: " .. id)
end

Screen.enter({ profile = "Default", dir = "workshop/test" })
local state = actions["editor.state"].run()
assert(state.mode == "core" and state.tab == "core" and not state.dirty)
assert(state.selected == "Core.CPUCore")
local changed, change_err = actions["editor.change_selected"].run(1)
assert(changed, change_err); assert(Screen.dirty)
local saved, save_err = actions["editor.save"].run()
assert(saved, save_err); assert(not Screen.dirty and #writes == 2)
local clean, clean_err = actions["editor.save"].run()
assert(clean == false and tostring(clean_err):match("no unsaved"))

local tab_ok, tab_err = actions["editor.switch_tab"].run("hacks")
assert(tab_ok, tab_err)
assert(actions["editor.state"].run().tab == "hacks")
local bad_tab, bad_tab_err = actions["editor.switch_tab"].run("missing")
assert(bad_tab == false and tostring(bad_tab_err):match("unknown editor tab"))

Screen.enter({ profile = "Default", dir = "workshop/test" })
local rec_ok, rec_err = actions["editor.recommend_selected"].run()
assert(rec_ok, rec_err); assert(Screen.dirty)

Screen.enter({ profile = "Factory", dir = "workshop/factory", locked = true })
local locked, locked_err = actions["editor.change_selected"].run(1)
assert(locked == false and tostring(locked_err):match("locked") and not Screen.dirty)
local locked_save, locked_save_err = actions["editor.save"].run()
assert(locked_save == false and tostring(locked_save_err):match("locked"))

Screen.enter({ profile = "Writable", dir = "workshop/test" })
actions["editor.change_selected"].run(1)
fail_write = true
local failed, failed_err = actions["editor.save"].run()
assert(failed == false and tostring(failed_err):match("could not write"))
assert(Screen.dirty, "failed save must preserve dirty state")

print("Editor NEXUS actions: all tests passed")
