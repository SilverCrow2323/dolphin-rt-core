-- core/rtcore_triage.lua — Rt:Core environment triage (v2, Flavour III).
--
-- Checks that the three layers of Dolphin Rt:Core are really installed:
--   I   Comfort Zone  — emulator, launcher, content assignments
--   II  Bash Arsenal  — RtSys profile engine + Task Toolkit
--   III FrontendONE   — this very app (Rt:UI)
-- and collects a few numbers (ROMs, disk, content). The scan is INCREMENTAL:
-- begin() builds a job, step(job) runs one small unit (one popen at most) so
-- the UI keeps animating while the scan runs. scan() runs the whole job
-- synchronously (used by headless tools / tests).
--
-- DOLPHINUI_TRIAGE_ROOT=<dir> prefixes every /opt, /mnt and /run path — lets
-- the PC build be tested against a fake muOS tree.

local M  = {}
local sh = require("core.sh")

local ROOT = os.getenv("DOLPHINUI_TRIAGE_ROOT") or ""
local function R(p)
    if ROOT ~= "" and (p:match("^/opt/") or p:match("^/mnt/") or p:match("^/run/")) then
        return ROOT .. p
    end
    return p
end

local EMU = "/opt/muos/share/emulator/dolphin"

-- kind: dir | file | exec | any     crit: failing it means "broken"
local function app(p) return sh.abs and sh.abs(p) or p end

local function flavours()
    return {
    { id = "I", name = "Comfort Zone", tag = "BASE ENGINE", accent = "gc",
      blurb = "Emulator, launcher, assignments.",
      checks = {
        { label = "Emulator folder",   path = EMU,                                   kind = "dir",  crit = true,
          hint = "Install the Rt:Core package first." },
        { label = "Dolphin binary",    path = EMU .. "/dolphin",                     kind = "exec", crit = true,
          hint = "Binary missing or not executable." },
        { label = "Launcher script",   path = "/opt/muos/script/launch/ext-dolphinrt.sh", kind = "exec", crit = true,
          hint = "muOS cannot start games." },
        { label = "Assign: GameCube",  path = "/opt/muos/share/info/assign/Nintendo GameCube", kind = "any",
          hint = "No Dolphin core offered for GameCube." },
        { label = "Assign: Wii",       path = "/opt/muos/share/info/assign/Nintendo Wii",      kind = "any",
          hint = "No Dolphin core offered for Wii." },
      } },
    { id = "II", name = "Bash Arsenal", tag = "POWER LAYER", accent = "boost",
      blurb = "Tier profiles and Task Toolkit.",
      checks = {
        { label = "RtSys engine",      path = EMU .. "/RtSys",                       kind = "dir",  crit = true,
          hint = "Tiers and device baseline need RtSys." },
        { label = "apply_profile.sh",  path = EMU .. "/RtSys/apply_profile.sh",      kind = "exec", crit = true,
          hint = "launch.sh applies the baseline with it." },
        { label = "Task Toolkit",      path = "/opt/muos/share/task/Dolphin RtCore", kind = "any",
          hint = "Task Toolkit entry is missing." },
      } },
    { id = "III", name = "FrontendONE", tag = "THIS APP", accent = "wii",
      blurb = "Rt:UI, workshop and databases.",
      checks = {
        { label = "main.lua",          path = app("main.lua"),                       kind = "file", crit = true,
          hint = "The app folder is incomplete." },
        { label = "LÖVE runtime",      path = app("lib/love"),                       kind = "exec", crit = true,
          hint = "lib/love missing or not executable." },
        { label = "Launch pipeline",   path = app("scripts/launch.sh"),              kind = "exec", crit = true,
          hint = "Games cannot start without launch.sh." },
        { label = "Workshop profiles", path = app("workshop/rtcoreprofile"),         kind = "dir",
          hint = "Profile editor would be empty." },
        { label = "Compatibility DB",  path = app("data/games_data.json"),           kind = "file",
          hint = "No compatibility data (Settings > Update)." },
        { label = "Cheat database",    path = app("data/rtcheats_db.json"),          kind = "file",
          hint = "Cheats & Boost need it (Settings > Update)." },
      } },
    }
