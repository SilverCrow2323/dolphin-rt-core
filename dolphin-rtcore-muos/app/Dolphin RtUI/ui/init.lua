-- ui/init.lua — navigation + input plumbing (v2).
--
-- Screens are plain tables: enter(params) leave() update(dt) draw()
-- pad(logical) key(k) [raw_pad(raw)] [accept_raw_input()].
-- Logical buttons: A B X Y L1 R1 L2 R2 START SELECT MENU UP DOWN LEFT RIGHT.
-- The D-pad auto-repeats (hold to scroll). START+MENU asks to quit.
-- SELECT is handled only by Home to enter Rt:Stream; all other screens own their input.
-- A screen that fails to load never takes the app down: it is skipped and
-- the error is logged.

local State  = require("core.state")
local IM     = require("ui.input")
local K      = require("ui.kit")
local Modal  = require("ui.modal")
local Notify = require("ui.notify")
local Nexus  = require("core.nexus")

local M = {}
local current, current_name = nil, nil
local stack = {}                         -- back stack of { name, params }
-- Transizione: la schermata uscente scivola di ~28 px e sfuma (OUT), poi la
-- nuova entra dal lato opposto (IN). Direzione: avanti = sx, indietro = dx.
-- Easing cubico, durata totale ~0.25 s: percepibile ma mai lenta su handheld.
local FADE_OUT, FADE_IN, SLIDE = 0.10, 0.15, 28
local fade = { phase = "idle", t = 0, dir = 1, target = nil }
local held = {}                          -- logical → true while physically down
local rep = { dir = nil, t = 0, first = true }
local DIRS = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

