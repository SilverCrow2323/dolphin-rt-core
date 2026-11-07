-- core/compatibility.lua — loader + aggregatore per data/games_data.json (v2)
--
-- Perche' e' stato riscritto (bug del v1):
--   * la Library leggeva una sezione [COMPAT] delle card che nessuno scriveva
--     mai -> "No compatibility data" sempre. Ora tutti passano da qui.
--   * "Playable" era dedotto da rating > 0 (sbagliato: usa test_review.playable)
--   * FPS = media dei min / media dei max, e "0-0" quando il dato e' N/A
--   * game_id duplicati nel DB (es. GEDP01 = Eternal Darkness E Geist) si
--     sovrascrivevano a vicenda; ora sono varianti, scelte per titolo
--   * outer id != id nell'entry (SEKJ99 / SEKE99) non veniva trovato
--   * valori null (json.null e' una table, truthy) facevano crashare le string ops
--   * file con BOM / scaricato a meta' -> tutto vuoto in silenzio. Ora fallback
--     su games_data.json.bak e errore leggibile in M.error
--   * game.lua ri-parsava 260 KB di JSON a ogni apertura (lento su ARM):
--     ora ricarica solo se il file e' cambiato
--
-- API (retro-compatibile):
--   M.load(force)        -> M       carica (o ricarica se il file e' cambiato)
--   M.games / M.by_id    array / mappa id -> gruppo
--   M.lookup(game)       -> gruppo, approx   (game = {id=,title=} o stringa id)
--   M.summary(gruppo)    -> tabella pronta da mostrare (stringhe + colori)
--   M.error              ultimo errore di caricamento (nil se ok)
--
-- Gruppo: { id, title, system, region, entries, n, avg, best, rated,
--           playable, playable_rank, boot, fps_lo, fps_hi, fps_text,
--           profiles = {...}, devices = {...} }

local json = require("core.json")

local M = {
  games = {}, by_id = {}, by_prefix = {}, variants = {},
  loaded = false, source = nil, error = nil, count = 0,
}

local PATHS = {
  "data/games_data.json",
  "frontend/data/games_data.json",
  "../data/games_data.json",
}

local _sig = nil          -- firma del file caricato (dimensione + path)

-- ── helper di sanificazione ────────────────────────────────
local function S(v, d)
  if type(v) == "string" then return (v:gsub("^%s+", ""):gsub("%s+$", "")) end
  if type(v) == "number" then return tostring(v) end
  return d or ""
end
local function N(v)
  local n = tonumber(v)               -- tonumber(json.null) == nil
  return n or 0
end
local function norm_title(s)
  return (S(s):lower():gsub("[^%w]", ""))
end

local PLAY_RANK = { ["YES"] = 3, ["YES WITH ISSUES"] = 2, ["NO"] = 1 }
local BOOT_RANK = { ["YES"] = 3, ["NO"] = 2, ["CRASH"] = 1 }

local function up(s) return (S(s):upper():gsub("%s+", " ")) end

-- ── lettura file ───────────────────────────────────────────
local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local c = f:read("*a"); f:close()
  return c
end

local function file_len(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local n = f:seek("end"); f:close()
  return n
end

local function candidates()
  local list = {}
  for _, p in ipairs(PATHS) do list[#list + 1] = p end
  -- se LOVE e' attivo, prova anche la cartella sorgente (cwd diverso dall'app)
  if love and love.filesystem and love.filesystem.getSource then
    local ok, src = pcall(love.filesystem.getSource)
    if ok and type(src) == "string" and src ~= "" then
      list[#list + 1] = src .. "/data/games_data.json"
    end
  end
  return list
end

local function find_source()
  for _, p in ipairs(candidates()) do
    local n = file_len(p)
    if n and n > 2 then return p, n end
  end
  return nil
end

-- ── normalizzazione di una singola entry ───────────────────
local function parse_fps(tr)
  local lo, hi = N(tr.fps_min), N(tr.fps_max)
  if lo <= 0 and hi <= 0 then
    local s = S(tr.fps)
    local a, b = s:match("(%d+)%D+(%d+)")
    if a then lo, hi = tonumber(a), tonumber(b)
    else
      local one = s:match("^(%d+)$")
      if one then lo, hi = tonumber(one), tonumber(one) end
    end
  end
  if hi > 0 and lo <= 0 then lo = hi end
  if lo > hi then lo, hi = hi, lo end
  return lo, hi
end

local function norm_entry(e)
  if type(e) ~= "table" then return nil end
  local tr = type(e.test_review) == "table" and e.test_review or {}
  local td = type(e.test_details) == "table" and e.test_details or {}
  local te = type(e.test_environment) == "table" and e.test_environment or {}
  local lo, hi = parse_fps(tr)
  local rating = math.max(0, math.min(5, N(tr.rating)))
  -- campi grezzi originali restano accessibili (game.lua li usa), ma puliti
  e.test_review, e.test_details, e.test_environment = tr, td, te
  e.norm = {
    rating   = rating,
    fps_lo   = lo, fps_hi = hi,
    playable = up(tr.playable),
    boot     = up(tr.boot),
    profile  = S(td.core_profile),
    version  = S(td.rtcore_version),
    note     = S(td.considerations),
    tester   = S(te.tester),
    device   = S(te.device),
  }
  return e
end

-- ── aggregazione di un gruppo ──────────────────────────────
local function aggregate(g)
  local gi = type(g.game_info) == "table" and g.game_info or {}
  local entries = {}
  for _, e in ipairs(type(g.entries) == "table" and g.entries or {}) do
    local ne = norm_entry(e)
    if ne then entries[#entries + 1] = ne end
  end

  local sum_r, n_r, best = 0, 0, 0
  local lo_min, hi_max = nil, 0
  local play_rank, boot_rank, play_txt, boot_txt = 0, 0, nil, nil
  local profiles, seen_p, devices, seen_d = {}, {}, {}, {}

  for _, e in ipairs(entries) do
    local x = e.norm
    if x.rating > 0 then n_r = n_r + 1; sum_r = sum_r + x.rating end
    if x.rating > best then best = x.rating end
    if x.fps_hi > 0 then
      lo_min = (lo_min == nil) and x.fps_lo or math.min(lo_min, x.fps_lo)
      hi_max = math.max(hi_max, x.fps_hi)
    end
    local pr = PLAY_RANK[x.playable] or 0
    if pr > play_rank then play_rank, play_txt = pr, x.playable end
    local br = BOOT_RANK[x.boot] or 0
    if br > boot_rank then boot_rank, boot_txt = br, x.boot end
    if x.playable ~= "NO" and x.profile ~= "" and not seen_p[x.profile] then
      seen_p[x.profile] = true; profiles[#profiles + 1] = x.profile
    end
    if x.device ~= "" and x.device ~= "Unknown Device" and not seen_d[x.device] then
      seen_d[x.device] = true; devices[#devices + 1] = x.device
    end
  end

  lo_min = lo_min or 0
  local fps_text = "N/A"
  if hi_max > 0 then
    fps_text = (lo_min == hi_max) and tostring(hi_max)
               or (lo_min .. "\226\128\147" .. hi_max)          -- en dash
  end

  return {
    id = S(gi.game_id), title = S(gi.game), system = S(gi.system),
    region = S(gi.region),
    entries = entries, n = #entries,
    rated = n_r,
    avg = n_r > 0 and (sum_r / n_r) or 0,
    best = best,
    playable = play_txt or "?", playable_rank = play_rank,
    boot = boot_txt or "?",
    fps_lo = lo_min, fps_hi = hi_max, fps_text = fps_text,
    profiles = profiles, devices = devices,
  }
end

-- ── caricamento ────────────────────────────────────────────
local function reset()
  M.games, M.by_id, M.by_prefix, M.variants = {}, {}, {}, {}
  M.count = 0
end

local function decode_file(path)
  local raw = read_all(path)
  if not raw or #raw < 3 then return nil, "empty file" end
  local d, err = json.decode_err(raw)
  if type(d) ~= "table" then return nil, err or "invalid JSON" end
  return d
end

local function build(data)
  reset()
  local list = data.games
  if type(list) ~= "table" then return false, "missing 'games' array" end

  -- 1) gruppi per (id, titolo normalizzato): stesso id+titolo => unisci le entry
  local by_key, order = {}, {}
  for _, g in ipairs(list) do
    if type(g) == "table" then
      local gi = type(g.game_info) == "table" and g.game_info or {}
      local gid = S(gi.game_id)
      -- id usati dalle singole entry (es. outer SEKJ99, entry SEKE99)
      local alt = {}
      for _, e in ipairs(type(g.entries) == "table" and g.entries or {}) do
        local egi = type(e) == "table" and type(e.game_info) == "table" and e.game_info or {}
        local eg = S(egi.game_id)
        if eg ~= "" and eg ~= gid then alt[eg] = true end
        if gid == "" and eg ~= "" then gid = eg end
      end
      if gid ~= "" then
        local key = gid .. "|" .. norm_title(gi.game)
        local slot = by_key[key]
        if not slot then
          slot = { raw = { game_info = { game_id = gid, game = gi.game,
                    system = gi.system, region = gi.region }, entries = {} },
                   alt = {} }
          by_key[key] = slot; order[#order + 1] = key
        end
        for _, e in ipairs(type(g.entries) == "table" and g.entries or {}) do
          slot.raw.entries[#slot.raw.entries + 1] = e
        end
        for k in pairs(alt) do slot.alt[k] = true end
      end
    end
  end

  -- 2) aggrega e indicizza
  for _, key in ipairs(order) do
    local slot = by_key[key]
    local grp = aggregate(slot.raw)
    grp.alt_ids = slot.alt
    M.games[#M.games + 1] = grp
    M.count = M.count + 1

    M.variants[grp.id] = M.variants[grp.id] or {}
    table.insert(M.variants[grp.id], grp)
    if not M.by_id[grp.id] then M.by_id[grp.id] = grp end
    for aid in pairs(grp.alt_ids) do
      M.variants[aid] = M.variants[aid] or {}
      table.insert(M.variants[aid], grp)
      if not M.by_id[aid] then M.by_id[aid] = grp end
    end
    local pre = grp.id:sub(1, 4)
    M.by_prefix[pre] = M.by_prefix[pre] or {}
    table.insert(M.by_prefix[pre], grp)
  end
  return true
end

function M.load(force)
  local path, len = find_source()
  local sig = path and (path .. ":" .. tostring(len)) or "none"
  if M.loaded and not force and sig == _sig then return M end

  M.error = nil
  if not path then
    reset(); M.loaded = true; _sig = sig; M.source = nil
    M.error = "games_data.json not found"
    return M
  end

  local data, err = decode_file(path)
  if data then
    M.source = path
  else
    -- download interrotto / file corrotto: prova il backup
    local bak = path .. ".bak"
    local d2 = decode_file(bak)
    if d2 then data, M.source = d2, bak
    else
      reset(); M.loaded = true; _sig = sig; M.source = path
      M.error = "games_data.json: " .. tostring(err)
      return M
    end
  end

  local ok, berr = build(data)
  if not ok then M.error = berr end
  M.loaded = true; _sig = sig
  return M
end

-- ── lookup ─────────────────────────────────────────────────
local function similarity(a, b)
  a, b = norm_title(a), norm_title(b)
  if a == "" or b == "" then return 0 end
  if a == b then return 1000 end
  if a:find(b, 1, true) or b:find(a, 1, true) then return 500 + math.min(#a, #b) end
  local n = 0
  for i = 1, math.min(#a, #b) do
    if a:sub(i, i) == b:sub(i, i) then n = n + 1 else break end
  end
  return n
end

local function pick(list, title)
  if not list or #list == 0 then return nil end
  if #list == 1 or not title or title == "" then return list[1] end
  local best, bs = list[1], -1
  for _, g in ipairs(list) do
    local s = similarity(g.title, title)
    if s > bs then best, bs = g, s end
  end
  return best
end

-- game: { id = "GEDP01", title = "..." } oppure direttamente la stringa id.
-- Ritorna gruppo, approx  (approx = true se trovato solo per prefisso a 4 char)
function M.lookup(game)
  -- Settings > System > Compatibility data (prima: toggle senza effetto)
  local okS, St = pcall(require, "core.settings")
  if okS and St.data and St.get("enable_compat_data") == false then return nil end
  M.load()
  local id, title
  if type(game) == "table" then id, title = game.id, game.title
  else id = game end
  if type(id) ~= "string" or id == "" then return nil end
  id = id:upper()

  local hit = pick(M.variants[id], title)
  if hit then return hit, false end

  -- stesso gioco, diverso codice publisher (GEDP01 / GEDP08): stesso prefisso
  -- a 4 caratteri (gioco + regione). Solo se non ambiguo.
  local pre = M.by_prefix[id:sub(1, 4)]
  if pre then
    local g = pick(pre, title)
    if g and (#pre == 1 or similarity(g.title, title) >= 3) then return g, true end
  end
  return nil
end

-- ── riepilogo pronto per l'UI ──────────────────────────────
-- kind: "ok" | "warn" | "bad" | "dim"  (mappa su K.C.ok / warn / bad / dim)
function M.summary(g)
  if not g then return nil end
  local play_kind = ({ [3] = "ok", [2] = "warn", [1] = "bad" })[g.playable_rank] or "dim"
  local boot_kind = ({ ["YES"] = "ok", ["NO"] = "warn", ["CRASH"] = "bad" })[g.boot] or "dim"
  local play_label = ({ ["YES"] = "Playable", ["YES WITH ISSUES"] = "Playable (issues)",
                        ["NO"] = "Not playable" })[g.playable] or "Unknown"
  local boot_label = ({ ["YES"] = "Boots", ["NO"] = "No boot", ["CRASH"] = "Crashes" })[g.boot] or "?"
  return {
    playable = g.playable, play_label = play_label, play_kind = play_kind,
    boot = g.boot, boot_label = boot_label, boot_kind = boot_kind,
    fps = g.fps_text, has_fps = g.fps_hi > 0,
    rating = g.avg, rating_text = g.rated > 0 and string.format("%.1f / 5", g.avg) or "not rated",
    stars = g.rated > 0 and g.avg or 0,
    n = g.n,
    profiles = table.concat(g.profiles, ", "),
    devices = table.concat(g.devices, ", "),
  }
end

return M