end

-- ── probes ──────────────────────────────────────────────────
local function probe(p)                      -- → exists, is_dir
    local f = io.open(R(p), "rb")
    if not f then return false, false end
    local _, _, code = f:read(0)
    f:close()
    return true, code == 21
end

local function shell_line(cmd)
    local h = io.popen(cmd .. " 2>/dev/null")
    if not h then return "" end
    local s = h:read("*a") or ""; h:close()
    return s
end

local function human_kb(kb)
    kb = tonumber(kb) or 0
    if kb >= 1048576 then return string.format("%.1f GB", kb / 1048576) end
    if kb >= 1024    then return string.format("%.0f MB", kb / 1024) end
    return kb .. " KB"
end
M.human_kb = human_kb

-- ── job ─────────────────────────────────────────────────────
local function run_flavour(job, i)
    local fl = job.flavours[i]
    local pass, total, crit_fail = 0, #fl.checks, false
    for _, c in ipairs(fl.checks) do
        local ex, isdir = probe(c.path)
        local ok
        if c.kind == "dir"  then ok = ex and isdir
        elseif c.kind == "file" then ok = ex and not isdir
        else ok = ex end                       -- exec/any: exec bit checked later
        c.ok = ok and true or false
        if c.ok then pass = pass + 1 elseif c.crit then crit_fail = true end
    end
    fl.pass, fl.total = pass, total
    fl.state = (pass == total) and "ok" or ((pass == 0 or crit_fail) and "missing" or "partial")
end

