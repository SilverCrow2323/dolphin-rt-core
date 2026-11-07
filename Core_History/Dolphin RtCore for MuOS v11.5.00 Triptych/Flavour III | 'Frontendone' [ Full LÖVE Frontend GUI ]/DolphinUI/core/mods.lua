-- core/mods.lua — "Mod Vault": ricerca mod per gioco nelle 4 cartelle di
-- /opt/muos/share/emulator/dolphin/Load/
--
--   Textures · WiiSDSync · Riivolution · DynamicInputTextures
--
-- Una voce (cartella, o file per Riivolution/.xml) e' APPLICABILE a un gioco se
-- il suo nome (senza estensione) e':
--   "id"      == GameID del gioco               (GALE01)
--   "prefix"  == primi 3 caratteri del GameID   (GAL: tutte le regioni)
--   "name"    == titolo del gioco, senza maiuscole/punteggiatura
--                ("Zelda: The Wind Waker" == "zelda-the wind waker")
--   "all"     == mod per tutti i giochi: cartella All / Global / Common / ...
--
-- Selezione per gioco: salvata come elenco delle voci SPENTE (default = tutte
-- accese, e' cosi' che Dolphin si comporta). Al lancio si scrive
-- data/mods_plan.txt e scripts/launch.sh sposta le voci spente in <Cat>.off
-- (e le riporta indietro quando servono). Nessun processo, nessuna cartella
-- non pertinente viene toccata.
--
-- Dolphin carica da solo SOLO cartelle col GameID (o il prefisso a 3 char):
-- per le voci "name"/"all" in Textures e DynamicInputTextures il launcher crea
-- al volo un link  Load/<Cat>/<GAMEID> -> <voce>  e lo toglie a fine partita.

local Shell = require("core.shell")

local M = {}

M.LOAD = "/opt/muos/share/emulator/dolphin/Load"
M.PLAN = "data/mods_plan.txt"

-- icon = nome per K.draw_tool_icon, acc = chiave in K.ACC
M.CATS = {
  { id = "Textures",             label = "Textures",      short = "Textures",    icon = "screen",  acc = "teal",  link = true  },
  { id = "WiiSDSync",            label = "Wii SD Sync",   short = "SD Sync",     icon = "rescan",  acc = "lime",  link = false },
  { id = "Riivolution",          label = "Riivolution",   short = "Riivolution", icon = "boost",   acc = "boost", link = false },
  { id = "DynamicInputTextures", label = "Dynamic Input", short = "Dyn. Input",  icon = "gamepad", acc = "hot",   link = true  },
  -- Mod grafiche native di Dolphin (Load/GraphicMods). Non si abbinano per nome:
  -- si elencano tutte e si scelgono a mano. Default SPENTE (come prima).
  -- Il lancio le gestisce con --mods (core/launcher), non col piano.
  { id = "GraphicMods",          label = "Graphic Mods",  short = "Gfx Mods",    icon = "mods",    acc = "mods",  link = false, legacy = true },
}

local ALL_NAMES = {
  all = true, global = true, common = true, shared = true, allgames = true,
  everygame = true, everygames = true, tutti = true, alltitles = true, universal = true,
}

local KIND_ORDER = { id = 1, prefix = 2, name = 3, all = 4 }
M.KIND_LABEL = { id = "ID", prefix = "REGIONS", name = "NAME", all = "ALL", gfx = "" }

function M.norm(s)
  return (tostring(s or ""):lower():gsub("[^%w]", ""))
end

