-- ui/screens/stream_settings.lua — Rt:Stream settings, PC tools, pairing and an on-screen keyboard.
-- Modes: "list" (settings + actions), "viewer" (job output), "osk" (text entry).
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local Notify = require("ui.notify")
local Stream = require("core.stream")
local lg     = love.graphics

local S = {}
S.mode = "list"
S.list = K.List(K.MARGIN, 86, K.W - K.MARGIN * 2 - 14, K.BOT - 86, 40)
local t = 0
local viewer, osk
S.hosts = {}
S.host_list = K.List(K.MARGIN, 104, K.W - K.MARGIN * 2 - 14, K.BOT - 104, 48)

local function read_discovered_hosts()
  local raw = Stream.read(Stream.DIR .. "/discovery.tsv") or ""
  local hosts, seen = {}, {}
  for line in raw:gmatch("[^\\n]+") do
    local source, host = line:match("^([^\\t]+)\\t([^\\t]+)")
    if host and host:match("^[%d%.]+$") and not seen[host] then
      seen[host] = true
      hosts[#hosts + 1] = { host = host, source = source or "LAN" }
    end
  end
  return hosts
end

local RES = { { 640, 480 }, { 800, 600 }, { 854, 480 }, { 960, 720 }, { 1280, 720 } }
local function res_label(s) return (s.WIDTH or "?") .. "x" .. (s.HEIGHT or "?") end

local function cycle(vals, cur, d)
  local idx = 1
  for i, v in ipairs(vals) do if tostring(v) == tostring(cur) then idx = i end end
  return vals[(idx - 1 + d) % #vals + 1]
end

local function open_viewer(title, script, result, opts)
  opts = opts or {}
  viewer = { title = title, script = script, result = result, t = 0, text = "", pair = opts.pair, scroll = 0 }
  os.remove(Stream.DIR .. "/" .. result)
  Stream.run_job(script)
  S.mode = "viewer"
end

local function open_osk(label, key, allowed)
  osk = { label = label, key = key, text = Stream.s[key] or "", r = 1, c = 1 }
  S.mode = "osk"
end

local function items()
  local s = Stream.s
  local function text(label, key, hint) return { kind = "text", label = label, key = key, hint = hint } end
  local function choice(label, vals, get, set, fmt) return { kind = "choice", label = label, vals = vals, get = get, set = set, fmt = fmt } end
  local function key_choice(label, key, vals) return choice(label, vals, function() return s[key] end, function(v) return Stream.set(key, v) end) end
  return {
    text("PC address", "HOST", "IP or name of the PC running Sunshine"),
    text("Library port", "SYNC_PORT", "portal port, default 8765"),
    text("PC MAC", "MAC", "only for Wake-on-LAN, 12 hex digits"),
    choice("Resolution", RES,
      function() return res_label(s) end,
      function(v) return Stream.set_many({ WIDTH = v[1], HEIGHT = v[2] }) end,
      function(v) return type(v) == "table" and (v[1] .. "x" .. v[2]) or tostring(v) end),
    key_choice("Frame rate", "FPS", { "30", "45", "60" }),
    key_choice("Bitrate (kbps)", "BITRATE", { "5000", "8000", "10000", "15000", "20000", "30000" }),
    key_choice("Codec", "CODEC", { "auto", "h264", "h265" }),
    key_choice("Network", "REMOTE", { "auto", "yes", "no" }),
    key_choice("Optimise game settings", "SOPS", { "yes", "no" }),
    { kind = "action", label = "Scan LAN + Tailscale", hint = "find Sunshine automatically", run = function() open_viewer("Sunshine discovery", "discover.sh", "discovery.txt") end },
    { kind = "action", label = "Pair with PC", hint = "type the PIN on the PC", run = function() open_viewer("Pair with PC", "pair.sh", "pair.log", { pair = true }) end },
    { kind = "action", label = "Sync library", hint = "games and covers from the PC", run = function() open_viewer("Sync library", "sync.sh", "sync.status") end },
    { kind = "action", label = "Test connection", run = function() open_viewer("Connection test", "test.sh", "test.txt") end },
    { kind = "action", label = "Wake PC", hint = "Wake-on-LAN", run = function() open_viewer("Wake PC", "wake.sh", "wake.txt") end },
    { kind = "action", label = "Latency (ping)", run = function() open_viewer("Latency", "latency.sh", "latency.txt") end },
    { kind = "action", label = "Sunshine apps", hint = "what the PC offers", run = function() open_viewer("Sunshine apps", "sunshine_verify.sh", "sunshine_verify.txt") end },
    { kind = "action", label = "Disk space", run = function() open_viewer("Disk space", "diskspace.sh", "diskspace.txt") end },
    { kind = "action", label = "Diagnostics report", hint = "token and MAC are hidden", run = function() open_viewer("Diagnostics", "diagnostics.sh", "diagnostics.txt") end },
  }
end

function S.enter()
  K.set_accent("wii"); t = 0; S.mode = "list"
  Stream.init()
  S.list:set(items(), true)
end
function S.leave() if viewer and viewer.pair then Stream.kill_pair() end end

function S.update(dt)
  t = t + dt; S.list:update(dt)
  if S.mode == "hosts" then S.host_list:update(dt) end
  if S.mode == "viewer" and viewer then
    viewer.t = viewer.t + dt
    local d = Stream.read(Stream.DIR .. "/" .. viewer.result)
    if d then viewer.text = d end
    viewer.done = Stream.job_done()
    if viewer.done and viewer.script == "discover.sh" and not viewer.discovery_handled then
      viewer.discovery_handled = true
      local host = Stream.read(Stream.DIR .. "/discovered_host.txt")
      host = host and host:gsub("%s+", "") or ""
      if host ~= "" then
        local ok, err = Stream.set("HOST", host)
        if ok then
          Notify.show("success", "Sunshine found at " .. host .. " — pairing…", 3)
          open_viewer("Pair with detected PC", "pair.sh", "pair.log", { pair = true })
        else
          Notify.show("error", "Could not save detected host: " .. tostring(err))
        end
      else
        S.hosts = read_discovered_hosts()
        if #S.hosts > 1 then
          S.host_list:set(S.hosts, true)
          S.mode = "hosts"
          Notify.show("info", tostring(#S.hosts) .. " Sunshine hosts found — choose one")
        end
      end
    end
  end
end

-- ── on-screen keyboard ──────────────────────────────────────
local ROWS = { "1234567890", "qwertyuiop", "asdfghjkl-", "zxcvbnm.:_", "ABCDEF" }

local function osk_pad(b)
  if b == "UP" then osk.r = (osk.r - 2) % #ROWS + 1
  elseif b == "DOWN" then osk.r = osk.r % #ROWS + 1
  elseif b == "LEFT" then osk.c = osk.c - 1
  elseif b == "RIGHT" then osk.c = osk.c + 1
  elseif b == "A" then
    local row = ROWS[osk.r]; local ch = row:sub(osk.c, osk.c)
    if ch ~= "" and #osk.text < 60 then osk.text = osk.text .. ch; SFX.play("menu_move") end
  elseif b == "B" then
    if osk.text == "" then S.mode = "list" else osk.text = osk.text:sub(1, -2) end
  elseif b == "Y" then osk.text = ""
  elseif b == "START" then
    local ok, err = Stream.set(osk.key, osk.text)
    if ok then Notify.show("success", osk.label .. " saved", 1.2); S.list:set(items(), true) else Notify.show("error", tostring(err)) end
    S.mode = "list"
  elseif b == "SELECT" then S.mode = "list" end
  local n = #ROWS[osk.r]
  if osk.c < 1 then osk.c = n elseif osk.c > n then osk.c = 1 end
end

local function draw_osk()
  K.header(osk.label, "A type   B delete   Y clear   START save", nil, { accent = K.ACC.wii })
  K.panel(K.MARGIN, 86, K.W - K.MARGIN * 2, 44, { accent = K.ACC.wii, cut = 8 })
  K.text("body", osk.text .. ((math.floor(t * 2) % 2 == 0) and "_" or " "), K.MARGIN + 14, 98, K.C.text)
  local cw, ch, y0 = 52, 50, 150
  for r, row in ipairs(ROWS) do
    local x0 = (K.W - #row * cw) / 2
    for c = 1, #row do
      local x, y = x0 + (c - 1) * cw, y0 + (r - 1) * ch
      local f = (r == osk.r and c == osk.c)
      K.panel(x + 2, y + 2, cw - 4, ch - 4, { focus = f, force = true, accent = K.ACC.wii, cut = 5 })
      K.text("body", row:sub(c, c), x, y + 12, f and K.C.text or K.C.dim, 1, cw, "center")
    end
  end
  K.footer({ { key = "A", label = "Type" }, { key = "B", label = "Delete" }, { key = "Y", label = "Clear" }, { key = "START", label = "Save" }, { key = "SELECT", label = "Cancel" } })
end

-- ── viewer ──────────────────────────────────────────────────
local function draw_viewer()
  K.header(viewer.title, viewer.done and "done" or "working...", nil, { accent = K.ACC.wii })
  K.panel(K.MARGIN, 86, K.W - K.MARGIN * 2, K.BOT - 86, { accent = K.ACC.wii, cut = 10 })
  local txt = viewer.text ~= "" and viewer.text or "..."
  if viewer.pair then
    local pin = txt:match("PIN[^%d]*(%d%d%d%d)")
    if pin then
      K.text("small", "Type this PIN on the PC (Sunshine web UI > PIN):", K.MARGIN + 18, 98, K.C.dim)
      K.text("title", pin, K.MARGIN + 18, 120, K.ACC.boost)
    end
  end
  lg.setScissor(K.MARGIN + 8, 168, K.W - K.MARGIN * 2 - 16, K.BOT - 178)
  K.para("small", txt, K.MARGIN + 18, 172 - viewer.scroll, K.W - K.MARGIN * 2 - 36, K.C.text)
  lg.setScissor()
  if not viewer.done then
    for i = 0, 2 do K.color(K.ACC.wii, 0.3 + 0.7 * (((t * 3 - i * 0.4) % 1))); lg.circle("fill", K.W - 60 + i * 14, 40, 4) end
  end
  K.footer({ { key = "B", label = "Back" }, { key = "UP/DOWN", label = "Scroll" } })
end

-- ── list ────────────────────────────────────────────────────
local function value_of(it)
  local s = Stream.s
  if it.kind == "text" then local v = s[it.key]; return (v and v ~= "") and v or "not set" end
  if it.kind == "choice" then return it.fmt and it.fmt(it.get()) or tostring(it.get()) end
end

local function change(it, d)
  if it.kind ~= "choice" then return end
  local cur = it.get()
  local nv
  if it.fmt then -- table values: find by label
    local idx = 1
    for i, v in ipairs(it.vals) do if it.fmt(v) == cur then idx = i end end
    nv = it.vals[(idx - 1 + d) % #it.vals + 1]
  else nv = cycle(it.vals, cur, d) end
  local ok, err = it.set(nv)
  if ok == false then return false, err or "could not persist Stream setting" end
  SFX.play("menu_move")
  return true
end

-- NEXUS adapter: expose the existing Stream Settings behavior without
-- returning connection identifiers or secret material to external callers.
function S.register_actions(ui)
  if not ui or type(ui.register_action) ~= "function" then
    return false, "UI action registrar unavailable"
  end

  local function selected()
    return S.list and S.list:cur() or nil
  end
  local function refresh_list(keep)
    local index = keep or (S.list and S.list.sel) or 1
    S.list:set(items(), true)
    S.list.sel = math.max(1, math.min(index, math.max(1, #S.list.items)))
    if S.list._aim then S.list:_aim(true) end
  end

  local specs = {
    {
      id = "stream_settings.select", title = "Select Stream setting", order = 10,
      run = function(index)
        if S.mode ~= "list" then return false, "settings list is not active" end
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #S.list.items then
          return false, "Stream setting index out of range"
        end
        S.list.sel = index
        S.list:_aim(true)
        return true
      end,
    },
    {
      id = "stream_settings.change_selected", title = "Change selected Stream choice", order = 20,
      run = function(direction)
        if S.mode ~= "list" then return false, "settings list is not active" end
        if direction ~= -1 and direction ~= 1 then return false, "direction must be -1 or 1" end
        local row = selected()
        if not row or row.kind ~= "choice" then return false, "selected row is not a choice" end
        local ok, changed, detail = pcall(change, row, direction)
        if not ok then return false, tostring(changed) end
        if changed == false then return false, tostring(detail or "could not change Stream setting") end
        return true
      end,
    },
    {
      id = "stream_settings.set_text", title = "Set Stream connection field", order = 30,
      run = function(key, value)
        if S.mode ~= "list" then return false, "settings list is not active" end
        if key ~= "HOST" and key ~= "SYNC_PORT" and key ~= "MAC" then
          return false, "only HOST, SYNC_PORT and MAC are writable text fields"
        end
        if type(value) ~= "string" then return false, "value must be a string" end
        value = value:match("^%s*(.-)%s*$")
        if #value > 253 then return false, "value is too long" end
        if key == "HOST" then
          if value == "" or not value:match("^[%w%.%-:]+$") then return false, "invalid PC address" end
        elseif key == "SYNC_PORT" then
          local port = tonumber(value)
          if not port or port % 1 ~= 0 or port < 1 or port > 65535 then
            return false, "port must be an integer from 1 to 65535"
          end
        elseif key == "MAC" and value ~= "" then
          local compact = value:gsub("[:-]", "")
          if #compact ~= 12 or not compact:match("^%x+$") then
            return false, "MAC must contain 12 hexadecimal digits"
          end
        end
        local ok, err = Stream.set(key, value)
        if not ok then return false, tostring(err or "could not save Stream setting") end
        refresh_list()
        return true
      end,
    },
    {
      id = "stream_settings.open_text_editor", title = "Open Stream text editor", order = 40,
      run = function()
        if S.mode ~= "list" then return false, "settings list is not active" end
        local row = selected()
        if not row or row.kind ~= "text" then return false, "selected row is not a text field" end
        open_osk(row.label, row.key)
        return true
      end,
    },
    {
      id = "stream_settings.run_selected", title = "Run selected Stream tool", order = 50,
      run = function()
        if S.mode ~= "list" then return false, "settings list is not active" end
        local row = selected()
        if not row or row.kind ~= "action" or type(row.run) ~= "function" then
          return false, "selected row is not a Stream tool"
        end
        local ok, err = pcall(row.run)
        if not ok then return false, tostring(err) end
        return true
      end,
    },
    {
      id = "stream_settings.cancel_mode", title = "Return to Stream settings list", order = 60,
      run = function()
        if S.mode == "list" then return false, "settings list is already active" end
        if S.mode == "viewer" and viewer and viewer.pair then Stream.kill_pair() end
        S.mode = "list"
        return true
      end,
    },
    {
      id = "stream_settings.state", title = "Get redacted Stream settings state", order = 70,
      run = function()
        local row = selected()
        return {
          mode = S.mode,
          configured = Stream.configured(),
          host_is_set = Stream.s.HOST ~= nil and Stream.s.HOST ~= "",
          selected_label = row and row.label or nil,
          selected_kind = row and row.kind or nil,
          viewer_title = viewer and viewer.title or nil,
          viewer_done = viewer and viewer.done == true or false,
          osk_label = osk and osk.label or nil,
        }
      end,
    },
  }

  for _, spec in ipairs(specs) do
    local ok, err = ui.register_action(spec.id, spec.run, {
      title = spec.title, group = "stream", order = spec.order, screen = "stream_settings",
    })
    if not ok then return false, err or ("could not register " .. spec.id) end
  end
  return true
end

function S.pad(b)
  if S.mode == "osk" then return osk_pad(b) end
  if S.mode == "hosts" then
    local row = S.host_list:cur()
    if b == "UP" then S.host_list:move(-1)
    elseif b == "DOWN" then S.host_list:move(1)
    elseif b == "A" and row then
      local ok, err = Stream.set("HOST", row.host)
      if ok then
        Notify.show("success", "Sunshine found at " .. row.host .. " — pairing…", 3)
        open_viewer("Pair with detected PC", "pair.sh", "pair.log", { pair = true })
      else
        Notify.show("error", "Could not save detected host: " .. tostring(err))
      end
    elseif b == "B" then S.mode = "list" end
    return
  end
  if S.mode == "viewer" then
    if b == "B" then if viewer.pair then Stream.kill_pair() end S.mode = "list"; Stream.check_health()
    elseif b == "DOWN" then viewer.scroll = viewer.scroll + 40
    elseif b == "UP" then viewer.scroll = math.max(0, viewer.scroll - 40) end
    return
  end
  local it = S.list:cur()
  if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
  elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
  elseif b == "LEFT" then change(it, -1)
  elseif b == "RIGHT" then change(it, 1)
  elseif b == "A" and it then
    SFX.play("menu_select")
    if it.kind == "text" then open_osk(it.label, it.key)
    elseif it.kind == "choice" then change(it, 1)
    elseif it.kind == "action" then it.run() end
  elseif b == "B" or b == "START" then require("ui").back()
  end
end

function S.draw()
  K.bg()
  if S.mode == "osk" then return draw_osk() end
  if S.mode == "viewer" then return draw_viewer() end
  if S.mode == "hosts" then
    K.header("SELECT SUNSHINE HOST", "LAN · TAILSCALE", nil, { accent = K.ACC.wii })
    S.host_list:draw(function(row, x, y, w, h, focused)
      K.panel(x, y + 2, w, h - 4, { focus = focused, accent = K.ACC.wii, cut = 6 })
      K.text("body", row.host, x + 16, y + h / 2 - 10, focused and K.C.text or K.C.dim)
      local label = row.source or "LAN"
      K.text("small", label, x + w - K.width("small", label) - 16, y + h / 2 - 8, K.ACC.wii)
    end)
    K.footer({ { key = "A", label = "Pair with PC" }, { key = "B", label = "Back" } })
    return
  end
  K.header("STREAM SETTINGS", Stream.configured() and ("PC " .. Stream.s.HOST) or "set the PC address to begin", nil, { accent = K.ACC.wii })
  S.list:draw(function(it, x, y, w, h, focused)
    K.text("body", it.label, x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
    local right = x + w - 14
    if it.kind == "action" then
      K.text("small", it.hint or "", right - K.width("small", it.hint or ""), y + h / 2 - 8, K.C.faint)
    else
      local v = value_of(it)
      local col = (it.kind == "text" and v == "not set") and K.C.faint or K.ACC.wii
      K.text("body", v, right - K.width("body", v), y + h / 2 - 9, col)
    end
  end)
  K.footer({ { key = "A", label = "Edit/Run" }, { key = "L/R", label = "Change" }, { key = "B", label = "Back" } })
end

return S
