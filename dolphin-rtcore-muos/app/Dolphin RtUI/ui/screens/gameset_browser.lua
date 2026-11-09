-- ui/screens/gameset_browser.lua — LIBRARY / STORAGE / DATABASE con K.List e scroll.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local U        = require("ui.util")
local GL       = require("core.gameset_loader")
local GM       = require("core.gameset_manager")
local Library  = require("core.library")

local S = {}
S.tab = 1
S.rows = {}       -- righe “flat” (group / region / library)
S.expanded = {}   -- set di chiavi (titolo) espanse
S.sel = 1
S.list = K.List(K.MARGIN, 138, K.W - K.MARGIN * 2 - 14, K.BOT - 138, 46)

local TABS = {
    { id = "library",  label = "LIBRARY",  icon = "library", color = "gc" },
    { id = "storage",  label = "STORAGE",  icon = "folder",  color = "boost" },
    { id = "database", label = "DATABASE", icon = "file",    color = "wii" },
}

local function safe_id(v)
    if v == nil then return nil end
    if type(v) == "string" then return v end
    if type(v) == "table" then return v.id or v.gameid end
    return nil
end

local function region_of(id)
    if not id or #id < 4 then return "?" end
    local map = { E="US", P="EU", J="JP", K="KR", W="TW", U="US", D="EU", F="EU", I="EU", S="EU", X="EU", H="EU" }
    return map[id:sub(4,4)] or "?"
end

local function clean(t)
    if U.clean_title then return U.clean_title(t or "") end
    return t or ""
end

local function build_library()
    local rows = {}
    for _, g in ipairs(Library.games or {}) do
        if g.id and g.id ~= "" then
            local ok2, list = pcall(GM.list_for, g.id)
            local n = (ok2 and type(list) == "table") and #list or 0
            local title = clean(g.title or g.id)
            if title == "" then title = g.id end
            rows[#rows+1] = {
                kind = "library",
                id = g.id,
                title = title,
                region = region_of(g.id),
                n_cfg = n,
            }
        end
    end
    table.sort(rows, function(a,b) return (a.title or ""):lower() < (b.title or ""):lower() end)
    return rows
end

