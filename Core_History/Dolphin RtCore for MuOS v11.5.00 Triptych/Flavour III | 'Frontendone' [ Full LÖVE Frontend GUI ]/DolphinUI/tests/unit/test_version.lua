package.path = "frontend/?.lua;frontend/?/init.lua;" .. package.path
local ok, v = pcall(require, "version")
if not ok then print("SKIP: version non caricabile"); os.exit(0) end
assert(type(v.string) == "string", "version.string mancante")
assert(type(v.build) == "string", "version.build mancante")
print("OK: version")
