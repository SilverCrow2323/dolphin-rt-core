-- ui/statusbar.lua — battery + wifi indicator, top-right corner.
local K = require("ui.kit")

local M = {}
M._bat = { level = nil, charging = false, present = false }
M._wifi = { up = false, quality = 0, ssid = nil }
M._net = { ip = nil, tailscale = nil }
M._sunshine = "unknown"
M._stream_poll = 0
M._last_poll = 0
M.POLL_INTERVAL = 1.0

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local c = f:read("*a"); f:close()
    return c
end

local function poll_battery()
    -- cerca BAT0, BAT1, battery, axp20x-battery, ...
    local h = io.popen("ls -1 /sys/class/power_supply/ 2>/dev/null | grep -iE 'bat|battery|axp' | head -1")
    if not h then M._bat.present = false; return end
    local dev = (h:read("*a") or ""):gsub("%s+", "")
    h:close()
    if dev == "" then M._bat.present = false; return end
    local base = "/sys/class/power_supply/" .. dev
    local cap = read_file(base .. "/capacity")
    if not cap then M._bat.present = false; return end
    M._bat.present = true
    M._bat.level = tonumber((cap:gsub("%s+", ""))) or 0
    local st = read_file(base .. "/status")
    M._bat.charging = st and (st:lower():find("charging") ~= nil) or false
end

local function poll_wifi()
    local wl = read_file("/proc/net/wireless")
    if not wl then M._wifi.up = false; return end
    -- cerca la prima riga con wlanX:
    for line in wl:gmatch("[^\n]+") do
        local iface, status, qual = line:match("^%s*(%w+):%s*(%w+)%s*([%d%.]+)")
        if iface and iface:match("^wlan") then
            M._wifi.up = (status ~= "0000")
            -- quality può essere "56." (su 70) o "56/70"
            local q = tonumber(qual) or 0
            M._wifi.quality = math.min(1, q / 70)
            return
        end
    end
    -- fallback: cerca una interfaccia con operstate=up
    local h = io.popen("ls -1 /sys/class/net/ 2>/dev/null | grep -E '^wlan|^wlp' | head -1")
    if h then
        local iface = (h:read("*a") or ""):gsub("%s+", "")
        h:close()
        if iface ~= "" then
            local op = read_file("/sys/class/net/" .. iface .. "/operstate")
            M._wifi.up = op and op:lower():find("up") ~= nil or false
            M._wifi.quality = M._wifi.up and 0.6 or 0
        end
    end
end

local function poll_network()
    local h = io.popen("ip -4 -o addr show scope global 2>/dev/null")
    local chosen
    if h then
        for line in h:lines() do
            local iface, addr = line:match("%d+:%s+([%w_.%-]+)%s+inet%s+([%d%.]+)/")
            if iface and addr and iface ~= "lo" and not iface:match("^tailscale") then
                chosen = addr
                if iface:match("^wlan") then break end
            end
        end
        h:close()
    end
    M._net.ip = chosen
    local ts = io.popen("command -v tailscale >/dev/null 2>&1 && tailscale ip -4 2>/dev/null | head -1")
    if ts then
        local value = (ts:read("*a") or ""):gsub("%s+", "")
        ts:close()
        M._net.tailscale = value ~= "" and value or nil
    else
        M._net.tailscale = nil
    end
end

local function poll_stream()
    local ok, Stream = pcall(require, "core.stream")
    if not ok or not Stream then M._sunshine = "unknown"; return end
    if not Stream._statusbar_initialized then
        Stream._statusbar_initialized = pcall(Stream.init)
    end
    pcall(Stream.poll_health)
    if Stream.configured() and not Stream.health.pending then Stream.check_health() end
    M._sunshine = Stream.health.sunshine or "unknown"
end

function M.update(dt)
    M._last_poll = M._last_poll + dt
    if M._last_poll < M.POLL_INTERVAL then return end
    M._last_poll = 0
    pcall(poll_battery)
    pcall(poll_wifi)
    pcall(poll_network)
    M._stream_poll = M._stream_poll + 1
    if M._stream_poll >= 5 then
        M._stream_poll = 0
        pcall(poll_stream)
    end
