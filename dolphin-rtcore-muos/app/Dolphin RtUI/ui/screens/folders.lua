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
    if S.mode ~= "browse" then return false, "folder browser is not active" end
    if system ~= "GC" and system ~= "Wii" then return false, "system must be GC or Wii" end
    if Settings.add_rom_path(S.cwd, system) then
        SFX.play("menu_toggleoption")
        Notify.show("success", system .. " folder added — rescan from Settings")
        return true
    end
    Notify.show("info", "Already in the list")
    return false, "folder is already registered"
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
        K.text("body", K.clip("body", r.path, w - 90), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.pill(tostring(r.system or "GC"):upper(), x + w - 12, y + h / 2, tostring(r.system):lower() == "wii" and K.ACC.wii or K.ACC.gc, true)
    else K.text("body", K.clip("body", r.label, w - 40), x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
        K.text("body", "›", x + w - 22, y + h / 2 - 9, K.C.faint) end
end

-- NEXUS adapters keep folder navigation and ROM-path mutations in this screen.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function selected() return S.list and S.list:cur() or nil end
    local specs = {
        { id = "folders.refresh", title = "Refresh ROM folder view", order = 10,
          run = function()
              if S.mode == "browse" then show_dir(S.cwd) else show_set() end
              return true
          end },
        { id = "folders.start_browse", title = "Browse for ROM folder", order = 20,
          run = function()
              if S.mode ~= "set" then return false, "folder browser is already active" end
              start_browse()
              return true
          end },
        { id = "folders.open_selected", title = "Open selected folder", order = 30,
          run = function()
              local row = selected()
              if not row then return false, "no folder entry selected" end
              if S.mode == "set" and row.add then start_browse(); return true end
              if S.mode == "browse" and row.dir then show_dir(row.dir); return true end
              return false, "selected entry cannot be opened"
          end },
        { id = "folders.add_selected", title = "Add current folder for a system", order = 40,
          run = function(system) return add(system) end },
        { id = "folders.return_to_list", title = "Return to registered folder list", order = 45,
          run = function()
              if S.mode ~= "browse" then return false, "folder browser is not active" end
              show_set()
              return true
          end },
        { id = "folders.remove_selected", title = "Remove selected ROM folder", order = 50,
          run = function()
              if S.mode ~= "set" then return false, "return to the folder list before removing paths" end
              local row = selected()
              if not row or not row.idx then return false, "no registered folder selected" end
              local ok, err = pcall(Settings.remove_rom_path, row.idx)
              if not ok then return false, tostring(err) end
              SFX.play("menu_back"); show_set()
              return true
          end },
        { id = "folders.finish", title = "Save folders and rescan library", order = 60,
          run = function()
              if S.mode ~= "set" then return false, "finish browsing before leaving" end
              local ok, result = pcall(Library.scan)
              if not ok or result == false then return false, tostring(result or "library scan failed") end
              ui.back()
              return true
          end },
        { id = "folders.state", title = "Get ROM folder state", order = 70,
          run = function()
              local row = selected()
              return { mode = S.mode, cwd = S.cwd,
                  selected_path = row and (row.path or row.dir),
                  selected_system = row and row.system,
                  selected_is_add = row and row.add == true,
                  registered_count = #(Settings.get("rom_paths") or {}) }
          end },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "folders", order = spec.order, screen = "folders",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
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
