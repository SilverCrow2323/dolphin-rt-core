-- ui/system_panel.lua — Rt:System Status Center.
-- M expands the global header into a readable, scrollable system dashboard.

local SFX = require("ui.sfx")
local Icons = require("ui.icons")
local Fonts = require("ui.theme.fonts")
local Hub = require("core.notification_hub")

local M = {}
local W, H = 640, 480
M._open, M._progress, M._t = false, 0, 0
M._sel, M._scroll = 1, 0
M._items, M._focus, M._positions = {}, {}, {}
M._content_h, M._viewport_h = 0, 0
M._refresh_t, M._last_stream_check = 0, 0
local _ops, _op_order = {}, {}
local GAP = 5

local C = {
    panel = {0.035, 0.045, 0.068},
    card = {0.075, 0.090, 0.125},
    card_alt = {0.055, 0.068, 0.098},
    line = {0.19, 0.23, 0.30},
    text = {0.94, 0.97, 1.00},
    dim = {0.63, 0.70, 0.82},
    faint = {0.42, 0.50, 0.63},
    cyan = {0.25, 0.78, 1.00},
    green = {0.30, 0.86, 0.48},
    amber = {1.00, 0.72, 0.25},
    red = {1.00, 0.36, 0.36},
    purple = {0.70, 0.52, 1.00},
}

