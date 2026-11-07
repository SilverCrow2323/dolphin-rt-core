package.path = "./?.lua;" .. package.path
local L = require("core.stream_lib")
local n = 0
local function ok(c, m) n = n + 1; if not c then error("FAIL: " .. m, 2) end end
local g = L.parse_library("# h\ngc\tMetroid Prime\tGC - Metroid Prime\tcovers/M.png\tGM8P01\t/x\nwii\tXeno\tWii - Xeno\t-\tSX4E01\t/y\nps2\tNope\tA\t-\t-\t-\ngc\tEvil\tbad\1name\t-\t-\t-\ngc\tEsc\tGC - Esc\t../../etc/passwd\tID\t-\n")
ok(#g == 3, "3 valid rows, got " .. #g)
ok(L.valid_app("GC - Zelda: The Wind Waker (2)") and L.valid_app("Wii - Mario & Luigi's Pok\195\169mon") and not L.valid_app("a\"b") and not L.valid_app("a\nb"), "real titles accepted, control chars refused")
ok(g[1].cover == "M.png" and g[1].kind == "gc", "cover prefix stripped")
ok(g[2].cover == nil and g[2].kind == "wii", "dash cover")
ok(g[3].cover == nil, "path escape cover rejected")
local s = L.parse_conf('HOST="100.1.2.3"\nFPS="30"\nBITRATE="a;b"\n')
ok(s.HOST == "100.1.2.3" and s.FPS == "30" and s.BITRATE == "10000", "conf parse + reject bad value")
local s2 = L.parse_conf(L.serialize_conf(s)); ok(s2.HOST == "100.1.2.3" and s2.FPS == "30", "conf roundtrip")
local st = L.parse_stats(L.serialize_stats({ ["GC - A"] = { plays = 3, last = 99, fav = true } }))
ok(st["GC - A"].plays == 3 and st["GC - A"].fav, "stats roundtrip")
local a = L.moonlight_args({ BITRATE = "999999999", WIDTH = "640", HEIGHT = "480", FPS = "60", CODEC = "av1", REMOTE = "auto", SOPS = "no" }, "GC - A", "/k")
ok(a[1] == "stream" and a[3] == "GC - A" and a[7] == "150000" and a[#a] == "-nosops", "moonlight args clamp")
ok(L.ago(0, 1800000000) == "never played" and L.ago(1800000000 - 7200, 1800000000) == "2 h ago", "ago")
print("stream_lib: " .. n .. " checks OK")
