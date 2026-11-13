-- Draw-contract regression for Compatibility List dynamic content.
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local function wrap(text, width)
    local max_chars = math.max(1, math.floor(width / 8))
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
        if current == "" then
            current = word
        elseif #current + 1 + #word <= max_chars then
            current = current .. " " .. word
        else
            lines[#lines + 1] = current
            current = word
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return width, lines
end

local font = {
    getWidth = function(_, value) return #tostring(value or "") * 8 end,
    getHeight = function() return 16 end,
    getWrap = function(_, value, width) return wrap(value, width) end,
}
local calls = {texts = {}, pills = {}, paragraphs = {}}
local K = {
    MARGIN = 24, BOT = 436, W = 640,
    C = {sys={},lime={},boost={},hot={},ok={},dim={},faint={},text={},warn={},line={},bad={}},
    ACC = {gc={},wii={},sys={},lime={},boost={},hot={}},
    font = function() return font end,
    width = function(_, value) return #tostring(value or "") * 8 end,
    clip = function(_, value, max_width)
        value = tostring(value or "")
        local max_chars = math.max(1, math.floor(max_width / 8))
        if #value <= max_chars then return value end
        return value:sub(1, math.max(1, max_chars - 1)) .. "…"
    end,
    color = function() end,
    panel = function() end,
    star = function() end,
    header = function() end,
    footer = function() end,
    set_accent = function() end,
}
function K.text(kind, value, x, y, color, alpha, limit, align)
    calls.texts[#calls.texts + 1] = {
        kind=kind, value=tostring(value or ""), x=x, y=y, limit=limit, align=align,
    }
end
function K.pill(value, right, center_y)
    local width = font:getWidth(value) + 14
    calls.pills[#calls.pills + 1] = {
        value=value, left=right-width, right=right, y=center_y,
    }
    return width + 6
end
function K.para(kind, value, x, y, width)
    local _, lines = font:getWrap(value, width)
    local height = #lines * font:getHeight()
    calls.paragraphs[#calls.paragraphs + 1] = {
        value=value, x=x, y=y, width=width, lines=#lines, height=height,
    }
    return height
end

local list = {}
function list:set(items)
    self.items, self.sel = items, 1
end
function list:cur() return self.items[self.sel] end
function list:update() end
function list:move(delta)
    self.sel = math.max(1, math.min(#self.items, self.sel + delta))
    return true
end
function list:page(delta) return self:move(delta * 5) end
function list:_aim() end
function list:draw(draw_row)
    local item = self:cur()
    if item then draw_row(item, self.x, self.y, self.w, self.ih, true) end
end

K.List = function(x, y, w, h, row_height)
    list.x, list.y, list.w, list.h, list.ih = x, y, w, h, row_height
    return list
end

love = { graphics = {
    circle=function() end, rectangle=function() end,
} }

local long_note = string.rep(
    "This compatibility test records sustained gameplay, shader behavior, audio timing and frame pacing under the selected profile. ",
    18)
local game = {
    id = "GABC01",
    title = "A Very Long Compatibility Title That Must Be Clipped Cleanly",
    system = "GameCube",
    region = "NTSC-Japan-Revision",
    playable_rank = 2,
    entries = {{norm = {note = long_note, rating = 4.5}}},
}
local Compat = {
    games = {game}, count = 1, error = nil,
    load = function() return true end,
    summary = function()
        return {
            play_label = "Playable (issues)", play_kind = "warn",
            boot_label = "Boots with intermittent audio and timing issues",
            boot_kind = "warn", has_fps = true, fps = "12–59",
            stars = 4.5, rating = 4.5, rating_text = "4.5 / 5", n = 28,
            profiles = string.rep("Performance, Speedhack, Balanced, ", 8),
            devices = string.rep("Anbernic RG35XX H, ", 10),
        }
    end,
}
local Library = {games = {{id=game.id,title=game.title,path="/roms/test.iso"}}}

package.preload["ui.kit"] = function() return K end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.util"] = function() return {} end
package.preload["core.compatibility"] = function() return Compat end
package.preload["core.library"] = function() return Library end

local Screen = require("ui.screens.compat_list")
Screen.enter()
Screen.draw()

assert(#calls.paragraphs == 1, "the selected entry's note should render once")
local note = calls.paragraphs[1]
local status
for _, item in ipairs(calls.texts) do
    if item.value == "In your library" then status = item end
end
assert(status, "ownership footer must remain visible")
assert(note.y + note.height <= status.y - 8,
       "long test notes must not overlap the ownership footer")

local last_badge = 0
for _, pill in ipairs(calls.pills) do
    last_badge = math.max(last_badge, pill.right)
end
local id_text
for _, item in ipairs(calls.texts) do
    if item.value == game.id then id_text = item end
end
assert(id_text and id_text.x >= last_badge + 8,
       "Game ID must not overlap the system/region badges")

local boot
for _, item in ipairs(calls.texts) do
    if item.value:find("Boots", 1, true) then boot = item end
end
assert(boot and boot.x + K.width("small", boot.value) <= 332 + (640 - 332 - 24) - 14,
       "boot/FPS line must remain inside the detail panel")

print("Compatibility List dynamic layout tests passed")