local function build_grouped(tab_id)
    local lib = {}
    for _, g in ipairs(Library.games or {}) do
        if g.id and g.id ~= "" then lib[g.id] = clean(g.title or g.id) end
    end
    local groups = {}   -- title -> { title, regions = { { id, region, n_cfg, in_lib } } }
    local order = {}

    local function add_group(title)
        if not title or title == "" then title = "?" end
        if not groups[title] then
            groups[title] = { title = title, regions = {} }
            order[#order+1] = title
        end
        return groups[title]
    end

    if tab_id == "storage" then
        local h = io.popen("ls -1d workshop/gamesettings/*/ 2>/dev/null")
        if h then
            for line in h:lines() do
                local id = line:match("([^/]+)/?$")
                if id then
                    local ok2, list = pcall(GM.list_for, id)
                    local n = (ok2 and type(list) == "table") and #list or 0
                    if n > 0 then
                        local title = lib[id] or id
                        local grp = add_group(title)
                        table.insert(grp.regions, {
                            id = id, region = region_of(id),
                            n_cfg = n, in_lib = lib[id] ~= nil,
                        })
                    end
                end
            end
            h:close()
        end
    else -- database
        local ok_l, d = pcall(GL.load)
        if ok_l and type(d) == "table" and d.games then
            for _, entry in ipairs(d.games) do
                local title = clean(entry.game or "?")
                local grp = add_group(title)
                for _, idv in ipairs(entry.ids or {}) do
                    local gid = safe_id(idv)
                    if gid then
                        local ok2, list = pcall(GM.list_for, gid)
                        local n = (ok2 and type(list) == "table") and #list or 0
                        table.insert(grp.regions, {
                            id = gid, region = region_of(gid),
                            n_cfg = n, in_lib = lib[gid] ~= nil,
                        })
                    end
                end
            end
        end
    end

    -- costruisci righe piatte
    local rows = {}
    table.sort(order, function(a,b) return a:lower() < b:lower() end)
    for _, title in ipairs(order) do
        local grp = groups[title]
        local expanded = S.expanded[title] or false
        rows[#rows+1] = {
            kind = "group",
            title = grp.title,
            n_regions = #grp.regions,
            expanded = expanded,
        }
        if expanded then
            for _, r in ipairs(grp.regions) do
                rows[#rows+1] = {
                    kind = "region",
                    title = grp.title,
                    id = r.id, region = r.region,
                    n_cfg = r.n_cfg, in_lib = r.in_lib,
                }
            end
        end
    end
    return rows
end

local function refresh()
    local ok, r = pcall(function()
        if S.tab == 1 then return build_library()
        elseif S.tab == 2 then return build_grouped("storage")
        else return build_grouped("database") end
    end)
    local err
    if not ok or type(r) ~= "table" then
        err = tostring(r)
        print("[gameset_browser] refresh failed: " .. err)
        r = {}
    end
    S.rows = r
    S.list:set(S.rows, false)
    S.list.sel = 1
    K.set_accent(K.ACC[TABS[S.tab].color] or K.ACC.gc)
    return err == nil, err
end

function S.enter()
    S.tab = 1
    S.expanded = {}
    S.sel = 1
    refresh()
end
function S.update(dt) S.list:update(dt) end

local function cycle_tab(d)
    S.tab = ((S.tab - 1 + d) % #TABS) + 1
    S.expanded = {}
    refresh()
    SFX.play("menu_pagescroll")
end

local function alphabet_jump(d)
    if #S.rows == 0 then return end
    local cur = S.list.sel
    local cl = (S.rows[cur].title or "?"):sub(1,1):upper()
    local i = cur
    for _ = 1, #S.rows do
        i = i + d
        if i < 1 then i = #S.rows elseif i > #S.rows then i = 1 end
        local l = (S.rows[i].title or "?"):sub(1,1):upper()
        if l ~= cl then
            S.list.sel = i; S.list:_aim(); SFX.play("menu_pagescroll"); return
        end
    end
end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP" then
        if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then
        if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "L1" then cycle_tab(-1)
    elseif b == "R1" then cycle_tab(1)
    elseif b == "L2" or b == "LEFT" then alphabet_jump(-1)
    elseif b == "R2" or b == "RIGHT" then alphabet_jump(1)
    elseif b == "A" and row then
        if row.kind == "library" then
            SFX.play("menu_select")
            require("ui").go("gameset_explorer", { game_id = row.id, game_title = row.title })
        elseif row.kind == "group" then
            S.expanded[row.title] = not S.expanded[row.title]
            SFX.play("menu_flip")
            refresh()
        elseif row.kind == "region" then
            SFX.play("menu_select")
            require("ui").go("gameset_explorer", { game_id = row.id, game_title = row.title })
        end
    elseif b == "B" then
        require("ui").back()
    end
end

local function draw_tab_bar()
    local tw = (K.W - K.MARGIN * 2 - 8) / #TABS
    for i, tab in ipairs(TABS) do
        local x = K.MARGIN + (i - 1) * (tw + 4)
        local y, h = 90, 34
        local active = (i == S.tab)
        local acc = K.ACC[tab.color] or K.ACC.gc
        if active then
            K.color(acc, 0.28); love.graphics.rectangle("fill", x, y, tw, h, 6, 6)
            K.color(acc, 1); love.graphics.rectangle("line", x, y, tw, h, 6, 6)
            love.graphics.rectangle("fill", x, y + h - 3, tw, 3)
        else
            K.color(K.C.surf, 0.85); love.graphics.rectangle("fill", x, y, tw, h, 6, 6)
            K.color(K.C.line, 0.55); love.graphics.rectangle("line", x, y, tw, h, 6, 6)
        end
        if K.draw_tool_icon then
            K.draw_tool_icon(tab.icon, x + 18, y + h/2, 12, active and acc or K.C.dim, 1)
        end
        K.text("key", tab.label, x + 34, y + h/2 - 8, active and K.C.text or K.C.dim)
    end
end

local function draw_row(row, x, y, w, h, focused)
    if not row then return end
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if row.kind == "library" then
        if K.draw_tool_icon then
            K.draw_tool_icon("gamepad", x + 26, y + h/2, 18, K.acc, focused and 1 or 0.7)
        end
        local rx = x + 48
        K.region_flag(row.region, rx, y + h/2 - 10, 40, 20)
        local tx = rx + 48
        K.text("body", K.clip("body", row.title, w - tx - 130), tx, y + h/2 - 11,
               focused and K.C.text or K.C.dim)
        K.id_plate(row.id, x + w - 110, y + h/2 - 10, 96, 20)
    elseif row.kind == "group" then
        local acc = K.ACC[TABS[S.tab].color] or K.ACC.gc
        K.text("h", row.expanded and "▼" or "▶", x + 12, y + h/2 - 11, acc)
        K.text("body", K.clip("body", row.title, w - 250), x + 34, y + h/2 - 11,
               focused and K.C.text or K.C.dim)
        local txt = row.n_regions .. " region" .. (row.n_regions == 1 and "" or "s")
        K.text("small", txt, x + w - K.width("small", txt) - 14, y + h/2 - 9, K.C.faint)
    elseif row.kind == "region" then
        K.region_flag(row.region, x + 30, y + h/2 - 10, 40, 20)
        K.id_plate(row.id, x + 78, y + h/2 - 10, 90, 20)
        if row.n_cfg and row.n_cfg > 0 then
            K.text("small", row.n_cfg .. " cfg", x + w - 64, y + h/2 - 8, K.C.ok)
        elseif row.in_lib then
            K.text("small", "in library", x + w - 90, y + h/2 - 8, K.C.dim)
        end
    end
end

function S.draw()
    K.bg()
    K.header("GameSettings", "LIBRARY · STORAGE · DATABASE", nil, { icon = "file" })
    draw_tab_bar()
    if #S.list.items == 0 then
        K.text("body", "Nothing here.", 0, 240, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end
    K.footer({
        { key = "A", label = "Open / Expand" },
        { key = "L1 R1", label = "Tab" },
        { key = "L2 R2", label = "Letter" },
        { key = "B", label = "Back" },
    })
end

-- NEXUS adapters preserve browser selection and keep navigation in ui/init.lua.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function row_key(row)
        if not row then return nil end
        return tostring(row.kind) .. ":" .. tostring(row.id or row.title or "")
    end
    local specs = {
        { id = "gameset_browser.refresh", title = "Refresh GameSettings browser", order = 10,
          run = function()
              local key = row_key(S.list and S.list:cur())
              local ok, err = refresh()
              if not ok then return false, err end
              if key then
                  for i, row in ipairs(S.rows) do
                      if row_key(row) == key then S.list.sel = i; break end
                  end
              end
              return true
          end },
        { id = "gameset_browser.switch_tab", title = "Switch GameSettings browser tab", order = 20,
          run = function(tab_id)
              if type(tab_id) ~= "string" then return false, "tab ID is required" end
              for i, tab in ipairs(TABS) do
                  if tab.id == tab_id then
                      S.tab, S.expanded = i, {}
                      local ok, err = refresh()
                      if not ok then return false, err end
                      SFX.play("menu_pagescroll")
                      return true
                  end
              end
              return false, "unknown GameSettings tab: " .. tab_id
          end },
        { id = "gameset_browser.open_selected", title = "Open or expand selected GameSettings entry", order = 30,
          run = function()
              local row = S.list and S.list:cur()
              if not row then return false, "no GameSettings entry selected" end
              if row.kind == "group" then
                  S.expanded[row.title] = not S.expanded[row.title]
                  local ok, err = refresh()
                  if not ok then return false, err end
                  return true
              elseif row.kind == "library" or row.kind == "region" then
                  return ui.go("gameset_explorer", { game_id = row.id, game_title = row.title })
              end
              return false, "unsupported GameSettings entry"
          end },
        { id = "gameset_browser.state", title = "Get GameSettings browser state", order = 40,
          run = function()
              local row = S.list and S.list:cur()
              return { tab = TABS[S.tab] and TABS[S.tab].id,
                  selected_kind = row and row.kind, game_id = row and row.id,
                  title = row and row.title, expanded = row and row.expanded == true }
          end },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "gamesettings", order = spec.order, screen = "gameset_browser",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

return S
