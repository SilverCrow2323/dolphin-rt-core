-- ui/screens/triage.lua — Rt:Core Env Triage (v2).
--
-- One glance tells whether the three layers of Dolphin Rt:Core are really
-- installed:   I Comfort Zone · II Bash Arsenal · III FrontendONE (this app).
--
--   ┌ cards (UP/DOWN, L1/R1) ┐ ┌ checklist of the selected flavour (A) ┐
--   │ I   Comfort Zone  OK   │ │ ✓ Emulator folder   … path / hint     │
--   │ II  Bash Arsenal  !    │ └───────────────────────────────────────┘
--   │ III FrontendONE   OK   │ ┌ numbers: ROMs · size · free · content ┐
--   ├ verdict ring + next fix┤ └───────────────────────────────────────┘
--
-- The scan is incremental (core.rtcore_triage): the screen keeps animating
-- and the card states appear one by one as soon as each step is finished.
--   A inspect checks · X save report · Y rescan · B back

local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local Triage = require("core.rtcore_triage")

local S = {}
S.job, S.t = nil, 0
S.sel, S.csel, S.mode = 1, 1, "cards"      -- mode: cards | checks
S.shown = 0                                -- smoothed score for the ring
S.report_path = nil

local function start_scan()
    S.job = Triage.begin()
    S.shown = 0
    S.step_clock = 0
    S.report_path = nil
end

function S.enter()
    S.t, S.mode, S.sel, S.csel = 0, "cards", 1, 1
    K.set_accent("teal")
    start_scan()
end

function S.update(dt)
    S.t = S.t + dt
    local j = S.job
    if j and not j.done then
        S.step_clock = S.step_clock + dt
        -- ~12 steps/s: fast enough, slow enough to be *seen* working
        if S.step_clock >= 0.07 then
            S.step_clock = 0
            Triage.step(j)
            if j.done then SFX.play(j.verdict == "HEALTHY" and "menu_select" or "notif_general") end
        end
    end
    local target = (j and j.done) and (j.score or 0) or 0
    S.shown = S.shown + (target - S.shown) * math.min(1, dt * 5)
end

local function flavour() return S.job and S.job.flavours[S.sel] end

-- NEXUS adapters expose the incremental triage lifecycle and report operation.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local specs = {
        { id = "triage.rescan", title = "Rescan Rt:Core environment", order = 10,
          run = function()
              start_scan(); S.mode = "cards"; S.sel = 1; S.csel = 1
              SFX.play("menu_toggleoption")
              return true
          end },
        { id = "triage.select_flavour", title = "Select triage flavour", order = 20,
          run = function(index)
              if type(index) ~= "number" or index % 1 ~= 0 then return false, "flavour index must be an integer" end
              local count = S.job and #S.job.flavours or 0
              if index < 1 or index > count then return false, "flavour index out of range" end
              S.sel, S.csel = index, 1
              return true
          end },
        { id = "triage.inspect", title = "Inspect selected flavour checks", order = 30,
          run = function()
              if not S.job or not S.job.done then return false, "triage scan is not complete" end
              S.mode = (S.mode == "cards") and "checks" or "cards"
              S.csel = 1
              SFX.play("menu_select")
              return true
          end },
        { id = "triage.select_check", title = "Select a triage check", order = 40,
          run = function(index)
              if S.mode ~= "checks" then return false, "check list is not active" end
              local fl = flavour()
              if not fl or type(index) ~= "number" or index % 1 ~= 0
                  or index < 1 or index > #fl.checks then
                  return false, "check index out of range"
              end
              S.csel = index
              return true
          end },
        { id = "triage.save_report", title = "Save triage report", order = 50,
          run = function()
              if not S.job or not S.job.done then return false, "triage scan is not complete" end
              local ok, path = pcall(Triage.save_report, S.job)
              if not ok or type(path) ~= "string" or path == "" then
                  return false, tostring(path or "could not write triage report")
              end
              S.report_path = path
              require("ui.notify").show("success", "Report saved: " .. path, 3.5)
              SFX.play("menu_select")
              return true, path
          end },
        { id = "triage.state", title = "Get triage state", order = 60,
          run = function()
              local job, fl = S.job, flavour()
              local check = (S.mode == "checks" and fl and fl.checks[S.csel]) or nil
              return { done = job and job.done == true or false,
                  progress = job and Triage.progress(job) or 0,
                  verdict = job and job.verdict or nil,
                  selected_flavour = fl and fl.id or nil,
                  mode = S.mode, selected_check = check and check.label or nil,
                  report_path = S.report_path }
          end },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "triage", order = spec.order, screen = "triage",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

function S.pad(b)
    local j = S.job
    if b == "START" or (b == "B" and S.mode == "cards") then
        require("ui").back(); return
    elseif b == "B" then
        S.mode = "cards"; SFX.play("menu_back"); return
    elseif b == "Y" then
        start_scan(); S.mode = "cards"; SFX.play("menu_toggleoption"); return
    elseif b == "X" then
        if j and j.done then
            S.report_path = Triage.save_report(j)
            require("ui.notify").show(S.report_path and "success" or "error",
                S.report_path and ("Report saved: " .. S.report_path) or "Could not write the report", 3.5)
            SFX.play("menu_select")
        end
        return
    elseif b == "A" then
        if j and j.done then
            S.mode = (S.mode == "cards") and "checks" or "cards"; S.csel = 1
            SFX.play("menu_select")
        end
        return
    end
    local n = j and #j.flavours or 0
    if n == 0 then return end
    if b == "L1" or (b == "UP" and S.mode == "cards") then
        S.sel = (S.sel - 2) % n + 1; S.csel = 1; SFX.play("menu_move")
    elseif b == "R1" or (b == "DOWN" and S.mode == "cards") then
        S.sel = S.sel % n + 1; S.csel = 1; SFX.play("menu_move")
    elseif S.mode == "checks" then
        local m = #flavour().checks
        if b == "UP"   then S.csel = (S.csel - 2) % m + 1; SFX.play("menu_move")
        elseif b == "DOWN" then S.csel = S.csel % m + 1;   SFX.play("menu_move") end
    end
end

-- ── small vector glyphs (the font has no check/cross) ──────────────
local function g_check(x, y, c, a)
    K.color(c, a or 1); love.graphics.setLineWidth(2.4)
    love.graphics.line(x - 5, y, x - 1.5, y + 4, x + 5.5, y - 4.5)
    love.graphics.setLineWidth(1)
end
local function g_cross(x, y, c, a)
    K.color(c, a or 1); love.graphics.setLineWidth(2.4)
    love.graphics.line(x - 4, y - 4, x + 4, y + 4); love.graphics.line(x + 4, y - 4, x - 4, y + 4)
    love.graphics.setLineWidth(1)
end
local function g_dots(x, y, c, t)
    for i = 0, 2 do
        K.color(c, 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 7 - i * 1.2)))
        love.graphics.circle("fill", x - 6 + i * 6, y, 2)
    end
