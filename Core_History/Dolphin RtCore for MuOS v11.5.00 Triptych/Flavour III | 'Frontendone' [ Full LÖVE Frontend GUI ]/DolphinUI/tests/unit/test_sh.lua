package.path = "frontend/?.lua;frontend/?/init.lua;" .. package.path
local ok, sh = pcall(require, "sh")
if not ok then print("SKIP: sh non caricabile"); os.exit(0) end
assert(sh.shq("a'b") == "'a'\\''b'", "shq sbagliato su apostrofo")
assert(sh.shq(nil) == "''", "shq nil sbagliato")
assert(sh.shq("") == "''", "shq vuoto sbagliato")
print("OK: sh")
