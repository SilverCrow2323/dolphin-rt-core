-- ui/screens/about.lua — version, storage, last log lines.
local K = require("ui.kit")
local Mascot = require("ui.mascot")
local S = { t = 0, lines = {} }

local function sh(cmd)
    local p = io.popen(cmd .. " 2>/dev/null"); if not p then return "" end
    local o = p:read("*a") or ""; p:close(); return (o:gsub("%s+$", ""))
end

function S.enter()
    S.t = 0; K.set_accent("sys"); Mascot.load()
    local V = require("version")
    S.info = {
        { "Version", V.string .. "  " .. (V.codename or "") },
        { "Build", V.build or "?" },
        { "Core", (V.core or ""):gsub("^Dolphin Rt:Core for muOS %- ", "") },
        { "Games", tostring(#require("core.library").games) },
        { "Free space", sh("df -h . | awk 'NR==2{print $4\" free of \"$2}'") },
        { "Cheat index", (require("core.rtcheats").status().index.count or 0) .. " games" },
    }
    S.log = {}
    for l in (sh("tail -n 3 data/logs/ui.log")):gmatch("[^\n]+") do S.log[#S.log + 1] = l end
    S.launch_log = {}
    local newest = sh("ls -t data/logs/launch_*.log 2>/dev/null | head -1")
    S.launch_name = newest ~= "" and newest:match("[^/]+$") or nil
    if newest ~= "" then
        for l in (sh("tail -n 4 '" .. newest .. "'")):gmatch("[^\n]+") do S.launch_log[#S.launch_log + 1] = l end
    end
end
function S.leave() Mascot.release() end
function S.update(dt) S.t = S.t + dt end
function S.pad(b) if b == "B" or b == "A" then require("ui").back() end end

function S.draw()
    K.header("About", "Dolphin Rt:UI for muOS", nil)
    K.panel(K.MARGIN, 92, K.W - K.MARGIN * 2, 186, { cut = 12 })
    for i, row in ipairs(S.info) do
        local y = 104 + (i - 1) * 28
        K.text("small", row[1], K.MARGIN + 16, y, K.C.faint)
        K.text("body", K.clip("body", row[2], 290), K.MARGIN + 140, y - 2, K.C.text)
    end
    if Mascot.loaded() then Mascot.draw(Mascot.frame_at(S.t, 1), K.W - K.MARGIN - 92, 96, 0.9, 0.95) end
    K.panel(K.MARGIN, 288, K.W - K.MARGIN * 2, 142, { cut = 12 })
    K.text("key", "UI LOG", K.MARGIN + 16, 296, K.acc)
    if #S.log == 0 then K.text("small", "Clean — no UI errors logged.", K.MARGIN + 100, 294, K.C.ok)
    else for i, l in ipairs(S.log) do K.text("mono", K.clip("mono", l, 560), K.MARGIN + 16, 312 + (i - 1) * 14, K.C.dim) end end
    K.text("key", "LAST LAUNCH LOG  " .. (S.launch_name or "none"), K.MARGIN + 16, 358, K.acc)
    for i, l in ipairs(S.launch_log or {}) do
        K.text("mono", K.clip("mono", l, 560), K.MARGIN + 16, 374 + (i - 1) * 14, K.C.dim)
    end
    K.footer({ { key = "B", label = "Back" } })
end

return S