end

local function tail_clip(kind, str, maxw)
    local f = K.font(kind)
    if f:getWidth(str) <= maxw then return str end
    local lo = 1
    while lo < #str and f:getWidth("…" .. str:sub(lo)) > maxw do lo = lo + 1 end
    while lo < #str and str:byte(lo) and str:byte(lo) >= 0x80 and str:byte(lo) < 0xC0 do lo = lo + 1 end
    return "…" .. str:sub(lo)
end

local ACC_OF = { gc = "gc", boost = "boost", wii = "wii" }
local function fl_accent(fl) return K.ACC[ACC_OF[fl.accent] or "gc"] end
local function state_col(st)
    if st == "ok" then return K.C.ok elseif st == "partial" then return K.C.warn end
    return K.C.bad
end
local STATE_WORD = { ok = "READY", partial = "PARTIAL", missing = "MISSING" }

-- ── header ──────────────────────────────────────────────────
local function draw_header()
    K.header("Rt:Core Env Triage", "Flavour I · II · III — is everything installed?", nil, { icon = "info" })
    local j = S.job
    if j and not j.done then          -- progress line riding on the header rule
        local m = K.MARGIN
        K.color(K.C.line, 0.5); love.graphics.rectangle("fill", m, 68, K.W - 2 * m, 3)
        K.color(K.acc, 1);      love.graphics.rectangle("fill", m, 68, (K.W - 2 * m) * Triage.progress(j), 3)
    end
end

-- ── left: flavour cards ─────────────────────────────────────
local CARD_X, CARD_W, CARD_H, CARD_Y0, CARD_GAP = 24, 296, 64, 86, 8

