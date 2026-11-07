-- ui/notify.lua — thin wrapper around core.notification_hub.
-- Keeps the legacy API (show(kind, message, ttl, opts)) so existing
-- screens continue to work, but everything renders as workshop-style
-- push notifications in the top-right corner.

local Hub = require("core.notification_hub")

local N = {}

-- show(kind, message, ttl, opts)
--   opts.title    → main title (default: derived from kind)
--   opts.subtitle → italic subtitle (default: message)
--   opts.persistent, opts.meta pass through
function N.show(kind, message, ttl, opts)
  opts = opts or {}
  local titles = {
    info     = "Info",
    success  = "Success",
    warning  = "Warning",
    error    = "Error",
    update   = "Update",
    download = "Download",
    scan     = "Scan",
  }
  local title    = opts.title    or titles[kind or "info"] or "Notice"
  local subtitle = opts.subtitle or message or ""
  Hub.push(kind or "info", title, subtitle, {
    ttl = ttl or 4,
    persistent = opts.persistent or false,
    meta = opts.meta,
  })
end

function N.update(dt) Hub.update(dt) end
function N.draw(w, h)
  Hub.draw(w, h)
end

-- Direct passthrough helpers
N.push      = Hub.push
N.history   = Hub.history
N.clear_all = Hub.clear_history

return N
