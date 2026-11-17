-- Rt:System Status Center behaviour: snapshots, navigation, scrolling and history actions.
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local calls = {removed = {}, cleared_active = 0, cleared_history = 0}
local history = {}
for i = 1, 18 do
    history[i] = {
        id = "notice_" .. tostring(i),
        kind = (i % 2 == 0) and "success" or "info",
        title = "Notification " .. tostring(i),
        subtitle = "Status center fixture entry " .. tostring(i),
        ts = os.time() - i,
    }
end

package.loaded["ui.sfx"] = {play = function() end}
package.loaded["ui.icons"] = {draw = function() end}
package.loaded["ui.theme.fonts"] = {
    get = function(_, size)
        return {getWidth = function(_, text) return #(tostring(text or "")) * (size or 10) * 0.55 end}
    end,
}
package.loaded["core.notification_hub"] = {
    history = function() return history end,
    remove_history = function(id)
        calls.removed[#calls.removed + 1] = id
        for i, entry in ipairs(history) do
            if entry.id == id then table.remove(history, i); return true end
        end
        return false
    end,
    clear_active = function() calls.cleared_active = calls.cleared_active + 1 end,
    clear_history = function()
        calls.cleared_history = calls.cleared_history + 1
        history = {}
    end,
    push = function() end,
}

package.loaded["ui.statusbar"] = {
    snapshot = function()
        return {
            checked = true,
            wifi = {up = true, quality = 0.8, ssid = "RtCore-Test"},
            battery = {present = true, level = 78, charging = false},
        }
    end,
}
package.loaded["core.boot_initializer"] = {
    snapshot = function()
        return {
            step = "done",
            databases = {
                games_data = {state = "updated", size = 120000},
                gamesettings_json = {state = "cached", size = 240000},
                rtcheats_db = {state = "retained", size = 90000},
            },
            gamesets = {status = "complete", deployed = 6},
            cheats = {status = "complete"},
            roms = 18,
            cards = 18,
        }
    end,
}
package.loaded["core.stream"] = {
    s = {HOST = "test-host"},
    health = {library = "ok", sunshine = "fail", pending = false},
    configured = function() return true end,
    check_health = function() end,
    poll_health = function() end,
}
package.loaded["core.library"] = {games = {}}

local Panel = require("ui.system_panel")
Panel.init()
Panel.open()

local function status(name)
    for _, item in ipairs(Panel._items) do
        if item.kind == "status" and item.title == name then return item end
    end
end

assert(status("Portal Library").status == "ONLINE", "Portal success state is visible")
assert(status("Sunshine").status == "OFFLINE", "Sunshine failure state is visible")
assert(status("Compatibility Database").status == "UPDATED", "fresh database status is visible")
assert(status("GameSettings Database").status == "CACHED", "cached GameSettings status is visible")
assert(status("Cheats & Boost Database").status == "PREVIOUS COPY", "retained database status is visible")
assert(status("GameSettings Deployment").status == "READY", "GameSettings deployment result is visible")
assert(status("Games Library").status == "INDEXED", "completed boot scan reports library indexed")
assert(Panel._items[2].left.status == "CONNECTED", "Wi-Fi link is separate from server health")
assert(Panel._items[2].left.detail:find("RtCore%-Test"), "Wi-Fi SSID is displayed")

Panel.operation_start("compat-db", "Compatibility Database", {progress = 0.5, detail = "Receiving fixture"})
local operation
for _, item in ipairs(Panel._items) do
    if item.kind == "operation" and item.op.id == "compat-db" then operation = item; break end
end
assert(operation and operation.op.progress == 0.5, "background operation is included")

Panel._viewport_h = 120
assert(Panel._content_h > Panel._viewport_h, "content exceeds the panel viewport")
Panel.pad("RIGHT")
assert(Panel._scroll > 0, "horizontal navigation scrolls the panel by a page")

local notification_focus
for position, item_index in ipairs(Panel._focus) do
    if Panel._items[item_index].kind == "notification" then
        notification_focus = position
        break
    end
end
assert(notification_focus, "notification history rows are focusable")
Panel._sel = notification_focus
local selected_id = Panel._items[Panel._focus[Panel._sel]].entry.id
Panel.pad("A")
assert(calls.removed[1] == selected_id, "A removes the selected history entry")
assert(#history == 17, "history count decreases after dismissal")

Panel.pad("X")
assert(calls.cleared_active == 1, "X clears active toasts")
assert(calls.cleared_history == 1 and #history == 0, "X clears the history")
Panel.pad("B")
assert(not Panel.is_open(), "B closes the status center")

print("Rt:System Status Center behaviour: all checks passed")
