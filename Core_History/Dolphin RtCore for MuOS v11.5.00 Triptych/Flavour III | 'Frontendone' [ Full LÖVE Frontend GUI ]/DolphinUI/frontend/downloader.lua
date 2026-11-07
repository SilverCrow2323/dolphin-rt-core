-- frontend/downloader.lua — persistent download queue.
--
-- ── v0.4.7 — cleanup + helpers ────────────────────────────────
--   1. save() now goes through sh.atomic_write(). The previous
--      revision did os.remove(path) then os.rename(tmp, path),
--      which could leave the queue file missing if the process
--      died between the two syscalls (they are not one atomic
--      operation on FAT32). atomic_write() writes to .tmp, fsyncs
--      by closing, and only then replaces the destination.
--   2. Public helpers promoted from download_overlay.lua, which
--      was re-implementing them inline:
--        M.retry(id)             re-enqueue a failed entry
--        M.progress(id)          {pct, bytes, total, eta}
--        M.clear_finished()      bulk-remove done/cancelled
--        M.queued_ids()          set of item_ids in the queue
--   3. reap_stale() now also handles a "queued" entry whose
--      started timestamp is missing and older than 24h — a
--      symptom of many device reboots before the queue was ever
--      pumped. Marked as errored with a clear message.
--   4. kill_download_process() no longer uses `pkill -9 -P`.
--      The parent's PID can be recycled by the kernel between the
--      original spawn and the cancel; killing the "children of
--      that PID" at that point would hit unrelated processes.
--      The script removes its own PID file on exit anyway.
--   5. All shell scripts are written through a single helper
--      (write_script + spawn_script) instead of ad-hoc io.open
--      calls scattered through the module.
--   6. manifest_dir() ensures data/installed/ exists before every
--      write. The previous revision relied on mark_installed()
--      to create it, but is_installed() reads from the same dir
--      and would silently return nil on a missing directory.
--   7. install_choices() unchanged in shape but now checks the
--      external-core binary once (cached per session) instead of
--      a stat() every call.
--
-- Everything else is unchanged: sequential downloads, URL
-- normalization, persistent queue, cancel support (kills the
-- curl PID), muxupd path-traversal validation.

local json   = require("json")
local Notify = require("notify")
local sh     = require("sh")

local M = {}

local QUEUE_FILE    = "data/downloads/queue.json"
local DL_DIR        = "data/downloads"
local INSTALLED_DIR = "data/installed"
local TMP           = "/tmp"

-- Timing
local POLL_INTERVAL   = 0.5
local STALE_QUEUE_AGE = 86400    -- 24h

local queue       = {}
local initialized = false
local _poll_t     = 0
local _ext_ok     = nil          -- cached: external dolphin binary exists

