-- ROM folders + Registratore Z.
-- No directory is changed by scanning. A rename is a two-step, explicit action.
local K           = require("ui.kit")
local SFX         = require("ui.sfx")
local U           = require("ui.util")
local FS          = require("core.fs")
local Notify      = require("ui.notify")
local Settings    = require("core.settings")
local Library     = require("core.library")
local FolderTools = require("core.folder_tools")

local S = {}
S.list = K.List(K.MARGIN, 90, K.W - K.MARGIN * 2 - 14, K.BOT - 90, 36)
S.mode, S.cwd, S.t = "set", "/", 0
S.z_items, S.z_item, S.z_system = {}, nil, nil

local function show_set()
    S.mode = "set"
    local rows = {
        { add = true, label = "+  Browse for a ROM folder" },
        { autodetect = true, label = "Auto-detect ROM roots" },
        { registrator = true, label = "Registratore Z — diagnose folder names" },
    }
    for i, e in ipairs(Settings.get("rom_paths") or {}) do
        rows[#rows + 1] = { idx = i, path = e.path, system = e.system }
    end
    S.list:set(rows, false)
end

local function show_dir(path)
    S.mode, S.cwd = "browse", path
    local rows = {}
    for _, d in ipairs(U.ls(path)) do
        local full = (path == "/" and "" or path) .. "/" .. d
        local p = io.popen("test -d '" .. full:gsub("'", "'\\''") .. "' && echo d")
        local isdir = p and p:read("*l") == "d"
        if p then p:close() end
        if isdir then rows[#rows + 1] = { dir = full, label = d } end
    end
    S.list:set(rows, false)
end

local function start_browse()
    for _, p in ipairs(Settings.rom_root_candidates()) do
        if FS.is_dir(p) then show_dir(p); return end
    end
    show_dir("/")
end

local function add(system)
    if S.mode ~= "browse" then return end
    if Settings.add_rom_path(S.cwd, system) then
        SFX.play("menu_toggleoption")
        Notify.show("success", system .. " folder added — rescan from Library")
    else
        Notify.show("info", "Folder already registered for " .. system)
    end
end

local function start_zscan()
    S.z_items = FolderTools.scan()
    S.z_item, S.z_system = nil, nil
    S.mode = "zscan"
    local rows = {}
    for i, item in ipairs(S.z_items) do
        local status = item.status == "skip-match" and "SKIP NAME"
            or item.status == "unmapped" and "NO ASSIGN"
            or item.status == "mapped" and "MAPPED"
            or "REVIEW"
        local system = item.inferred_system or item.mapped_system or "?"
        rows[#rows + 1] = {
            zidx = i, item = item,
            label = item.name,
            status = status,
            system = system,
        }
    end
    S.list:set(rows, false)
end

local function preview(item, system)
    S.z_item, S.z_system = item, system
    S.mode = "zpreview"
end

local function back_to_zscan()
    S.z_item, S.z_system = nil, nil
    start_zscan()
end

local function commit_z()
    if not S.z_item then return end
    if S.z_system ~= "GC" and S.z_system ~= "Wii" then
        Notify.show("warning", "Choose GameCube (Y) or Wii (X) first")
        return
    end
    local ok, result = FolderTools.rename_register(S.z_item, S.z_system)
    if ok then
        Notify.show("success", "Renamed to " .. (result.target:match("([^/]+)$") or result.target)
            .. " and registered as " .. result.alias)
        SFX.play("menu_select")
        start_zscan()
    else
        Notify.show("error", tostring(result))
    end
end

function S.enter()
    S.t = 0
    K.set_accent("sys")
    show_set()
end

function S.update(dt)
    S.t = S.t + dt
    S.list:update(dt)
end

function S.pad(b)
    local row = S.list:cur()
    if S.mode == "set" then
        if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
        elseif b == "A" and row then
            if row.add then start_browse()
            elseif row.autodetect then
                local n = Settings.auto_discover_rom_paths()
                show_set()
                if n > 0 then
                    Notify.show("success", n .. " ROM root(s) discovered")
                else
                    Notify.show("info", "No new ROM root found. You can browse or run Registratore Z.")
                end
            elseif row.registrator then
                start_zscan()
            end
        elseif b == "X" and row and row.idx then
            Settings.remove_rom_path(row.idx)
            SFX.play("menu_back")
            show_set()
        elseif b == "B" then
            require("ui").back()
        end
        return
    end

    if S.mode == "browse" then
        if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
        elseif b == "A" and row and row.dir then
            show_dir(row.dir)
        elseif b == "X" then add("Wii")
        elseif b == "Y" then add("GC")
        elseif b == "B" then
            if S.cwd == "/" then show_set()
            else show_dir(S.cwd:match("^(.*)/[^/]*$") ~= "" and S.cwd:match("^(.*)/[^/]*$") or "/") end
        end
        return
    end

    if S.mode == "zscan" then
        if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
        elseif (b == "A" or b == "Y" or b == "X") and row and row.item then
            local system = row.item.inferred_system or row.item.mapped_system
            if b == "Y" then system = "GC" elseif b == "X" then system = "Wii" end
            preview(row.item, system)
            if not system then Notify.show("info", "Choose GameCube (Y) or Wii (X) in the preview") end
        elseif b == "B" then show_set() end
        return
    end

    if S.mode == "zpreview" then
        if b == "Y" then S.z_system = "GC"; SFX.play("menu_toggleoption")
        elseif b == "X" then S.z_system = "Wii"; SFX.play("menu_toggleoption")
        elseif b == "A" then commit_z()
        elseif b == "B" then back_to_zscan() end
    end
end

local function draw_row(r, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if r.add or r.autodetect or r.registrator then
        K.text("body", r.label, x + 14, y + h / 2 - 9, focused and K.acc or K.C.dim)
    elseif r.idx then
        K.text("body", K.clip("body", r.path, w - 110), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.pill(tostring(r.system or "GC"):upper(), x + w - 12, y + h / 2,
            tostring(r.system):lower() == "wii" and K.ACC.wii or K.ACC.gc, true)
    elseif r.dir then
        K.text("body", K.clip("body", r.label, w - 40), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.text("body", "›", x + w - 22, y + h / 2 - 9, K.C.faint)
    elseif r.zidx then
        K.text("body", K.clip("body", r.label, w - 160), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        local colour = r.status == "SKIP NAME" and K.C.warn
            or r.status == "NO ASSIGN" and K.C.bad
            or r.status == "MAPPED" and K.C.ok or K.C.dim
        K.pill(r.status, x + w - 12, y + h / 2, colour, true)
    end
end

local function draw_zpreview()
    local item = S.z_item
    if not item then return end
    local source_name = item.name
    local target = "Rt" .. source_name
    local alias = FolderTools.normalize_alias(target)
    local system_text = S.z_system or "not selected"
    local status = item.status == "skip-match" and "Matches muOS skip.ini pattern(s): "
        .. table.concat(item.skip_matches or {}, ", ")
        or item.status == "unmapped" and "No matching assignment alias is present in assign.json."
        or item.status == "mapped" and "An assignment alias already exists; this diagnostic still allows an explicit Rt-prefixed repair."
        or "Folder contains ROM images but its system could not be inferred from the name."

    K.header("Registratore Z", "Review the exact folder before renaming", nil, { icon = "folder" })
    K.panel(K.MARGIN, 105, K.W - K.MARGIN * 2, 278, { cut = 12 })
    K.text("small", "SOURCE FOLDER", K.MARGIN + 18, 125, K.C.dim)
    K.text("body", K.clip("body", item.path, K.W - K.MARGIN * 2 - 36), K.MARGIN + 18, 148, K.C.text)
    K.text("small", "PROPOSED NAME", K.MARGIN + 18, 188, K.C.dim)
    K.text("h", K.clip("h", target, K.W - K.MARGIN * 2 - 36), K.MARGIN + 18, 211, K.acc)
    K.text("small", "SYSTEM / NEW ASSIGN ALIAS", K.MARGIN + 18, 248, K.C.dim)
    K.text("body", system_text .. "  ·  " .. alias, K.MARGIN + 18, 270, K.C.text)
    K.text("small", "DIAGNOSTIC", K.MARGIN + 18, 307, K.C.dim)
    K.text("small", K.clip("small", status, K.W - K.MARGIN * 2 - 36), K.MARGIN + 18, 329,
        item.status == "skip-match" and K.C.warn or K.C.dim)
    K.text("small", "Only the folder name changes. ROM files are not modified. Alias registration follows the rename; failure rolls the rename back.",
        K.MARGIN + 18, 355, K.C.dim, 1, K.W - K.MARGIN * 2 - 36)
    K.footer({ { key = "Y", label = "GameCube" }, { key = "X", label = "Wii" },
        { key = "A", label = "Rename + register" }, { key = "B", label = "Back" } })
end

function S.draw()
    if S.mode == "zpreview" then
        draw_zpreview()
        return
    end

    local title = S.mode == "browse" and S.cwd
        or S.mode == "zscan" and "Folders that may be hidden or lack a system alias"
        or "Folders scanned for GameCube / Wii games"
    K.header(S.mode == "zscan" and "Registratore Z" or "ROM folders", title, nil, { icon = "folder" })

    if #S.list.items == 0 then
        local msg = S.mode == "zscan" and "No candidate folders found under the detected ROM roots."
            or "No sub-folders here."
        K.text("body", msg, 0, 200, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end

    if S.mode == "browse" then
        K.footer({ { key = "A", label = "Open" }, { key = "Y", label = "Add GC" }, { key = "X", label = "Add Wii" }, { key = "B", label = "Up" } })
    elseif S.mode == "zscan" then
        K.footer({ { key = "A", label = "Review" }, { key = "Y", label = "Review as GC" }, { key = "X", label = "Review as Wii" }, { key = "B", label = "Back" } })
    else
        K.footer({ { key = "A", label = "Open" }, { key = "X", label = "Remove" }, { key = "B", label = "Done" } })
    end
end

return S
