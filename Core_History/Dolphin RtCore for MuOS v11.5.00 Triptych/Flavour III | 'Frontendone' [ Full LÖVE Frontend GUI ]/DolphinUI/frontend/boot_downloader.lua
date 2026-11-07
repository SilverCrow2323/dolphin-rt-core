-- frontend/boot_downloader.lua — async data file refresh.
--
-- Downloads games_data.json, rtenhancerhub.json, wiitdb.txt into data/,
-- then sanity-checks them. CWD is frontend/, so all paths are relative.
--
-- v0.4.5 — atomic download
--   * Files are downloaded to <dest>.tmp, validated in Lua, then
--     renamed over <dest>. The previous revision wrote directly to
--     <dest>, so a failed/truncated download replaced the last-known-
--     good file and the app booted with zero games until the user
--     manually restored it from a backup. Now a bad download is
--     simply discarded and the old file survives.
--
-- v0.4.4
--   * Per-file download flags under advanced.* :
--       download_games_data
--       download_rtenhancerhub
--       download_wiitdb
--     The master switch advanced.data_auto_download is checked first:
--     if it is false, nothing is downloaded.

local M = {}

local DATA_URLS = {
  games    = "https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/refs/heads/main/data/games_data.json",
  enhancer = "https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/refs/heads/main/data/rtenhancerhub.json",
  wiitdb   = "https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/refs/heads/main/data/database/wiitdb.txt",
}

local READY_MARKER = "/tmp/dolphinui_dl_ready"
local LOCK_MARKER  = "/tmp/dolphinui_dl_running"

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Minimal validity check: file exists, > threshold bytes, first
-- non-whitespace byte is '{' or '['. For wiitdb.txt, we check the first
-- bytes look like text (a leading "TITLES" header or any printable).
local function looks_like_json(path, min_bytes)
    local f = io.open(path, "rb")
    if not f then return false, "not found" end
    f:seek("end")
    local size = f:seek()
    f:close()
    if size < (min_bytes or 100) then
        return false, "too small (" .. size .. " bytes)"
    end
    local f2 = io.open(path, "r")
    if not f2 then return false, "unreadable" end
    local head = f2:read(64); f2:close()
    local first = head:match("^%s*(.)")
    if first ~= "{" and first ~= "[" then
        return false, "bad first byte: " .. tostring(first)
    end
    return true
end

