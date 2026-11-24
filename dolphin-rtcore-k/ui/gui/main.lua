-- Dolphin Rt:UI for KNULLI and ROCKNIX
-- Controller-first game library and per-title advanced settings editor.
-- Configuration is written to the same files and keys used by EmulationStation.
local APP = {}
local W, H = 640, 480
local ROOT = os.getenv("RTCORE_PORT_ROOT") or "."
local PLATFORM = os.getenv("RTCORE_PLATFORM") or "unknown"
local USERDATA = os.getenv("RTCORE_USERDATA") or (PLATFORM == "rocknix" and "/storage" or "/userdata")
local ROM_ROOT = os.getenv("RTCORE_ROM_ROOT") or (USERDATA .. "/roms")
local CONF = os.getenv("RTCORE_CONF") or (PLATFORM == "rocknix"
    and (USERDATA .. "/.config/system/configs/system.cfg")
    or (USERDATA .. "/system/batocera.conf"))
local OPTIONS_FILE = ROOT .. "/config/options.tsv"
local COLOURS = {
    bg = {0.035, 0.043, 0.070}, panel = {0.075, 0.090, 0.135},
    panel2 = {0.105, 0.125, 0.180}, line = {0.20, 0.24, 0.34},
    text = {0.91, 0.94, 1.00}, muted = {0.53, 0.60, 0.73},
    accent = {0.47, 0.72, 1.00}, accent2 = {0.68, 0.54, 1.00},
    ok = {0.44, 0.85, 0.65}, warn = {1.00, 0.72, 0.36}
}
local FONT, SMALL, TINY
local state = {
    page = "home", home_sel = 1, system = "gamecube", games = {},
    game_sel = 1, selected_game = nil, options = {}, groups = {},
    group_sel = 1, option_sel = 1, status = "Choose GAMECUBE or WII",
    status_time = 0, scroll = 0, smoke = false
}

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a") or ""
    f:close()
    return data
end

local function write_atomic(path, data)
    local dir = path:match("^(.*)/[^/]+$") or "."
    os.execute("mkdir -p " .. quote(dir) .. " 2>/dev/null")
    local tmp = path .. ".rtcore-tmp"
    local f, err = io.open(tmp, "wb")
    if not f then return false, err end
    local ok, write_err = f:write(data)
    local close_ok, close_err = f:close()
    if not ok or close_ok == nil then
        os.remove(tmp)
        return false, write_err or close_err or "write failed"
    end
    if love and love.filesystem then
        -- os.rename is atomic when source and destination share a filesystem.
    end
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then os.remove(tmp); return false, rename_err end
    return true
end

local function set_status(message, kind)
    state.status = tostring(message or "")
    state.status_kind = kind or "info"
    state.status_time = 5
end

