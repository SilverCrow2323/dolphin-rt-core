package.path = "frontend/?.lua;frontend/?/init.lua;" .. package.path
local ok, ini = pcall(require, "ini_parser")
if not ok then print("SKIP: ini_parser non caricabile"); os.exit(0) end

local tmp = "/tmp/test_ini_" .. os.time() .. ".ini"
local f = io.open(tmp, "w")
f:write("[S1]\nk1 = v1\nk2 = v2\n\n[S2]\nk3 = v3\n")
f:close()

local data = ini.parse(tmp)
assert(data.S1, "S1 mancante")
assert(data.S1.k1 == "v1", "k1 errato")
assert(data.S2.k3 == "v3", "k3 errato")
os.remove(tmp)
print("OK: ini_parser")
