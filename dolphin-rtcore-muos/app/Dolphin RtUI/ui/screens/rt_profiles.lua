-- ui/screens/rt_profiles.lua — Profile Editor picker with metal drawer.
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local Notify = require("ui.notify")
local PM     = require("core.profile_manager")
local sh     = require("core.sh")

local S = {}
local W, H = K.W, K.H
local PANEL_W = 440

local TYPE_META = {
    ["Rt:CORE"]     = { rgb = {0.96,0.77,0.26}, icon = "cube",   label = "Rt:CORE" },
    ["Balanced"]    = { rgb = {0.55,0.35,0.95}, icon = "gear",   label = "Balanced" },
    ["Performance"] = { rgb = {0.90,0.30,0.30}, icon = "play",   label = "Performance" },
    ["Accuracy"]    = { rgb = {0.30,0.85,0.40}, icon = "info",   label = "Accuracy" },
    ["Fix"]         = { rgb = {0.20,0.72,0.98}, icon = "wrench", label = "Fix" },
    ["Custom"]      = { rgb = {0.96,0.55,0.26}, icon = "star",   label = "Custom" },
}
local DEFAULT_META = { rgb = {0.55,0.35,0.95}, icon = "gear", label = "Other" }

local function glyph(name, cx, cy, s, col, a)
    a = a or 1
    K.color(col or K.C.text, a)
    love.graphics.setLineWidth(1.8)
    if name == "gear" then
        for i = 0, 7 do
            local ang = i * math.pi / 4
            love.graphics.line(cx + math.cos(ang)*s*0.55, cy + math.sin(ang)*s*0.55,
                               cx + math.cos(ang)*s, cy + math.sin(ang)*s)
        end
        love.graphics.circle("line", cx, cy, s * 0.55)
        love.graphics.circle("fill", cx, cy, s * 0.20)
    elseif name == "screen" then
        love.graphics.rectangle("line", cx - s*0.9, cy - s*0.7, s*1.8, s*1.3, 2, 2)
        love.graphics.line(cx, cy + s*0.6, cx, cy + s*0.9)
        love.graphics.line(cx - s*0.5, cy + s*0.9, cx + s*0.5, cy + s*0.9)
    elseif name == "wrench" then
        love.graphics.line(cx - s*0.7, cy + s*0.7, cx + s*0.3, cy - s*0.3)
        love.graphics.circle("line", cx + s*0.5, cy - s*0.5, s*0.4)
    elseif name == "star" then
        K.star(cx, cy, s * 0.9, col or K.C.text, a)
    elseif name == "info" then
        love.graphics.circle("line", cx, cy, s * 0.85)
        love.graphics.circle("fill", cx, cy - s*0.35, 1.8)
        love.graphics.line(cx, cy - s*0.05, cx, cy + s*0.55)
    elseif name == "cube" then
        love.graphics.polygon("line",
            cx, cy - s*0.85, cx + s*0.75, cy - s*0.42,
            cx + s*0.75, cy + s*0.42, cx, cy + s*0.85,
            cx - s*0.75, cy + s*0.42, cx - s*0.75, cy - s*0.42)
        love.graphics.line(cx - s*0.75, cy - s*0.42, cx, cy, cx + s*0.75, cy - s*0.42)
        love.graphics.line(cx, cy, cx, cy + s*0.85)
    elseif name == "play" then
        love.graphics.polygon("fill", cx - s*0.4, cy - s*0.6,
                                      cx - s*0.4, cy + s*0.6,
                                      cx + s*0.6, cy)
    elseif name == "plus" then
        love.graphics.line(cx - s*0.7, cy, cx + s*0.7, cy)
        love.graphics.line(cx, cy - s*0.7, cx, cy + s*0.7)
    end
    love.graphics.setLineWidth(1)
end

local ORDER = { "Rt:CORE", "Balanced", "Performance", "Accuracy", "Fix", "Custom", "Other" }

