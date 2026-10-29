local M = {}
local JSON = require("core.json")
local sh   = require("core.sh")
M.REPO = "https://api.github.com/repos/SilverCrow2323/Dolphin-Core-for-MuOS/releases/latest"
M._cache = nil
function M.check_async(cb)
    if M._cache then cb(M._cache); return end
    os.execute("curl -fsSL -m 8 " .. sh.shq(M.REPO) .. " -o /tmp/rtcore_latest.json 2>/dev/null &")
    M._pending = cb
end
function M.poll()
    if not M._pending then return end
    local f = io.open("/tmp/rtcore_latest.json", "r")
    if not f then return end
    local txt = f:read("*a"); f:close()
    os.remove("/tmp/rtcore_latest.json")
    local ok, d = pcall(JSON.decode, txt)
    if ok and type(d) == "table" and d.tag_name then
        M._cache = { tag = d.tag_name, url = d.html_url, body = d.body or "" }
    else
        M._cache = { tag = "?", url = "", body = "" }
    end
    local cb = M._pending; M._pending = nil; cb(M._cache)
end
function M.latest() return M._cache end
return M