end

-- ── icone ─────────────────────────────────────────────────
local function draw_battery(x, y, w, h)
    local b = M._bat
    local body_w = w
    local tip_w = 2
    -- contorno
    K.color(K.C.line, 0.9)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", x, y, body_w, h, 2, 2)
    love.graphics.rectangle("fill", x + body_w + 1, y + h/4, tip_w, h/2, 1, 1)
    love.graphics.setLineWidth(1)

    if not b.present or not b.level then
        -- sconosciuta
        K.color(K.C.faint, 0.7)
        love.graphics.print("?", x + body_w/2 - 4, y + h/2 - 7)
        return
    end

    -- colore in base al livello
    local c
    if b.level >= 50 then c = K.C.ok
    elseif b.level >= 20 then c = K.C.warn
    else c = K.C.bad end
    if b.charging then c = { 0.35, 0.75, 1.00 } end

    -- riempimento proporzionale
    local pad = 2
    local inner_w = body_w - pad * 2
    local fill_w = inner_w * (b.level / 100)
    if fill_w > 0 then
        K.color(c, 1)
        love.graphics.rectangle("fill", x + pad, y + pad, fill_w, h - pad * 2, 1, 1)
    end

    -- testo livello (piccolo)
    local txt = tostring(math.floor(b.level)) .. "%"
    K.text("key", txt, x + body_w + 6, y - 1, c or K.C.text)
end

local function draw_wifi(x, y, w, h)
    local wf = M._wifi
    local bars = 0
    if wf.up then
        if wf.quality >= 0.7 then bars = 3
        elseif wf.quality >= 0.4 then bars = 2
        else bars = 1 end
    end
    local base_y = y + h
    local bar_w = 3
    local gap = 2
    for i = 1, 3 do
        local bx = x + (i - 1) * (bar_w + gap)
        local bh = 3 + i * 2
        local by = base_y - bh
        if i <= bars then
            K.color(K.C.ok, 1)
            love.graphics.rectangle("fill", bx, by, bar_w, bh, 1, 1)
        else
            K.color(K.C.line, 0.55)
            love.graphics.rectangle("fill", bx, by, bar_w, bh, 1, 1)
        end
    end
    if not wf.up then
        -- piccola X sopra se spento
        K.color(K.C.bad, 0.8)
        love.graphics.setLineWidth(1.4)
        love.graphics.line(x - 2, y - 2, x + 15, y + h + 1)
        love.graphics.setLineWidth(1)
    end
end

function M.draw(W, H)
    W = W or K.W or 640
    H = H or K.H or 480
    -- posizione: in alto a destra, con margine
    local margin = 8
    local y0 = 8
    local bat_x = W - margin - 26
    local bat_y = y0 + 2
    local bat_w = 20
    local bat_h = 11
    local wifi_x = bat_x - 34
    local wifi_y = y0 + 1
    local wifi_w = 14
    local wifi_h = 12
    local ip = M._net.ip or "NO IP"
    K.text("mono", "IP " .. ip, W - 310, y0 + 2, M._net.ip and K.C.dim or K.C.bad)
    local tx = W - 160
    K.color(M._net.tailscale and K.C.ok or K.C.faint, 1)
    love.graphics.circle("fill", tx, y0 + 8, 3)
    K.text("key", "TS", tx + 7, y0 + 1, M._net.tailscale and K.C.ok or K.C.faint)
    local sx = W - 112
    local sun_ok = M._sunshine == "ok"
    local sun_fail = M._sunshine == "fail"
    K.color(sun_ok and K.C.ok or (sun_fail and K.C.bad or K.C.warn), 1)
    love.graphics.circle("fill", sx, y0 + 8, 3)
    K.text("key", "SUN", sx + 7, y0 + 1, sun_ok and K.C.ok or (sun_fail and K.C.bad or K.C.dim))
    draw_wifi(wifi_x, wifi_y, wifi_w, wifi_h)
    draw_battery(bat_x, bat_y, bat_w, bat_h)
end

return M
