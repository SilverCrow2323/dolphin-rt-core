-- frontend/async_scanner.lua
-- Asynchronous ROM scanner.
--
-- Instead of blocking the main thread with dozens of io.popen() calls,
-- this writes a shell script to /tmp, launches it detached, and polls
-- for a .done marker. Results are read from a TSV file.
--
-- API:
--   M.start()       → bool  begin background scan
--   M.poll()        → bool done, array|nil  check progress
--   M.is_running()  → bool
--   M.cancel()      → stop and cleanup
--
-- Output row format (TSV):
--   SYS \t PATH \t FILE \t GAMEID \t BASENAME
--
-- SYS is "GC" or "Wii".
--
-- ── GameID extraction ─────────────────────────────────────────
-- The GameID is read from the binary content of the file, exactly
-- like Dolphin itself does — not from the filename. Supported
-- formats and offsets:
--
--   ISO / GCM   → 0x00 (6 ASCII bytes)
--   RVZ         → "RVZ\x01" magic; scan first 512 bytes
--   WIA         → "WIA\x01" magic; scan first 512 bytes
--   WBFS        → "WBFS" magic; try 0x100, then 0x10, then scan
--   GCZ         → gzip magic (1f 8b); scan first 4 KB
--   anything    → try 0x00, then scan first 512 bytes
--
-- A valid GameID is [A-Z][A-Z0-9]{5} and is never one of the
-- container magic words (RVZ, WBFS, WIA, ISO, GCM).

local M = {}

local SH_PATH   = "/tmp/dolphinui_scan.sh"
local OUT_PATH  = "/tmp/dolphinui_scan.out"
local DONE_PATH = "/tmp/dolphinui_scan.done"
local TMP_PATH  = OUT_PATH .. ".tmp"

local _running   = false
local _start_t   = 0
local _timeout_s = 120   -- hard timeout for a stuck scan

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- ── Scan parameters ──────────────────────────────────────────
local DEFAULT_EXTS    = { "iso", "gcm", "rvz", "wbfs", "wia", "ciso", "nkit", "gcz" }
local RECURSIVE_DEPTH = 4

