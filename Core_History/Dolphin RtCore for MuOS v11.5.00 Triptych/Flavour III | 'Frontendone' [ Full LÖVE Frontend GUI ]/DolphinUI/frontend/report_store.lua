local json = require("json")
local sh   = require("sh")
local M = {}

local DIR = "data/reports"
local function ensure_dir() os.execute('mkdir -p "' .. DIR .. '"') end

-- POSIX single-quote for shell args.
local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Report ids end up in file paths and shell commands, and part of the id
-- is the game_id typed by hand in the report editor: keep it to
-- [A-Za-z0-9_-] so it can never escape data/reports/.
local function safe_id(s)
    s = tostring(s or ""):gsub("[^%w_%-]", "_")
    if s == "" then s = "report" end
    if #s > 64 then s = s:sub(1, 64) end
    return s
end

-- ── Public API ────────────────────────────────────────────────
function M.list()
    ensure_dir()
    local out = {}
    local h = io.popen('ls -1t "' .. DIR .. '"/*.json 2>/dev/null')
    if not h then return out end
    for line in h:lines() do
        local f = io.open(line, "r")
        if f then
            local c = f:read("*a"); f:close()
            local ok, rep = pcall(json.decode, c)
            if ok and type(rep) == "table" then
                rep._path = line
                table.insert(out, rep)
            end
        end
    end
    h:close()
    return out
end

function M.get(id)
    for _, rep in ipairs(M.list()) do
        if rep._meta and rep._meta.id == id then return rep end
    end
    return nil
end

function M.save(report)
    ensure_dir()
    report._meta = report._meta or {}
    if not report._meta.id then
        local t = os.date("*t")
        report._meta.id = string.format("%04d%02d%02d_%02d%02d%02d_%s",
            t.year, t.month, t.day, t.hour, t.min, t.sec,
            safe_id((report.game_info and report.game_info.game_id) or "unknown"))
    else
        report._meta.id = safe_id(report._meta.id)
    end
    if not report._meta.created then
        report._meta.created = os.date("%Y-%m-%dT%H:%M:%S")
    end
    report._meta.dolphinui_version = report._meta.dolphinui_version or "0.4.0"

    local path = DIR .. "/" .. report._meta.id .. ".json"
    -- Atomic write: .tmp + rename (with FAT32 cp fallback inside
    -- sh.atomic_write). Previously this wrote directly to `path`, so
    -- a crash mid-write could leave a truncated JSON that M.list()
    -- then silently skipped, losing the report.
    if not sh.atomic_write(path, json.encode(report)) then
        return false
    end

    -- Merge into State.games_data so compat / game_detail
    -- pick up the new report instantly without a restart.
    M._merge_into_state(report)
    return true
end

function M.delete(id)
    id = safe_id(id)
    local path = DIR .. "/" .. id .. ".json"
    local f = io.open(path, "r")
    if not f then return false end
    f:close()
    os.remove(path)
    -- We don't remove from State.games_data — the entry may still be
    -- referenced by other reports. A restart will clean it.
    return true
end

function M.export(id, dest_dir)
    id = safe_id(id)
    dest_dir = dest_dir or "data/exports"
    os.execute("mkdir -p " .. shq(dest_dir))
    os.execute("cp " .. shq(DIR .. "/" .. id .. ".json") .. " " ..
               shq(dest_dir .. "/" .. id .. ".json"))
    return dest_dir .. "/" .. id .. ".json"
end

function M.empty()
    return {
        game_info = { game_id="", system="GC", game="", region="PAL" },
        test_review = { rating=3, fps="", boot="YES", playable="YES", fps_min=0, fps_max=0 },
        test_details = { rtcore_version="", core_profile="Performance", considerations="" },
        test_environment = { tester="", device="", muos_version="" },
        cover_art = "",
        custom_settings = {},
        attachments = {},
        _meta = {},
        _extended = {},
    }
end

-- ── Internal: merge new report into in-memory State ──────────
function M._merge_into_state(report)
    local ok, State = pcall(require, "state")
    if not ok or not State then return end

    local gi = report.game_info or {}
    local id = gi.game_id
    if not id or id == "" then return end

    -- Build the entry shape expected by load_games_data
    local entry = {
        test_review      = report.test_review or {},
        test_details     = report.test_details or {},
        test_environment = report.test_environment or {},
        _meta            = report._meta or {},
    }

    local slot = State.games_data[id]
    if slot then
        slot.entries = slot.entries or {}
        table.insert(slot.entries, entry)
        slot.report_count = #slot.entries

        -- Re-evaluate best (highest rating, latest breaks ties)
        local new_r = tonumber(entry.test_review.rating) or 0
        local cur_r = tonumber(slot.rating) or 0
        if new_r > cur_r then
            local tr = entry.test_review
            local td = entry.test_details
            local te = entry.test_environment
            slot.rating         = tonumber(tr.rating) or 0
            slot.fps_min        = tonumber(tr.fps_min) or 0
            slot.fps_max        = tonumber(tr.fps_max) or 0
            slot.fps_str        = tr.fps or ""
            slot.boot           = tr.boot or "?"
            slot.playable       = tr.playable or "?"
            slot.considerations = td.considerations or ""
            slot.core_profile   = td.core_profile or ""
            slot.rtcore_version = td.rtcore_version or ""
            slot.tester         = te.tester or ""
            slot.device         = te.device or ""
            slot.muos_version   = te.muos_version or ""
        end
    else
        -- New game — create entry from scratch
        local tr = entry.test_review
        local td = entry.test_details
        local te = entry.test_environment
        State.games_data[id] = {
            game_id        = id,
            game           = gi.game or "",
            system         = gi.system or "",
            region         = gi.region or "",
            info           = gi,
            rating         = tonumber(tr.rating) or 0,
            fps_min        = tonumber(tr.fps_min) or 0,
            fps_max        = tonumber(tr.fps_max) or 0,
            fps_str        = tr.fps or "",
            boot           = tr.boot or "?",
            playable       = tr.playable or "?",
            considerations = td.considerations or "",
            core_profile   = td.core_profile or "",
            rtcore_version = td.rtcore_version or "",
            tester         = te.tester or "",
            device         = te.device or "",
            muos_version   = te.muos_version or "",
            entries        = { entry },
            report_count   = 1,
        }
        State.games_data_count = (State.games_data_count or 0) + 1
    end

    -- Invalidate the per-ROM compat memo in screens/library.lua.
    -- That screen caches State.find_compat(rom) on the rom table
    -- itself (`rom._compat_lookup_done`). Without this, a ROM
    -- already scanned keeps showing the OLD rating until a full
    -- rescan. Iterating State.roms once per save is negligible.
    if State.roms then
        for _, r in ipairs(State.roms) do
            if r.id == id or (r.file and r.file:find(id, 1, true)) then
                r._compat_lookup_done = nil
                r._compat_result      = nil
            end
        end
    end

    print(string.format("[report_store] merged report for %s (now %d report(s))",
        id, (State.games_data[id] and State.games_data[id].report_count) or 0))
end

return M