local function looks_like_text(path, min_bytes)
    local f = io.open(path, "rb")
    if not f then return false, "not found" end
    f:seek("end")
    local size = f:seek()
    f:close()
    if size < (min_bytes or 500) then
        return false, "too small (" .. size .. " bytes)"
    end
    local f2 = io.open(path, "r")
    if not f2 then return false, "unreadable" end
    local head = f2:read(64); f2:close()
    -- First non-whitespace token must be TITLES (the wiitdb header).
    -- The previous version also accepted any [%w%s=#], which matched
    -- basically every text file on earth, so the check was useless.
    if not head:match("^%s*TITLES") then
        return false, "unexpected header"
    end
    return true
end

-- Download to <dest>.tmp. The caller validates <dest>.tmp and then
-- either os.rename()s it over <dest> or removes it.
local function dl_cmd(url, dest)
    local tmp = dest .. ".tmp"
    return string.format(
        '{ curl -fsSL --connect-timeout 15 --max-time 90 -o %s %s 2>/dev/null || ' ..
        '  wget -q --timeout=15 --tries=2 -O %s %s 2>/dev/null; }',
        shq(tmp), shq(url), shq(tmp), shq(url))
end

local function want(key)
    -- nil counts as true (default on). Only an explicit false disables.
    local ok, Store = pcall(require, "settings_store")
    if not ok or not Store then return true end
    local v = Store.get("advanced", key)
    return v ~= false
end

-- Promote a validated .tmp over the live file. On any failure,
-- remove the .tmp and leave the live file untouched.
local function promote(tmp, dest)
    local f = io.open(tmp, "rb")
    if not f then return false end
    f:seek("end")
    local sz = f:seek()
    f:close()
    if not sz or sz == 0 then
        os.remove(tmp)
        return false
    end
    -- POSIX rename is atomic and overwrites the destination.
    if os.rename(tmp, dest) then return true end
    -- FAT32 fallback: cp then remove.
    local ok = os.execute("cp -f " .. shq(tmp) .. " " .. shq(dest))
    os.remove(tmp)
    return ok == true or ok == 0
end

function M.update_all()
    -- Master switch.
    if not want("data_auto_download") then
        print("[BootDownloader] data_auto_download disabled, skipping")
        return false
    end

    local want_games    = want("download_games_data")
    local want_enhancer = want("download_rtenhancerhub")
    local want_wiitdb   = want("download_wiitdb")

    if not want_games and not want_enhancer and not want_wiitdb then
        print("[BootDownloader] all individual download flags disabled")
        return false
    end

    os.execute("mkdir -p " .. shq("data"))
    os.execute("mkdir -p " .. shq("data/database"))
    os.remove(READY_MARKER)

    local games_dest    = "data/games_data.json"
    local enhancer_dest = "data/rtenhancerhub.json"
    local wiitdb_dest   = "data/wiitdb.txt"

    local parts = {}
    if want_games then
        parts[#parts + 1] = dl_cmd(DATA_URLS.games, games_dest)
    end
    if want_enhancer then
        parts[#parts + 1] = dl_cmd(DATA_URLS.enhancer, enhancer_dest)
    end
    if want_wiitdb then
        parts[#parts + 1] = dl_cmd(DATA_URLS.wiitdb, wiitdb_dest)
    end
    -- Use ";" not "&&": one failed download must not block the
    -- others, and the ready marker must always be touched or the
    -- polling loop in main.lua never unblocks.
    parts[#parts + 1] = 'touch ' .. READY_MARKER

    local script = table.concat(parts, " ; ")

    local shf = io.open("/tmp/dolphinui_dl.sh", "w")
    if not shf then return false end
    shf:write("#!/bin/sh\n")
    shf:write(script .. "\n")
    shf:close()
    os.execute("chmod +x /tmp/dolphinui_dl.sh")

    os.execute('touch ' .. LOCK_MARKER)
    os.execute('setsid sh /tmp/dolphinui_dl.sh </dev/null >/dev/null 2>&1 &')
    print(string.format(
        "[BootDownloader] scheduled refresh (games=%s enhancer=%s wiitdb=%s)",
        tostring(want_games), tostring(want_enhancer), tostring(want_wiitdb)))
    return true
end

-- Called by main.lua every frame until it returns true. Validates
-- each .tmp in turn, promotes good ones, discards bad ones. The live
-- files are never touched until validation succeeds.
function M.poll_ready()
    local f = io.open(READY_MARKER, "r")
    if not f then return false end
    f:close()
    os.remove(READY_MARKER)
    os.remove(LOCK_MARKER)

    local function check_and_promote(dest, validator, min_bytes, label)
        local tmp = dest .. ".tmp"
        local tf = io.open(tmp, "rb")
        if not tf then
            -- Download never produced a file (network down, etc.).
            -- Leave the old <dest> alone.
            return
        end
        tf:close()
        local ok, reason = validator(tmp, min_bytes)
        if ok then
            if promote(tmp, dest) then
                print("[BootDownloader] " .. label .. " refreshed")
            else
                print("[BootDownloader] " .. label .. " promote failed")
                os.remove(tmp)
            end
        else
            print("[BootDownloader] " .. label .. " rejected: " ..
                  tostring(reason) .. " (old file kept)")
            os.rename(tmp, tmp .. ".bad")
        end
    end

    if want("download_games_data") then
        check_and_promote("data/games_data.json", looks_like_json, 5000, "games_data.json")
    end
    if want("download_rtenhancerhub") then
        check_and_promote("data/rtenhancerhub.json", looks_like_json, 500, "rtenhancerhub.json")
    end
    if want("download_wiitdb") then
        check_and_promote("data/wiitdb.txt", looks_like_text, 50000, "wiitdb.txt")
    end

    return true
end

return M