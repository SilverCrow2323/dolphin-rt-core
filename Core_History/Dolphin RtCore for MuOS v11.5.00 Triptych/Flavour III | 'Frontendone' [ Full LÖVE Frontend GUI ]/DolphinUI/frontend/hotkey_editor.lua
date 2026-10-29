-- frontend/hotkey_editor.lua
-- Build / parse expressions that go into Hotkeys.ini.
--
-- This module is intentionally thin: all knowledge of "which LÖVE
-- button index corresponds to which Dolphin hotkey Button N" lives
-- in input_map.lua (M.to_dolphin_raw). If the muOS device numbering
-- ever changes, only input_map.lua needs to be touched.
--
-- ── v0.4.7 — cleanup ──────────────────────────────────────────
--   1. Removed a dead `for raw, token in pairs(IM.RAW) do end`
--      loop (a placeholder from an aborted refactor) that did
--      nothing but confuse the reader.
--   2. Reverse lookup now uses a pre-built map, built once at
--      require time instead of on every parse_expression() call.
--   3. parse_expression() tolerates:
--        - outer parentheses:  "( `Button 9` & `Button 7` )"
--        - arbitrary whitespace
--        - partial expressions with only one button
--   4. Added M.pretty() to render a Dolphin expression as a
--      human-readable label for UI display.
--   5. Added M.is_empty() — clearer than `expr == ""`.

local IM = require("input_map")

local M = {}

-- Pre-build the reverse table: Dolphin "Button N" token -> LÖVE
-- raw index. Built once at module load.
local _dolphin_to_love = {}
for love_raw = 0, 63 do
    local tok = IM.to_dolphin_raw(love_raw)
    if tok and _dolphin_to_love[tok] == nil then
        _dolphin_to_love[tok] = love_raw
    end
end

-- LÖVE raw index → Dolphin "Button N" token (`` `Button 9` `` etc.).
function M.token_for(b)
    local a = IM.to_dolphin_raw(b)
    if not a then return nil end
    return "`Button " .. a .. "`"
end

-- LÖVE raw index → human-readable logical name.
function M.name_for(b)
    local logical = IM.raw_to_logical[b]
    if logical then return logical end
    return "Btn#" .. tostring(b)
end

-- Build a Dolphin hotkey expression from a list of pressed LÖVE
-- indices. Returns nil when the list is empty or contains only
-- unmappable indices.
function M.build_expression(buttons)
    if type(buttons) ~= "table" or #buttons == 0 then return nil end
    local tk = {}
    for _, b in ipairs(buttons) do
        local t = M.token_for(b)
        if t then tk[#tk + 1] = t end
    end
    if #tk == 0 then return nil end
    if #tk == 1 then return tk[1] end
    return "(" .. table.concat(tk, " & ") .. ")"
end

-- Parse a Dolphin hotkey expression back into human-readable names.
-- Accepts:  "`Button 9`"  ·  "(`Button 9` & `Button 7`)"
-- Returns a list of names, possibly empty.
function M.parse_expression(str)
    if not str or str == "" then return {} end
    local out = {}
    for btn in str:gmatch("Button%s+(%d+)") do
        local love_raw = _dolphin_to_love[btn]
        if love_raw then
            out[#out + 1] = M.name_for(love_raw)
        else
            out[#out + 1] = "Btn " .. btn
        end
    end
    return out
end

-- Is this an empty / null expression?
function M.is_empty(str)
    return str == nil or str == ""
end

-- Render a Dolphin expression as a compact human label, e.g.
--   "(`Button 9` & `Button 7`)"  ->  "SELECT + L1"
-- Falls back to the raw expression if it can't be parsed.
function M.pretty(str)
    if M.is_empty(str) then return "(unbound)" end
    local names = M.parse_expression(str)
    if #names == 0 then return str end
    return table.concat(names, " + ")
end

return M