local function scan()
    local list, groups = {}, {}
    local ok, raw = pcall(PM.list, "rtcoreprofile")
    if not ok or type(raw) ~= "table" then return list, groups end
    for _, it in ipairs(raw) do
        local leaf = (it.name or ""):match("([^/]+)$") or it.name or ""
        if leaf ~= "lite" and leaf ~= "std" and leaf ~= "max" then
            local meta = it.meta or {}
            local pm, ui, rt = meta.Profile or {}, meta.UI or {}, meta.Runtime or {}
            local has = {
                lite = sh.is_dir(it.dir .. "/lite"), std = sh.is_dir(it.dir .. "/std"),
                max  = sh.is_dir(it.dir .. "/max"),
            }
            local family = has.lite or has.std or has.max
            local cat = pm.Type or (family and "Rt:CORE") or "Custom"
            local fam_key = family and "Rt:CORE" or cat
            local m = TYPE_META[fam_key] or DEFAULT_META
            list[#list + 1] = {
                name = it.name, dir = it.dir,
                label = pm.Name or it.name, desc = pm.Description or "",
                cat = cat, family = family, has = has,
                locked = tostring(rt.Locked or "False"):lower() == "true",
                icon = m.icon, type_label = m.label, rgb = m.rgb,
            }
        end
    end
    for _, p in ipairs(list) do
        groups[p.type_label] = groups[p.type_label] or {}
        table.insert(groups[p.type_label], p)
    end
    for _, g in pairs(groups) do
        table.sort(g, function(a, b) return (a.label or ""):lower() < (b.label or ""):lower() end)
    end
    return list, groups
end

S.phase = "intro"
S.t, S.slide, S.sel = 0, 0, 1
S.rows = {}