local function parse_exts(s)
  if type(s) ~= "string" or s == "" then return nil end
  local out = {}
  for e in s:gmatch("[^,%s]+") do
    e = e:gsub("^%.", ""):gsub("[^%w]", ""):lower()
    if e ~= "" then out[#out + 1] = e end
  end
  if #out == 0 then return nil end
  return out
end

local function ext_clause(exts)
  local parts = {}
  for _, e in ipairs(exts) do
    parts[#parts + 1] = "-iname '*." .. e .. "'"
  end
  return "\\( " .. table.concat(parts, " -o ") .. " \\)"
end

-- ── Script builder ───────────────────────────────────────────
local function build_script(gc_paths, wii_paths, depth, exts)
  local parts = {}
  local function w(line) parts[#parts + 1] = line end

  w("#!/bin/sh")
  w("OUT="  .. shq(OUT_PATH))
  w("DONE=" .. shq(DONE_PATH))
  w("TMP="  .. shq(TMP_PATH))
  w(': > "$TMP"')
  w('rm -f "$DONE"')
  w("")

  -- ═══════════════════════════════════════════════════════════════
  --  GameID extraction — Dolphin-compatible
  -- ═══════════════════════════════════════════════════════════════
  w("_rtc_valid_id() {")
  w('  [ ${#1} -eq 6 ] || return 1')
  w('  case "$1" in')
  w('    RVZ|WBFS|WIA|ISO|GCM|GCZ|NKIT) return 1 ;;')
  w('  esac')
  w('  echo "$1" | grep -qE "^[A-Z][A-Z0-9]{5}$"')
  w("}")
  w("")

  w("_rtc_read_at() {")
  w('  dd if="$1" bs=1 skip="$2" count=6 2>/dev/null | tr -cd "A-Z0-9"')
  w("}")
  w("")

  w("_rtc_scan_head() {")
  w('  dd if="$1" bs=1 count="${2:-512}" 2>/dev/null \\')
  w("    | tr -c 'A-Z0-9' '\\n' \\")
  w("    | grep -oE '^[A-Z][A-Z0-9]{5}$' \\")
  w("    | grep -vE '^(RVZ|WBFS|WIA|ISO|GCM|GCZ|NKIT)$' \\")
  w("    | head -1")
  w("}")
  w("")

  w("_rtc_extract_id() {")
  w('  F="$1"')
  w('  [ -f "$F" ] || { echo "UNKNOWN"; return; }')
  w('  MAGIC=$(xxd -p -l 4 "$F" 2>/dev/null | tr -d "\\n")')
  w('  case "$MAGIC" in')
  w("    52565a01|52565a00)")           -- RVZ
  w('      ID=$(_rtc_scan_head "$F" 512)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w("      ;;")
  w("    57424653)")                     -- WBFS
  w('      ID=$(_rtc_read_at "$F" 256)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w('      ID=$(_rtc_read_at "$F" 16)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w('      ID=$(_rtc_scan_head "$F" 1024)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w("      ;;")
  w("    57494101|57494100)")           -- WIA
  w('      ID=$(_rtc_scan_head "$F" 512)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w("      ;;")
  w("    1f8b08*)")                     -- GCZ (gzip)
  w('      ID=$(_rtc_scan_head "$F" 4096)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w("      ;;")
  w("    *)")                          -- ISO / GCM / anything else
  w('      ID=$(_rtc_read_at "$F" 0)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w('      ID=$(_rtc_scan_head "$F" 512)')
  w('      _rtc_valid_id "$ID" && { echo "$ID"; return; }')
  w("      ;;")
  w("  esac")
  w('  echo "UNKNOWN"')
  w("}")
  w("")

  -- ── scan_dir ──────────────────────────────────────────────
  w("scan_dir() {")
  w('  SYS="$1"')
  w('  DIR="$2"')
  w('  [ -d "$DIR" ] || return 0')
  w("  find \"$DIR\" -maxdepth " .. depth .. " -type f \\")
  w("    " .. ext_clause(exts) .. " \\")
  w("    2>/dev/null | while IFS= read -r F; do")
  w('    NAME=$(basename "$F")')
  w("    BASE=$(echo \"$NAME\" | sed 's/\\.[^.]*$//')")
  w('    ID=$(_rtc_extract_id "$F")')
  w("    printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$SYS\" \"$F\" \"$NAME\" \"$ID\" \"$BASE\" >> \"$TMP\"")
  w("  done")
  w("}")
  w("")

  w("find_keyword_dirs() {")
  w('  BASE="$1"')
  w('  shift')
  w('  [ -d "$BASE" ] || return 0')
  w("  find \"$BASE\" -maxdepth 3 -type d 2>/dev/null | while IFS= read -r D; do")
  w("    LOW=$(echo \"$D\" | tr 'A-Z' 'a-z')")
  w('    for KW in "$@"; do')
  w("      case \"/$LOW/\" in")
  w("        *\"/$KW/\"*)")
  w('          echo "$D"')
  w("          break")
  w("          ;;")
  w("      esac")
  w("    done")
  w("  done")
  w("}")
  w("")

  for _, p in ipairs(gc_paths)  do w("scan_dir GC  " .. shq(p)) end
  for _, p in ipairs(wii_paths) do w("scan_dir Wii " .. shq(p)) end

  local FALLBACK = {
    "/mnt/mmc/ROMS",      "/mnt/sdcard/ROMS",
    "/mnt/mmc/roms",      "/mnt/sdcard/roms",
    "/mnt/mmc/MUOS/roms", "/mnt/sdcard/MUOS/roms",
  }
  for _, base in ipairs(FALLBACK) do
    w("find_keyword_dirs " .. shq(base) ..
      " nintendo\\ gamecube gamecube ngc | while IFS= read -r D; do scan_dir GC \"$D\"; done")
    w("find_keyword_dirs " .. shq(base) ..
      " nintendo\\ wii wii | while IFS= read -r D; do scan_dir Wii \"$D\"; done")
  end

  w("")
  w('mv "$TMP" "$OUT" 2>/dev/null')
  w('touch "$DONE"')

  return table.concat(parts, "\n") .. "\n"
end

-- ── Public API ───────────────────────────────────────────────
function M.start()
  if _running then return false end

  local gc_paths, wii_paths = {}, {}
  local depth, exts = 1, nil
  local ok, Store = pcall(require, "settings_store")
  if ok and Store then
    if Store.get_paths then
      gc_paths  = Store.get_paths("gc")  or {}
      wii_paths = Store.get_paths("wii") or {}
    end
    if Store.get then
      if Store.get("roms", "scan_recursive") ~= false then
        depth = RECURSIVE_DEPTH
      end
      exts = parse_exts(Store.get("roms", "extensions"))
    end
  end
  exts = exts or DEFAULT_EXTS

  local body = build_script(gc_paths, wii_paths, depth, exts)
  local f = io.open(SH_PATH, "w")
  if not f then return false end
  f:write(body)
  f:close()
  os.execute("chmod +x " .. shq(SH_PATH))

  os.remove(OUT_PATH)
  os.remove(DONE_PATH)

  os.execute("setsid sh " .. shq(SH_PATH) ..
             " </dev/null >/dev/null 2>&1 &")

  _running = true
  _start_t = love.timer.getTime()
  return true
end

function M.is_running()
  return _running
end

function M.poll()
  if not _running then return false, nil end

  if love.timer.getTime() - _start_t > _timeout_s then
    M.cancel()
    return true, {}
  end

  local df = io.open(DONE_PATH, "r")
  if not df then return false, nil end
  df:close()

  local roms = {}
  local out = io.open(OUT_PATH, "r")
  if out then
    for line in out:lines() do
      local sys, path, file, id, title =
        line:match("^(%S+)\t(.-)\t(.-)\t(.-)\t(.*)$")
      if sys and path and file then
        table.insert(roms, {
          sys   = sys,
          path  = path,
          file  = file,
          id    = (id ~= "" and id ~= "UNKNOWN") and id or nil,
          title = title or file,   -- provisional; main.lua overrides via wiitdb
        })
      end
    end
    out:close()
  end

  os.remove(SH_PATH)
  os.remove(OUT_PATH)
  os.remove(DONE_PATH)

  _running = false
  return true, roms
end

function M.cancel()
  if not _running then return end
  os.execute("pkill -f dolphinui_scan.sh 2>/dev/null")
  os.remove(SH_PATH)
  os.remove(OUT_PATH)
  os.remove(DONE_PATH)
  _running = false
end

return M