local function draw_card(i, fl)
    local x, y = CARD_X, CARD_Y0 + (i - 1) * (CARD_H + CARD_GAP)
    local focus = (i == S.sel)
    local acc   = fl_accent(fl)
    local done  = fl.state ~= nil
    K.panel(x, y, CARD_W, CARD_H, { focus = focus, accent = acc, force = true, cut = 10 })

    -- Roman numeral plate
    local cx, cy = x + 34, y + CARD_H / 2
    K.color(acc, focus and 0.28 or 0.14); love.graphics.circle("fill", cx, cy, 22)
    K.color(acc, focus and 1 or 0.7); love.graphics.setLineWidth(1.6)
    love.graphics.circle("line", cx, cy, 22); love.graphics.setLineWidth(1)
    K.text("h", fl.id, cx - 22, cy - 14, K.C.text, 1, 44, "center")

    K.text("h", fl.name, x + 66, y + 7, K.C.text)
    K.text("key", fl.tag, x + 66, y + 36, acc, 0.9)

    -- check segments (one per check)
    local sx = x + CARD_W - 14
    local segw, gap = 11, 3
    local total = #fl.checks
    for k = total, 1, -1 do
        local c = fl.checks[k]
        local sxk = sx - (total - k + 1) * (segw + gap) + gap
        local col, a
        if c.ok == nil then col, a = acc, 0.18 + 0.30 * (0.5 + 0.5 * math.sin(S.t * 6 - k))
        elseif c.ok then col, a = K.C.ok, 0.95
        else col, a = K.C.bad, 0.95 end
        K.color(col, a); love.graphics.rectangle("fill", sxk, y + CARD_H - 20, segw, 6, 2, 2)
    end

    -- status pill
    if done then
        K.pill(STATE_WORD[fl.state], x + CARD_W - 12, y + 18, state_col(fl.state), true)
    else
        g_dots(x + CARD_W - 30, y + 18, acc, S.t)
    end

    -- scan sweep on the card being processed
    local j = S.job
    if j and not j.done and not done then
        local sw = ((S.t * 220) % (CARD_W + 60)) - 30
        K.color(acc, 0.10); love.graphics.rectangle("fill", x + math.max(0, sw - 20), y + 2, 40, CARD_H - 4)
    end
end

-- ── left bottom: verdict ring ───────────────────────────────
local function draw_verdict()
    local x, y, w, h = 24, 318, 296, 118
    K.panel(x, y, w, h, { cut = 10 })
    local j = S.job
    local cx, cy, r = x + 60, y + h / 2, 38
    local done = j and j.done
    local col = done and (j.verdict == "HEALTHY" and K.C.ok or (j.verdict == "DEGRADED" and K.C.warn or K.C.bad)) or K.acc

    K.color(K.C.surf2, 1); love.graphics.setLineWidth(7)
    love.graphics.circle("line", cx, cy, r)
    local frac = done and S.shown or Triage.progress(j) * 0.0
    if not done then      -- spinner while scanning
        K.color(col, 1)
        love.graphics.arc("line", "open", cx, cy, r, S.t * 4, S.t * 4 + math.pi * 0.7, 20)
    elseif frac > 0.004 then
        K.color(col, 1)
        love.graphics.arc("line", "open", cx, cy, r, -math.pi / 2, -math.pi / 2 + 2 * math.pi * math.min(frac, 0.9999), 56)
    end
    love.graphics.setLineWidth(1)
    if done then
        K.text("h", math.floor(S.shown * 100 + 0.5) .. "%", cx - 40, cy - 14, K.C.text, 1, 80, "center")
    else
        K.text("h", math.floor(Triage.progress(j) * 100) .. "%", cx - 40, cy - 14, K.C.dim, 1, 80, "center")
    end

    local tx, tw = x + 118, w - 118 - 12
    if not done then
        K.text("key", "SCANNING", tx, y + 14, K.C.dim)
        K.text("h", K.clip("h", j.current or "…", tw), tx, y + 32, K.C.text)
        K.bar(tx, y + 68, tw, 6, Triage.progress(j), K.acc)
        return
    end
    K.text("key", "VERDICT", tx, y + 10, K.C.faint)
    K.text("h", j.verdict, tx, y + 24, col)
    K.text("small", j.pass .. " / " .. j.total .. " checks passed", tx, y + 50, K.C.dim)
    local fix = j.fixes and j.fixes[1]
    if fix then
        K.text("key", "FIX FIRST", tx, y + 72, fix.crit and K.C.bad or K.C.warn)
        K.text("small", K.clip("small", "F" .. fix.flavour .. " · " .. fix.label, tw), tx, y + 88, K.C.text)
    else
        K.text("small", K.clip("small", "All clear.", tw), tx, y + 76, K.C.ok)
    end
end