local function build_rows()
    S.rows = {}
    for _, gname in ipairs(ORDER) do
        local g = S.groups[gname]
        if g and #g > 0 then
            S.rows[#S.rows + 1] = { head = true, label = gname }
            for _, p in ipairs(g) do S.rows[#S.rows + 1] = { profile = p } end
        end
    end
    S.rows[#S.rows + 1] = { new = true }
end

function S.enter(params)
    params = params or {}
    S.t, S.slide, S.phase = 0, 0, "intro"
    S.picked = nil
    local _, groups = scan()
    S.groups = groups
    build_rows()
    S.sel = 1
    for i, r in ipairs(S.rows) do if not r.head then S.sel = i; break end end
    if params.focus then
        for i, r in ipairs(S.rows) do
            if r.profile and r.profile.name == params.focus then S.sel = i; break end
        end
    end
    K.set_accent("gc")
end

function S.leave() end

function S.update(dt)
    S.t = S.t + dt
    if S.phase == "intro" then
        S.slide = math.min(1, S.slide + dt * 3.5)
        if S.slide >= 1 then S.phase = "browse" end
    elseif S.phase == "pick" then
        S.slide = math.max(0, S.slide - dt * 5)
        if S.slide <= 0 then
            local p = S.picked
            require("ui").go("rt_editor", {
                mode = "core", profile = p.name, name = p.label,
                dir = p.dir, locked = p.locked,
                icon = p.icon, type_label = p.type_label, rgb = p.rgb,
            })
        end
    end
end

local function move_row(d)
    local n = #S.rows
    local i = S.sel
    for _ = 1, n do
        i = i + d
        if i < 1 then i = n elseif i > n then i = 1 end
        if S.rows[i] and not S.rows[i].head then S.sel = i; SFX.play("menu_move"); return end
    end
end

local function create_new()
    local name = "Custom_" .. os.date("%m%d_%H%M")
    local dst = "workshop/rtcoreprofile/" .. name
    sh.mkdir_p(dst)
    local src = "workshop/rtcoreprofile/Default"
    if sh.is_dir(src) then
        os.execute("cp -a " .. sh.shq(src) .. "/. " .. sh.shq(dst) .. "/ 2>/dev/null")
    else
        for _, f in ipairs({ "Dolphin.ini", "GFX.ini" }) do
            local o = io.open(dst .. "/" .. f, "w"); if o then o:write(""); o:close() end
        end
    end
    local meta = io.open(dst .. "/rtprofile_data.ini", "w")
    if meta then
        meta:write("[Profile]\nName        = " .. name .. "\nType        = Custom\n")
        meta:write("Family      = Custom\nDescription = Created from Profile Editor\n")
        meta:write("Author      = RtUI\nVersion     = 1.0.0\n\n")
        meta:write("[UI]\nColor       = #F5A742\nIcon        = star\nOrder       = 999\n\n")
        meta:write("[Runtime]\nLocked      = False\n")
        meta:close()
    end
    SFX.play("newupdate")
    Notify.show("success", "Created " .. name)
    local _, groups = scan()
    S.groups = groups
    build_rows()
    for i, r in ipairs(S.rows) do
        if r.profile and r.profile.name == name then S.sel = i; break end
    end
end

-- NEXUS action adapters. Profile selection and creation stay owned by
-- this screen; navigation remains delegated to ui/init.lua.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end

    local function selected_profile()
        local row = S.rows and S.rows[S.sel]
        return row and row.profile or nil
    end

    local specs = {
        {
            id = "profiles.refresh", title = "Refresh profile list", order = 10,
            run = function()
                if S.phase ~= "browse" then return false, "profile picker is not ready" end
                local _, groups = scan()
                S.groups = groups
                build_rows()
                S.sel = math.max(1, math.min(S.sel or 1, #S.rows))
                return true
            end,
        },
        {
            id = "profiles.create", title = "Create custom profile", order = 20,
            run = function()
                if S.phase ~= "browse" then return false, "profile picker is not ready" end
                create_new()
                return true
            end,
        },
        {
            id = "profiles.open_selected", title = "Open selected profile", order = 30,
            run = function()
                if S.phase ~= "browse" then return false, "profile picker is not ready" end
                local p = selected_profile()
                if not p then return false, "no profile selected" end
                S.picked = p
                S.phase = "pick"
                SFX.play("menu_select")
                return true
            end,
        },
        {
            id = "profiles.open", title = "Open profile by ID", order = 40,
            run = function(name)
                if S.phase ~= "browse" then return false, "profile picker is not ready" end
                if type(name) ~= "string" or name == "" then
                    return false, "profile name is required"
                end
                for i, row in ipairs(S.rows or {}) do
                    if row.profile and row.profile.name == name then
                        S.sel = i
                        S.picked = row.profile
                        S.phase = "pick"
                        SFX.play("menu_select")
                        return true
                    end
                end
                return false, "profile not found: " .. name
            end,
        },
    }

    local failures = {}
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "profiles", screen = "rt_profiles", order = spec.order,
        })
        if not ok then failures[#failures + 1] = spec.id .. ": " .. tostring(err) end
    end
    if #failures > 0 then return false, table.concat(failures, "; ") end
    return true
end

function S.pad(b)
    if S.phase ~= "browse" then return end
    local row = S.rows[S.sel]
    if b == "UP" then move_row(-1)
    elseif b == "DOWN" then move_row(1)
    elseif b == "A" and row then
        if row.new then create_new()
        elseif row.profile then
            S.picked = row.profile
            S.phase = "pick"
            SFX.play("menu_select")
        end
    elseif b == "B" then require("ui").back() end
end

local function draw_row(row, x, y, w, h, focused)
    if row.head then
        K.text("key", row.label, x + 4, y + h - 22, K.C.faint, 1)
        K.color(K.C.line, 0.5)
        love.graphics.rectangle("fill", x + 12 + K.width("key", row.label), y + h - 14,
                                w - 24 - K.width("key", row.label), 1)
        return
    end
    if row.new then
        K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6, accent = K.ACC.sys })
        glyph("plus", x + 24, y + h / 2, 10, focused and K.ACC.sys or K.C.dim, 1)
        K.text("body", "Create new profile", x + 46, y + h / 2 - 9,
               focused and K.ACC.sys or K.C.text)
        return
    end
    local p = row.profile
    local acc = p.rgb or K.ACC.gc
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6, accent = acc })
    local cx, cy = x + 26, y + h / 2
    K.color(acc, 0.18); love.graphics.circle("fill", cx, cy, 14)
    K.color(acc, 1);    love.graphics.circle("line", cx, cy, 14)
    glyph(p.icon, cx, cy, 9, acc, 1)
    K.text("body", K.clip("body", p.label, w - 180), x + 48, y + h / 2 - 9,
           focused and K.C.text or K.C.dim)
    local badge = p.family and "RT:CORE" or p.cat:upper()
    local bw = K.width("key", badge) + 12
    K.color(acc, 0.20); love.graphics.rectangle("fill", x + w - bw - 8, y + h / 2 - 10, bw, 20, 4, 4)
    K.color(acc, 1);    love.graphics.rectangle("line", x + w - bw - 8, y + h / 2 - 10, bw, 20, 4, 4)
    K.text("key", badge, x + w - bw - 2, y + h / 2 - 7, acc)
    if p.family then
        local dotx = x + w - bw - 22
        for i, t in ipairs({ "lite", "std", "max" }) do
            if p.has[t] then
                local c = (t == "lite" and K.ACC.wii) or (t == "std" and K.C.ok) or K.C.bad
                K.color(c, 1)
                love.graphics.circle("fill", dotx - (3 - i) * 8, y + h / 2, 2.5)
            end
        end
    end
