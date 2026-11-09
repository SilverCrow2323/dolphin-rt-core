-- ui/screens/gameset_explorer.lua — editor per-game con K.List e scroll.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local Notify   = require("ui.notify")
local Modal    = require("ui.modal")
local GM       = require("core.gameset_manager")
local GL       = require("core.gameset_loader")

local S = {}
S.list = K.List(K.MARGIN, 138, K.W - K.MARGIN * 2 - 14, K.BOT - 138, 46)
S.rows = {}

local function region_of(id)
    if not id or #id < 4 then return "?" end
    local map = { E="US", P="EU", J="JP", K="KR", W="TW", U="US", D="EU", F="EU", I="EU", S="EU", X="EU", H="EU" }
    return map[id:sub(4,4)] or "?"
end

local function build(keep_file)
    local rows = {}
    local list = GM.list_for(S.game_id) or {}
    for _, cfg in ipairs(list) do
        rows[#rows+1] = { kind = "file", file = cfg.file, active = cfg.active }
    end
    rows[#rows+1] = { kind = "new" }
    S.rows = rows
    S.list:set(rows, false)
    S.list.sel = 1
    if keep_file then
        for i, row in ipairs(rows) do
            if row.kind == "file" and row.file == keep_file then S.list.sel = i; break end
        end
    end
end

function S.enter(params)
    params = params or {}
    S.game_id = params.game_id or "?"
    S.game_title = params.game_title or S.game_id
    S.region = region_of(S.game_id)
    K.set_accent("wii")
    build()
end
function S.update(dt) S.list:update(dt) end

local function open_config(filename)
    SFX.play("menu_select")
    require("ui").go("rt_editor", {
        mode = "game", game_id = S.game_id,
        game_title = S.game_title, config_file = filename,
    })
end

local function delete_custom(filename)
    if type(filename) ~= "string" or filename == "" then return false, "config filename is required" end
    Modal.show("Delete config?", "File: " .. filename,
        { accept_label = "Delete", cancel_label = "Cancel", color = K.C.bad,
          on_accept = function()
              local ok, err = GM.delete(S.game_id, filename)
              if ok == false then Notify.show("error", "Delete failed: " .. tostring(err)); return end
              SFX.play("menu_back")
              build()
          end })
    return true
end

local function create_new()
    local name = "custom_" .. os.date("%m%d_%H%M") .. ".ini"
    local ok, err = GM.add(S.game_id, name)
    if ok then
        SFX.play("menu_select")
        build(name)
        open_config(name)
        return true
    end
    Notify.show("error", "Could not create file: " .. tostring(err))
    return false, err or "could not create config"
end

local function toggle_active(row)
    if not row or row.kind ~= "file" then return false, "no config selected" end
    local ok, err
    if row.active then
        ok, err = GM.clear_active(S.game_id)
        if ok == false then return false, err or "could not clear active config" end
        Notify.show("info", "Deactivated: " .. row.file)
    else
        ok, err = GM.set_active(S.game_id, row.file)
        if ok == false then return false, err or "could not activate config" end
        Notify.show("success", "Active: " .. row.file)
    end
    SFX.play("menu_toggleoption")
    build(row.file)
    return true
end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP" then
        if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then
        if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "A" and row then
        if row.kind == "new" then create_new()
        else open_config(row.file) end
    elseif b == "Y" and row and row.kind == "file" then
        toggle_active(row)
    elseif b == "X" and row and row.kind == "file" then
        delete_custom(row.file)
    elseif b == "B" then
        require("ui").back()
    end
end

local function draw_header()
    local m = K.MARGIN
    local acc = K.acc or K.ACC.wii
    K.disc(m + 26, 44, 26, nil, K.t or 0, acc)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    local px, py = m + 62, 24
    love.graphics.line(px, py, px + 12, py + 12)
    love.graphics.line(px + 12, py + 12, px + 16, py + 16)
    love.graphics.circle("line", px + 3, py + 3, 4)
    love.graphics.setLineWidth(1)
    local tx = m + 80
    K.text("key", "GAME SETTINGS", tx, 10, K.C.faint)
    K.text("h", K.clip("h", S.game_title, K.W - tx - m - 20), tx, 26, K.C.text)
    local ry = 52
    K.region_flag(S.region, tx, ry, 42, 20)
    K.id_plate(S.game_id, tx + 48, ry, 96, 20)
    K.color(acc, 1)
    love.graphics.rectangle("fill", m, 80, K.W - m * 2, 2)
end

local function draw_row(row, x, y, w, h, focused)
    if row.kind == "new" then
        K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6, accent = K.C.ok })
        K.text("body", "+  Create new config", x + 14, y + h/2 - 11,
               focused and K.C.ok or K.C.text)
        return
    end
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if K.draw_tool_icon then
        K.draw_tool_icon("file", x + 26, y + h/2, 20, focused and K.acc or K.C.dim,
                         focused and 1 or 0.7)
    end
    K.text("body", K.clip("body", row.file, w - 200), x + 46, y + h/2 - 11,
           focused and K.C.text or K.C.dim)
    local right = x + w - 14
    if row.active then
        local txt = "● ACTIVE"
        local tw = K.width("key", txt) + 12
        K.color(K.C.ok, 0.22)
        love.graphics.rectangle("fill", right - tw, y + h/2 - 11, tw, 22, 5, 5)
        K.color(K.C.ok, 1)
        love.graphics.rectangle("line", right - tw, y + h/2 - 11, tw, 22, 5, 5)
        K.text("key", txt, right - tw + 6, y + h/2 - 7, K.C.ok)
    else
        K.text("small", "inactive", right - K.width("small", "inactive"), y + h/2 - 9, K.C.faint)
    end
end

function S.draw()
    K.bg()
    draw_header()
    if #S.list.items == 0 then
        K.text("body", "No configs. Press A to create one.", 0, 240, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end
    K.footer({
        { key = "A", label = "Open" },
        { key = "Y", label = "Activate" },
        { key = "X", label = "Delete" },
        { key = "B", label = "Back" },
    })
end

-- NEXUS adapters reuse the existing per-game configuration operations.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function selected() return S.list and S.list:cur() or nil end
    local specs = {
        { id = "gameset_explorer.refresh", title = "Refresh game configs", order = 10,
          run = function()
              local row = selected()
              local keep = row and row.kind == "file" and row.file or nil
              local ok, err = pcall(build, keep)
              if not ok then return false, tostring(err) end
              return true
          end },
        { id = "gameset_explorer.open_selected", title = "Open selected game config", order = 20,
          run = function()
              local row = selected()
              if not row then return false, "no config selected" end
              if row.kind == "file" then open_config(row.file); return true end
              if row.kind == "new" then return create_new() end
              return false, "unsupported config entry"
          end },
        { id = "gameset_explorer.create", title = "Create game config", order = 30,
          run = create_new },
        { id = "gameset_explorer.set_active_selected", title = "Activate or deactivate selected config", order = 40,
          run = function() return toggle_active(selected()) end },
        { id = "gameset_explorer.request_delete_selected", title = "Request deletion of selected config", order = 50,
          run = function()
              local row = selected()
              if not row or row.kind ~= "file" then return false, "no config selected" end
              return delete_custom(row.file)
          end },
        { id = "gameset_explorer.state", title = "Get game config state", order = 60,
          run = function()
              local row = selected()
              return { game_id = S.game_id, game_title = S.game_title,
                  selected_kind = row and row.kind, config_file = row and row.file,
                  active = row and row.active == true }
          end },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "gamesettings", order = spec.order, screen = "gameset_explorer",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

return S
