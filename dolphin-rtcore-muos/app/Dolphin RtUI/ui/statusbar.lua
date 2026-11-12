-- ui/statusbar.lua — battery, Wi-Fi, device IP and Rt:Stream service health.
local K = require("ui.kit")
local M = {}
M._bat = { level = nil, charging = false, present = false }
M._wifi = { up = false, quality = 0, ssid = nil }
M._network = { ip = nil, tailscale = nil }
M._stream = { library = "unknown", sunshine = "unknown" }
M._last_poll, M._stream_poll, M._stream_ready = 0, 0, false
M.POLL_INTERVAL = 1.0

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local c = f:read("*a"); f:close(); return c
end
local function command_first(cmd)
    local h = io.popen(cmd .. " 2>/dev/null")
    if not h then return nil end
    local v = (h:read("*l") or ""):gsub("^%s+", ""):gsub("%s+$", "")
    h:close()
    return v ~= "" and v or nil
end
local function poll_battery()
    local dev = command_first("ls -1 /sys/class/power_supply/ | grep -iE 'bat|battery|axp' | head -1")
    if not dev then M._bat.present = false; return end
    local base = "/sys/class/power_supply/" .. dev
    local cap = read_file(base .. "/capacity")
    if not cap then M._bat.present = false; return end
    M._bat.present = true
    M._bat.level = tonumber((cap:gsub("%s+", ""))) or 0
    local st = read_file(base .. "/status")
    M._bat.charging = st and st:lower():find("charging") ~= nil or false
end
local function interface_is_up(iface)
    if type(iface) ~= "string" or not iface:match("^[%w_.%-]+$") then return false end
    local op = read_file("/sys/class/net/" .. iface .. "/operstate")
    op = op and op:gsub("^%s+", ""):gsub("%s+$", ""):lower() or ""
    if op == "up" then return true end
    if op == "down" or op == "dormant" or op == "lowerlayerdown" then return false end
    local carrier = read_file("/sys/class/net/" .. iface .. "/carrier")
    carrier = carrier and carrier:gsub("%s+", "") or ""
    return carrier == "1"
end

local function poll_wifi()
    local wl = read_file("/proc/net/wireless") or ""
    for line in wl:gmatch("[^\n]+") do
        local iface, qual = line:match("^%s*([%w_.%-]+):%s*[%x]+%s*([%d%.]+)")
        if iface and (iface:match("^wlan") or iface:match("^wlp") or iface:match("^wl")) then
            M._wifi.iface = iface
            M._wifi.up = interface_is_up(iface)
            M._wifi.quality = math.min(1, math.max(0, (tonumber(qual) or 0) / 70))
            return
        end
    end
    local iface = command_first("ls -1 /sys/class/net/ | grep -E '^(wlan|wlp|wl)' | head -1")
    M._wifi.iface = iface
    M._wifi.up = iface and interface_is_up(iface) or false
    M._wifi.quality = M._wifi.up and 0.6 or 0
end

local function poll_network()
    local ip = command_first("ip -4 route get 1.1.1.1 | sed -n 's/.* src \\([^ ]*\\).*/\\1/p' | head -1")
    if not ip then ip = command_first("hostname -I | awk '{print $1}'") end
    M._network.ip = ip
    M._network.tailscale = command_first("command -v tailscale >/dev/null 2>&1 && tailscale ip -4 | head -1")
end
local function poll_stream(dt)
    local ok, Stream = pcall(require, "core.stream")
    if not ok then return end
    if not M._stream_ready then M._stream_ready = pcall(Stream.init) end
    if M._stream_ready then
        Stream.poll_health()
        M._stream = Stream.health or M._stream
        M._stream_poll = M._stream_poll + (dt or 0)
        if Stream.configured() and M._stream_poll >= 5 and not Stream.health.pending then
            M._stream_poll = 0
            Stream.check_health()
        end
    end
end
function M.update(dt)
    M._last_poll = M._last_poll + dt
    pcall(poll_stream, dt)
    if M._last_poll < M.POLL_INTERVAL then return end
    M._last_poll = 0
    pcall(poll_battery); pcall(poll_wifi); pcall(poll_network)
end
local function draw_battery(x, y, w, h)
    local b = M._bat
    K.color(K.C.line, 0.9); love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", x, y, w, h, 2, 2)
    love.graphics.rectangle("fill", x + w + 1, y + h/4, 2, h/2, 1, 1)
    love.graphics.setLineWidth(1)
    if not b.present or not b.level then K.color(K.C.faint, 0.7); love.graphics.print("?", x + w/2 - 4, y + h/2 - 7); return end
    local c = b.charging and {0.35,0.75,1.00} or (b.level >= 50 and K.C.ok or (b.level >= 20 and K.C.warn or K.C.bad))
    local fill_w = (w - 4) * (b.level / 100)
    if fill_w > 0 then K.color(c, 1); love.graphics.rectangle("fill", x + 2, y + 2, fill_w, h - 4, 1, 1) end
    K.text("key", tostring(math.floor(b.level)) .. "%", x + w + 6, y - 1, c)
end
local function draw_wifi(x, y, h)
    local wf, bars = M._wifi, 0
    if wf.up then bars = wf.quality >= 0.7 and 3 or (wf.quality >= 0.4 and 2 or 1) end
    for i = 1, 3 do
        local bx, bh = x + (i - 1) * 5, 3 + i * 2
        K.color(i <= bars and K.C.ok or K.C.line, i <= bars and 1 or 0.55)
        love.graphics.rectangle("fill", bx, y + h - bh, 3, bh, 1, 1)
    end
    if not wf.up then K.color(K.C.bad, 0.8); love.graphics.setLineWidth(1.4); love.graphics.line(x - 2, y - 2, x + 15, y + h + 1); love.graphics.setLineWidth(1) end
end
local function led(x, y, state, label)
    local c = state == "ok" and K.C.ok or (state == "fail" and K.C.bad or K.C.faint)
    K.color(c, state == "unknown" and 0.45 or 1)
    love.graphics.circle("fill", x, y + 7, 3)
    K.text("key", label, x + 6, y, state == "ok" and c or K.C.dim)
end
function M.draw(W, H)
    W, H = W or K.W or 640, H or K.H or 480
    local y, bat_x = 8, W - 34
    draw_battery(bat_x, y + 2, 20, 11)
    draw_wifi(bat_x - 34, y + 1, 12)
    led(bat_x - 64, y, M._stream.library or "unknown", "PC")
    led(bat_x - 99, y, M._stream.sunshine or "unknown", "SUN")
    K.text("mono", "IP " .. (M._network.ip or "offline"), math.max(8, bat_x - 260), y + 1, K.C.dim)
    if M._network.tailscale then K.text("mono", "TS " .. M._network.tailscale, math.max(8, bat_x - 260), y + 15, K.ACC.wii or K.C.dim) end
end
return M