local function split_tsv(line)
    local fields = {}
    local start = 1
    while true do
        local p = line:find("\t", start, true)
        if not p then fields[#fields + 1] = line:sub(start); break end
        fields[#fields + 1] = line:sub(start, p - 1)
        start = p + 1
    end
    return fields
end

local function load_options()
    local raw = read_file(OPTIONS_FILE)
    if not raw then return false, "Missing " .. OPTIONS_FILE end
    local map, groups, ordered = {}, {}, {}
    for line in raw:gmatch("[^\r\n]+") do
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local f = split_tsv(line)
            if f[1] == "F" and #f >= 5 then
                local option = {
                    group = f[2], key = f[3], label = f[4],
                    description = f[5], choices = {}
                }
                map[option.key] = option
                if not groups[option.group] then
                    groups[option.group] = {}
                    ordered[#ordered + 1] = option.group
                end
                table.insert(groups[option.group], option)
            elseif f[1] == "C" and #f >= 5 and map[f[2]] then
                table.insert(map[f[2]].choices, {
                    value = f[3], label = f[4], override = f[5]
                })
            end
        end
    end
    state.option_map, state.options, state.groups = map, groups, ordered
    return true
end

local DEFAULTS = {
    rtc_gamesettings = "on", rtc_textures = "off", rtc_cheats = "off",
    rtc_fps = "off", rtc_pad = "2", rtc_orient = "upright",
    rtc_exit = "select_start", rtc_platform = "auto"
}

local function system_key(game, key)
    return (game.system or "gamecube") .. "." .. key
end

local function game_key(game, key)
    return (game.system or "gamecube") .. '["' .. game.path .. '"].' .. key
end

local function find_value(lines, prefix)
    local wanted = prefix .. "="
    for _, line in ipairs(lines) do
        if line:sub(1, #wanted) == wanted then
            return line:sub(#wanted + 1)
        end
    end
    return nil
end

local function config_lines()
    local raw = read_file(CONF)
    local lines = {}
    if raw then
        for line in raw:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
    end
    return lines
end

local function get_value(game, key)
    local lines = config_lines()
    return find_value(lines, game_key(game, key))
        or find_value(lines, system_key(game, key))
        or find_value(lines, "global." .. key)
        or DEFAULTS[key] or "auto"
end

local function save_value(game, key, value)
    if not game or not game.path then return false, "No game selected" end
    local prefix = game_key(game, key)
    local wanted = prefix .. "="
    local lines, found = config_lines(), false
    for i, line in ipairs(lines) do
        if line:sub(1, #wanted) == wanted then
            lines[i] = wanted .. tostring(value)
            found = true
            break
        end
    end
    if not found then lines[#lines + 1] = wanted .. tostring(value) end

    local old = read_file(CONF)
    if old and not read_file(CONF .. ".rtcore.bak") then
        local ok, err = write_atomic(CONF .. ".rtcore.bak", old)
        if not ok then return false, "Backup failed: " .. tostring(err) end
    end
    local ok, err = write_atomic(CONF, table.concat(lines, "\n") .. "\n")
    if not ok then return false, tostring(err) end
    return true
end

local function option_for(key)
    return state.option_map and state.option_map[key] or nil
end

local function choice_index(option, value)
    for i, choice in ipairs(option.choices or {}) do
        if choice.value == value then return i end
    end
    return 1
end

local function choice_label(option, value)
    for _, choice in ipairs(option.choices or {}) do
        if choice.value == value then return choice.label end
    end
    return tostring(value)
end

local function extension_ok(path)
    local ext = path:match("%.([^%.\\/]+)$")
    ext = ext and ext:lower() or ""
    return ({
        iso=true, gcm=true, rvz=true, wbfs=true, wia=true,
        gcz=true, ciso=true
    })[ext] == true
end

local function game_id(path)
    local name = path:match("([^/]+)$") or path
    local tagged = name:match("[%[%(%{]([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])[%]%)%}]")
    if tagged then return tagged end
    local ext = (name:match("%.([^%.]+)$") or ""):lower()
    local offsets = {wbfs=512, rvz=88, wia=88, ciso=32768}
    local f = io.open(path, "rb")
    if not f then return "------" end
    f:seek("set", offsets[ext] or 0)
    local id = f:read(6) or ""
    f:close()
    if #id == 6 and id:match("^[A-Z0-9]+$") then return id end
    return "------"
end

local function scan_system(system)
    local folder = ROM_ROOT .. "/" .. system
    local command = "find -L " .. quote(folder) ..
        " -type f \\( -iname '*.iso' -o -iname '*.gcm' -o -iname '*.rvz' -o -iname '*.wbfs' -o -iname '*.wia' -o -iname '*.gcz' -o -iname '*.ciso' \\) -print 2>/dev/null"
    local pipe = io.popen(command, "r")
    local games = {}
    if pipe then
        for path in pipe:lines() do
            if extension_ok(path) then
                local name = path:match("([^/]+)$") or path
                local title = name:gsub("%.[^%.]+$", ""):gsub("_", " ")
                games[#games + 1] = {
                    path = path, title = title, id = game_id(path), system = system
                }
            end
        end
        pipe:close()
    end
    table.sort(games, function(a, b) return a.title:lower() < b.title:lower() end)
    return games
end

local function scan_current()
    state.games = scan_system(state.system)
    state.game_sel = math.max(1, math.min(state.game_sel, math.max(1, #state.games)))
    set_status(#state.games .. " " .. state.system:upper() .. " game(s) found", "success")
end

local function open_game(game)
    state.selected_game = game
    state.page = "settings"
    state.group_sel = 1
    state.option_sel = 1
    state.scroll = 0
    set_status("Editing " .. game.title, "info")
end

local function active_group()
    return state.groups[state.group_sel]
end

local function visible_options()
    local group = active_group()
    local rows = {}
    if not group then return rows end
    for _, option in ipairs(state.options[group] or {}) do
        if not (state.system == "gamecube" and option.key == "rtc_orient") then
            rows[#rows + 1] = option
        end
    end
    return rows
end

local function cycle_option(direction)
    local rows = visible_options()
    local option = rows[state.option_sel]
    if not option or not state.selected_game then return end
    local current = choice_index(option, get_value(state.selected_game, option.key))
    local next_index = ((current - 1 + direction) % #option.choices) + 1
    local next_choice = option.choices[next_index]
    local ok, err = save_value(state.selected_game, option.key, next_choice.value)
    if ok then
        set_status(option.label .. " → " .. next_choice.label, "success")
    else
        set_status("Could not save: " .. tostring(err), "error")
    end
end

local function clear_override()
    local rows = visible_options()
    local option = rows[state.option_sel]
    if not option or not state.selected_game then return end
    local prefix = game_key(state.selected_game, option.key) .. "="
    local lines, kept, removed = config_lines(), {}, false
    for _, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix then removed = true
        else kept[#kept + 1] = line end
    end
    if not removed then
        set_status("No per-game override to clear", "info")
        return
    end
    local old = read_file(CONF)
    if old and not read_file(CONF .. ".rtcore.bak") then
        local ok, err = write_atomic(CONF .. ".rtcore.bak", old)
        if not ok then set_status("Backup failed: " .. tostring(err), "error"); return end
    end
    local ok, err = write_atomic(CONF, table.concat(kept, "\n") .. "\n")
    set_status(ok and (option.label .. ": using system/global/profile default")
        or ("Could not save: " .. tostring(err)), ok and "success" or "error")
end

local function move_group(direction)
    if #state.groups == 0 then return end
    state.group_sel = ((state.group_sel - 1 + direction) % #state.groups) + 1
    state.option_sel, state.scroll = 1, 0
    set_status(active_group() or "", "info")
end

local function back()
    if state.page == "settings" then
        state.page, state.selected_game = "library", nil
    elseif state.page == "library" or state.page == "diagnostics" then
        state.page = "home"
    else
        love.event.quit()
    end
end

local function activate()
    if state.page == "home" then
        if state.home_sel == 3 then
            state.page = "diagnostics"
        else
            state.system = state.home_sel == 1 and "gamecube" or "wii"
            state.page = "library"
            state.game_sel = 1
            scan_current()
        end
    elseif state.page == "library" then
        local game = state.games[state.game_sel]
        if game then open_game(game) end
    elseif state.page == "settings" then
        cycle_option(1)
    elseif state.page == "diagnostics" then
        back()
    end
end

local function key_action(action)
    if state.page == "home" then
        if action == "up" then state.home_sel = math.max(1, state.home_sel - 1)
        elseif action == "down" then state.home_sel = math.min(3, state.home_sel + 1)
        elseif action == "left" then state.home_sel = math.max(1, state.home_sel - 1)
        elseif action == "right" then state.home_sel = math.min(3, state.home_sel + 1)
        elseif action == "a" then activate()
        elseif action == "b" then love.event.quit() end
    elseif state.page == "library" then
        if action == "up" then state.game_sel = math.max(1, state.game_sel - 1)
        elseif action == "down" then state.game_sel = math.min(#state.games, state.game_sel + 1)
        elseif action == "left" or action == "l1" then
            state.system = "gamecube"; state.game_sel = 1; scan_current()
        elseif action == "right" or action == "r1" then
            state.system = "wii"; state.game_sel = 1; scan_current()
        elseif action == "a" then activate()
        elseif action == "y" then scan_current()
        elseif action == "b" then back() end
    elseif state.page == "settings" then
        if action == "up" then state.option_sel = math.max(1, state.option_sel - 1)
        elseif action == "down" then state.option_sel = math.min(#visible_options(), state.option_sel + 1)
        elseif action == "left" then cycle_option(-1)
        elseif action == "right" then cycle_option(1)
        elseif action == "l1" then move_group(-1)
        elseif action == "r1" then move_group(1)
        elseif action == "a" then cycle_option(1)
        elseif action == "x" then clear_override()
        elseif action == "b" then back() end
    elseif state.page == "diagnostics" then
        if action == "b" or action == "a" then back() end
    end
end

local function has_arg(name)
    if type(arg) ~= "table" then return false end
    for _, value in pairs(arg) do if value == name then return true end end
    return false
end

local function smoke_test()
    local ok, err = load_options()
    assert(ok, err)
    local expected = PLATFORM == "knulli" and 23 or 24
    local option_count = 0
    for _, rows in pairs(state.options) do option_count = option_count + #rows end
    assert(option_count == expected, "unexpected options count: " .. option_count)
    local gc = scan_system("gamecube")
    local wii = scan_system("wii")
    assert(#gc == 1 and #wii == 1, "fixture ROMs not discovered in both systems")
    local target = state.option_map.rtc_res
    assert(target and #target.choices > 1, "rtc_res option missing")
    local game = gc[1]
    local chosen
    for _, c in ipairs(target.choices) do if c.value == "2" then chosen = c end end
    assert(chosen, "2x resolution choice missing")
    local saved, save_err = save_value(game, target.key, chosen.value)
    assert(saved, save_err)
    assert(get_value(game, target.key) == "2", "saved per-game option did not read back")
    local raw = read_file(CONF) or ""
    assert(raw:find(game.system .. '["' .. game.path .. '"].rtc_res=2', 1, true),
        "expected shared EmulationStation config key was not written")
    print("RTUI_PORT_SMOKE_OK platform=" .. PLATFORM .. " options=" .. option_count ..
        " gamecube=1 wii=1 per_game_setting=verified")
    love.event.quit(0)
end

function love.load()
    love.window.setMode(W, H, {fullscreen = true, vsync = 1, resizable = false})
    love.window.setTitle("Dolphin Rt:UI")
    FONT = love.graphics.newFont(18)
    SMALL = love.graphics.newFont(13)
    TINY = love.graphics.newFont(11)
    local ok, err = load_options()
    if not ok then set_status(err, "error") end
    if has_arg("--smoke") then
        smoke_test()
        return
    end
end

function love.update(dt)
    state.status_time = math.max(0, state.status_time - dt)
end

function love.gamepadpressed(_, button)
    local map = {
        dpup="up", dpdown="down", dpleft="left", dpright="right",
        a="a", b="b", x="x", y="y", leftshoulder="l1", rightshoulder="r1",
        start="b", back="b"
    }
    if map[button] then key_action(map[button]) end
end

function love.keypressed(key)
    local map = {
        up="up", down="down", left="left", right="right",
        ["return"]="a", space="a", z="a", escape="b", backspace="b",
        x="x", q="l1", e="r1", r="y"
    }
    if map[key] then key_action(map[key]) end
end

local function colour(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

local function panel(x, y, w, h, selected)
    colour(selected and COLOURS.panel2 or COLOURS.panel)
    love.graphics.rectangle("fill", x, y, w, h, 9, 9)
    colour(selected and COLOURS.accent or COLOURS.line, 0.9)
    love.graphics.rectangle("line", x, y, w, h, 9, 9)
end

local function text(value, x, y, font, c, limit)
    love.graphics.setFont(font or SMALL)
    colour(c or COLOURS.text)
    if limit then love.graphics.printf(tostring(value or ""), x, y, limit, "left")
    else love.graphics.print(tostring(value or ""), x, y) end
end

local function header(title, subtitle)
    colour(COLOURS.panel)
    love.graphics.rectangle("fill", 0, 0, W, 66)
    colour(COLOURS.accent)
    love.graphics.rectangle("fill", 0, 64, W, 2)
    text("DOLPHIN Rt:UI", 22, 12, FONT, COLOURS.text)
    text(title, 270, 13, SMALL, COLOURS.accent)
    text(subtitle or "", 270, 34, TINY, COLOURS.muted)
    text(PLATFORM:upper(), 520, 18, TINY, COLOURS.ok, 96)
end

local function footer()
    colour(COLOURS.panel)
    love.graphics.rectangle("fill", 0, H - 34, W, 34)
    colour(COLOURS.line)
    love.graphics.rectangle("fill", 0, H - 34, W, 1)
    local msg = state.status_time > 0 and state.status or
        "A SELECT   B BACK   L/R SECTION   X CLEAR GAME OVERRIDE"
    text(msg, 18, H - 24, TINY,
        state.status_kind == "error" and COLOURS.warn or COLOURS.muted, W - 36)
end

function love.draw()
    love.graphics.clear(COLOURS.bg[1], COLOURS.bg[2], COLOURS.bg[3], 1)
    if state.page == "home" then
        header("HOME", "Choose an emulator library")
        text("GAME LIBRARIES", 28, 92, SMALL, COLOURS.muted)
        local cards = {
            {title="GAMECUBE", desc="GameCube library and per-game settings", hint="GC"},
            {title="WII", desc="Wii library and per-game settings", hint="WII"},
            {title="SYSTEM", desc="Paths, build and configuration diagnostics", hint="INFO"}
        }
        for i, card in ipairs(cards) do
            local y = 126 + (i - 1) * 88
            panel(28, y, W - 56, 72, state.home_sel == i)
            text(card.hint, 45, y + 17, FONT, state.home_sel == i and COLOURS.accent or COLOURS.muted)
            text(card.title, 125, y + 12, FONT, COLOURS.text)
            text(card.desc, 125, y + 40, TINY, COLOURS.muted)
        end
    elseif state.page == "library" then
        header(state.system:upper(), "Select a game, then open its advanced settings")
        text("GAMES  ·  " .. #state.games .. " found", 24, 82, SMALL, COLOURS.muted)
        local first = math.max(1, state.game_sel - 7)
        local last = math.min(#state.games, first + 7)
        for i = first, last do
            local g = state.games[i]
            local y = 112 + (i - first) * 39
            panel(24, y, W - 48, 34, state.game_sel == i)
            text(g.title, 36, y + 8, SMALL, COLOURS.text, 390)
            text(g.id, 505, y + 9, TINY, COLOURS.accent)
        end
        text("L1 GAMECUBE     R1 WII     Y RESCAN", 28, 438, TINY, COLOURS.muted)
    elseif state.page == "settings" then
        local game = state.selected_game
        header("ADVANCED GAME SETTINGS", game and game.title or "")
        text((game and game.system:upper() or "") .. "  ·  " .. (game and game.id or ""),
            22, 75, TINY, COLOURS.muted)
        local tabs = table.concat(state.groups, "     ")
        text("L1/R1 SWITCH CATEGORY", 22, 94, TINY, COLOURS.muted)
        local group = active_group() or ""
        text(group, 22, 113, SMALL, COLOURS.accent)
        local rows = visible_options()
        local first = math.max(1, state.option_sel - 5)
        local last = math.min(#rows, first + 5)
        for i = first, last do
            local option = rows[i]
            local y = 144 + (i - first) * 43
            panel(22, y, W - 44, 38, state.option_sel == i)
            local value = get_value(game, option.key)
            text(option.label, 36, y + 5, SMALL, COLOURS.text, 340)
            text(choice_label(option, value), 420, y + 10, TINY, COLOURS.accent, 170)
            if state.option_sel == i then
                text(option.description, 32, 414, TINY, COLOURS.muted, W - 64)
            end
        end
        text("LEFT/RIGHT CHANGE VALUE   X CLEAR PER-GAME OVERRIDE",
            22, 438, TINY, COLOURS.muted)
    elseif state.page == "diagnostics" then
        header("SYSTEM DIAGNOSTICS", "Read-only device and configuration overview")
        local rows = {
            {"Firmware adapter", PLATFORM},
            {"User data", USERDATA},
            {"ROM root", ROM_ROOT},
            {"Settings file", CONF},
            {"Options in catalog", tostring((function()
                local n = 0; for _, items in pairs(state.options) do n = n + #items end; return n
            end)())},
            {"Dolphin executable", ROOT .. "/core/dolphin"}
        }
        for i, row in ipairs(rows) do
            local y = 102 + (i - 1) * 49
            panel(24, y, W - 48, 40, false)
            text(row[1], 38, y + 5, TINY, COLOURS.muted)
            text(row[2], 38, y + 20, TINY, COLOURS.text, W - 76)
        end
    end
    footer()
end

APP.scan = scan_system
APP.options = function() return state.options end
APP.get_value = get_value
APP.save_value = save_value
return APP