local function run_exec_bits(job)
    local list = {}
    for _, fl in ipairs(job.flavours) do
        for _, c in ipairs(fl.checks) do
            if c.kind == "exec" and c.ok then list[#list + 1] = c end
        end
    end
    if #list == 0 then return end
    local parts = {}
    for i, c in ipairs(list) do
        parts[#parts + 1] = string.format("[ -x %s ] && echo %d", sh.shq(R(c.path)), i)
    end
    local out = shell_line(table.concat(parts, "; "))
    local good = {}
    for n in out:gmatch("%d+") do good[tonumber(n)] = true end
    for i, c in ipairs(list) do
        if not good[i] then c.ok = false; c.noexec = true end
    end
    -- recompute flavour totals after exec-bit demotions
    for _, fl in ipairs(job.flavours) do
        local pass, crit_fail = 0, false
        for _, c in ipairs(fl.checks) do
            if c.ok then pass = pass + 1 elseif c.crit then crit_fail = true end
        end
        fl.pass = pass
        fl.state = (pass == fl.total) and "ok" or ((pass == 0 or crit_fail) and "missing" or "partial")
    end
end

local function rom_roots()
    local out = {}
    local ok, St = pcall(require, "core.settings")
    if ok and St.data and type(St.data.rom_paths) == "table" then
        for _, e in ipairs(St.data.rom_paths) do
            if e.path then out[#out + 1] = { path = e.path, system = e.system or "GC" } end
        end
    end
    if #out == 0 then
        out = { { path = "/mnt/mmc/ROMS/Nintendo GameCube", system = "GC" },
                { path = "/mnt/mmc/ROMS/Nintendo Wii",      system = "Wii" } }
    end
    return out
end

local function run_roms(job, idx)
    local r = job.roots[idx]
    local depth = 4
    pcall(function() depth = tonumber(require("core.settings").get("scan_depth")) or 4 end)
    local cmd = string.format(
        "find %s -maxdepth %d -type f \\( -iname '*.iso' -o -iname '*.rvz' -o -iname '*.wbfs' " ..
        "-o -iname '*.gcm' -o -iname '*.gcz' -o -iname '*.ciso' -o -iname '*.wia' \\) | wc -l",
        sh.shq(R(r.path)), depth)
    local n = tonumber(shell_line(cmd):match("(%d+)")) or 0
    local sys = tostring(r.system):upper() == "WII" and "wii" or "gc"
    job.stats[sys] = (job.stats[sys] or 0) + n
    job.stats.roms = (job.stats.roms or 0) + n
    local ex = probe(r.path)
    if not ex then job.stats.missing_roots = (job.stats.missing_roots or 0) + 1 end
end

local function run_disk(job)
    job.stats.disk_kb = tonumber(shell_line("du -sk " .. sh.shq(R(EMU))):match("(%d+)")) or 0
end

local function run_free(job)
    local target = "/mnt/sdcard"
    if not probe(target) then target = "/mnt/mmc" end
    if not probe(target) then target = "/" end
    local line = shell_line("df -Pk " .. sh.shq(R(target)) .. " | tail -1")
    local total, used, avail = line:match("%S+%s+(%d+)%s+(%d+)%s+(%d+)")
    job.stats.sd_total_kb = tonumber(total)
    job.stats.sd_free_kb  = tonumber(avail)
end

local function run_content(job)
    local function count(dirpath, pattern)
        local out = shell_line("find " .. sh.shq(app(dirpath)) .. " -mindepth 1 -maxdepth 1 " .. pattern .. " | wc -l")
        return tonumber(out:match("(%d+)")) or 0
    end
    job.stats.profiles     = count("workshop/rtcoreprofile", "-type d")
    job.stats.gamesettings = count("workshop/gamesettings",   "-type d")
    job.stats.gamecards    = count("workshop/gameslibrary",   "-type f")
    local n = 0
    pcall(function() for _ in pairs(require("core.rtcheats").index()) do n = n + 1 end end)
    job.stats.cheats = n
end

local function run_versions(job)
    pcall(function()
        local V = dofile(app("version.lua"))
        job.stats.ui_version   = V.string
        job.stats.ui_codename  = V.codename
        job.stats.core_version = (V.core or ""):match("v([%d%.]+)") or "?"
        job.stats.build        = V.build
    end)
    for _, p in ipairs({ "/opt/muos/config/system/version", "/opt/muos/config/version",
                         "/opt/muos/version" }) do
        local f = io.open(R(p), "r")
        if f then
            local s = (f:read("*l") or ""):gsub("%s+$", ""); f:close()
            if s ~= "" then job.stats.muos = s; break end
        end
    end
end

function M.begin()
    local job = { flavours = flavours(), roots = rom_roots(), stats = {}, i = 0, steps = {}, done = false }
    local S = job.steps
    for i = 1, #job.flavours do
        S[#S + 1] = { "Flavour " .. job.flavours[i].id, function() run_flavour(job, i) end }
    end
    S[#S + 1] = { "Permissions", function() run_exec_bits(job) end }
    for i = 1, #job.roots do
        S[#S + 1] = { "ROM folders", function() run_roms(job, i) end }
    end
    S[#S + 1] = { "Emulator size", function() run_disk(job) end }
    S[#S + 1] = { "Free space",    function() run_free(job) end }
    S[#S + 1] = { "Content",       function() run_content(job) end }
    S[#S + 1] = { "Versions",      function() run_versions(job) end }
    job.n = #S
    return job
end

-- one unit of work; returns true while there is more to do
function M.step(job)
    if job.done then return false end
    job.i = job.i + 1
    local s = job.steps[job.i]
    if not s then job.done = true; M.finish(job); return false end
    job.current = s[1]
    local ok, err = pcall(s[2])
    if not ok then job.errors = (job.errors or "") .. tostring(err) .. "\n" end
    if job.i >= job.n then job.done = true; M.finish(job); return false end
    return true
end

function M.progress(job) return job.n and job.n > 0 and (job.i / job.n) or 1 end

-- overall verdict: 100 = everything present
function M.finish(job)
    local pass, total, broken = 0, 0, false
    for _, fl in ipairs(job.flavours) do
        pass, total = pass + (fl.pass or 0), total + (fl.total or 0)
        if fl.state == "missing" then broken = true end
    end
    job.score = total > 0 and (pass / total) or 0
    job.pass, job.total = pass, total
    if pass == total then job.verdict = "HEALTHY"
    elseif broken then job.verdict = "BROKEN"
    else job.verdict = "DEGRADED" end
    -- ordered list of what to fix first (critical first)
    job.fixes = {}
    for _, fl in ipairs(job.flavours) do
        for _, c in ipairs(fl.checks) do
            if not c.ok then
                job.fixes[#job.fixes + 1] = { flavour = fl.id, label = c.label, crit = c.crit,
                    hint = c.noexec and (c.label .. " is not executable (chmod +x).") or c.hint }
            end
        end
    end
    table.sort(job.fixes, function(a, b)
        if (a.crit and 1 or 0) ~= (b.crit and 1 or 0) then return a.crit and true or false end
        return a.flavour < b.flavour
    end)
end

function M.scan()
    local job = M.begin()
    while M.step(job) do end
    return job
end

-- plain-text report (saved to data/logs/triage_report.txt)
function M.report(job)
    local L = {}
    L[#L + 1] = "Dolphin Rt:Core — Env Triage report"
    L[#L + 1] = os.date("%Y-%m-%d %H:%M:%S")
    local st = job.stats or {}
    L[#L + 1] = string.format("Rt:UI %s (%s)  ·  Rt:Core %s  ·  muOS %s", st.ui_version or "?",
        st.build or "?", st.core_version or "?", st.muos or "n/a")
    L[#L + 1] = string.format("VERDICT: %s  (%d/%d checks, %d%%)", job.verdict or "?",
        job.pass or 0, job.total or 0, math.floor((job.score or 0) * 100 + 0.5))
    L[#L + 1] = ""
    for _, fl in ipairs(job.flavours) do
        L[#L + 1] = string.format("Flavour %s · %s — %s (%d/%d)", fl.id, fl.name,
            (fl.state or "?"):upper(), fl.pass or 0, fl.total or 0)
        for _, c in ipairs(fl.checks) do
            L[#L + 1] = string.format("  [%s] %-18s %s", c.ok and "OK" or "--", c.label, c.path)
        end
    end
    L[#L + 1] = ""
    L[#L + 1] = string.format("ROMs: %d (GC %d / Wii %d)  ·  Emulator: %s  ·  SD free: %s",
        st.roms or 0, st.gc or 0, st.wii or 0, human_kb(st.disk_kb),
        st.sd_free_kb and human_kb(st.sd_free_kb) or "n/a")
    L[#L + 1] = string.format("Profiles: %d  ·  GameSettings: %d  ·  Game cards: %d  ·  Cheat titles: %d",
        st.profiles or 0, st.gamesettings or 0, st.gamecards or 0, st.cheats or 0)
    if job.fixes and #job.fixes > 0 then
        L[#L + 1] = ""
        L[#L + 1] = "TO FIX:"
        for _, f in ipairs(job.fixes) do
            L[#L + 1] = string.format("  %s Flavour %s · %s — %s", f.crit and "!!" or " -", f.flavour, f.label, f.hint or "")
        end
    end
    return table.concat(L, "\n") .. "\n"
end

function M.save_report(job)
    local path = app("data/logs/triage_report.txt")
    os.execute("mkdir -p " .. sh.shq(app("data/logs")) .. " 2>/dev/null")
    local f = io.open(path, "w")
    if not f then return nil end
    f:write(M.report(job)); f:close()
    return "data/logs/triage_report.txt"
end

-- legacy helpers kept for older callers (settings toggles)
function M.toggle(id, on)
    local flag = "/tmp/rtcore_triage_" .. id .. ".on"
    if on then local f = io.open(flag, "w"); if f then f:close() end
    else os.remove(flag) end
end
function M.is_on(id)
    local f = io.open("/tmp/rtcore_triage_" .. id .. ".on", "r")
    if f then f:close(); return true end
    return false
end

return M
