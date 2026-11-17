-- ui/screens/folders.lua — ROM folders. Top: folders already registered.
-- Browse mode: A enter, B up, Y add as GameCube, X add as Wii.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local U        = require("ui.util")
local Notify   = require("ui.notify")
local Settings = require("core.settings")
local Library  = require("core.library")

local S = {}
S.list = K.List(K.MARGIN, 90, K.W - K.MARGIN * 2 - 14, K.BOT - 90, 34)
S.mode, S.cwd, S.t = "set", "/", 0
local STARTS = { "/mnt/sdcard/roms", "/mnt/mmc/ROMS", "/mnt/union/ROMS", "/roms", "/mnt" }

local function show_set()
    S.mode = "set"
    local rows = { { add = true, label = "+  Add a folder…" } }
    for i, e in ipairs(Settings.get("rom_paths") or {}) do rows[#rows + 1] = { idx = i, path = e.path, system = e.system } end
    S.list:set(rows, false)
end

local function show_dir(path)
    S.mode, S.cwd = "browse", path
    local rows = {}
    for _, d in ipairs(U.ls(path)) do
        local full = (path == "/" and "" or path) .. "/" .. d
        local p = io.popen("test -d '" .. full:gsub("'", "'\\''") .. "' && echo d")
        local isdir = p and p:read("*l") == "d"; if p then p:close() end
        if isdir then rows[#rows + 1] = { dir = full, label = d } end
    end
    S.list:set(rows, false)
end

function S.enter()
    S.t = 0; K.set_accent("sys"); show_set()
end
function S.update(dt) S.t = S.t + dt; S.list:update(dt) end

local function start_browse()
    for _, p in ipairs(STARTS) do if U.exists(p .. "/.") then show_dir(p); return end end
    show_dir("/")
end

local function add(system)
    if S.mode ~= "browse" then return end
    local ok, status = Settings.add_rom_path(S.cwd, system)
    if ok then
        SFX.play("menu_toggleoption")
        local message = status == "updated"
            and "Folder updated: GameCube + Wii — rescan from Settings"
            or (system .. " folder added — rescan from Settings")
        Notify.show("success", message)
    else
        Notify.show("info", status == "exists" and "Folder already registered" or "Invalid folder path")
    end
end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "A" and row then
        if S.mode == "set" and row.add then start_browse()
        elseif S.mode == "browse" and row.dir then show_dir(row.dir) end
    elseif b == "X" then
        if S.mode == "browse" then add("Wii")
        elseif row and row.idx then Settings.remove_rom_path(row.idx); SFX.play("menu_back"); show_set() end
    elseif b == "Y" then add("GC")
    elseif b == "B" then
        if S.mode == "browse" then
            if S.cwd == "/" then show_set() else show_dir(S.cwd:match("^(.*)/[^/]*$") ~= "" and S.cwd:match("^(.*)/[^/]*$") or "/") end
        else
            pcall(Library.scan)
            require("ui").back()
        end
    end
end

local function draw_row(r, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if r.add then K.text("body", r.label, x + 14, y + h / 2 - 9, focused and K.acc or K.C.dim)
    elseif r.idx then
        K.text("body", K.clip("body", r.path, w - 110), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        local system = tostring(r.system or "GC"):upper()
        local label = system == "BOTH" and "GC + WII" or system
        local accent = system == "BOTH" and K.ACC.teal
            or (system == "WII" and K.ACC.wii or K.ACC.gc)
        K.pill(label, x + w - 12, y + h / 2, accent, true)
    else K.text("body", K.clip("body", r.label, w - 40), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.text("body", "›", x + w - 22, y + h / 2 - 9, K.C.faint) end
end

function S.draw()
    K.header("ROM folders", S.mode == "browse" and S.cwd or "Folders scanned for GameCube / Wii games", nil, nil, { icon = "folder" })
    if #S.list.items == 0 then K.text("body", "No sub-folders here.", 0, 200, K.C.dim, 1, K.W, "center")
    else S.list:draw(draw_row) end
    if S.mode == "browse" then
        K.footer({ { key = "A", label = "Open" }, { key = "Y", label = "Add GC" }, { key = "X", label = "Add Wii" }, { key = "B", label = "Up" } })
    else
        K.footer({ { key = "A", label = "Add" }, { key = "X", label = "Remove" }, { key = "B", label = "Done (rescan)" } })
    end
end

return S
