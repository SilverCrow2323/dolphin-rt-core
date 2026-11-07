
Testing
1. dev.sh
Every invocation writes a detailed log to
.pclogs/dev_<YYYYMMDD>_<HHMMSS>_<cmd>.log. A symlink
.pclogs/latest.log always points to the newest log.

Subcommands
Command	Effect
./dev.sh run [WxH]	Launch LOVE at the given resolution (default 640x480)
./dev.sh check	Syntax-check every Lua file
./dev.sh clean	Rotate dev.sh and LOVE logs
./dev.sh shell	Open a shell in frontend/
./dev.sh logs	Tail the latest dev.sh log
Syntax check
./dev.sh check uses luajit -bl if available, otherwise
luac5.1 -p, otherwise luac -p. It walks every .lua file under
frontend/ and reports per-file failures.

Expected final line:

text
All N Lua files OK
If a file fails, the command prints the file path and the first
three lines of the error message.

2. Live launch
bash
./dev.sh run
Runs love . 640x480 with CWD set to frontend/. Close with
Escape or with the pad.

3. Log files
Path	Producer
.pclogs/dev_*.log	dev.sh
frontend/data/logs/launcher_*.log	launch.sh
frontend/data/logs/dolphinrtcore_*.log	Dolphin core
frontend/data/logs/frontend.log	LOVE restart from launch.sh
frontend/data/logs/crash_*.log	crash_handler.lua
4. Crash handler
crash_handler.lua installs a global error hook. On crash:

Writes data/logs/crash_<timestamp>.log with stack trace.

Surfaces the previous crash on the next boot (once).

Does NOT kill the app unless the crash is in love.load.

5. Manual test checklist
Before any commit touching UI or input:

./dev.sh check passes.

./dev.sh run boots to Nexus.

Flip theme GC ↔ Wii with SELECT.

Open and close every top-level panel.

Launch a ROM from the library.

Check the Live Menu opens (MENU + START).

Return to the frontend after exit.

Open the Download overlay with R2.

Open the Quick Guide with L2.

Open the Dashboard with START (or F8).

6. Data refresh check
Delete data/games_data.json.

Launch. First boot triggers boot_downloader.

Verify the file reappears at data/games_data.json within 30 s.

Verify the file is valid JSON (python3 -m json.tool).
