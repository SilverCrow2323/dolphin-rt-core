-- frontend/backup_manager.lua
-- Config file backup/restore with atomic writes and shell-safe commands.
--
-- Directory layout (absolute via State):
--   <root>/dolphin-emu/Config/*.ini                     (live files)
--   <root>/dolphin-emu/Config/.backup/<Base>_<ts>.ini   (backups)
--
-- API:
--   M.backup(filename)   -> bool   snapshot current file
--   M.restore(path)      -> bool   restore a specific backup
--   M.list()             -> array  all backups

local M = {}

-- ── state/path helpers (lazy, tolerant) ────────────────────
local function S_state()
    local ok, s = pcall(require, "state")
    if ok then return s end
    return nil
end

local function root_dir()
    local s = S_state()
    if s and s.root then return s.root() end
    return "."
end

-- The process CWD is always the LOVE game dir (frontend/), see
-- mux_launch.sh. Going through root_dir() pointed one level too high and
-- the backups ended up outside the app.
local function config_dir()
    return "dolphin-emu/Config"
end

local function backup_dir()
    return config_dir() .. "/.backup"
end

-- POSIX single-quote
local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function basename(p)
    return (p:gsub("^.*/", ""))
end

local function file_exists(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

local function ensure_dir(p)
    os.execute("mkdir -p " .. shq(p))
end

local MAX_BACKUPS = 5

-- ── Internal: list backups for one base name ────────────────
-- `base` = "Dolphin" (no extension, no path). Returns full paths
-- sorted newest first.
local function list_backups_for(base)
    local out = {}
    local dir = backup_dir()
    local h = io.popen('ls -1t ' .. shq(dir) .. ' 2>/dev/null')
    if not h then return out end
    for line in h:lines() do
        local name = basename(line)
        -- Match "<base>_<digits>.ini"
        local stem, ts = name:match("^(.+)_(%d+)%.ini$")
        if stem == base then
            table.insert(out, {
                path = dir .. "/" .. name,
                name = name,
                ts = tonumber(ts),
            })
        end
    end
    h:close()
    -- Already newest-first from `ls -1t`, but re-sort for safety
    table.sort(out, function(a, b)
        return (a.ts or 0) > (b.ts or 0)
    end)
    return out
end

-- ── Public: backup ──────────────────────────────────────────
function M.backup(filename)
    if not filename or filename == "" then return false end

    local src = config_dir() .. "/" .. filename
    if not file_exists(src) then return false end

    ensure_dir(backup_dir())

    local ts = os.time()
    local base = filename:gsub("%.ini$", "")
    local dst = backup_dir() .. "/" .. base .. "_" .. ts .. ".ini"

    -- Copy atomically: write to .tmp then rename
    local tmp = dst .. ".tmp"
    os.execute("cp " .. shq(src) .. " " .. shq(tmp))
    os.rename(tmp, dst)

    -- Rotate old backups
    local backs = list_backups_for(base)
    for i = MAX_BACKUPS + 1, #backs do
        os.remove(backs[i].path)
    end
    return true
end

-- ── Public: restore ─────────────────────────────────────────
-- `path` = full path to the backup .ini file.
function M.restore(path)
    if not path or not file_exists(path) then return false end

    local name = basename(path)
    local base = name:match("^(.+)_%d+%.ini$")
    if not base then return false end

    local target = config_dir() .. "/" .. base .. ".ini"
    local tmp    = target .. ".tmp"

    -- Copy to .tmp then rename, so a crash mid-copy doesn't corrupt
    -- the live file.
    os.execute("cp " .. shq(path) .. " " .. shq(tmp))
    os.remove(target)
    os.rename(tmp, target)
    return true
end

-- ── Public: list ────────────────────────────────────────────
function M.list()
    ensure_dir(backup_dir())
    local out = {}
    local dir = backup_dir()
    local h = io.popen('ls -1t ' .. shq(dir) .. '/*.ini 2>/dev/null')
    if not h then return out end
    for line in h:lines() do
        local name = basename(line)
        local base, ts = name:match("^(.+)_(%d+)%.ini$")
        if base and ts then
            local full = dir .. "/" .. name
            local size = 0
            local f = io.open(full, "rb")
            if f then
                f:seek("end"); size = f:seek(); f:close()
            end
            table.insert(out, {
                path     = full,
                filename = base,
                ts       = tonumber(ts),
                size     = size,
            })
        end
    end
    h:close()
    table.sort(out, function(a, b)
        return (a.ts or 0) > (b.ts or 0)
    end)
    return out
end

return M