local KEY_MAP = {
    up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT",
    ["return"] = "A", space = "A", z = "A", escape = "B", backspace = "B",
    x = "X", c = "Y", y = "Y", q = "L1", e = "R1", ["1"] = "L2", ["3"] = "R2",
    tab = "START", rshift = "SELECT", lshift = "SELECT", m = "MENU",
}
local HAT = { u = "UP", d = "DOWN", l = "LEFT", r = "RIGHT",
              up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT" }

local function log(msg)
    print("[rtui] " .. tostring(msg))
    pcall(function()
        local ok, S = pcall(require, "core.settings")
        if ok and S and S.get("log_level") == "off" then return end
        os.execute("mkdir -p data/logs 2>/dev/null")
        local path = "data/logs/ui.log"
        local maxkb = (ok and S and S.get("log_max_kb")) or 512
        local f = io.open(path, "a+")
        if not f then return end
        f:seek("end")
        local sz = f:seek()
        if sz > maxkb * 1024 then
            f:close()
            os.execute("mv -f data/logs/ui.log data/logs/ui.log.1 2>/dev/null")
            f = io.open(path, "w")
            if not f then return end
        end
        f:write(os.date("%H:%M:%S "), msg, "\n")
        f:close()
    end)
end

function M.register(name, mod_path, metadata)
    local ok, mod = pcall(require, mod_path)
    if ok and type(mod) == "table" then
        local registered, err = Nexus.register_screen(name, mod, metadata or { title = name })
        if not registered then log("screen '" .. name .. "' registry: " .. tostring(err)) end
    else
        log("screen '" .. name .. "' failed: " .. tostring(mod))
    end
end

-- Public NEXUS hooks: stable action IDs can be invoked by menus, shortcuts
-- and future integrations without coupling those callers to screen modules.
function M.register_action(id, callback, metadata)
    return Nexus.register_action(id, callback, metadata)
end
function M.run_action(id, ...)
    local ok, result, detail = Nexus.run_action(id, ...)
    if not ok then
        log("action '" .. tostring(id) .. "' failed: " .. tostring(result))
        Notify.show("error", "Action unavailable: " .. tostring(id))
    end
    return ok, result, detail
end
function M.catalog()
    return { screens = Nexus.list_screens(), actions = Nexus.list_actions() }
end

local SCREEN_MODULES = {
    { "boot", "ui.screens.boot" }, { "home", "ui.screens.home" }, { "library", "ui.screens.library" },
    { "mods", "ui.screens.mods" }, { "cheatdb", "ui.screens.cheatdb" },
    { "game", "ui.screens.game" }, { "cheats", "ui.screens.cheats" },
    { "hotkeys", "ui.screens.hotkeys" }, { "safe_exit", "ui.screens.safe_exit" }, { "settings", "ui.screens.settings" },
    { "rt_editor", "ui.screens.rt_editor" },
    { "folders", "ui.screens.folders" }, { "about", "ui.screens.about" },
    { "diagnostics", "ui.screens.diagnostics" },
    { "controller_map", "ui.screens.controller_map" },
    { "controller_profiles", "ui.screens.controller_profiles" },
    { "triage", "ui.screens.triage" },
    { "rt_profiles", "ui.screens.rt_profiles" },
    { "gameset_browser", "ui.screens.gameset_browser" },
    { "keymap", "ui.screens.keymap" },
    { "gameset_explorer", "ui.screens.gameset_explorer" },
    { "compat_list", "ui.screens.compat_list" },
    { "stream_library", "ui.screens.stream_library" },
    { "stream_settings", "ui.screens.stream_settings" },
}

function M.screen_manifest()
    local out = {}
    for i, entry in ipairs(SCREEN_MODULES) do
        out[i] = { id = entry[1], module = entry[2] }
    end
    return out
end

function M.init()
    for _, s in ipairs(SCREEN_MODULES) do M.register(s[1], s[2]) end

    -- Let feature screens publish stable NEXUS actions after all screens
    -- exist, while keeping navigation ownership in this module.
    local library_screen = Nexus.get_screen("library")
    if library_screen and library_screen.register_actions then
        local ok, registered, detail = pcall(library_screen.register_actions, M)
        if not ok or registered == false then
            log("library NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local stream_settings_screen = Nexus.get_screen("stream_settings")
    if stream_settings_screen and stream_settings_screen.register_actions then
        local ok, registered, detail = pcall(stream_settings_screen.register_actions, M)
        if not ok or registered == false then
            log("stream settings NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local hotkeys_screen = Nexus.get_screen("hotkeys")
    if hotkeys_screen and hotkeys_screen.register_actions then
        local ok, registered, detail = pcall(hotkeys_screen.register_actions, M)
        if not ok or registered == false then
            log("hotkeys NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local cheatdb_screen = Nexus.get_screen("cheatdb")
    if cheatdb_screen and cheatdb_screen.register_actions then
        local ok, registered, detail = pcall(cheatdb_screen.register_actions, M)
        if not ok or registered == false then
            log("cheat database NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local compat_screen = Nexus.get_screen("compat_list")
    if compat_screen and compat_screen.register_actions then
        local ok, registered, detail = pcall(compat_screen.register_actions, M)
        if not ok or registered == false then
            log("compatibility NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local compat_screen = Nexus.get_screen("compat_list")
    if compat_screen and compat_screen.register_actions then
        local ok, registered, detail = pcall(compat_screen.register_actions, M)
        if not ok or registered == false then
            log("compatibility NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local controller_profiles_screen = Nexus.get_screen("controller_profiles")
    if controller_profiles_screen and controller_profiles_screen.register_actions then
        local ok, registered, detail = pcall(controller_profiles_screen.register_actions, M)
        if not ok or registered == false then
            log("controller profiles NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local keymap_screen = Nexus.get_screen("keymap")
    if keymap_screen and keymap_screen.register_actions then
        local ok, registered, detail = pcall(keymap_screen.register_actions, M)
        if not ok or registered == false then
            log("keymap NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local keymap_screen = Nexus.get_screen("keymap")
    if keymap_screen and keymap_screen.register_actions then
        local ok, registered, detail = pcall(keymap_screen.register_actions, M)
        if not ok or registered == false then
            log("keymap NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local game_screen = Nexus.get_screen("game")
    if game_screen and game_screen.register_actions then
        local ok, registered, detail = pcall(game_screen.register_actions, M)
        if not ok or registered == false then
            log("game NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local gameset_browser_screen = Nexus.get_screen("gameset_browser")
    if gameset_browser_screen and gameset_browser_screen.register_actions then
        local ok, registered, detail = pcall(gameset_browser_screen.register_actions, M)
        if not ok or registered == false then
            log("gameset browser NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local cheats_screen = Nexus.get_screen("cheats")
    if cheats_screen and cheats_screen.register_actions then
        local ok, registered, detail = pcall(cheats_screen.register_actions, M)
        if not ok or registered == false then
            log("cheats NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local diagnostics_screen = Nexus.get_screen("diagnostics")
    if diagnostics_screen and diagnostics_screen.register_actions then
        local ok, registered, detail = pcall(diagnostics_screen.register_actions, M)
        if not ok or registered == false then
            log("diagnostics NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    local settings_screen = Nexus.get_screen("settings")
    if settings_screen and settings_screen.register_actions then
        local ok, registered, detail = pcall(settings_screen.register_actions, M)
        if not ok or registered == false then
            log("settings NEXUS actions: " .. tostring(ok and detail or registered))
        end
    end

    -- Every registered screen gets a stable navigation action. This makes
    -- the complete screen map discoverable by diagnostics and future menus.
    for _, entry in ipairs(Nexus.list_screens()) do
        local target = entry.id
        local action_id = "navigation.go." .. target
        if not Nexus.has_action(action_id) then
            M.register_action(action_id, function(params)
                return M.go(target, params)
            end, { title = "Open " .. (entry.metadata.title or target),
                   group = "navigation", screen = target, order = 100 })
        end
    end

    -- Stable built-in action IDs are the first consumers of NEXUS. Keep the
    -- callbacks here so navigation remains the single owner of transitions.
    if not Nexus.has_action("navigation.back") then
        M.register_action("navigation.back", function()
            local ok, reason = M.back()
            -- A busy transition is a harmless no-op for action callers.
            if not ok and reason == "transition in progress" then return true end
            return ok, reason
        end, { title = "Back", group = "navigation", order = 10 })
    end
    if not Nexus.has_action("navigation.open_library") then
        M.register_action("navigation.open_library", function()
            M.go("library")
            return true
        end, { title = "Open library", group = "navigation", order = 20 })
    end
    if not Nexus.has_action("system.open_drawer") then
        M.register_action("system.open_drawer", function()
            local ok, panel = pcall(require, "ui.system_panel")
            if not ok or not panel or not panel.open then return false, "system drawer unavailable" end
            panel.open()
            return true
        end, { title = "Open system drawer", group = "system", order = 30 })
    end

    local ok, SP = pcall(require, "ui.system_panel")
    if ok and SP and SP.init then SP.init() end
    local okS, Settings = pcall(require, "core.settings")
    if okS then
        K.fx = Settings.get("fx") or "lite"
        local _pal = Settings.get("palette")
        if _pal then K.set_palette(_pal) end
        if not os.getenv("DOLPHINUI_FPS") then love.fps_cap = tonumber(Settings.get("fps_cap")) or 60 end
        pcall(function() require("ui.sfx").set_enabled(Settings.get("sfx_on") ~= false) end)
    end
end

local function enter(name, params)
    local scr = Nexus.get_screen(name) or Nexus.get_screen("library")
    if not scr then return end
    if current and current.leave then pcall(current.leave) end
    current, current_name = scr, name
    scr.params = params
    State.screen = name
    State.raw_input = false
    if scr.enter then
        local ok, err = pcall(scr.enter, params or {})
        if not ok then
            log("enter " .. name .. ": " .. tostring(err))
            log("  trace: " .. debug.traceback())
            Notify.show("error", "Screen error: " .. name)
        end
    end
end

-- ── stato di selezione: "indietro" torna sulla voce da cui si era partiti ──
-- Una schermata puo' definire save_state()/restore_state(st); altrimenti si
-- usa S.list.sel (K.List) oppure S.sel (numero).
local function capture(scr)
    if not scr then return nil end
    if scr.save_state then
        local ok, st = pcall(scr.save_state)
        return ok and st or nil
    end
    if scr.list and type(scr.list.sel) == "number" then return { sel = scr.list.sel } end
    if type(scr.sel) == "number" then return { sel = scr.sel } end
    return nil
end

local function restore(scr, st)
    if not scr or not st then return end
    if scr.restore_state then pcall(scr.restore_state, st); return end
    if type(st.sel) ~= "number" then return end
    local L = scr.list
    if L and L.items and #L.items > 0 then
        local n = #L.items
        local i = math.max(1, math.min(st.sel, n))
        local function ok_row(k) return L.items[k] and not L.items[k].skip end
        if not ok_row(i) then                       -- intestazioni di sezione: cerca la riga piu' vicina
            local j = i
            while j <= n and not ok_row(j) do j = j + 1 end
            if j > n then j = i; while j >= 1 and not ok_row(j) do j = j - 1 end end
            if j >= 1 and j <= n then i = j end
        end
        L.sel = i
        if L._aim then L:_aim(true) end
    elseif type(scr.sel) == "number" then
        local rows = scr.items or scr.rows
        local n = rows and #rows or st.sel
        scr.sel = math.max(1, math.min(st.sel, math.max(1, n)))
    end
end

-- Navigate with a short fade. `params` is handed to enter().
function M.go(name, params, opts)
    if not Nexus.has_screen(name) then Notify.show("error", "Unknown screen: " .. tostring(name)); return false, "unknown screen" end
    if fade.phase ~= "idle" then return false, "transition in progress" end
    if not (opts and opts.no_push) and current_name and current_name ~= name then
        stack[#stack + 1] = { name = current_name, params = current and current.params,
                              state = capture(current) }
    end
    fade.phase, fade.t, fade.dir = "out", 0, 1
    fade.target = { name = name, params = params }
    return true
end

function M.go_instant(name, params)
    if not Nexus.has_screen(name) then Notify.show("error", "Unknown screen: " .. tostring(name)); return false end
    stack = {}
    fade.phase = "idle"
    enter(name, params)
    return true
end

function M.is_root()
    return #stack == 0
end

function M.back()
    -- Do not consume history while another transition owns the navigation state.
    if fade.phase ~= "idle" then return false, "transition in progress" end
    local prev = table.remove(stack)
    fade.phase, fade.t, fade.dir = "out", 0, -1
    fade.target = prev and { name = prev.name, params = prev.params, state = prev.state }
                       or { name = "library" }
    return true
end
function M.current() return current_name end

-- ── logical dispatch ────────────────────────────────────────
local function dispatch(lg)
    if not lg then return end
    if Modal.is_open() then Modal.pad(lg); return end

    local ok_sp, SP = pcall(require, "ui.system_panel")    local ok_sp, SP = pcall(require, "ui.system_panel")
    if ok_sp and SP then
        if SP.is_open() then SP.pad(lg); return end
        if lg == "MENU" then SP.open(); return end
    end
    if fade.phase ~= "idle" then return end
    if current and current.pad then
        local ok, err = pcall(current.pad, lg)
        if not ok then log("pad " .. tostring(current_name) .. ": " .. tostring(err)); Notify.show("error", "Input error") end
    end
end

-- Edge-triggered dispatch. main.lua never forwards the release of a hat
-- (D-pad "centre"), so presses must NOT depend on a matching release: a
-- missed release would otherwise block the button or repeat forever.
local last_press = {}
local function now() return love.timer.getTime() end

local function combo_check(lg)
    if lg ~= "START" and lg ~= "MENU" then return false end
    held[lg] = now()
    local o = (lg == "START") and "MENU" or "START"
    if held[o] and now() - held[o] < 0.5 and not Modal.is_open() then
        held.START, held.MENU = nil, nil
        local okS, St = pcall(require, "core.settings")
        if okS and St.get("confirm_quit") == false then love.event.quit(); return true end
        Modal.show("Quit", "Close Dolphin Rt:UI and return to muOS? (START + MENU)", {
            accept_label = "Quit", cancel_label = "Stay", color = K.C.bad,
            on_accept = function() love.event.quit() end })
        return true
    end
    return false
end

-- repeatable: only for sources whose release we really receive
local function press(lg, repeatable)
    if not lg then return end
    local t = now()
    if last_press[lg] and t - last_press[lg] < 0.03 then return end   -- joystick+gamepad twin
    last_press[lg] = t
    if combo_check(lg) then return end
    if DIRS[lg] and repeatable then rep.dir, rep.t, rep.first, rep.age = lg, 0, true, 0 end
    dispatch(lg)
end
local function release(lg)
    if not lg then return end
    if rep.dir == lg then rep.dir = nil end
end

function M.pad(raw)
    local logical = IM.from_raw(raw)
    if current and current.raw_pad and not Modal.is_open() then
        local ok, eaten = pcall(current.raw_pad, raw)
        if ok and eaten then return end
    end
    press(logical, true)
end
function M.pad_released(raw) release(IM.from_raw(raw)) end
function M.gamepad(name)
    local logical = IM.from_gamepad(name)
    if current and current.raw_pad and not Modal.is_open() then
        local ok, eaten = pcall(current.raw_pad, name)
        if ok and eaten then return end
    end
    press(logical, true)
end
function M.gamepad_released(name) release(IM.from_gamepad(name)) end

function M.hat(dir)
    local lg = HAT[tostring(dir)]
    if lg then press(lg, false) end              -- no release is ever delivered: no auto-repeat
end

function M.key(k)
    if Modal.is_open() then Modal.key(k); return end
    if State.raw_input and current and current.key then
        local ok, err = pcall(current.key, k)
        if not ok then log("key: " .. tostring(err)) end
        return
    end
    local lg = KEY_MAP[k]
    if lg then press(lg, false) end
    if current and current.key and not lg then pcall(current.key, k) end
end
function M.key_released(_) end

-- ── frame ───────────────────────────────────────────────────
function M.update(dt)
    K.update(dt)
    Modal.update(dt)
    if rep.dir then
        rep.age = (rep.age or 0) + dt
        if rep.age > 12 then rep.dir = nil end       -- safety: never repeat forever
    end
    if rep.dir then
        rep.t = rep.t + dt
        local gate = rep.first and 0.38 or 0.075
        if rep.t >= gate then rep.t = 0; rep.first = false; dispatch(rep.dir) end
    end
    if fade.phase == "out" then
        fade.t = fade.t + dt
        if fade.t >= FADE_OUT then
            local g = fade.target
            enter(g.name, g.params)
            restore(current, g.state)                 -- solo quando si torna indietro
            fade.phase, fade.t = "in", 0
        end
    elseif fade.phase == "in" then
        fade.t = fade.t + dt
        if fade.t >= FADE_IN then fade.phase = "idle" end
    end
    if current and current.update then
        local ok, err = pcall(current.update, dt)
        if not ok then log("update " .. tostring(current_name) .. ": " .. tostring(err)) end
    end
    local ok_sp, SP = pcall(require, "ui.system_panel")
    if ok_sp and SP and SP.update then SP.update(dt) end
    local ok_cl, CL = pcall(require, "core.cover_loader")
    if ok_cl and CL and CL.update then CL.update(dt) end
    local ok_sb, SB = pcall(require, "ui.statusbar")
    if ok_sb and SB and SB.update then SB.update(dt) end
end

local function draw_scene()
    K.bg()
    if current and current.draw then
        local ok, err = pcall(current.draw)
        if not ok then
            log("draw " .. tostring(current_name) .. ": " .. tostring(err))
            K.text("body", "Screen error — see data/logs/ui.log", 24, 220, K.C.bad)
        end
    end
    Modal.draw(K.W, K.H)
    local ok_sp, SP = pcall(require, "ui.system_panel")
    if ok_sp and SP and SP.draw then SP.draw(K.W, K.H) end

    -- statusbar globale (batteria + wifi) in alto a dx
    local ok_sb, SB = pcall(require, "ui.statusbar")
    if ok_sb and SB and SB.draw then SB.draw(K.W, K.H) end
end

local trans_canvas
local function get_trans_canvas()
    if trans_canvas == nil then
        local ok, c = pcall(love.graphics.newCanvas, K.W, K.H)
        trans_canvas = ok and c or false
    end
    return trans_canvas or nil
end

function M.draw()
    if fade.phase == "idle" then
        draw_scene()
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local c = get_trans_canvas()
    local dur = (fade.phase == "out") and FADE_OUT or FADE_IN
    local p = math.max(0, math.min(1, fade.t / dur))
    local e = 1 - (1 - p) ^ 3                        -- ease-out cubic

    if not c then                                    -- fallback: vecchio fade nero
        draw_scene()
        local a = (fade.phase == "out") and e or (1 - e)
        love.graphics.setColor(0.02, 0.025, 0.05, a)
        love.graphics.rectangle("fill", 0, 0, K.W, K.H)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- scena su canvas (push/pop "all" ripristina anche un eventuale canvas esterno)
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.clear(0.02, 0.025, 0.05, 1)
    love.graphics.origin()
    draw_scene()
    love.graphics.pop()

    local off, a
    if fade.phase == "out" then off, a = -fade.dir * e * SLIDE, 1 - e
    else                        off, a =  fade.dir * (1 - e) * SLIDE, e end
    love.graphics.setColor(0.02, 0.025, 0.05, 1)
    love.graphics.rectangle("fill", 0, 0, K.W, K.H)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(c, off, 0)
    love.graphics.setColor(1, 1, 1, 1)
end

return M