end

local function draw_panel()
    local ox = -PANEL_W * (1 - S.slide)
    K.color({ 0, 0, 0 }, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, H)
    K.color({ 0.11, 0.12, 0.15 }, 1)
    love.graphics.rectangle("fill", ox, 0, PANEL_W, H)
    for i = 0, H, 4 do
        K.color({ 1, 1, 1 }, 0.010 + (i % 8 == 0 and 0.010 or 0))
        love.graphics.rectangle("fill", ox, i, PANEL_W, 1)
    end
    local acc = K.ACC.gc
    K.color(acc, 0.9)
    love.graphics.rectangle("fill", ox + PANEL_W - 3, 0, 3, H)
    K.text("title", "PROFILE EDITOR", ox + 20, 20, K.C.text)
    K.color(acc, 0.5); love.graphics.rectangle("fill", ox + 20, 54, PANEL_W - 40, 1)
    K.text("small", "Pick a profile or create a new one", ox + 20, 62, K.C.dim)
    local list_y = 96
    local row_h = 44
    local visible_h = H - list_y - 40
    local sel_y = list_y
    for i, r in ipairs(S.rows) do
        local hh = r.head and 24 or row_h
        if i < S.sel then sel_y = sel_y + hh end
    end
    local scroll = math.max(0, sel_y + row_h - (list_y + visible_h))
    love.graphics.setScissor(ox, list_y, PANEL_W - 30, visible_h)
    local y = list_y - scroll
    for i, r in ipairs(S.rows) do
        local hh = r.head and 24 or row_h
        if y + hh > list_y and y < list_y + visible_h then
            draw_row(r, ox + 16, y, PANEL_W - 48, hh, i == S.sel)
        end
        y = y + hh
    end
    love.graphics.setScissor()
    K.text("small", "A open · B back", ox + 20, H - 26, K.C.faint)
end

function S.draw()
    K.bg()
    if S.slide < 0.98 then
        local rx = PANEL_W + 20
        K.text("title", "Profile Editor", rx, 80, K.C.text)
        K.text("body", "Choose a profile to edit its INI settings.",
               rx, 130, K.C.dim, 1, W - rx - 20)
        if S.picked then
            K.text("h", "Opening: " .. (S.picked.label or "?"), rx, 200, K.ACC.gc)
        end
    end
    draw_panel()
end

return S
