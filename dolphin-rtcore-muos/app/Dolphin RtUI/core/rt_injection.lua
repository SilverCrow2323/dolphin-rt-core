-- core/rt_injection.lua — turn a flat profile into an Rt:CORE family.

local sh = require("core.sh")
local TG = require("core.tier_generator")

local M = {}

function M.inject(src_dir, root)
    if not src_dir or not root then return nil, "missing args" end
    if not sh.is_dir(src_dir) then return nil, "source not found" end

    local name = src_dir:match("([^/]+)$") or "Profile"
    local clean = name:gsub("%W", "")
    if clean == "" then clean = "Profile" end
    local fam_name = "Rt" .. clean
    local fam_dir = root .. "/" .. fam_name

    os.execute("mkdir -p " .. sh.shq(fam_dir .. "/std"))

    for _, f in ipairs({ "Dolphin.ini", "GFX.ini" }) do
        local sf = src_dir .. "/" .. f
        if sh.is_file(sf) then
            sh.atomic_copy(sf, fam_dir .. "/std/" .. f)
        end
    end

    TG.regenerate_tier(fam_dir, "lite")
    TG.regenerate_tier(fam_dir, "max")

    local f = io.open(fam_dir .. "/rtprofile_data.ini", "wb")
    if f then
        f:write("[Profile]\n")
        f:write("Name        = " .. fam_name .. "\n")
        f:write("Type        = Rt:CORE\n")
        f:write("Family      = RtBoost\n")
        f:write("Description = Created by Rt:Injection from " .. name .. "\n")
        f:write("Author      = Rt:Injection\n")
        f:write("Version     = 1.0.0\n")
        f:write("Date        = " .. os.date("%Y-%m-%d") .. "\n")
        f:write("\n[UI]\n")
        f:write("Color       = #4CC850\n")
        f:write("Icon        = droplet\n")
        f:write("Order       = 100\n")
        f:write("\n[Runtime]\n")
        f:write("Locked      = False\n")
        f:close()
    end
    return fam_dir
end

return M
