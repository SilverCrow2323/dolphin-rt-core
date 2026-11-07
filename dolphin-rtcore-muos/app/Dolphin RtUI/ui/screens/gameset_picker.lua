-- ui/screens/gameset_picker.lua — per-game GameSettings browser.
--
-- params = { game_id, game_title }
--
-- A  open in rt_editor (mode "game")
-- Y  set as active
-- X  delete
-- N  create a new config
-- D  deploy bundled configs from data/gamesettings.json (if available)
-- B  back

local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local Notify   = require("ui.notify")
local Modal    = require("ui.modal")
local GM       = require("core.gameset_manager")
local GL       = require("core.gameset_loader")
local sh       = require("core.sh")

local S = {}
S.list = K.List(K.MARGIN, 92, K.W - K.MARGIN * 2 - 20, K.BOT - 92, 42)

local function build()
    local rows = {}
    for _, cfg in ipairs(GM.list_for(S.game_id)) do
        rows[#rows + 1] = { kind = "file", cfg = cfg }
    end
    rows[#rows + 1] = { kind = "new" }
    local bundled = GL.for_game(S.game_id)
    if bundled and #bundled.configs > 0 then
        rows[#rows + 1] = { kind = "deploy", entry = bundled }
    end
    S.list:set(rows, false)
end

function S.enter(params)
    params = params or {}
    S.game_id = params.game_id or "?"
    S.game_title = params.game_title or S.game_id
    K.set_accent("gc")
    build()
end
function S.update(dt) S.list:update(dt) end

local function set_active(row)
    GM.set_active(S.game_id, row.cfg.file)
    SFX.play("menu_select")
    build()
    Notify.show("success", "Active: " .. row.cfg.file)
end

local function delete(row)
    Modal.show("Delete config?",
        "File: " .. row.cfg.file .. "\nThis action is irreversible.",
        { accept_label = "Delete", cancel_label = "Cancel", color = K.C.bad,
          on_accept = function()
              GM.delete(S.game_id, row.cfg.file)
              SFX.play("menu_back")
              build()
          end })
end

local function create_new()
    local name = "custom_" .. os.date("%m%d_%H%M")
    local ok = GM.add(S.game_id, name .. ".ini")
    if ok then
        SFX.play("menu_select")
        build()
        Notify.show("success", "Created " .. name .. ".ini")
    else
        Notify.show("error", "Could not create file")
    end
end

local function deploy(entry)
    local n = GL.deploy(entry, S.game_id)
    if n > 0 then
        SFX.play("newupdate")
        Notify.show("success", n .. " bundled config(s) added")
        build()
    else
        Notify.show("info", "Already up to date")
    end
end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP"   then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "A" and row then
        if row.kind == "file" then
            SFX.play("menu_select")
            require("ui").go("rt_editor", {
                mode = "game",
                game_id = S.game_id,
                game_title = S.game_title,
                config_file = row.cfg.file,
            })
        elseif row.kind == "new" then create_new()
        elseif row.kind == "deploy" then deploy(row.entry) end
    elseif b == "Y" and row and row.kind == "file" then set_active(row)
    elseif b == "X" and row and row.kind == "file" then delete(row)
    elseif b == "N" then create_new()
    elseif b == "D" then
        local bundled = GL.for_game(S.game_id)
        if bundled then deploy(bundled) else Notify.show("info", "No bundled configs for this game") end
    elseif b == "B" then require("ui").back() end
end

local function draw_row(row, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if row.kind == "file" then
        K.text("body", row.cfg.file, x + 14, y + 6, focused and K.C.text or K.C.dim)
        if row.cfg.active then
            K.text("small", "● active", x + w - 96, y + 6, K.C.ok)
        end
        K.text("small", K.clip("small", row.cfg.display or row.cfg.file, w - 40),
               x + 14, y + 24, K.C.faint, 0.9)
    elseif row.kind == "new" then
        K.text("body", "+  New custom config", x + 14, y + 12, focused and K.acc or K.C.dim)
    elseif row.kind == "deploy" then
        K.text("body", "↓  Deploy bundled configs", x + 14, y + 6, focused and K.acc or K.C.dim)
        K.text("small", ("%d available for %s"):format(#row.entry.configs, S.game_id),
               x + 14, y + 24, K.C.faint)
    end
end

function S.draw()
    K.header("GameSettings", S.game_title, nil)
    if #S.list.items == 0 then
        K.text("body", "No configs yet. Press N to create one.",
               0, 220, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end
    K.footer({
        { key = "A", label = "Open" },
        { key = "Y", label = "Active" },
        { key = "X", label = "Delete" },
        { key = "N", label = "New" },
        { key = "B", label = "Back" },
    })
end

return S