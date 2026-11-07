-- frontend/wii_title_db.lua
-- GameID → official title lookup, sourced from GameTDB's wiitdb.txt.
--
-- Format of each data line in wiitdb.txt:
--     RMCE01 = Mario Kart Wii
-- (The `TITLES = ...` header line is skipped.)
--
-- The file is fetched automatically by boot_downloader.lua into
-- data/wiitdb.txt (or data/database/wiitdb.txt). If neither exists,
-- the module silently returns nil for every lookup, and the ROM
-- scanner falls back to the filename-derived title.

local M = { _loaded = false, _map = {}, _count = 0 }

local function trim(s)
  if not s then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function candidate_paths()
  local out = {}
  out[#out + 1] = "data/wiitdb.txt"
  out[#out + 1] = "data/database/wiitdb.txt"
  local ok, S = pcall(require, "state")
  if ok and S and S.frontend_path then
    out[#out + 1] = S.frontend_path("data/wiitdb.txt")
    out[#out + 1] = S.frontend_path("data/database/wiitdb.txt")
  end
  return out
end

function M.load()
  if M._loaded then return M._map end
  M._loaded = true

  for _, path in ipairs(candidate_paths()) do
    local f = io.open(path, "r")
    if f then
      local n = 0
      for line in f:lines() do
        if line:sub(1, 1) ~= "#"
           and line:sub(1, 7) ~= "TITLES " then
          local id, title = line:match(
            "^([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%s*=%s*(.+)$")
          if id and title then
            title = trim(title)
            if title ~= "" and not M._map[id] then
              M._map[id] = title
              n = n + 1
            end
          end
        end
      end
      f:close()
      M._count = n
      print(string.format("[wii_title_db] loaded %d titles from %s", n, path))
      return M._map
    end
  end

  print("[wii_title_db] wiitdb.txt not found — filenames will be used")
  return M._map
end

-- Return the official title for a 6-character GameID, or nil.
function M.title_for(id)
  if type(id) ~= "string" or #id ~= 6 then return nil end
  if not M._loaded then M.load() end
  return M._map[id]
end

function M.count()
  if not M._loaded then M.load() end
  return M._count
end

-- Force a reload — call after boot_downloader refreshes wiitdb.txt.
function M.reset()
  M._loaded = false
  M._map    = {}
  M._count  = 0
end

return M