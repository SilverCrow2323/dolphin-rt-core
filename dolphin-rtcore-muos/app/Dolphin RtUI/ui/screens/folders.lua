-- ROM folders + FolderWaker.
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
S.warning_list = K.List(K.MARGIN + 14, 306, K.W - K.MARGIN * 2 - 28, K.BOT - 306, 26)
S.mode, S.cwd, S.t = "set", "/", 0
S.folder_waker_items, S.folder_waker_item, S.folder_waker_system, S.folder_waker_plan = {}, nil, nil, nil

local function show_set()
    S.mode = "set"
    S.folder_waker_browse = false
    local rows = {
        { add = true, system = "GC", label = "ADD GAMECUBE ROM FOLDER" },
        { add = true, system = "Wii", label = "ADD WII ROM FOLDER" },
        { folder_waker = true, label = "FolderWaker — repair Content Explorer folders" },
        { folder_waker_browse = true, label = "FolderWaker — inspect a folder manually" },
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

local function start_browse(for_folder_waker, system)
    S.folder_waker_browse = (for_folder_waker == true)
    S.add_system = system
    for _, p in ipairs(Settings.rom_root_candidates()) do
        if FS.is_dir(p) then show_dir(p); return end
    end
    show_dir("/")
end

local function add(system)
    if S.mode ~= "browse" then return end
    system = system or S.add_system or "GC"
    if Settings.add_rom_path(S.cwd, system) then
        SFX.play("menu_toggleoption")
        Notify.show("success", system .. " folder added — rescan from Library")
    else
        Notify.show("info", "Folder already registered — one shared path is kept")
    end
end

local function start_folder_waker_scan(show_warning)
    S.folder_waker_items = FolderTools.scan()
    S.folder_waker_roots = FolderTools.root_report()
    S.folder_waker_item, S.folder_waker_system = nil, nil
    local rows, warning_rows = {}, {}
    for i, item in ipairs(S.folder_waker_items) do
        local system = item.inferred_system or item.mapped_system or "?"
        local row = {
            folder_waker_idx = i, item = item,
            label = item.name,
            status = "CONTENT EXPLORER BLOCKED",
            system = system,
        }
        rows[#rows + 1] = row
        if item.content_explorer_blocked then warning_rows[#warning_rows + 1] = row end
    end
    S.folder_waker_rows = rows
    if show_warning and #warning_rows > 0 then
        S.mode = "folder_waker_warning"
        S.warning_list:set(warning_rows, false)
    else
        S.mode = "folder_waker_scan"
        S.list:set(rows, false)
        if #rows == 0 then show_set() end
    end
end

local function preview(item, system)
    local plan, err = FolderTools.preview(item, system or item.inferred_system or item.mapped_system)
    if not plan then Notify.show("warning", tostring(err)); return end
    S.folder_waker_item = item
    S.folder_waker_system = plan.system
    S.folder_waker_plan = plan
    S.mode = "folder_waker_preview"
end

local function back_to_folder_waker_scan()
    S.folder_waker_item, S.folder_waker_system, S.folder_waker_plan = nil, nil, nil
    start_folder_waker_scan()
end

local function commit_folder_waker()
    if not S.folder_waker_item then return end
    if S.folder_waker_system ~= "GC" and S.folder_waker_system ~= "Wii" then
        Notify.show("warning", "Choose GameCube (Y) or Wii (X) first")
        return
    end
    if S.folder_waker_item.has_roms ~= true then
        Notify.show("warning", "Rename blocked: no supported GameCube/Wii disc image was found here.")
        return
    end
    local ok, result = FolderTools.rename_register(S.folder_waker_item, S.folder_waker_system)
    if ok then
        Notify.show("success", "Renamed to " .. (result.target:match("([^/]+)$") or result.target)
            .. " and registered as " .. result.alias)
        SFX.play("menu_select")
        start_folder_waker_scan(false)
        show_set()
    else
        Notify.show("error", tostring(result))
    end
end

function S.enter()
    S.t = 0
    S.first_run = Settings.get("rom_discovery_done") ~= true
    K.set_accent("sys")
    show_set()
    -- Automatically explain the Content Explorer restriction when affected
    -- directory names are present. No rename or registration happens here.
    start_folder_waker_scan(true)
    if S.mode ~= "folder_waker_warning" then show_set() end
end

function S.update(dt)
    S.t = S.t + dt
    S.list:update(dt)
    if S.mode == "folder_waker_warning" then S.warning_list:update(dt) end
end

function S.pad(b)
    local row = S.list:cur()
    if S.mode == "set" then
        if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
        elseif b == "A" and row then
            if row.add then start_browse(false, row.system)
            elseif row.folder_waker_browse then start_browse(true)
            elseif row.folder_waker then start_folder_waker_scan(true) end
        elseif b == "R2" and row and row.idx then
            Settings.remove_rom_path(row.idx)
            SFX.play("menu_back")
            show_set()
        elseif b == "Y" then start_browse(false, "GC")
        elseif b == "X" then start_browse(false, "Wii")
        elseif b == "B" then
            if S.first_run then
                -- Explicitly skip manual path selection; no paths are added.
                Settings.set("rom_discovery_done", true)
                Notify.show("info", "ROM setup skipped. Add GameCube/Wii folders later in Settings.")
                require("ui").go("home", nil, { no_push = true })
            else
                require("ui").back()
            end
        end
        return
    end

    if S.mode == "browse" then
        if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
        elseif b == "A" and row and row.dir then
            show_dir(row.dir)
        elseif b == "X" or b == "Y" then
            local system = b == "Y" and "GC" or "Wii"
            if S.folder_waker_browse and row and row.dir then
                local item, err = FolderTools.inspect(row.dir)
                if not item then Notify.show("error", tostring(err))
                else preview(item, system) end
            else
                add(system)
            end
        elseif b == "B" then
            if S.cwd == "/" then show_set()
            else show_dir(S.cwd:match("^(.*)/[^/]*$") ~= "" and S.cwd:match("^(.*)/[^/]*$") or "/") end
        end
        return
    end

    if S.mode == "folder_waker_warning" then
        if b == "UP" then if S.warning_list:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.warning_list:move(1) then SFX.play("menu_move") end
        elseif b == "A" then
            S.mode = "folder_waker_scan"
            S.list:set(S.folder_waker_rows or {}, false)
            if #(S.folder_waker_rows or {}) == 0 then show_set() end
        elseif b == "B" then show_set() end
        return
    end

    if S.mode == "folder_waker_scan" then
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

    if S.mode == "folder_waker_preview" then
        if b == "Y" then S.folder_waker_system = "GC"; SFX.play("menu_toggleoption")
        elseif b == "X" then S.folder_waker_system = "Wii"; SFX.play("menu_toggleoption")
        elseif b == "A" then commit_folder_waker()
        elseif b == "B" then back_to_folder_waker_scan() end
    end
end

local function draw_row(r, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if r.add then
        local c = r.system == "Wii" and K.ACC.wii or K.ACC.gc
        K.text("body", K.clip("body", r.label, w - 150), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.pill(r.system == "Wii" and "X  ·  ADD WII" or "Y  ·  ADD GC", x + w - 12, y + h / 2, c, true)
    elseif r.folder_waker or r.folder_waker_browse then
        K.text("body", r.label, x + 14, y + h / 2 - 9, focused and K.acc or K.C.dim)
    elseif r.idx then
        K.text("body", K.clip("body", r.path, w - 110), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.pill(tostring(r.system or "GC"):upper(), x + w - 12, y + h / 2,
            tostring(r.system):lower() == "wii" and K.ACC.wii or K.ACC.gc, true)
    elseif r.dir then
        K.text("body", K.clip("body", r.label, w - 40), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.text("body", "›", x + w - 22, y + h / 2 - 9, K.C.faint)
    elseif r.folder_waker_idx then
        K.text("body", K.clip("body", r.label, w - 170), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.text("h", "!", x + w - 152, y + h / 2 - 12, K.C.warn)
        K.pill(r.status, x + w - 12, y + h / 2, K.C.warn, true)
    end
end

local function draw_folder_waker_preview()
    local item = S.folder_waker_item
    if not item then return end
    local source_name = item.name
    local target = (S.folder_waker_plan and S.folder_waker_plan.target) or ("Rt" .. source_name)
    local alias = (S.folder_waker_plan and S.folder_waker_plan.alias) or FolderTools.normalize_alias(target)
    local system_text = S.folder_waker_system or "not selected"
    local status = item.is_scan_root and "This is already an Rt:UI ROM path; FolderWaker will update the saved path."
        or item.status == "skip-match" and "Matches muOS skip.ini pattern(s): "
        .. table.concat(item.skip_matches or {}, ", ")
        or item.status == "unmapped" and "No matching assignment alias is present in assign.json."
        or item.status == "mapped" and "An assignment alias already exists; this diagnostic still allows an explicit Rt-prefixed repair."
        or "Folder contains ROM images but its system could not be inferred from the name."

    K.header("FolderWaker", "Review folder name and system alias before applying changes", nil, { icon = "folder" })
    K.panel(K.MARGIN, 105, K.W - K.MARGIN * 2, 300, { cut = 12 })
    K.text("small", "SOURCE FOLDER", K.MARGIN + 18, 125, K.C.dim)
    K.text("body", K.clip("body", item.path, K.W - K.MARGIN * 2 - 36), K.MARGIN + 18, 148, K.C.text)
    K.text("small", "PROPOSED NAME", K.MARGIN + 18, 188, K.C.dim)
    K.text("h", K.clip("h", target, K.W - K.MARGIN * 2 - 36), K.MARGIN + 18, 211, K.acc)
    K.text("small", "SYSTEM / NEW ASSIGN ALIAS", K.MARGIN + 18, 248, K.C.dim)
    K.text("body", system_text .. "  ·  " .. alias, K.MARGIN + 18, 270, K.C.text)
    K.text("small", "DIAGNOSTIC", K.MARGIN + 18, 307, K.C.dim)
    K.text("small", K.clip("small", status, K.W - K.MARGIN * 2 - 36), K.MARGIN + 18, 329,
        item.status == "skip-match" and K.C.warn or K.C.dim)
    K.text("small",
        item.is_scan_root
            and "Rt:UI will update this saved ROM path to the new folder name."
            or "No symlink: muOS skips symbolic-link folders. Only the directory name changes.",
        K.MARGIN + 18, 355, K.C.dim, 1, K.W - K.MARGIN * 2 - 36)
    K.text("small", item.has_roms and "DISC CHECK: supported ROM image found" or "DISC CHECK: no supported ROM image — rename disabled",
        K.MARGIN + 18, 382, item.has_roms and K.C.ok or K.C.warn, 1, K.W - K.MARGIN * 2 - 36)
    local footer = { { key = "Y", label = "GameCube" }, { key = "X", label = "Wii" } }
    if item.has_roms then
        footer[#footer + 1] = { key = "A", label = "Rename + register" }
    end
    footer[#footer + 1] = { key = "B", label = "Back" }
    K.footer(footer)
end

function S.draw()
    if S.mode == "folder_waker_warning" then
        K.header("CONTENT EXPLORER WARNING", "muOS folder-name restriction detected", nil, { icon = "folder" })
        K.panel(K.MARGIN, 92, K.W - K.MARGIN * 2, 322, { cut = 12, accent = K.C.warn })
        K.text("body", "muOS Content Explorer has an explicit firmware block for folders named gc, ngc, gamecube, game cube, or wii.", K.MARGIN + 16, 108, K.C.text, 1, K.W - K.MARGIN * 2 - 32)
        K.text("small", "This is a muOS restriction — not a damaged ROM and not a Dolphin problem. Content Explorer will not index games inside these folders, even when the files are valid.", K.MARGIN + 16, 151, K.C.dim, 1, K.W - K.MARGIN * 2 - 32)
        K.text("small", "NO — leave every folder untouched. Games remain available in Dolphin Rt:UI.", K.MARGIN + 16, 207, K.C.ok, 1, K.W - K.MARGIN * 2 - 32)
        K.text("small", "YES — FolderWaker can rename only the affected folder to RtGC or RtWii and register the matching muOS Content Explorer alias. You can also do this manually by changing the folder name by one character.", K.MARGIN + 16, 244, K.C.dim, 1, K.W - K.MARGIN * 2 - 32)
        K.text("key", "FIX CONTENT EXPLORER FOLDERS?  ·  AFFECTED FOLDERS BELOW", K.MARGIN + 16, 294, K.C.warn)
        S.warning_list:draw(draw_row)
        K.footer({ { key = "A", label = "YES · Review fixes" }, { key = "B", label = "NO · Rt:UI only" } })
        return
    end
    if S.mode == "folder_waker_preview" then
        draw_folder_waker_preview()
        return
    end

    local title = S.mode == "browse" and S.cwd
        or S.mode == "folder_waker_scan" and "Find hidden game folders or missing muOS system aliases"
        or "Folders scanned for GameCube / Wii games"
    K.header(S.mode == "folder_waker_scan" and "FolderWaker" or "ROM folders", title, nil, { icon = "folder" })

    if #S.list.items == 0 then
        if S.mode == "folder_waker_scan" then
            K.text("body", "No candidate folders found. These are the ROM roots checked:", K.MARGIN, 145, K.C.dim, 1, K.W - K.MARGIN * 2)
            for i, root in ipairs(S.folder_waker_roots or {}) do
                if i > 6 then break end
                local status = not root.accessible and "NOT MOUNTED"
                    or root.has_roms and "ROMs FOUND" or "NO SUPPORTED ROM"
                local colour = not root.accessible and K.C.bad
                    or root.has_roms and K.C.ok or K.C.warn
                K.text("small", K.clip("small", root.path, K.W - K.MARGIN * 2 - 110),
                    K.MARGIN, 178 + (i - 1) * 38, K.C.text)
                K.pill(status, K.W - K.MARGIN, 188 + (i - 1) * 38, colour, true)
            end
            K.text("small", "Use “choose a folder manually” to inspect another directory or verify the ROM card mount.", K.MARGIN, 420, K.C.dim, 1, K.W - K.MARGIN * 2)
        else
            K.text("body", "No sub-folders here.", 0, 200, K.C.dim, 1, K.W, "center")
        end
    else
        S.list:draw(draw_row)
    end

    if S.mode == "browse" then
        K.footer({ { key = "A", label = "Open" }, { key = "Y", label = "Add GC" }, { key = "X", label = "Add Wii" }, { key = "B", label = "Up" } })
    elseif S.mode == "folder_waker_scan" then
        K.footer({ { key = "A", label = "Review" }, { key = "Y", label = "Review as GC" }, { key = "X", label = "Review as Wii" }, { key = "B", label = "Back" } })
    elseif S.mode == "set" then
        K.footer({ { key = "A", label = "Open" }, { key = "Y", label = "Add GC" }, { key = "X", label = "Add Wii" }, { key = "R2", label = "Remove path" }, { key = "B", label = "Done" } })
    else
        K.footer({ { key = "A", label = "Open" }, { key = "Y", label = "Add GC" }, { key = "X", label = "Add Wii" }, { key = "R2", label = "Remove path" }, { key = "B", label = "Done" } })
    end
end

return S