-- ── listing ────────────────────────────────────────────────
local function ls(dir)
  local out = {}
  local raw = Shell.popen("ls -1Ap " .. Shell.shq(dir), 5)
  if not raw then return out end
  for line in raw:gmatch("[^\n]+") do
    local is_dir = line:sub(-1) == "/"
    local name = is_dir and line:sub(1, -2) or line
    if name ~= "" and name:sub(1, 1) ~= "." then
      out[#out + 1] = { name = name, is_dir = is_dir }
    end
  end
  return out
end

-- voci della categoria: attive (Load/<Cat>) + parcheggiate (Load/<Cat>.off)
function M.entries(cat, root)
  root = root or M.LOAD
  local seen, out = {}, {}
  for _, parked in ipairs({ false, true }) do
    local dir = root .. "/" .. cat.id .. (parked and ".off" or "")
    for _, e in ipairs(ls(dir)) do
      if not seen[e.name] then
        seen[e.name] = true
        e.parked = parked
        e.base = e.is_dir and e.name or e.name:gsub("%.[^%.]+$", "")
        out[#out + 1] = e
      end
    end
  end
  return out
end

-- ── matching ───────────────────────────────────────────────
-- titles: lista di titoli equivalenti del gioco (nome file pulito, nome DB...)
function M.match_kind(game_id, titles_norm, entry)
  local up = entry.base:upper()
  if game_id and #game_id >= 3 then
    if up == game_id:upper() then return "id" end
    if up == game_id:sub(1, 3):upper() then return "prefix" end
  end
  local n = M.norm(entry.base)
  if n == "" then return nil end
  if ALL_NAMES[n] then return "all" end
  if titles_norm[n] then return "name" end
  return nil
end

local function titles_set(titles)
  local set = {}
  for _, t in ipairs(titles or {}) do
    local n = M.norm(t)
    if n ~= "" then set[n] = true end
  end
  return set
end

-- Voci applicabili al gioco, ordinate: id, prefix, name, all (poi per nome).
-- game = { id=, title= }.  Se game == nil restituisce tutto (catalogo).
function M.for_game(cat, game, titles, root)
  local list = {}
  local ts = titles_set(titles)
  for _, e in ipairs(M.entries(cat, root)) do
    if cat.legacy then
      e.kind = "gfx"; list[#list + 1] = e
    elseif game then
      local k = M.match_kind(game.id, ts, e)
      if k then e.kind = k; list[#list + 1] = e end
    else
      e.kind = "all"; list[#list + 1] = e
    end
  end
  table.sort(list, function(a, b)
    local ka, kb = KIND_ORDER[a.kind] or 9, KIND_ORDER[b.kind] or 9
    if ka ~= kb then return ka < kb end
    return a.name:lower() < b.name:lower()
  end)
  return list
end

-- ── piano di lancio ────────────────────────────────────────
-- off_of(cat_id) -> set { [nome]=true } delle voci spente per questo gioco
-- Ritorna il numero di righe scritte (o nil, errore).
function M.write_plan(game, titles, off_of, root, path)
  path = path or M.PLAN
  local lines = {}
  for _, cat in ipairs(M.CATS) do
   if not cat.legacy then
    local off = off_of and off_of(cat.id) or {}
    local list = M.for_game(cat, game, titles, root)
    local has_native = false           -- voce che Dolphin carica da solo (id/prefix)
    for _, e in ipairs(list) do
      if off[e.name] then
        lines[#lines + 1] = ("OFF|%s|%s"):format(cat.id, e.name)
      else
        lines[#lines + 1] = ("ON|%s|%s"):format(cat.id, e.name)
        if e.kind == "id" or e.kind == "prefix" then has_native = true end
      end
    end
    if cat.link and game and game.id and not has_native then
      for _, e in ipairs(list) do
        if not off[e.name] and (e.kind == "name" or e.kind == "all") and e.is_dir then
          lines[#lines + 1] = ("LINK|%s|%s|%s"):format(cat.id, e.name, game.id)
          break                        -- un solo link: Dolphin ne legge uno per gioco
        end
      end
    end
   end
  end
  local f = io.open(path, "w")
  if not f then return nil, "cannot write " .. path end
  f:write(table.concat(lines, "\n"), #lines > 0 and "\n" or "")
  f:close()
  return #lines
end

return M
