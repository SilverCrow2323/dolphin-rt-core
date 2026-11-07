-- core/tier_generator.lua — Rigenera LITE / MAX da STD.
-- Intensità 1..5 controlla quanto aggressivo è l'underclock e quanti
-- hack vengono attivati. Il file .intensity in ogni cartella tier
-- memorizza il valore.

local PMerger = (function()
    local ok, m = pcall(require, "core.profile_merger")
    if ok and m and m.parse_ini then return m end
    return { parse_ini = function(p) return nil end }
end)()

local M = {}

local FILES = { "Dolphin.ini", "GFX.ini" }

-- Overclock per intensità (1 = soft, 5 = aggressive)
local OC_LITE = { "0.92", "0.88", "0.85", "0.82", "0.78" }
local OC_MAX  = { "0.72", "0.68", "0.65", "0.60", "0.55" }

-- Trasformazioni per tier (per-sezione). I nomi delle sezioni coprono
-- sia lo schema "top-level" di GFX.ini sia lo schema "Video_*" di
-- GameSettings, così il generatore funziona in entrambi i casi.
local TRANSFORMS = {
    lite = {
        Core             = { OverclockEnable = "True" },
        Hacks            = { EFBAccessEnable = "False", VISkip = "False",
                             BBoxEnable = "False",
                             EFBToTextureEnable = "True" },
        Video_Hacks      = { EFBAccessEnable = "False", VISkip = "False",
                             BBoxEnable = "False",
                             EFBToTextureEnable = "True" },
        Settings         = { ShaderCompilationMode = "2" },
        Video_Settings   = { ShaderCompilationMode = "2" },
    },
    max = {
        Core             = { OverclockEnable = "True" },
        Hacks            = { EFBAccessEnable = "False", VISkip = "True",
                             BBoxEnable = "False",
                             EFBToTextureEnable = "True",
                             EFBEmulateFormatChanges = "False",
                             DeferEFBCopies = "True" },
        Video_Hacks      = { EFBAccessEnable = "False", VISkip = "True",
                             BBoxEnable = "False",
                             EFBToTextureEnable = "True",
                             EFBEmulateFormatChanges = "False",
                             DeferEFBCopies = "True" },
        Settings         = { ShaderCompilationMode = "3",
                             DisableFog = "True" },
        Video_Settings   = { ShaderCompilationMode = "3",
                             DisableFog = "True" },
    },
}

local function shq(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function read_ini(path)
    return PMerger.parse_ini(path)
end

local function write_ini(path, parsed)
    local f = io.open(path, "w")
    if not f then return false end
    local secs = {}
    for sec in pairs(parsed.data or {}) do secs[#secs + 1] = sec end
    table.sort(secs)
    for _, sec in ipairs(secs) do
        f:write("[" .. sec .. "]\n")
        local keys = parsed.order[sec] or {}
        local written = {}
        for _, k in ipairs(keys) do
            local v = parsed.data[sec][k]
            if v ~= nil then
                f:write(k .. " = " .. tostring(v) .. "\n")
                written[k] = true
            end
        end
        for k, v in pairs(parsed.data[sec]) do
            if not written[k] then
                f:write(k .. " = " .. tostring(v) .. "\n")
            end
        end
        f:write("\n")
    end
    f:close()
    return true
end

function M.read_intensity(family_dir, tier)
    local p = family_dir .. "/" .. tier .. "/.intensity"
    local f = io.open(p, "r")
    if not f then return 3 end
    local n = tonumber(f:read("*a"))
    f:close()
    return math.max(1, math.min(5, math.floor(n or 3)))
end

function M.write_intensity(family_dir, tier, n)
    local dir = family_dir .. "/" .. tier
    os.execute("mkdir -p " .. shq(dir))
    local f = io.open(dir .. "/.intensity", "w")
    if f then f:write(tostring(n)); f:close() end
end

function M.set_intensity(family_dir, tier, n)
    n = math.max(1, math.min(5, math.floor(tonumber(n) or 3)))
    M.write_intensity(family_dir, tier, n)
    return true
end

local function std_dir_of(family_dir)
    for _, cand in ipairs({
        family_dir .. "/std",
        family_dir,                     -- base case
    }) do
        for _, f in ipairs(FILES) do
            local fh = io.open(cand .. "/" .. f, "r")
            if fh then fh:close(); return cand end
        end
    end
    return nil
end

local function apply_transforms(parsed, tier, intensity)
    if not parsed then return parsed end
    parsed.data  = parsed.data  or {}
    parsed.order = parsed.order or {}

    local T = TRANSFORMS[tier]
    if T then
        for sec, kv in pairs(T) do
            parsed.data[sec]  = parsed.data[sec]  or {}
            parsed.order[sec] = parsed.order[sec] or {}
            for k, v in pairs(kv) do
                if parsed.data[sec][k] == nil then
                    table.insert(parsed.order[sec], k)
                end
                parsed.data[sec][k] = v
            end
        end
    end

    local oc = (tier == "lite") and OC_LITE[intensity] or OC_MAX[intensity]
    if oc then
        local sec = "Core"
        parsed.data[sec]  = parsed.data[sec]  or {}
        parsed.order[sec] = parsed.order[sec] or {}
        if parsed.data[sec].Overclock == nil then
            table.insert(parsed.order[sec], "Overclock")
        end
        parsed.data[sec].Overclock = oc
    end

    return parsed
end

function M.regenerate_tier(family_dir, tier)
    if tier ~= "lite" and tier ~= "max" then
        return false, "tier must be lite or max"
    end
    if not family_dir or family_dir == "" then
        return false, "no family dir"
    end

    local sd = std_dir_of(family_dir)
    if not sd then return false, "no STD/base tier" end

    local intensity = M.read_intensity(family_dir, tier)
    local target    = family_dir .. "/" .. tier
    os.execute("mkdir -p " .. shq(target))

    -- Backup tier esistente
    local ts   = os.date("%Y%m%d_%H%M%S")
    local bdir = target .. "/.backup_" .. ts
    os.execute("mkdir -p " .. shq(bdir))
    for _, f in ipairs(FILES) do
        local src = target .. "/" .. f
        local fh  = io.open(src, "r")
        if fh then
            fh:close()
            os.execute("cp -f " .. shq(src) .. " " .. shq(bdir .. "/" .. f))
        end
    end

    -- Read STD → apply → write
    local wrote_any = false
    for _, f in ipairs(FILES) do
        local parsed = read_ini(sd .. "/" .. f)
        if parsed then
            apply_transforms(parsed, tier, intensity)
            if write_ini(target .. "/" .. f, parsed) then
                wrote_any = true
            end
        end
    end

    if not wrote_any then return false, "no source files" end

    M.write_intensity(family_dir, tier, intensity)
    return true
end

function M.available_tiers(family_dir)
    local out = {}
    for _, t in ipairs({ "lite", "std", "max" }) do
        for _, f in ipairs(FILES) do
            local fh = io.open(family_dir .. "/" .. t .. "/" .. f, "r")
            if fh then fh:close(); out[t] = true; break end
        end
    end
    for _, f in ipairs(FILES) do
        local fh = io.open(family_dir .. "/" .. f, "r")
        if fh then fh:close(); out.base = true; break end
    end
    return out
end

return M
