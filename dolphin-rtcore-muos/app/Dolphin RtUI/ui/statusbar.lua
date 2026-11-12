-- ui/statusbar.lua — battery + wifi indicator, top-right corner.
local K = require("ui.kit")

local M = {}
M._bat = { level = nil, charging = false, present = false }
M._wifi = { up = false, quality = 0, ssid = nil }
M._last_poll = 0
M._polled = false
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
    -- /proc/net/wireless starts with a status bitfield (often "0000");
    -- that is not a connected/disconnected flag. Use carrier/operstate for link.
    local quality = 0
    local wl = read_file("/proc/net/wireless")
    if wl then
        for line in wl:gmatch("[^\n]+") do
            local iface, _, q = line:match("^%s*([%w_.%-]+):%s*([%x]+)%s*([%d%.]+)")
            if iface and (iface:match("^wlan") or iface:match("^wlp")) then
                quality = math.min(1, (tonumber(q) or 0) / 70)
                break
            end
        end
    end

    local h = io.popen(
        "for p in /sys/class/net/wlan* /sys/class/net/wlp*; do " ..
        "[ -d \"$p\" ] && basename \"$p\"; done 2>/dev/null | head -1")
    if not h then M._wifi.up = false; M._wifi.quality = 0; return end
    local iface = (h:read("*a") or ""):gsub("%s+", "")
    h:close()
    if iface == "" or not iface:match("^[%w_.%-]+$") then
        M._wifi.up, M._wifi.quality, M._wifi.ssid = false, 0, nil
        return
    end

    local base = "/sys/class/net/" .. iface
    local carrier = read_file(base .. "/carrier")
    local operstate = read_file(base .. "/operstate")
    if carrier then
        M._wifi.up = carrier:gsub("%s+", "") == "1"
    else
        M._wifi.up = operstate and operstate:gsub("%s+", "") == "up" or false
    end
    M._wifi.quality = M._wifi.up and quality or 0

    local iw = io.popen("iwgetid -r " .. iface .. " 2>/dev/null")
    if iw then
        local ssid = (iw:read("*a") or ""):gsub("[%r\n]+$", "")
        iw:close()
        M._wifi.ssid = ssid ~= "" and ssid or nil
    else
        M._wifi.ssid = nil
    end
end
function M.update(dt)
    M._last_poll = M._last_poll + dt
    if M._last_poll < M.POLL_INTERVAL then return end
    M._last_poll = 0
    pcall(poll_battery)
    pcall(poll_wifi)
    M._polled = true
end

function M.snapshot()
    return {
        checked = M._polled,
        wifi = { up = M._wifi.up == true, quality = tonumber(M._wifi.quality) or 0 },
        battery = {
            present = M._bat.present == true,
            level = M._bat.level,
            charging = M._bat.charging == true,
        },
    }
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
    draw_wifi(wifi_x, wifi_y, wifi_w, wifi_h)
    draw_battery(bat_x, bat_y, bat_w, bat_h)
end

return M
