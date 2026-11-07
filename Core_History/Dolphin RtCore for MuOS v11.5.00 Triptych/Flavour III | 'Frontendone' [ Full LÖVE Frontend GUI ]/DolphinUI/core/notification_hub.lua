-- core/notification_hub.lua — Push notification system with history.
--
-- Types (define icon + colour + border style):
--   info      cyan solid      — generic information
--   success   green solid     — task completed
--   warning   amber double    — something needs attention
--   error     red double      — failure
--   update    purple glowing  — new version available
--   download  blue dashed     — download in progress
--   scan      orange dashed   — library scan / rebuild
--
-- Rendered top-right in workshop aesthetic:
--   chamfered plate, accent strip, icon chip, main title (Orbitron-Bold)
--   and italic subtitle (ChakraPetch-Italic).
--
-- History persisted in data/notifications_history.json.

local JSON = require("core.json")
local FS   = require("core.fs")

local M = {}

local HISTORY_PATH = "data/notifications_history.json"
local HISTORY_DIR  = "data/notifications"
local MAX_HISTORY  = 100
local MAX_ACTIVE   = 2
local DEFAULT_TTL  = 5.0
local SLIDE_TIME   = 0.35

-- ── Type catalogue ──────────────────────────────────────────
local TYPES = {
  info     = { color = {0.20, 0.72, 0.98}, icon = "info",     border = "solid",  label = "INFO"  },
  success  = { color = {0.30, 0.85, 0.40}, icon = "check",    border = "solid",  label = "OK"    },
  warning  = { color = {0.96, 0.77, 0.26}, icon = "warning",  border = "double", label = "WARN"  },
  error    = { color = {0.90, 0.30, 0.30}, icon = "error",    border = "double", label = "ERROR" },
  update   = { color = {0.62, 0.35, 0.98}, icon = "update",   border = "glow",   label = "UPDATE"},
  download = { color = {0.20, 0.65, 0.95}, icon = "save",     border = "dashed", label = "DL"    },
  scan     = { color = {0.96, 0.62, 0.20}, icon = "library",  border = "dashed", label = "SCAN"  },
}

M._active = {}
M._history = {}
M._t = 0
M._loaded = false

local function load_history()
  if M._loaded then return end
  M._loaded = true
  local raw = FS.read(HISTORY_PATH)
  if not raw then return end
  local ok, d = pcall(JSON.decode, raw)
  if ok and type(d) == "table" and type(d.entries) == "table" then
    M._history = d.entries
  end
end

local function save_history()
  FS.mkdir_p(HISTORY_DIR)
  local payload = { version = 1, updated = os.time(), entries = M._history }
  FS.atomic_write(HISTORY_PATH, JSON.encode(payload))
end

-- ── Public: push ────────────────────────────────────────────
-- push(kind, title, subtitle, opts)
--   opts.ttl         = float (default 5)
--   opts.persistent  = bool (never auto-dismiss)
--   opts.meta        = any table
function M.push(kind, title, subtitle, opts)
  opts = opts or {}
  load_history()

  -- Dedupe: if the same (title, subtitle) is already visible within
  -- 2 seconds, drop the new one. Prevents burst-flood at boot.
  local now_s = os.time()
  for _, a in ipairs(M._active) do
    if a.entry.title == tostring(title or "")
       and a.entry.subtitle == tostring(subtitle or "")
       and (now_s - (a.entry.ts or 0)) < 2 then
      return nil
    end
  end

  local entry = {
    id       = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999)),
    kind     = kind or "info",
    title    = tostring(title or ""),
    subtitle = tostring(subtitle or ""),
    ts       = os.time(),
    ttl      = tonumber(opts.ttl) or DEFAULT_TTL,
    persistent = opts.persistent == true,
    meta     = opts.meta,
  }

  -- Silent: history only, never rendered as an active toast.
  if opts.silent then
    table.insert(M._history, 1, entry)
    while #M._history > MAX_HISTORY do table.remove(M._history) end
    save_history()
    return entry.id
  end

  table.insert(M._active, { entry = entry, t = 0, dying = false })
  while #M._active > MAX_ACTIVE do table.remove(M._active, 1) end
  table.insert(M._history, 1, entry)
  while #M._history > MAX_HISTORY do table.remove(M._history) end
  save_history()
  return entry.id
end

function M.history()       load_history(); return M._history end
function M.clear_history() M._history = {}; save_history() end

function M.dismiss(id)
  for i, a in ipairs(M._active) do
    if a.entry.id == id then table.remove(M._active, i); return true end
  end
  return false
end

function M.clear_active() M._active = {} end

function M.count_active() return #M._active end

-- ── Update / animation ──────────────────────────────────────
function M.update(dt)
  M._t = M._t + dt
  for i = #M._active, 1, -1 do
    local a = M._active[i]
    a.t = a.t + dt
    if not a.entry.persistent and a.t >= a.entry.ttl then
      a.dying = true
    end
    if a.dying and a.t >= a.entry.ttl + SLIDE_TIME then
      table.remove(M._active, i)
    end
  end
end

-- ── Drawing ─────────────────────────────────────────────────
local function chamfer(x, y, w, h, c)
  return { x+c, y, x+w, y, x+w, y+h-c, x+w-c, y+h, x, y+h, x, y+c }
