-- frontend/system_info.lua
-- Rileva info di sistema del device muOS per pre-fill dei Test Report
local M = {}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a"); f:close()
    return c
end

local function read_first_line(path)
    local c = read_file(path)
    if not c then return nil end
    return c:match("^([^\n]+)")
end

local function trim(s)
    if not s then return nil end
    return s:match("^%s*(.-)%s*$")
end

-- ── muOS version ───────────────────────────────────────────────────────
function M.muos_version()
    -- Prova vari path noti
    local paths = {
        "/opt/muos/config/system/version",
        "/opt/muos/config/version",
        "/etc/muos-version",
    }
    for _, p in ipairs(paths) do
        local v = trim(read_first_line(p))
        if v and v ~= "" then return v end
    end
    -- Fallback: version + build
    local ver = trim(read_first_line("/opt/muos/config/system/version"))
    local bld = trim(read_first_line("/opt/muos/config/system/build"))
    if ver then
        if bld then return ver .. " (" .. bld .. ")" end
        return ver
    end
    return ""
end

-- ── Device name ────────────────────────────────────────────────────────
function M.device_name()
    -- muOS custom name
    local name = trim(read_first_line("/opt/muos/config/system/name"))
    if name and name ~= "" then return name end

    -- da device/board/name
    local board = trim(read_first_line("/opt/muos/config/board/name"))
    if board and board ~= "" then return board end

    -- da /proc/device-tree/model (kernel)
    local model = trim(read_first_line("/proc/device-tree/model"))
    if model then
        -- rimuovi null bytes
        model = model:gsub("%z", "")
        if model ~= "" then return model end
    end

    -- hostname come fallback
    local host = trim(read_first_line("/etc/hostname"))
    if host and host ~= "" then return host end

    return "Unknown Device"
end

-- ── Tester username ────────────────────────────────────────────────────
function M.tester_username()
    -- $USER o $LOGNAME
    local u = os.getenv("USER") or os.getenv("LOGNAME")
    if u and u ~= "" then return u end

    -- da /etc/passwd (uid 1000)
    local passwd = read_file("/etc/passwd")
    if passwd then
        for line in passwd:gmatch("[^\n]+") do
            local name, _uid = line:match("^([^:]+):[^:]*:(%d+):")
            if tonumber(_uid) == 1000 then return name end
        end
    end

    -- hostname root fallback
    return "sirpips"
end

-- ── Full snapshot ──────────────────────────────────────────────────────
function M.snapshot()
    return {
        muos   = M.muos_version(),
        device = M.device_name(),
        tester = M.tester_username(),
    }
end

-- ── Ultimo log di sessione Dolphin ─────────────────────────────────────
-- Cerca il log più recente in /opt/muos/share/emulator/dolphin/rtdata/logs
-- oppure in DolphinUI/data/logs
function M.latest_session_log()
    local dirs = {
        "/opt/muos/share/emulator/dolphin/rtdata/logs",
        "data/logs",
    }
    for _, dir in ipairs(dirs) do
        local h = io.popen('ls -1t "' .. dir .. '"/dolphinrtcore_*.log 2>/dev/null | head -1')
        if h then
            local path = h:read("*a"):match("^([^\n]+)")
            h:close()
            if path and path ~= "" then return path end
        end
    end
    return nil
end

-- Parse di un log per estrarre i campi chiave
function M.parse_session_log(path)
    if not path then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a"); f:close()

    local out = {
        path = path,
        name = path:match("([^/]+)$") or "log",
    }

    -- NAME, CORE, ROM, GAMEID, GAMENAME
    out.game_name   = content:match("NAME:%s*([^\n]+)") or ""
    out.core        = content:match("CORE:%s*([^\n]+)") or ""
    out.rom_path    = content:match("ROM:%s*([^\n]+)") or ""
    out.game_id_log = content:match("GAMEID:%s*([^\n]+)") or ""
    out.game_title  = content:match("GAMENAME:%s*([^\n]+)") or ""

    -- Exit code
    out.exit_code = tonumber(content:match("Dolphin exited with code%s*(%d+)")) or 0

    -- Timestamp inizio
    out.start_date = content:match("Starting Dolphin:%s*([^\n]+)") or ""

    -- Info da log Dolphin interno (es. "Dolphin 2412-81-dirty | JITARM64 DC | OpenGL ES | HLE | GCNE7D")
    out.dolphin_line = content:match("(Dolphin%s+[%d%-]+%S*%s*[|][^\n]+)") or ""

    -- Crash indicator
    out.crash_signal = content:match("(corrupted double%-linked list)") or
                       content:match("(Segmentation fault)") or
                       content:match("(Aborted)") or ""

    -- tail (ultime 15 righe non vuote)
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        if line:match("%S") then
            table.insert(lines, line)
            if #lines > 30 then table.remove(lines, 1) end
        end
    end
    out.tail = table.concat(lines, "\n")

    return out
end

return M