-- ── right top: checklist ────────────────────────────────────
local DX, DW, DY, DH = 332, 284, 86, 224
local function draw_detail()
    local fl = flavour(); if not fl then return end
    local acc = fl_accent(fl)
    K.panel(DX, DY, DW, DH, { cut = 10, accent = acc, focus = (S.mode == "checks"), force = true })
    K.text("h", "Flavour " .. fl.id, DX + 14, DY + 6, acc)
    K.text("small", K.clip("small", fl.blurb, DW - 28), DX + 14, DY + 30, K.C.dim)
    K.color(K.C.line, 0.6); love.graphics.rectangle("fill", DX + 12, DY + 52, DW - 24, 1)

    local rowh, y0 = 20, DY + 56
    for i, c in ipairs(fl.checks) do
        local y = y0 + (i - 1) * rowh
        local sel = (S.mode == "checks" and i == S.csel)
        if sel then K.color(acc, 0.20); love.graphics.rectangle("fill", DX + 8, y - 1, DW - 16, rowh, 4, 4) end
        if c.ok == nil then g_dots(DX + 24, y + 9, K.C.faint, S.t + i * 0.3)
        elseif c.ok then g_check(DX + 24, y + 9, K.C.ok)
        else g_cross(DX + 24, y + 9, K.C.bad) end
        K.text("small", K.clip("small", c.label, 150), DX + 42, y, c.ok == false and K.C.text or K.C.dim)
        local right = c.ok == nil and "…" or (c.ok and "found" or (c.noexec and "not +x" or "missing"))
        K.text("key", right, DX + 14, y + 2, c.ok and K.C.faint or (c.ok == nil and K.C.faint or K.C.bad), 1, DW - 28, "right")
    end

    -- info box for the highlighted (or first failing) check
    local focus_c = fl.checks[S.csel]
    if S.mode ~= "checks" then
        for _, c in ipairs(fl.checks) do if c.ok == false then focus_c = c; break end end
        if focus_c and focus_c.ok ~= false then focus_c = nil end
    end
    local iy = DY + DH - 44
    K.color(K.C.line, 0.6); love.graphics.rectangle("fill", DX + 12, iy, DW - 24, 1)
    if focus_c then
        if focus_c.ok == false then
            K.text("small", K.clip("small", focus_c.noexec and "Not executable — chmod +x" or (focus_c.hint or "Missing"), DW - 28),
                DX + 14, iy + 3, focus_c.crit and K.C.bad or K.C.warn)
        else
            K.text("small", focus_c.crit and "Required" or "Optional", DX + 14, iy + 3, K.C.ok)
        end
        K.text("mono", tail_clip("mono", focus_c.path, DW - 28), DX + 14, iy + 23, K.C.faint)
    else
        K.text("small", S.job.done and "All checks of this flavour passed." or "Scanning…", DX + 14, iy + 3, K.C.ok)
        K.text("key", "A: inspect the checks one by one", DX + 14, iy + 25, K.C.faint)
    end
end

-- ── right bottom: numbers ───────────────────────────────────
local function draw_stats()
    local x, y, w, h = DX, 318, DW, 118
    K.panel(x, y, w, h, { cut = 10 })
    local st = (S.job and S.job.stats) or {}
    local done = S.job and S.job.done
    local function v(x_) if x_ == nil then return done and "—" or "…" end return tostring(x_) end
    local free = st.sd_free_kb and Triage.human_kb(st.sd_free_kb) or nil
    local cells = {
        { "ROMS",        st.roms and (st.roms .. "  GC " .. (st.gc or 0) .. " · Wii " .. (st.wii or 0)) or nil },
        { "EMULATOR",    st.disk_kb and Triage.human_kb(st.disk_kb) or nil },
        { "SD FREE",     free },
        { "PROFILES",    st.profiles and (st.profiles .. " · " .. (st.gamesettings or 0) .. " game") or nil },
        { "CHEAT TITLES", st.cheats },
        { "RT:UI · CORE", st.ui_version and (st.ui_version .. " · " .. (st.core_version or "?")) or nil },
    }
    local cw, rh = (w - 24) / 2, 36
    for i, c in ipairs(cells) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local cx, cy = x + 12 + col * cw, y + 7 + row * rh
        K.text("key", c[1], cx, cy, K.C.faint)
        K.text("small", K.clip("small", v(c[2]), cw - 8), cx, cy + 14, c[2] and K.C.text or K.C.faint)
    end
end

function S.draw()
    K.bg()
    draw_header()
    if not S.job then return end
    for i, fl in ipairs(S.job.flavours) do draw_card(i, fl) end
    draw_verdict()
    draw_detail()
    draw_stats()
    local done = S.job.done
    K.footer({
        { key = "A", label = S.mode == "cards" and "Inspect" or "Cards" },
        { key = "X", label = "Report" },
        { key = "Y", label = "Rescan" },
        { key = "B", label = S.mode == "checks" and "Cards" or "Back" },
    })
end

return S
