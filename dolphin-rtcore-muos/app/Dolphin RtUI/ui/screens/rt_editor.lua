-- ui/screens/rt_editor.lua — 4-tab GUI editor for Dolphin INI options.
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local Notify = require("ui.notify")
local Modal  = require("ui.modal")
local Ini    = require("core.ini_edit")
local Cats   = require("core.editor_categories")
local GDB    = require("core.guide_db")
local GP     = require("core.guide_parser")
local sh     = require("core.sh")

local S = {}

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
    end
    love.graphics.setLineWidth(1)
end

S.mode = "core"
S.tab = 1
S.dirty = false
S.list = K.List(K.MARGIN, 134, K.W - K.MARGIN * 2 - 20, K.BOT - 134, 50)

local _gc = {}
local GUIDE_FILES = {
    dolphin = "data/guide/dolphin_guide.ini",
    gfx = "data/guide/gfx_guide.ini",
    gamesettings = "data/guide/gamesettings_guide.ini",
}

local function load_guide(name)
    if _gc[name] ~= nil then return _gc[name] or nil end
    if GDB and type(GDB.load) == "function" then
        local ok, g = pcall(GDB.load, name)
        if ok and g then _gc[name] = g; return g end
    end
    local path = GUIDE_FILES[name]
    if not path then _gc[name] = false; return nil end
    local ok, parsed = pcall(GP.parse, path)
    if not ok or not parsed then _gc[name] = false; return nil end
    local out = { sections = {} }
    for sec_name, sec in pairs(parsed.sections or {}) do
        local s_out = { order = {}, items = {} }
        for _, key in ipairs(sec.order or {}) do
            local o = sec.options[key]
            if o then
                local dt = (o.declared_type or ""):lower()
                local kind = "text"
                if dt:find("bool") then kind = "bool"
                elseif dt:find("int") then kind = "int"
                elseif dt:find("float") then kind = "float"
                elseif dt:find("path") then kind = "path" end
                local mn, mx
                local a, b = dt:match("(%-?%d+%.?%d*)%s*%-%s*(%-?%d+%.?%d*)")
                if a and b then
                    mn, mx = tonumber(a), tonumber(b)
                    if kind == "text" then kind = "float" end
                end
                s_out.order[#s_out.order+1] = key
                s_out.items[key] = {
                    key = key, description = o.desc or "",
                    effects = o.effects or "",
                    default = o.default or o.value or "",
                    type = { kind = kind, min = mn, max = mx },
                    hints = (o.hints and o.hints ~= "") and { o.hints } or {},
                    recommend = o.recommend,
                    muos = { flag = o.muos or "other", rec = o.recommend },
                }
            end
        end
        out.sections[sec_name] = s_out
    end
    _gc[name] = out
    return out
end

local FALLBACK_TYPES = {
    -- Core
    CPUCore = "int", CPUThread = "bool", Overclock = "float",
    OverclockEnable = "bool", EnableIdleSkipping = "bool",
    Framelimit = "int", Fastmem = "bool", MMU = "bool",
    SyncGPU = "bool", EmulationSpeed = "float", TimingVariance = "int",
    FPRF = "bool",
    -- DSP
    DSPThread = "bool", Backend = "text",
    -- Video
    InternalResolution = "float", AspectRatio = "int",
    DisableFog = "bool", FastDepthCalc = "bool",
    ShaderCompilationMode = "int", MSAA = "int",
    MaxAnisotropy = "int", SafeTextureCacheColorSamples = "int",
    -- Hacks
    VISkip = "bool", EFBToTextureEnable = "bool", EFBAccessEnable = "bool",
    XFBToTextureEnable = "bool", DeferEFBCopies = "bool",
    SkipDuplicateXFBs = "bool", VertexRounding = "bool",
    FastTextureSampling = "bool", EFBEmulateFormatChanges = "bool",
    BBoxEnable = "bool",
    -- Enhancements
    ForceTrueColor = "bool", DisableCopyFilter = "bool",
    ArbitraryMipmapDetection = "bool",
}

local function guide_for(item)
    if not item or not item.sec then return nil end
    local name = (S.mode == "game") and "gamesettings"
        or ((Cats.file_for_core(item.sec) == "GFX.ini") and "gfx" or "dolphin")
    local g = load_guide(name)
    if g and g.sections[item.sec] and g.sections[item.sec].items[item.key] then
        return g.sections[item.sec].items[item.key]
    end
    -- fallback stub: usa FALLBACK_TYPES per indovinare il tipo
    local k = item.key or "?"
    local kind = FALLBACK_TYPES[k] or "bool"
    return {
        key = k,
        description = "",
        effects = "",
        default = (kind == "bool") and "False" or "",
        type = { kind = kind },
        hints = {},
        muos = { flag = "other", rec = nil },
    }
end

local function load_core_files(dir)
    S.files = {}
    for _, name in ipairs({ "Dolphin.ini", "GFX.ini" }) do
        S.files[name] = { path = dir .. "/" .. name, lines = Ini.read_lines(dir .. "/" .. name) }
    end
end
local function load_game_file(path)
    S.file = { path = path, lines = Ini.read_lines(path) }
end
local function file_of(item)
    if S.mode == "game" then return S.file end
    return S.files[Cats.file_for_core(item.sec)]
end
local function current_value(item)
    local f = file_of(item)
    if not f then return nil, false end
    local v = Ini.get(f.lines, item.sec, item.key)
    if v == nil or v == "" then
        local g = guide_for(item)
        return g and g.default or nil, false
    end
    return v, true
end
local function set_value(item, value)
    if S.locked and S.mode ~= "game" then return false, "profile is locked" end
    local f = file_of(item)
    if not f then return false, "configuration file unavailable" end
    Ini.set(f.lines, item.sec, item.key, value)
    S.dirty = true
    return true
end

local function build_list()
    local tab = Cats.tabs_for(S.mode)[S.tab]
    local rows = {}
    if tab then
        local data = Cats.tab(S.mode, tab.id)
        for _, entry in ipairs(data.items) do
            local guide = guide_for(entry)
            if guide then
                local v, present = current_value(entry)
                rows[#rows + 1] = { item = entry, guide = guide, label = guide.key, value = v, present = present }
            end
        end
    end
    S.list:set(rows, false)
    S.list.sel = 1
end

local function switch_tab(d)
    local tabs = Cats.tabs_for(S.mode)
    S.tab = ((S.tab - 1 + d) % #tabs) + 1
    build_list(); SFX.play("menu_pagescroll")
end

local function type_of(g) return g and g.type and g.type.kind or "text" end
local function step_of(g)
    local t = g and g.type or {}
    if t.kind == "float" then return ((t.max or 2) - (t.min or 0)) <= 2.5 and 0.05 or 0.1 end
    if t.kind == "int" then return ((t.max or 0) - (t.min or 0)) >= 100 and 5 or 1 end
    return 1
end
local function fmt_num(n) local s = string.format("%.2f", n); return (s:gsub("0+$", ""):gsub("%.$", "")) end

local function change(row, dir)
    if not row then return false, "no option selected" end
    if S.locked and S.mode ~= "game" then
        Notify.show("warning", "Profilo bloccato: copialo per modificarlo")
        return false, "profile is locked"
    end
    local g = row.guide; local kind = type_of(g)
    local cur = row.value or (g and g.default) or ""
    if kind == "bool" then
        local nv = (tostring(cur):lower() == "true") and "False" or "True"
        local ok, err = set_value(row.item, nv)
        if not ok then return false, err end
        row.value = nv; SFX.play("menu_toggleoption")
        return true
    elseif kind == "int" or kind == "float" then
        local n = (tonumber(cur) or 0) + dir * step_of(g)
        local t = g.type
        if t.min and n < t.min then n = t.min end
        if t.max and n > t.max then n = t.max end
        local nv = (kind == "int") and tostring(math.floor(n + 0.5)) or fmt_num(n)
        local ok, err = set_value(row.item, nv)
        if not ok then return false, err end
        row.value = nv; SFX.play("menu_toggleoption")
        return true
    end
    return false, "selected option is not editable"
end

local function apply_recommend(row)
    if not row or not row.guide then return false, "no option selected" end
    if S.locked and S.mode ~= "game" then
        Notify.show("warning", "Profilo bloccato: copialo per modificarlo")
        return false, "profile is locked"
    end
    local rec = (row.guide.muos and row.guide.muos.rec) or row.guide.recommend
    if not rec or rec == "" then Notify.show("info", "No recommendation"); return false, "no recommendation available" end
    rec = tostring(rec):gsub("%s*%b()%s*$", "")
    local lo = rec:match("^(%-?[%d%.]+)%s*%-%s*[%d%.]+$")
    if lo then rec = lo end
    local ok, err = set_value(row.item, rec)
    if not ok then return false, err end
    row.value = rec
    SFX.play("menu_select"); Notify.show("info", "Set to " .. rec)
    return true
end

local function save()
    if S.locked and S.mode ~= "game" then return false, "profile is locked" end
    local function write(file)
        if not file or type(file.path) ~= "string" then
            return false, "configuration file unavailable"
        end
        local ok, result = pcall(Ini.write_lines, file.path, file.lines)
        if not ok then return false, tostring(result) end
        if result ~= true then return false, "could not write " .. file.path end
        return true
    end
    if S.mode == "game" then
        local ok, err = write(S.file)
        if not ok then Notify.show("error", "Save failed: " .. tostring(err)); return false, err end
    else
        for _, name in ipairs({ "Dolphin.ini", "GFX.ini" }) do
            local ok, err = write(S.files and S.files[name])
            if not ok then Notify.show("error", "Save failed: " .. tostring(err)); return false, err end
        end
    end
    S.dirty = false
    SFX.play("menu_select"); Notify.show("success", "Saved")
    return true
end

function S.enter(params)
    params = params or {}
    S.mode = params.mode or "core"
    S.tab = 1; S.dirty = false
    if S.mode == "game" then
        S.game_id = params.game_id or "?"
        S.game_title = params.game_title or S.game_id
        S.config_file = params.config_file or "base.ini"
        local dir = "workshop/gamesettings/" .. S.game_id
        sh.mkdir_p(dir)
        load_game_file(dir .. "/" .. S.config_file)
        S.icon       = params.icon       or "screen"
        S.type_label = params.type_label or "GAMESETTINGS"
        S.rgb        = params.rgb        or K.ACC.wii
    else
        S.profile = params.profile or "Default"
        S.name = params.name or S.profile
        S.dir = params.dir or ("workshop/rtcoreprofile/" .. S.profile)
        S.locked = params.locked or false
        load_core_files(S.dir)
        S.icon       = params.icon       or "gear"
        S.type_label = params.type_label or "RT:CORE"
        S.rgb        = params.rgb        or K.ACC.gc
    end
    K.set_accent(S.rgb)
    build_list()
end

function S.leave() end
function S.update(dt) S.list:update(dt) end

-- NEXUS adapters reuse the editor's existing INI, guide and lock semantics.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function selected_row() return S.list and S.list:cur() or nil end
    local specs = {
        { id = "editor.save", title = "Save editor changes", order = 10,
          run = function()
              if S.locked and S.mode ~= "game" then return false, "profile is locked" end
              if not S.dirty then return false, "there are no unsaved changes" end
              return save()
          end },
        { id = "editor.change_selected", title = "Change selected option", order = 20,
          run = function(direction)
              if direction ~= -1 and direction ~= 1 then return false, "direction must be -1 or 1" end
              return change(selected_row(), direction)
          end },
        { id = "editor.recommend_selected", title = "Apply selected recommendation", order = 30,
          run = function() return apply_recommend(selected_row()) end },
        { id = "editor.switch_tab", title = "Switch editor tab", order = 40,
          run = function(tab_id)
              if type(tab_id) ~= "string" then return false, "tab ID is required" end
              for i, tab in ipairs(Cats.tabs_for(S.mode)) do
                  if tab.id == tab_id then
                      S.tab = i; build_list(); SFX.play("menu_pagescroll")
                      return true
                  end
              end
              return false, "unknown editor tab: " .. tab_id
          end },
        { id = "editor.state", title = "Get editor state", order = 50,
          run = function()
              local row = selected_row()
              local tab = Cats.tabs_for(S.mode)[S.tab]
              return {
                  mode = S.mode, profile = S.profile, game_id = S.game_id,
                  tab = tab and tab.id,
                  selected = row and row.item and (row.item.sec .. "." .. row.item.key) or nil,
                  dirty = S.dirty == true, locked = S.locked == true,
              }
          end },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "editor", order = spec.order, screen = "rt_editor",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

local function try_back()
    local function out() require("ui").back() end
    if S.dirty then
        Modal.show("Unsaved changes", "Leave without saving?",
            { accept_label = "Leave", cancel_label = "Stay", on_accept = out })
    else out() end
end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "LEFT" then change(row, -1)
    elseif b == "RIGHT" then change(row, 1)
    elseif b == "A" and row then
        local k = type_of(row.guide)
        if k == "bool" or k == "int" or k == "float" then change(row, 1) end
    elseif b == "X" then apply_recommend(row)
    elseif b == "Y" then
        if S.locked then
            Notify.show("warning", "Profilo bloccato: copialo per modificarlo")
        elseif S.dirty then save() else Notify.show("info", "Nothing to save") end
    elseif b == "L1" then switch_tab(-1)
    elseif b == "R1" then switch_tab(1)
    elseif b == "B" then try_back() end
end

local function draw_header()
    local m = K.MARGIN
    local acc = K.acc or K.ACC.gc
    local title, sub
    if S.mode == "game" then
        title = S.game_title or S.game_id
        sub = "GAMESETTINGS · " .. (S.config_file or "base.ini")
    else
        title = S.name or S.profile or "?"
        sub = (S.type_label or "RT:CORE"):upper()
    end
    if S.dirty then sub = sub .. "  ● UNSAVED" end

    -- profile icon on the left
    local icx, icy = m + 18, 26
    K.color(acc, 0.20); love.graphics.circle("fill", icx, icy, 16)
    K.color(acc, 1);    love.graphics.circle("line", icx, icy, 16)
    if S.icon then glyph(S.icon, icx, icy, 10, acc, 1) end

    -- title + subtitle (profile type)
    K.text("title", K.clip("title", title, K.W - 120), m + 44, 12, K.C.text)
    K.text("small", sub, m + 44, 40, acc, 0.95)

    -- accent line
    K.color(acc, 1);        love.graphics.rectangle("fill", m, 66, 56, 3)
    K.color(K.C.line, 0.5); love.graphics.rectangle("fill", m + 56, 67, K.W - m * 2 - 56, 1)
end

local function draw_tab_bar()
    local tabs = Cats.tabs_for(S.mode)
    local gap = 6
    local tw = (K.W - K.MARGIN * 2 - gap * (#tabs - 1)) / #tabs
    for i, t in ipairs(tabs) do
        local x = K.MARGIN + (i - 1) * (tw + gap)
        local y, h = 86, 40
        local active = (i == S.tab)
        local acc = K.ACC[t.color] or K.ACC.gc
        if active then
            K.color(acc, 0.28); love.graphics.rectangle("fill", x, y, tw, h, 6, 6)
            K.color(acc, 1);    love.graphics.rectangle("line", x, y, tw, h, 6, 6)
            love.graphics.rectangle("fill", x, y + h - 3, tw, 3)
        else
            K.color(K.C.surf, 0.85); love.graphics.rectangle("fill", x, y, tw, h, 6, 6)
            K.color(K.C.line, 0.55); love.graphics.rectangle("line", x, y, tw, h, 6, 6)
        end
        glyph(t.icon, x + 20, y + h/2, 10, active and acc or K.C.dim, 1)
        K.text("key", t.label, x + 38, y + h/2 - 8, active and K.C.text or K.C.dim)
        local cnt = tostring(t.count)
        K.text("small", cnt, x + tw - K.width("small", cnt) - 10, y + h/2 - 7,
               active and acc or K.C.faint)
    end
end

local function draw_row(row, x, y, w, h, focused)
    if not row then return end
    local g = row.guide
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    local kind = type_of(g)
    local cur = row.value or (g and g.default) or ""
    K.text("body", K.clip("body", g.key, w - 200), x + 14, y + 6, focused and K.C.text or K.C.dim)
    if g.description and g.description ~= "" then
        K.text("small_i", K.clip("small_i", g.description, w - 200), x + 14, y + 26, K.C.faint, 0.9)
    end
    local right = x + w - 14
    if kind == "bool" then
        local on = tostring(cur):lower() == "true"
        K.switch(right - 38, y + h / 2, on, focused)
        K.text("small", on and "On" or "Off", right - 80, y + h / 2 - 8, K.C.dim)
    else
        local vtxt = tostring(cur)
        K.text("body", vtxt, right - K.width("body", vtxt), y + h / 2 - 9,
               focused and K.acc or K.C.text)
        if focused then
            K.text("body", "<", right - K.width("body", vtxt) - 14, y + h / 2 - 9, K.C.faint)
            K.text("body", ">", right + 2, y + h / 2 - 9, K.C.faint)
        end
    end
end

function S.draw()
    K.bg()
    draw_header()
    draw_tab_bar()
    if #S.list.items == 0 then
        K.text("body", "No options in this tab.", 0, 220, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end
    K.footer({
        { key = "A", label = "Edit" }, { key = "< >", label = "Value" },
        { key = "X", label = "Recommend" }, { key = "Y", label = "Save" },
        { key = "L1 R1", label = "Tab" }, { key = "B", label = "Back" },
    })
end

return S
