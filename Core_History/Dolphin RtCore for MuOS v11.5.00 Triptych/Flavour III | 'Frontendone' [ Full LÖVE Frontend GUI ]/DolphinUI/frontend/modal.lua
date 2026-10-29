-- frontend/modal.lua — modal dialog with optional callbacks.
--
-- API:
--   Modal.show(title, message)                       -- informational
--   Modal.show(title, message, on_accept)            -- confirm (A)
--   Modal.show(title, message, on_accept, on_cancel) -- confirm + cancel
--   Modal.show(title, message, { ... })              -- opts table
--
-- main.lua routes input here when Modal.is_open() is true.

local A     = require("assets")
local State = require("state")
local BI    = require("ui.button_icons")

local M = { current = nil, drawn_this_frame = false }

function M.show(title, message, a, b)
  local opts
  if type(a) == "table" then
    opts = a
  else
    opts = { on_accept = a, on_cancel = b }
  end
  M.current = {
    title        = title or "",
    message      = message or "",
    on_accept    = opts.on_accept,
    on_cancel    = opts.on_cancel,
    accept_label = opts.accept_label,
    cancel_label = opts.cancel_label,
    color        = opts.color,
    open_time    = love.timer.getTime(),
  }
end

function M.close()
  M.current = nil
end

function M.is_open()
  return M.current ~= nil
end

-- Legge il modale aperto senza modificare lo stato. Utile per
-- screen che vogliono evitare di aprire un secondo modale sopra.
function M.peek()
  return M.current
end

-- Segna che il modale è stato disegnato in questo frame.
function M.set_drawn()
  M.drawn_this_frame = true
end

local function invoke(cb)
  if type(cb) == "function" then
    local ok, err = pcall(cb)
    if not ok then
      print("[modal] callback error: " .. tostring(err))
    end
  end
end

function M.accept()
  local c = M.current
  if not c then return end
  M.current = nil
  invoke(c.on_accept)
end

function M.cancel()
  local c = M.current
  if not c then return end
  M.current = nil
  invoke(c.on_cancel)
end

function M.pad(b)
  local IM = require("input_map")
  if type(b) == "number" then
    local logical = IM.raw_to_logical[b]
    b = logical and IM[logical] or b
  end
  if b == IM.A then M.accept()
  elseif b == IM.B then M.cancel() end
end

function M.key(k)
  if k == "return" or k == "space" then M.accept()
  elseif k == "escape" then M.cancel() end
end

function M.draw()
  local c = M.current
  M.drawn_this_frame = true
  if not c then return end

  local th = State.theme
  local W, H = 640, 480

  local elapsed = love.timer.getTime() - (c.open_time or 0)
  local ease = math.min(1, elapsed / 0.15)
  ease = 1 - (1 - ease) ^ 3
  if ease <= 0.01 then return end

  local body = A.font(th.font_body, 12)

  local msg_h = BI.rich_text_height(
    c.message, 40, 0, 380, body, th, 18)

  local w = 460
  local h = math.max(180, 130 + msg_h)
  local x = (W - w) / 2
  local y = (H - h) / 2 + (1 - ease) * 20

  love.graphics.setColor(0, 0, 0, 0.55 * ease)
  love.graphics.rectangle("fill", 0, 0, W, H)

  love.graphics.setColor(th.panel)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)

  local accent = c.color or th.accent
  love.graphics.setColor(accent)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 10, 10)
  love.graphics.setLineWidth(1)

  if ease < 0.7 then return end

  love.graphics.setColor(accent)
  love.graphics.setFont(A.font(th.font_body_bold, 18))
  love.graphics.printf(c.title, x, y + 16, w, "center")

  love.graphics.setColor(accent[1], accent[2], accent[3], 0.35)
  love.graphics.rectangle("fill", x + 20, y + 46, w - 40, 1)

  BI.draw_rich_text(
    c.message,
    x + 20, y + 60, w - 40,
    body, th, 18)

  local is_confirm = (c.on_accept ~= nil) or (c.accept_label ~= nil)
  local footer
  if is_confirm then
    local al = c.accept_label or "Confirm"
    local cl = c.cancel_label or "Cancel"
    footer = ("[A] %s   [B] %s"):format(al, cl)
  else
    footer = "[A] Close   [B] Close"
  end
  BI.draw_hint_centered(
    footer,
    W, y + h - 26,
    A.font(th.font_body, 11), th)
end

return M