end

local function type_def(kind)
  return TYPES[kind] or TYPES.info
end

local function draw_border(x, y, w, h, col, style)
  if style == "double" then
    love.graphics.setColor(col)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", chamfer(x, y, w, h, 6))
    love.graphics.setColor(col[1], col[2], col[3], 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", chamfer(x+3, y+3, w-6, h-6, 5))
    love.graphics.setLineWidth(1)
  elseif style == "dashed" then
    love.graphics.setColor(col)
    love.graphics.setLineWidth(1.5)
    for dx = 0, w - 12, 12 do
      love.graphics.line(x+dx,   y,   x+dx+6, y)
      love.graphics.line(x+dx,   y+h, x+dx+6, y+h)
    end
    for dy = 0, h - 12, 12 do
      love.graphics.line(x,   y+dy,   x,   y+dy+6)
      love.graphics.line(x+w, y+dy,   x+w, y+dy+6)
    end
    love.graphics.setLineWidth(1)
  elseif style == "glow" then
    local pulse = 0.5 + 0.5 * math.sin(M._t * 4)
    love.graphics.setColor(col[1], col[2], col[3], 0.45 + pulse * 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", chamfer(x, y, w, h, 6))
    love.graphics.setLineWidth(1)
  else
    love.graphics.setColor(col[1], col[2], col[3], 0.85)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", chamfer(x, y, w, h, 6))
    love.graphics.setLineWidth(1)
  end
end

local function draw_icon_chip(kind, cx, cy, r, col)
  love.graphics.setColor(col[1]*0.22, col[2]*0.22, col[3]*0.22, 1)
  love.graphics.circle("fill", cx, cy, r + 2)
  love.graphics.setColor(col[1], col[2], col[3], 0.85)
  love.graphics.setLineWidth(1.4)
  love.graphics.circle("line", cx, cy, r + 2)
  love.graphics.setLineWidth(1)
  local ok, Icons = pcall(require, "ui.icons")
  if ok and Icons then
    Icons.draw(type_def(kind).icon, cx - r, cy - r, r*2, col)
  end
end

-- Renders the active stack top-right. Call from love.draw after UI.
function M.draw(W, H)
  load_history()
  local n = #M._active
  if n == 0 then return end

  local card_w = math.min(380, W - 24)
  local card_h = 68
  local gap    = 8
  local base_x = W - card_w - 12
  local base_y = 12

  local Fonts = require("ui.theme.fonts")

  for i, a in ipairs(M._active) do
    local entry = a.entry
    local td    = type_def(entry.kind)
    local col   = td.color

    -- slide animation (in from right, out to right)
    local slide = 1
    if a.t < SLIDE_TIME then
      slide = a.t / SLIDE_TIME
      slide = 1 - (1 - slide)^3
    elseif a.dying then
      local p = (a.t - entry.ttl) / SLIDE_TIME
      if p < 0 then p = 0 end
      if p > 1 then p = 1 end
      slide = 1 - p
    end

    local x = base_x + (1 - slide) * (card_w + 24)
    local y = base_y + (i - 1) * (card_h + gap)

    -- shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.polygon("fill", chamfer(x+2, y+3, card_w, card_h, 6))

    -- base plate
    love.graphics.setColor(0.045, 0.055, 0.080, 0.98)
    love.graphics.polygon("fill", chamfer(x, y, card_w, card_h, 6))

    -- left accent strip
    love.graphics.setColor(col[1], col[2], col[3], 0.95)
    love.graphics.rectangle("fill", x + 3, y + 8, 3, card_h - 16, 1, 1)

    -- border per type
    draw_border(x, y, card_w, card_h, col, td.border)

    -- icon chip
    local ico_r  = 16
    local ico_cx = x + 3 + 14 + ico_r
    local ico_cy = y + card_h / 2
    draw_icon_chip(entry.kind, ico_cx, ico_cy, ico_r, col)

    -- title (Orbitron-Bold)
    local tx = ico_cx + ico_r + 14
    local tw = card_w - (tx - x) - 12
    love.graphics.setFont(Fonts.get("assets/fonts/Orbitron-Bold.ttf", 14))
    love.graphics.setColor(1, 1, 1, 1)
    local title = entry.title
    if #title > 44 then title = title:sub(1, 42) .. ".." end
    love.graphics.print(title, tx, y + 8)

    -- subtitle (ChakraPetch-Italic, small)
    love.graphics.setFont(Fonts.get("assets/fonts/ChakraPetch-Italic.ttf", 12))
    love.graphics.setColor(0.82, 0.87, 0.95, 1)
    local sub = entry.subtitle
    if #sub > 70 then sub = sub:sub(1, 68) .. ".." end
    love.graphics.printf(sub, tx, y + 30, tw, "left")

    -- type label (bottom-right corner)
    love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Bold.ttf", 11))
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    love.graphics.printf(td.label, x + 6, y + card_h - 12,
                         card_w - 12, "right")

    -- timestamp (bottom-left)
    love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Regular.ttf", 10))
    love.graphics.setColor(0.55, 0.62, 0.74, 0.85)
    local ts = os.date("%H:%M:%S", entry.ts)
    love.graphics.print(ts, x + 12, y + card_h - 15)
  end
end

return M