local function color(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

local function font(name, size)
    return Fonts.get("assets/fonts/" .. name, size)
end

local function text(value, x, y, f, c)
    love.graphics.setFont(f)
    color(c or C.text)
    love.graphics.print(tostring(value or ""), x, y)
end

local function right_text(value, x, y, w, f, c)
    love.graphics.setFont(f)
    color(c or C.text)
    love.graphics.printf(tostring(value or ""), x, y, w, "right")
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function file_detail(size)
    size = tonumber(size) or 0
    if size >= 1024 * 1024 then return string.format("%.1f MB local", size / (1024 * 1024)) end
    if size >= 1024 then return string.format("%.0f KB local", size / 1024) end
    if size > 0 then return tostring(size) .. " B local" end
    return "Local file"
end

local function db_state(db)
    if type(db) ~= "table" then return "UNKNOWN", C.faint, "Status unavailable" end
    local states = {
        updated = {"UPDATED", C.green, "Downloaded in this session"},
        cached = {"CACHED", C.cyan, file_detail(db.size)},
        retained = {"PREVIOUS COPY", C.amber, "Update failed; existing file retained"},
        downloading = {"DOWNLOADING", C.cyan, "Background transfer in progress"},
        failed = {"MISSING", C.red, "No validated local database"},
        missing = {"MISSING", C.red, "No local database found"},
        not_checked = {"NOT CHECKED", C.faint, "Waiting for boot sequence"},
    }
    local row = states[db.state]
    if row then
        if db.state == "updated" then row[3] = file_detail(db.size) .. " · updated this boot" end
        return row[1], row[2], row[3]
    end
    return "UNKNOWN", C.faint, file_detail(db.size)
end

local function stream_state(health, configured, pending)
    if not configured then return "NOT CONFIGURED", C.faint end
    if pending then return "CHECKING", C.cyan end
    local state = tostring(health or "unknown"):lower()
    if state == "online" or state == "ok" or state == "ready" then return "ONLINE", C.green end
    if state == "offline" or state == "error" or state == "failed" or state == "fail" then return "OFFLINE", C.red end
    return "UNKNOWN", C.faint
end

local function add(item)
    item.height = item.height or 39
    M._items[#M._items + 1] = item
end

local function add_section(label)
    add({kind = "section", title = label, height = 20})
end

local function add_status(title, status, accent, detail, id)
    add({kind = "status", title = title, status = status, accent = accent,
         detail = detail, id = id, height = 43, focusable = true})
end

local function refresh_stream()
    local ok, Stream = pcall(require, "core.stream")
    if not ok or type(Stream) ~= "table" then
        return {configured = false, health = {}, pending = false}
    end
    local configured = false
    pcall(function() configured = Stream.configured() end)
    if configured then
        pcall(function() Stream.poll_health() end)
        local h = Stream.health or {}
        local now = os.time()
        if not h.pending and (M._last_stream_check == 0 or now - M._last_stream_check >= 25
            or h.library == "unknown" or h.sunshine == "unknown") then
            local started = pcall(function() Stream.check_health() end)
            if started then M._last_stream_check = now end
        end
        pcall(function() Stream.poll_health() end)
    end
    return {configured = configured, health = Stream.health or {},
            pending = Stream.health and Stream.health.pending or false}
end

local function refresh_items()
    M._items, M._focus, M._positions = {}, {}, {}
    local ok_bar, Bar = pcall(require, "ui.statusbar")
    local device = {checked = false, wifi = {}, battery = {}}
    if ok_bar and Bar and Bar.snapshot then
        local ok, value = pcall(Bar.snapshot)
        if ok and type(value) == "table" then device = value end
    end

    local ok_boot, Boot = pcall(require, "core.boot_initializer")
    local boot = {}
    if ok_boot and Boot and Boot.snapshot then
        local ok, value = pcall(Boot.snapshot)
        if ok and type(value) == "table" then boot = value end
    end

    local stream = refresh_stream()

    add_section("DEVICE & NETWORK")
    local wifi_status, wifi_color, wifi_detail
    if not device.checked then
        wifi_status, wifi_color, wifi_detail = "CHECKING", C.cyan, "Reading wireless interface"
    elseif device.wifi and device.wifi.up then
        local q = math.floor((tonumber(device.wifi.quality) or 0) * 100 + 0.5)
        wifi_status, wifi_color = "CONNECTED", C.green
        wifi_detail = q > 0 and ("Wi-Fi link · signal " .. q .. "%") or "Wi-Fi link active"
        local ssid = tostring(device.wifi.ssid or ""):gsub("[%c]", " ")
        if ssid ~= "" then wifi_detail = wifi_detail .. " · " .. ssid:sub(1, 22) end
    else
        wifi_status, wifi_color, wifi_detail = "OFFLINE", C.red, "No active Wi-Fi link detected"
    end

    local bat_status, bat_color, bat_detail
    local b = device.battery or {}
    if not device.checked then
        bat_status, bat_color, bat_detail = "CHECKING", C.cyan, "Reading power supply"
    elseif b.present and b.level ~= nil then
        bat_status = tostring(math.floor(tonumber(b.level) or 0)) .. "%"
        bat_color = (b.level < 20 and C.red) or (b.level < 50 and C.amber) or C.green
        bat_detail = b.charging and "Charging" or "Battery level"
    else
        bat_status, bat_color, bat_detail = "UNKNOWN", C.faint, "Battery telemetry unavailable"
    end
    add({kind = "pair",
         left = {title = "WI-FI LINK", status = wifi_status, accent = wifi_color, detail = wifi_detail},
         right = {title = "BATTERY", status = bat_status, accent = bat_color, detail = bat_detail},
         height = 62, focusable = true})

    add_section("RT:STREAM / SERVER")
    local portal, portal_color = stream_state(stream.health.library, stream.configured, stream.pending)
    local sunshine, sunshine_color = stream_state(stream.health.sunshine, stream.configured, stream.pending)
    local host_detail = "PC portal library"
    pcall(function()
        local St = require("core.stream")
        if St.s and St.s.HOST and St.s.HOST ~= "" then host_detail = "Host " .. tostring(St.s.HOST) end
    end)
    add_status("Portal Library", portal, portal_color, host_detail, "portal")
    add_status("Sunshine", sunshine, sunshine_color, "Streaming host service", "sunshine")

    add_section("DATA CENTER")
    local databases = boot.databases or {}
    local title_map = {
        {key = "games_data", title = "Compatibility Database"},
        {key = "gamesettings_json", title = "GameSettings Database"},
        {key = "rtcheats_db", title = "Cheats & Boost Database"},
    }
    for _, spec in ipairs(title_map) do
        local state, accent, detail = db_state(databases[spec.key])
        add_status(spec.title, state, accent, detail, spec.key)
    end

    local dep = boot.gamesets or {}
    local dep_status, dep_color, dep_detail
    if dep.status == "running" then
        dep_status, dep_color, dep_detail = "DEPLOYING", C.cyan, "Applying community GameSettings"
    elseif dep.status == "complete" then
        dep_status, dep_color = "READY", C.green
        dep_detail = tostring(dep.deployed or 0) .. " preset(s) deployed this boot"
    elseif dep.status == "timeout" then
        dep_status, dep_color, dep_detail = "TIMEOUT", C.amber, "Some presets may still be available"
    elseif dep.status == "unavailable" then
        dep_status, dep_color, dep_detail = "UNAVAILABLE", C.amber, "GameSettings deployer could not start"
    else
        dep_status, dep_color, dep_detail = "WAITING", C.faint, "Deployment follows database download"
    end
    add_status("GameSettings Deployment", dep_status, dep_color, dep_detail, "gamesets")

    local cheat = boot.cheats or {}
    local cheat_labels = {
        running = {"DOWNLOADING", C.cyan, "Checking per-game cheat and boost files"},
        complete = {"READY", C.green, "Cheat database check completed"},
        timeout = {"TIMEOUT", C.amber, "Some titles may not have refreshed"},
        unavailable = {"UNAVAILABLE", C.amber, "Cheat downloader could not start"},
        waiting = {"WAITING", C.faint, "Runs after GameSettings deployment"},
    }
    local cheat_row = cheat_labels[cheat.status or "waiting"] or cheat_labels.waiting
    add_status("Cheats & Boost Data", cheat_row[1], cheat_row[2], cheat_row[3], "cheats")

    local lib_count = tonumber(boot.roms) or 0
    local lib_status, lib_accent, lib_detail = "UNKNOWN", C.faint, "Library status unavailable"
    local ok_lib, Library = pcall(require, "core.library")
    local step = tostring(boot.step or "idle")
    if step == "scan_roms" then
        lib_status, lib_accent, lib_detail = "SCANNING", C.cyan, "Indexing GameCube / Wii ROMs"
    elseif step == "idle" or step == "update_check" or step == "wait_update" or step == "download_data" then
        lib_status, lib_accent, lib_detail = "WAITING", C.faint, "ROM scan has not run yet"
    elseif ok_lib and Library then
        lib_count = math.max(lib_count, #(Library.games or {}))
        lib_status, lib_accent = "INDEXED", C.green
        lib_detail = tostring(lib_count) .. " GameCube / Wii titles indexed"
    end
    add_status("Games Library", lib_status, lib_accent, lib_detail, "library")

    add_section("BACKGROUND OPERATIONS")
    local active_ops = 0
    for _, id in ipairs(_op_order) do
        if _ops[id] then active_ops = active_ops + 1 end
    end
    if active_ops == 0 then
        add({kind = "empty", title = "No background operations", detail = "Downloads and scans will appear here", height = 36})
    else
        for _, id in ipairs(_op_order) do
            local op = _ops[id]
            if op then add({kind = "operation", op = op, height = 50, focusable = true}) end
        end
    end

    add_section("NOTIFICATION HISTORY")
    local history = Hub.history()
    if #history == 0 then
        add({kind = "empty", title = "No notifications yet", detail = "System events will be recorded here", height = 36})
    else
        for i, entry in ipairs(history) do
            add({kind = "notification", entry = entry, height = 48, focusable = true})
            if i >= 40 then break end
        end
    end

    local y = 0
    for i, item in ipairs(M._items) do
        M._positions[i] = y
        if item.focusable then M._focus[#M._focus + 1] = i end
        y = y + item.height + GAP
    end
    M._content_h = math.max(0, y - GAP)
    M._sel = clamp(M._sel, 1, math.max(1, #M._focus))
    M._scroll = clamp(M._scroll, 0, math.max(0, M._content_h - M._viewport_h))
end

local function ensure_visible()
    local idx = M._focus[M._sel]
    if not idx then return end
    local top = M._positions[idx] or 0
    local bottom = top + (M._items[idx] and M._items[idx].height or 0)
    if top < M._scroll then M._scroll = top
    elseif bottom > M._scroll + M._viewport_h then M._scroll = bottom - M._viewport_h end
    M._scroll = clamp(M._scroll, 0, math.max(0, M._content_h - M._viewport_h))
end

function M.init()
    M._open, M._progress, M._t = false, 0, 0
    M._sel, M._scroll = 1, 0
    M._refresh_t, M._last_stream_check = 0, 0
    M._items, M._focus, M._positions = {}, {}, {}
    _ops, _op_order = {}, {}
end

function M.is_open() return M._open end

function M.open()
    if M._open then return end
    M._open = true
    M._sel, M._scroll, M._refresh_t = 1, 0, 1
    refresh_items()
    SFX.play("menu_flip")
end

function M.close()
    if not M._open then return end
    M._open = false
    SFX.play("menu_back")
end

function M.toggle()
    if M._open then M.close() else M.open() end
end

function M.operation_start(id, name, opts)
    opts = opts or {}
    if not _ops[id] then table.insert(_op_order, id) end
    _ops[id] = {id = id, name = name or id,
        progress = math.max(0, math.min(1, tonumber(opts.progress) or 0)),
        status = "running", detail = opts.detail or "",
        ttl_done = opts.ttl_done or 4, started = os.time(), updated = os.time()}
    if M._open then refresh_items() end
end

function M.operation_progress(id, p, detail)
    local o = _ops[id]
    if not o then return end
    if p then o.progress = math.max(0, math.min(1, tonumber(p) or o.progress)) end
    if detail then o.detail = detail end
    o.updated = os.time()
end

function M.operation_done(id, status)
    local o = _ops[id]
    if not o then return end
    o.status = status or "done"
    o.progress = 1
    o.updated = os.time()
end

function M.operation_remove(id)
    if _ops[id] then
        _ops[id] = nil
        for i, key in ipairs(_op_order) do
            if key == id then table.remove(_op_order, i); break end
        end
        if M._open then refresh_items() end
    end
end

function M.update(dt)
    M._t = M._t + dt
    local target = M._open and 1 or 0
    M._progress = M._progress + (target - M._progress) * math.min(1, dt * 10)
    if math.abs(M._progress - target) < 0.005 then M._progress = target end

    local now = os.time()
    for id, op in pairs(_ops) do
        if op.status ~= "running" and now - (op.updated or now) > (op.ttl_done or 4) then
            M.operation_remove(id)
        end
    end

    if M._open then
        M._refresh_t = M._refresh_t + dt
        if M._refresh_t >= 0.75 then
            M._refresh_t = 0
            refresh_items()
            ensure_visible()
        end
    end
end

local TYPE_COLORS = {
    info = C.cyan, success = C.green, warning = C.amber,
    error = C.red, update = C.purple, download = C.cyan, scan = C.amber,
}
local TYPE_ICON = {
    info = "info", success = "check", warning = "warning",
    error = "error", update = "update", download = "save", scan = "library",
}

local function chamfer(mode, x, y, w, h, cut)
    cut = cut or 5
    love.graphics.polygon(mode, x + cut, y, x + w - cut, y, x + w, y + cut,
        x + w, y + h - cut, x + w - cut, y + h, x + cut, y + h,
        x, y + h - cut, x, y + cut)
end

local function draw_card(x, y, w, h, title, status, accent, detail)
    color(C.card, 0.98); chamfer("fill", x, y, w, h, 6)
    color(C.line, 0.9); love.graphics.setLineWidth(1); chamfer("line", x, y, w, h, 6)
    text(title, x + 10, y + 6, font("JetBrainsMono-Bold.ttf", 11), C.dim)
    text(status, x + 10, y + 22, font("Orbitron-Bold.ttf", 15), accent)
    love.graphics.setFont(font("JetBrainsMono-Regular.ttf", 10))
    color(C.faint)
    love.graphics.printf(detail or "", x + 10, y + h - 15, w - 20, "left")
end

local function draw_section(item, x, y, w)
    local f = font("JetBrainsMono-Bold.ttf", 11)
    text(item.title, x + 2, y + 1, font("JetBrainsMono-Bold.ttf", 12), C.cyan)
    color(C.line, 0.75)
    love.graphics.rectangle("fill", x + 4 + f:getWidth(item.title), y + 9,
        math.max(8, w - f:getWidth(item.title) - 12), 1)
end

local function draw_status(item, x, y, w, h, focused)
    color(focused and {0.11, 0.14, 0.19} or C.card, 0.98)
    chamfer("fill", x, y, w, h, 5)
    if focused then color(item.accent or C.cyan, 1); love.graphics.rectangle("fill", x, y + 5, 3, h - 10, 1, 1) end
    text(item.title, x + 11, y + 5, font("Orbitron-Bold.ttf", 13), focused and C.text or C.dim)
    right_text(item.status or "UNKNOWN", x + w - 174, y + 5, 162,
        font("JetBrainsMono-Regular.ttf", 12), item.accent or C.faint)
    love.graphics.setFont(font("JetBrainsMono-Regular.ttf", 10))
    color(C.faint)
    love.graphics.printf(item.detail or "", x + 11, y + 23, w - 22, "left")
end

local function draw_operation(item, x, y, w, h, focused)
    local op = item.op
    local accent = (op.status == "error" and C.red) or (op.status == "done" and C.green) or C.cyan
    color(focused and {0.11, 0.14, 0.19} or C.card, 0.98)
    chamfer("fill", x, y, w, h, 5)
    text(op.name, x + 10, y + 5, font("Orbitron-Bold.ttf", 13), C.text)
    love.graphics.setFont(font("JetBrainsMono-Regular.ttf", 10))
    color(C.dim)
    love.graphics.printf(op.detail ~= "" and op.detail or op.status:upper(), x + 10, y + 22, w - 20, "left")
    local px, py, pw = x + 10, y + h - 9, w - 20
    color(C.line); love.graphics.rectangle("fill", px, py, pw, 4, 2, 2)
    color(accent); love.graphics.rectangle("fill", px, py, pw * (op.progress or 0), 4, 2, 2)
end

local function draw_notification(item, x, y, w, h, focused)
    local entry = item.entry
    local accent = TYPE_COLORS[entry.kind] or C.cyan
    color(focused and {0.12, 0.15, 0.21} or C.card_alt, 0.98)
    chamfer("fill", x, y, w, h, 5)
    if focused then color(accent); love.graphics.rectangle("fill", x, y + 5, 3, h - 10, 1, 1) end
    Icons.draw(TYPE_ICON[entry.kind] or "info", x + 12, y + 14, 19, accent)
    text(entry.title or "Notification", x + 40, y + 5,
        font("Orbitron-Bold.ttf", 12), focused and C.text or C.dim)
    love.graphics.setFont(font("JetBrainsMono-Regular.ttf", 10)); color(C.dim)
    love.graphics.print(entry.subtitle or "", x + 40, y + 24)
    right_text(os.date("%H:%M", entry.ts or os.time()), x + w - 62, y + 6, 52,
        font("JetBrainsMono-Regular.ttf", 10), C.faint)
end

function M.draw(W_, H_)
    W, H = W_ or W, H_ or H
    if M._progress < 0.005 then return end

    local p = M._progress
    local panel_h = math.min(424, H - 18)
    local py = -panel_h + panel_h * p
    local header_h, footer_h = 48, 30
    local list_top = py + header_h
    local list_bottom = py + panel_h - footer_h
    M._viewport_h = list_bottom - list_top
    M._scroll = clamp(M._scroll, 0, math.max(0, M._content_h - M._viewport_h))

    color({0, 0, 0}, 0.48 * p)
    love.graphics.rectangle("fill", 0, 0, W, H)
    color(C.panel, 0.99 * p)
    love.graphics.rectangle("fill", 0, py, W, panel_h)
    color(C.cyan, p); love.graphics.rectangle("fill", 0, py + panel_h - 2, W, 2)

    color(C.card_alt, p); love.graphics.rectangle("fill", 0, py, W, header_h)
    text("RT:SYSTEM STATUS CENTER", 14, py + 7, font("Orbitron-Bold.ttf", 16), C.cyan)
    right_text(os.date("%H:%M"), W - 78, py + 9, 64,
        font("JetBrainsMono-Bold.ttf", 13), C.text)
    text("M", W - 20, py + 10, font("Orbitron-Bold.ttf", 12), C.amber)

    love.graphics.setScissor(0, list_top, W, M._viewport_h)
    local origin_y = list_top - M._scroll
    for i, item in ipairs(M._items) do
        local y = origin_y + (M._positions[i] or 0)
        if y + item.height >= list_top and y <= list_bottom then
            local focused = M._focus[M._sel] == i
            if item.kind == "section" then
                draw_section(item, 12, y, W - 24)
            elseif item.kind == "pair" then
                local gap = 8
                local cw = (W - 24 - gap) / 2
                draw_card(12, y, cw, item.height, item.left.title, item.left.status,
                          item.left.accent, item.left.detail)
                draw_card(12 + cw + gap, y, cw, item.height, item.right.title,
                          item.right.status, item.right.accent, item.right.detail)
            elseif item.kind == "status" then
                draw_status(item, 12, y, W - 24, item.height, focused)
            elseif item.kind == "operation" then
                draw_operation(item, 12, y, W - 24, item.height, focused)
            elseif item.kind == "notification" then
                draw_notification(item, 12, y, W - 24, item.height, focused)
            elseif item.kind == "empty" then
                color(C.card_alt); chamfer("fill", 12, y, W - 24, item.height, 5)
                text(item.title, 22, y + 4, font("Orbitron-Bold.ttf", 12), C.dim)
                text(item.detail, 22, y + 20, font("JetBrainsMono-Regular.ttf", 10), C.faint)
            end
        end
    end
    love.graphics.setScissor()

    local rail_x, rail_y, rail_h = W - 5, list_top + 4, math.max(8, M._viewport_h - 8)
    if M._content_h > M._viewport_h then
        color(C.line, 0.8); love.graphics.rectangle("fill", rail_x, rail_y, 2, rail_h, 1, 1)
        local thumb_h = math.max(24, rail_h * M._viewport_h / M._content_h)
        local max_scroll = M._content_h - M._viewport_h
        local thumb_y = rail_y + (rail_h - thumb_h) * (M._scroll / max_scroll)
        color(C.cyan, 0.95); love.graphics.rectangle("fill", rail_x, thumb_y, 2, thumb_h, 1, 1)
    end

    color(C.card_alt, 0.98); love.graphics.rectangle("fill", 0, py + panel_h - footer_h, W, footer_h)
    text("↑↓", 12, py + panel_h - 22, font("JetBrainsMono-Bold.ttf", 12), C.cyan)
    text("SCROLL", 39, py + panel_h - 22, font("JetBrainsMono-Regular.ttf", 10), C.dim)
    text("A", 110, py + panel_h - 22, font("JetBrainsMono-Bold.ttf", 12), C.amber)
    text("DISMISS", 126, py + panel_h - 22, font("JetBrainsMono-Regular.ttf", 10), C.dim)
    text("X", 207, py + panel_h - 22, font("JetBrainsMono-Bold.ttf", 12), C.amber)
    text("CLEAR", 223, py + panel_h - 22, font("JetBrainsMono-Regular.ttf", 10), C.dim)
    text("M / B", W - 82, py + panel_h - 22, font("JetBrainsMono-Bold.ttf", 11), C.cyan)
    text("CLOSE", W - 43, py + panel_h - 21, font("JetBrainsMono-Regular.ttf", 9), C.dim)
    love.graphics.setColor(1, 1, 1, 1)
end

local function move_selection(delta)
    if #M._focus == 0 then return end
    M._sel = clamp(M._sel + delta, 1, #M._focus)
    ensure_visible()
    SFX.play("menu_move")
end

function M.pad(b)
    if not M._open then return end
    if b == "UP" then
        move_selection(-1)
    elseif b == "DOWN" then
        move_selection(1)
    elseif b == "LEFT" then
        M._scroll = clamp(M._scroll - M._viewport_h * 0.75, 0,
                          math.max(0, M._content_h - M._viewport_h))
    elseif b == "RIGHT" then
        M._scroll = clamp(M._scroll + M._viewport_h * 0.75, 0,
                          math.max(0, M._content_h - M._viewport_h))
    elseif b == "A" then
        local idx = M._focus[M._sel]
        local item = idx and M._items[idx]
        if item and item.kind == "notification" and item.entry then
            Hub.remove_history(item.entry.id)
            SFX.play("menu_select")
            refresh_items()
        end
    elseif b == "X" then
        Hub.clear_active()
        Hub.clear_history()
        M._sel, M._scroll = 1, 0
        SFX.play("menu_flip")
        refresh_items()
    elseif b == "MENU" or b == "B" then
        M.close()
    end
end

function M.key(k)
    if not M._open then return end
    if k == "up" then M.pad("UP")
    elseif k == "down" then M.pad("DOWN")
    elseif k == "left" then M.pad("LEFT")
    elseif k == "right" then M.pad("RIGHT")
    elseif k == "return" or k == "space" then M.pad("A")
    elseif k == "x" then M.pad("X")
    elseif k == "escape" or k == "m" then M.close() end
end

function M.notify(kind, message)
    Hub.push(kind or "info", kind or "Info", message or "", {ttl = 4})
end

return M
