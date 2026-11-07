#!/bin/sh
# rtcheats_sync.sh [GAMEID ...] — download per-game cheat files.
#
# The cheat database is one <GAMEID>.ini per game, hosted in the
# Dolphin-Core-for-MuOS repo (data/database/cheats_db/). The UI passes the ids
# it needs (index ids from data/rtcheats_db.json); with no arguments every
# game flagged performance_boost in the index is fetched.
# Existing files are kept unless FORCE=1.
#
# Status for the UI is written to data/rtcheats_sync.status
#   state=running|ok|fail  msg=...  done=N  total=M  time=...
BASE="${RTCHEATS_URL:-https://raw.githubusercontent.com/SilverCrow2323/Dolphin-Core-for-MuOS/refs/heads/main/data/database/cheats_db}"
DIRS="data/cheats_db /opt/muos/share/emulator/dolphin/cheats_db workshop/db/cheats_db"
INDEX="data/rtcheats_db.json"
STATUS="data/rtcheats_sync.status"

mkdir -p data 2>/dev/null
status() { printf 'state=%s\nmsg=%s\ndone=%s\ntotal=%s\ntime=%s\n' "$1" "$2" "${3:-0}" "${4:-0}" "$(date +%s 2>/dev/null)" > "$STATUS"; }

# first writable destination (reuse a directory that already holds files)
DEST=""
for d in $DIRS; do
    if [ -d "$d" ] && touch "$d/.rtw" 2>/dev/null; then rm -f "$d/.rtw"; DEST="$d"; break; fi
done
if [ -z "$DEST" ]; then
    for d in $DIRS; do
        mkdir -p "$d" 2>/dev/null
        if touch "$d/.rtw" 2>/dev/null; then rm -f "$d/.rtw"; DEST="$d"; break; fi
    done
fi
[ -n "$DEST" ] || { status fail "no writable cheat directory"; exit 1; }

if command -v curl >/dev/null 2>&1; then
    getf() { curl -fsSL --max-time 30 -o "$2" "$1" 2>/dev/null; }
elif command -v wget >/dev/null 2>&1; then
    getf() { wget -q -T 30 -O "$2" "$1" 2>/dev/null; }
else
    status fail "neither curl nor wget found"; exit 1
fi

IDS="$*"
if [ -z "$IDS" ]; then
    [ -f "$INDEX" ] || { status fail "index $INDEX missing (needs one online boot)"; exit 1; }
    IDS="$(awk '/"gameid"/{gsub(/[",]/,"",$2);id=$2} /"performance_boost"/{gsub(/,/,"",$2);if($2=="true")print id}' "$INDEX")"
fi

total=0; for _i in $IDS; do total=$((total+1)); done
done_n=0; failed=0
status running "starting" 0 "$total"
for id in $IDS; do
    done_n=$((done_n+1))
    f="$DEST/$id.ini"
    if [ -f "$f" ] && [ -z "$FORCE" ]; then continue; fi
    status running "downloading $id" "$done_n" "$total"
    if getf "$BASE/$id.ini" "$f.part" && grep -q '^\[' "$f.part" 2>/dev/null; then
        mv -f "$f.part" "$f"
    else
        rm -f "$f.part"; failed=$((failed+1))
    fi
done

if [ "$failed" -gt 0 ] && [ "$failed" -ge "$total" ]; then status fail "offline or repo unreachable" "$done_n" "$total"
elif [ "$failed" -gt 0 ]; then status ok "done, $failed file(s) failed" "$done_n" "$total"
else status ok "done" "$done_n" "$total"; fi