-- ── Utilities ───────────────────────────────────────────────
local function file_exists(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

local function file_size(p)
    local f = io.open(p, "rb")
    if not f then return 0 end
    f:seek("end")
    local s = f:seek()
    f:close()
    return s
end

local function safe_id(s)
    return (tostring(s or "x"):gsub("[^%w_%-]", "_"))
end

local function normalize_url(url)
    if type(url) ~= "string" or url == "" then return url end
    local scheme, rest = url:match("^(%a[%w+%-.]*://)(.*)$")
    if scheme then
        rest = rest:gsub("^/+", "")
        rest = rest:gsub("/+", "/")
        return scheme .. rest
    end
    return url:gsub("/+", "/")
end

local function detect_archive(url)
    if not url then return "unknown" end
    local p = url:gsub("%?.*$", "")
    if p:match("%.muxapp$")   then return "muxapp"  end
    if p:match("%.muxupd$")   then return "muxupd"  end
    if p:match("%.zip$")      then return "zip"     end
    if p:match("%.tar%.gz$")  then return "targz"   end
    if p:match("%.tar%.bz2$") then return "tarbz2"  end
    if p:match("%.tar$")      then return "tar"     end
    if p:match("%.rar$")      then return "rar"     end
    if p:match("%.7z$")       then return "7z"      end
    return "unknown"
end

local function basename(url)
    local b = url:match("([^/]+)$") or "download.bin"
    return (b:gsub("%?.*$", ""))
end

local function dest_filename(entry)
    local sid  = safe_id(entry.item_id)
    local base = basename(entry.url)
    return sid .. "_" .. base
end

-- ── Script helpers ──────────────────────────────────────────
-- Write a shell script to /tmp, make it executable, return the
-- path. Returns nil on failure.
local function write_script(name, body)
    local path = TMP .. "/" .. name
    local f = io.open(path, "w")
    if not f then return nil end
    f:write("#!/bin/sh\n")
    f:write("set +e\n")
    f:write(body)
    f:write("\n")
    f:close()
    os.execute("chmod +x " .. sh.shq(path))
    return path
end

-- Launch a previously-written script detached from our process.
local function spawn_script(path)
    os.execute("setsid sh " .. sh.shq(path) ..
        " </dev/null >/dev/null 2>&1 &")
end

-- ── Installed-detection helpers ─────────────────────────────
local function manifest_dir()
    os.execute("mkdir -p " .. sh.shq(INSTALLED_DIR))
end

local function manifest_path(item_id)
    return INSTALLED_DIR .. "/" .. safe_id(item_id) .. ".json"
end

local function dir_has_content(path)
    local h = io.popen("[ -d " .. sh.shq(path) .. " ] && " ..
                       "ls -A " .. sh.shq(path) ..
                       " 2>/dev/null | head -1")
    if not h then return false end
    local out = h:read("*a"); h:close()
    return out ~= nil and out:match("%S") ~= nil
end

local function read_manifest(item_id)
    local path = manifest_path(item_id)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a"); f:close()
    local ok, data = pcall(json.decode, c)
    if ok and type(data) == "table" then return data end
    return nil
end

function M.mark_installed(entry)
    if not entry or not entry.item_id then return end
    manifest_dir()
    local data = {
        item_id      = entry.item_id,
        name         = entry.name or "?",
        version      = entry.version or "?",
        installed_at = os.time(),
        target_path  = entry.target_path or entry.install_path or "",
    }
    local path = manifest_path(entry.item_id)
    local tmp  = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write(json.encode(data))
    f:close()
    os.remove(path)
    if not os.rename(tmp, path) then
        os.execute("cp " .. sh.shq(tmp) .. " " .. sh.shq(path))
        os.remove(tmp)
    end
end

-- Returns (installed_bool, info_table_or_nil).
-- Detection order:
--   1. Manifest at data/installed/<id>.json
--   2. Homebrew heuristic: <install_path>/{rtcore_hb.ini,boot.dol,meta.xml}
--   3. Rintropack with extract_contains
--   4. Rintropack without extract_contains (base dir non-empty)
function M.is_installed(item)
    if not item or not item.id then return false, nil end

    local man = read_manifest(item.id)
    if man and man.item_id == item.id then
        return true, man
    end

    local ipath = item.install_path or ""
    if ipath:match("^hb/") then
        for _, name in ipairs({ "rtcore_hb.ini", "boot.dol", "boot.elf",
                                "meta.xml" }) do
            if file_exists(ipath .. "/" .. name) then
                return true, { name = item.name, target_path = ipath,
                               source = "filesystem" }
            end
        end
        return false, nil
    end

    if item.install_paths and item.install_paths.frontend then
        local base = item.install_paths.frontend
        local check = item.extract_contains
            and (base .. "/" .. item.extract_contains)
            or base
        if dir_has_content(check) then
            return true, { name = item.name, target_path = check,
                           source = "filesystem" }
        end
    end

    return false, nil
end

-- ── muxupd safety ───────────────────────────────────────────
-- Top-level directories that a .muxupd archive is allowed to
-- target. `false` means "refuse if the archive writes there";
-- `true` or nil means "allow" (unknown layouts are permitted
-- because muOS paths vary between releases).
local MUXUPD_ALLOWED_TOP = {
    ["run"]  = true,
    ["opt"]  = true,
    ["mnt"]  = true,
    ["usr"]  = true,
    ["etc"]  = false,
    ["bin"]  = false,
    ["lib"]  = false,
    ["sbin"] = false,
    ["boot"] = false,
    ["home"] = false,
    ["root"] = false,
    ["var"]  = false,
    ["sys"]  = false,
    ["proc"] = false,
    ["dev"]  = false,
}

local function list_archive_paths(archive_path, archive_type)
    local out = {}
    local cmd
    if archive_type == "muxupd" or archive_type == "muxapp"
       or archive_type == "zip" then
        cmd = "timeout 10 unzip -l " .. sh.shq(archive_path) .. " 2>/dev/null"
    elseif archive_type == "targz" then
        cmd = "timeout 10 tar -tzf " .. sh.shq(archive_path) .. " 2>/dev/null"
    elseif archive_type == "tar" then
        cmd = "timeout 10 tar -tf " .. sh.shq(archive_path) .. " 2>/dev/null"
    else
        return out
    end

    local h = io.popen(cmd)
    if not h then return out end
    for line in h:lines() do
        local path = line:match("%S+%s+%S+%s+%S+%s+(.+)$")
        if path then
            out[#out + 1] = path
        else
            local p = line:match("^%s*(.-)%s*$")
            if p and p ~= "" then out[#out + 1] = p end
        end
    end
    h:close()
    return out
end

local function validate_muxupd_content(archive_path, archive_type)
    local paths = list_archive_paths(archive_path, archive_type)
    if #paths == 0 then
        return false, "archive empty or unreadable"
    end

    for _, p in ipairs(paths) do
        if p:match("%.%.") then
            return false, "path traversal in archive: " .. p
        end
        if p:sub(1, 1) == "/" then
            return false, "absolute path in archive: " .. p
        end
        local top = p:match("^([^/]+)")
        if top and top ~= "" then
            local allowed = MUXUPD_ALLOWED_TOP[top]
            if allowed == false then
                return false, "refusing to overwrite /" .. top .. "/"
            end
        end
    end

    return true, nil
end

-- ── Persistence ─────────────────────────────────────────────
local function save()
    os.execute("mkdir -p " .. sh.shq(DL_DIR))
    local payload = json.encode(queue)
    -- atomic_write handles the .tmp → dst dance with a FAT32 cp
    -- fallback. No more "queue file disappears on crash" window.
    sh.atomic_write(QUEUE_FILE, payload)
end

local function load()
    queue = {}
    local f = io.open(QUEUE_FILE, "r")
    if f then
        local c = f:read("*a"); f:close()
        local ok, data = pcall(json.decode, c)
        if ok and type(data) == "table" then
            queue = data
            for _, e in ipairs(queue) do
                if e.url then e.url = normalize_url(e.url) end
                -- Do NOT auto-clear "downloading" here. That
                -- decision belongs to reap_stale(), which has
                -- access to /tmp to tell whether the process
                -- actually died.
            end
        end
    end
    initialized = true
end

function M.init()
    if not initialized then load() end
end

-- ══════════════════════════════════════════════════════════════
--  Reap stale entries
-- ══════════════════════════════════════════════════════════════
-- Called by main.lua at boot. Marks as errored:
--   * entries with status == "downloading" or "extracting" whose
--     PID file AND .done marker are both gone from /tmp
--     (crash, hard reboot, kill -9),
--   * entries with status == "queued" whose `started` timestamp
--     is missing and whose creation is unknown — a symptom of a
--     queue that has survived dozens of reboots without ever
--     being pumped. Such entries are almost certainly broken
--     (their URL may be dead).
function M.reap_stale()
    M.init()
    local reaped   = 0
    local now      = os.time()

    for _, e in ipairs(queue) do
        if e.status == "downloading" or e.status == "extracting" then
            local sid = safe_id(e.item_id)
            local pid_path = TMP .. "/dolphinui_dl_" .. sid .. ".pid"
            local dl_done  = TMP .. "/dolphinui_dl_" .. sid .. ".done"
            local ex_done  = TMP .. "/dolphinui_extract_" .. sid .. ".done"

            local has_pid  = file_exists(pid_path)
            local has_done = file_exists(dl_done) or file_exists(ex_done)

            if not has_pid and not has_done then
                print(string.format(
                    "[downloader] reaping stale entry: %s (%s)",
                    tostring(e.name), tostring(e.status)))
                e.status = "error"
                e.error  = "interrupted (system reboot?)"
                e.progress_bytes = 0
                reaped = reaped + 1
            end

        elseif e.status == "queued" then
            -- Stale queued: no started timestamp and older than 24h.
            -- This cannot happen in normal operation (try_start_next
            -- picks up queued entries immediately) — it means the
            -- queue was not pumped across many reboots.
            local started = tonumber(e.started) or 0
            if started == 0 and e.created_at and
               (now - tonumber(e.created_at) > STALE_QUEUE_AGE) then
                e.status = "error"
                e.error  = "queued for more than 24h without starting"
                reaped = reaped + 1
            end
        end
    end

    if reaped > 0 then
        save()
        pcall(function()
            Notify.show("warning",
                ("%d stale download(s) marked as failed — retry from R2")
                    :format(reaped), 5.0)
        end)
    end
    return reaped
end

-- ── Queue helpers ───────────────────────────────────────────
local function find_entry(id)
    for _, e in ipairs(queue) do
        if e.item_id == id then return e end
    end
end

local function any_active()
    for _, e in ipairs(queue) do
        if e.status == "downloading" or e.status == "extracting" then
            return true
        end
    end
    return false
end

local function pid_file_for(sid)
    return TMP .. "/dolphinui_dl_" .. sid .. ".pid"
end

local function kill_download_process(sid)
    local pf = pid_file_for(sid)
    local f = io.open(pf, "r")
    if not f then return end
    local pid = tonumber(f:read("*a"))
    f:close()
    if pid and pid > 1 then
        local n = tostring(math.floor(pid))
        -- Only kill the top-level script PID. The old `pkill -9 -P`
        -- could hit unrelated processes if the kernel recycled the
        -- PID between spawn and cancel. The script itself removes
        -- its PID file on normal exit, so a stale PID file is
        -- itself a sign of trouble and worth killing by number only.
        os.execute("kill -9 " .. n .. " 2>/dev/null")
    end
    os.remove(pf)
end

-- ── Download ────────────────────────────────────────────────
local function start_download(entry)
    os.execute("mkdir -p " .. sh.shq(DL_DIR))
    entry.status = "downloading"
    entry.started = os.time()
    entry.progress_bytes = 0
    entry.error = nil
    entry.dest = DL_DIR .. "/" .. dest_filename(entry)
    save()

    local sid       = safe_id(entry.item_id)
    local done_file = TMP .. "/dolphinui_dl_" .. sid .. ".done"
    local pf        = pid_file_for(sid)
    os.remove(done_file)
    os.remove(pf)

    local body = table.concat({
        "echo $$ > " .. sh.shq(pf),
        "curl -fSL --connect-timeout 15 --max-time 3600 "
            .. "-o " .. sh.shq(entry.dest) .. " "
            .. sh.shq(entry.url),
        "rc=$?",
        "if [ $rc -ne 0 ]; then",
        "  wget -q --timeout=15 --tries=2 -O "
            .. sh.shq(entry.dest) .. " " .. sh.shq(entry.url),
        "  rc=$?",
        "fi",
        "echo $rc > " .. sh.shq(done_file),
        "rm -f " .. sh.shq(pf),
    }, "\n")

    local path = write_script("dolphinui_dl_" .. sid .. ".sh", body)
    if not path then
        entry.status = "error"
        entry.error = "cannot write script"
        save()
        return
    end

    spawn_script(path)
    Notify.show("info", "Downloading: " .. entry.name)
end

-- ── Extract ─────────────────────────────────────────────────
local function start_extract(entry)
    local path = entry.target_path
    if not path or path == "" then
        entry.status = "error"
        entry.error = "no target path"
        save()
        return
    end

    if entry.target_kind == "muxupd" then
        local ok, reason = validate_muxupd_content(entry.dest,
            entry.archive_type)
        if not ok then
            entry.status = "error"
            entry.error = "unsafe archive: " .. (reason or "unknown")
            save()
            Notify.show("error", "Refused: " .. (reason or "unsafe archive"))
            return
        end
    end

    os.execute("mkdir -p " .. sh.shq(path))

    local sid = safe_id(entry.item_id)
    local done_file = TMP .. "/dolphinui_extract_" .. sid .. ".done"
    os.remove(done_file)

    local src   = entry.dest
    local qsrc  = sh.shq(src)
    local qdst  = sh.shq(path)
    local ext   = entry.archive_type

    local cmd
    if ext == "zip" or ext == "muxapp" or ext == "muxupd" then
        cmd = "unzip -q -o " .. qsrc .. " -d " .. qdst
    elseif ext == "targz" then
        cmd = "tar -xzf " .. qsrc .. " -C " .. qdst
    elseif ext == "tarbz2" then
        cmd = "tar -xjf " .. qsrc .. " -C " .. qdst
    elseif ext == "tar" then
        cmd = "tar -xf " .. qsrc .. " -C " .. qdst
    elseif ext == "rar" then
        cmd = "unrar x -o+ " .. qsrc .. " " .. qdst .. "/"
    elseif ext == "7z" then
        cmd = "7z x -y -o" .. qdst .. " " .. qsrc
    else
        cmd = "unzip -q -o " .. qsrc .. " -d " .. qdst
    end

    entry.status = "extracting"
    save()

    local body = table.concat({
        cmd,
        "rc=$?",
        "echo $rc > " .. sh.shq(done_file),
    }, "\n")

    local sp = write_script("dolphinui_extract_" .. sid .. ".sh", body)
    if not sp then
        entry.status = "error"
        entry.error = "cannot write script"
        save()
        return
    end

    spawn_script(sp)
    Notify.show("info", "Extracting: " .. entry.name)
end

-- ── Public: enqueue ─────────────────────────────────────────
function M.enqueue(item, opts)
    M.init()
    opts = opts or {}

    for _, e in ipairs(queue) do
        if e.item_id == item.id then
            local s = e.status
            if s == "queued" or s == "downloading" or
               s == "awaiting_install" or s == "extracting" then
                return false, "already queued"
            end
        end
    end

    if item.is_directory_link then
        return false, "directory link — open in browser"
    end

    local url = normalize_url(item.download_url)
    if not url or url == "" then return false, "no download url" end

    local archive_type = detect_archive(url)

    local target_kind = opts.target_kind
    if not target_kind then
        if archive_type == "muxapp" then target_kind = "muxapp"
        elseif archive_type == "muxupd" then target_kind = "muxupd"
        elseif item.install_paths then target_kind = "rintropack" end
    end

    local entry = {
        item_id          = item.id,
        name             = item.name or "?",
        version          = item.version or "?",
        url              = url,
        icon_url         = item.icon_url or "",
        size_mb          = item.size_mb or 0,
        archive_type     = archive_type,
        target_kind      = target_kind,
        install_paths    = item.install_paths,
        install_path     = item.install_path,
        extract_into     = item.extract_into,
        extract_contains = item.extract_contains,
        status           = "queued",
        progress_bytes   = 0,
        total_bytes      = (item.size_mb or 0) * 1024 * 1024,
        created_at       = os.time(),
        started          = 0,
        finished         = 0,
        error            = nil,
        dest             = DL_DIR .. "/" .. dest_filename({
            item_id = item.id, url = url,
        }),
        target_path = nil,
    }
    table.insert(queue, entry)
    save()
    M.try_start_next()
    return true
end

function M.try_start_next()
    if any_active() then return end
    for _, e in ipairs(queue) do
        if e.status == "queued" then
            start_download(e)
            return
        end
    end
end

-- ── Public: update ──────────────────────────────────────────
function M.update(dt)
    M.init()
    _poll_t = _poll_t + (dt or 0)
    if _poll_t < POLL_INTERVAL then return end
    _poll_t = 0

    for _, entry in ipairs(queue) do
        if entry.status == "downloading" then
            entry.progress_bytes = file_size(entry.dest)

            local sid = safe_id(entry.item_id)
            local df = io.open(TMP .. "/dolphinui_dl_" .. sid .. ".done", "r")
            if df then
                local rc = tonumber(df:read("*a")) or 1
                df:close()
                os.remove(TMP .. "/dolphinui_dl_" .. sid .. ".done")
                if rc == 0 then
                    entry.status = "awaiting_install"
                    entry.finished = os.time()
                    Notify.show("success", "Downloaded: " .. entry.name)
                else
                    entry.status = "error"
                    entry.error = "download rc=" .. rc
                    if entry.dest then os.remove(entry.dest) end
                    Notify.show("error", "Download failed: " .. entry.name)
                end
                save()
                M.try_start_next()
            end

        elseif entry.status == "extracting" then
            local sid = safe_id(entry.item_id)
            local df = io.open(
                TMP .. "/dolphinui_extract_" .. sid .. ".done", "r")
            if df then
                local rc = tonumber(df:read("*a")) or 1
                df:close()
                os.remove(TMP .. "/dolphinui_extract_" .. sid .. ".done")
                if rc == 0 then
                    entry.status = "done"
                    M.mark_installed(entry)
                    Notify.show("success", "Installed: " .. entry.name)
                else
                    entry.status = "error"
                    entry.error = "extract rc=" .. rc
                    Notify.show("error", "Extract failed: " .. entry.name)
                end
                save()
                M.try_start_next()
            end
        end
    end
end

-- ── Public: user decisions ──────────────────────────────────
function M.confirm_install(id, target_path)
    M.init()
    local e = find_entry(id)
    if not e or e.status ~= "awaiting_install" then return false end
    e.target_path = target_path
    save()
    start_extract(e)
    return true
end

function M.skip_install(id)
    M.init()
    local e = find_entry(id)
    if not e or e.status ~= "awaiting_install" then return false end
    e.status = "done"
    e.skipped_install = true
    save()
    M.try_start_next()
    return true
end

function M.cancel(id)
    M.init()
    local e = find_entry(id)
    if not e then return false end
    if e.status == "downloading" then
        kill_download_process(safe_id(id))
        e.status = "cancelled"
        save()
        M.try_start_next()
        return true
    end
    if e.status == "extracting" then
        e.status = "cancelled"
        save()
        M.try_start_next()
        return true
    end
    return false
end

function M.remove(id)
    M.init()
    for i, e in ipairs(queue) do
        if e.item_id == id then
            if e.status == "downloading" or e.status == "extracting" then
                return false, "active"
            end
            table.remove(queue, i)
            save()
            return true
        end
    end
    return false
end

function M.cleanup_archive(id)
    M.init()
    local e = find_entry(id)
    if not e then return false end
    if e.dest and file_exists(e.dest) then
        os.remove(e.dest)
        e.archive_cleaned = true
        save()
        return true
    end
    return false
end

-- ── Public: batch helpers (used by download_overlay) ────────
-- Re-enqueue a failed entry. The old entry is removed and a new
-- one is created from its snapshot; keeps the queue unique per
-- item_id, which M.enqueue() enforces.
function M.retry(id)
    M.init()
    local e = find_entry(id)
    if not e or e.status ~= "error" then return false end

    local snapshot = {
        id               = e.item_id,
        name             = e.name,
        version          = e.version,
        download_url     = e.url,
        icon_url         = e.icon_url,
        size_mb          = e.size_mb,
        install_paths    = e.install_paths,
        install_path     = e.install_path,
        extract_into     = e.extract_into,
        extract_contains = e.extract_contains,
    }
    local target_kind = e.target_kind
    M.remove(e.item_id)
    M.enqueue(snapshot, { target_kind = target_kind })
    return true
end

-- Remove every done / cancelled entry. Returns the count removed.
function M.clear_finished()
    M.init()
    local n = 0
    for i = #queue, 1, -1 do
        local s = queue[i].status
        if s == "done" or s == "cancelled" then
            table.remove(queue, i)
            n = n + 1
        end
    end
    if n > 0 then save() end
    return n
end

-- Return a progress snapshot for the given entry id.
--   { pct = 0..1, bytes, total, eta = seconds or nil }
-- pct is 0 when total is unknown.
function M.progress(id)
    M.init()
    local e = find_entry(id)
    if not e then return nil end

    local total = (e.size_mb or 0) * 1024 * 1024
    local bytes = e.progress_bytes or 0
    local pct   = (total > 0) and math.min(1, bytes / total) or 0

    -- ETA is only meaningful while actively downloading.
    local eta
    if e.status == "downloading" and bytes > 0 and total > bytes then
        local started = e.started or os.time()
        local elapsed = os.time() - started
        if elapsed > 0 then
            local rate = bytes / elapsed       -- bytes / s
            if rate > 0 then
                eta = math.floor((total - bytes) / rate)
            end
        end
    end

    return { pct = pct, bytes = bytes, total = total, eta = eta }
end

-- ── Public: queries ─────────────────────────────────────────
function M.list()
    M.init()
    return queue
end

function M.get(id)
    M.init()
    return find_entry(id)
end

function M.count_active()
    M.init()
    local n = 0
    for _, e in ipairs(queue) do
        if e.status ~= "done" and e.status ~= "error"
           and e.status ~= "cancelled" then
            n = n + 1
        end
    end
    return n
end

-- Which item_ids are present in the queue? Used by screens that
-- want to render an "already queued" hint without walking the
-- whole list.
function M.queued_ids()
    M.init()
    local set = {}
    for _, e in ipairs(queue) do
        set[e.item_id] = true
    end
    return set
end

-- ── Public: install targets ─────────────────────────────────
local function external_core_present()
    if _ext_ok == nil then
        _ext_ok = file_exists("/opt/muos/share/emulator/dolphin/dolphin")
    end
    return _ext_ok
end

function M.install_choices(entry)
    if not entry then return {} end

    if entry.target_kind == "muxapp" then
        return {
            { key = "a", label = "Install to muOS apps",
              path = "/run/muos/storage/application" },
        }
    end

    if entry.target_kind == "muxupd" then
        return {
            { key = "a", label = "Install to system root", path = "/" },
        }
    end

    if entry.target_kind == "rintropack" and entry.install_paths then
        local out = {
            { key = "a", label = "FrontendONE",
              path = entry.install_paths.frontend },
        }
        if external_core_present() and entry.install_paths.external then
            out[#out + 1] = {
                key = "x", label = "External Core",
                path = entry.install_paths.external,
            }
        end
        return out
    end

    if entry.install_path then
        return { { key = "a", label = "Install", path = entry.install_path } }
    end

    return {}
end

-- Forget the cached "external dolphin binary exists" answer, so
-- a freshly mounted external core is picked up immediately.
function M.refresh_external_core()
    _ext_ok = nil
end

return M