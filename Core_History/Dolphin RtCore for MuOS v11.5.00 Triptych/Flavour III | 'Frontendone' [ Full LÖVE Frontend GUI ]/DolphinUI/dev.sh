#!/usr/bin/env bash
# dev.sh — DolphinUI Development Console
# Fancy TUI with ASCII animation, menu, per-run logging.
#
# Invoked with an argument, it acts as a CLI:
#   dev.sh run|check|clean|logs|tokens|docs|audit
# Invoked with no argument, it shows the interactive TUI.

set -u

# ════════════════════════════════════════════════════════════════
#  Terminal detection: if not in a TTY, re-exec inside one.
# ════════════════════════════════════════════════════════════════
_ensure_terminal() {
  [ -t 0 ] && [ -t 1 ] && return 0

  local self
  self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  local inner="\"$self\" \"\$@\"; echo; echo 'Press Enter to close...'; read -r _"

  local term
  for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal \
              mate-terminal lxterminal alacritty kitty foot wezterm \
              terminator tilix xterm urxvt rxvt st; do
    command -v "$term" >/dev/null 2>&1 || continue
    case "$term" in
      gnome-terminal|xfce4-terminal|mate-terminal|terminator|tilix)
        exec "$term" -- bash -c "$inner" ;;
      konsole)
        exec "$term" -e bash -c "$inner" ;;
      wezterm)
        exec "$term" start -- bash -c "$inner" ;;
      *)
        exec "$term" -e bash -c "$inner" ;;
    esac
  done

  echo "No terminal emulator found. Run this script from a shell."
  exit 1
}
_ensure_terminal

# ════════════════════════════════════════════════════════════════
#  Paths + logging
# ════════════════════════════════════════════════════════════════
ROOT="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$ROOT/frontend"
LOG_DIR_GAME="$GAME_DIR/data/logs"
PC_LOGS="$ROOT/.pclogs"
mkdir -p "$PC_LOGS"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$PC_LOGS/dev_${TS}.log"
LATEST="$PC_LOGS/latest.log"

: > "$LOG_FILE"
ln -sf "$(basename "$LOG_FILE")" "$LATEST" 2>/dev/null || true

_finalize_log() {
  local rc=$?
  {
    echo
    echo "================================================================"
    echo "  END OF LOG"
    printf "  %-14s %d\n" "Exit code :" "$rc"
    printf "  %-14s %s\n" "Time      :" "$(date '+%F %T')"
    echo "================================================================"
  } >> "$LOG_FILE" 2>/dev/null || true
  ln -sf "$(basename "$LOG_FILE")" "$LATEST" 2>/dev/null || true
}
trap _finalize_log EXIT

# ── Log helpers ────────────────────────────────────────────────
log_line() {
  echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}
run_and_log() {
  # Runs a command, tees its output to the log, returns the output.
  "$@" 2>&1 | tee -a "$LOG_FILE"
}
log_file_header() {
  {
    echo "================================================================"
    echo "  DolphinUI — dev.sh"
    echo "================================================================"
    printf "  %-14s %s\n" "Command :" "${1:-tui}"
    printf "  %-14s %s\n" "Date    :" "$(date '+%F %T')"
    printf "  %-14s %s\n" "Host    :" "$(uname -srm)"
    printf "  %-14s %s\n" "Shell   :" "bash ${BASH_VERSION}"
    printf "  %-14s %s\n" "Root    :" "$ROOT"
    echo "================================================================"
    echo
  } >> "$LOG_FILE"
}

# ════════════════════════════════════════════════════════════════
#  Colors / cursor
# ════════════════════════════════════════════════════════════════
E=$'\033'
C_RESET="${E}[0m"
C_BOLD="${E}[1m"
C_DIM="${E}[2m"
C_UL="${E}[4m"
C_REV="${E}[7m"

C_RED="${E}[31m"
C_GREEN="${E}[32m"
C_YELLOW="${E}[33m"
C_BLUE="${E}[34m"
C_MAGENTA="${E}[35m"
C_CYAN="${E}[36m"
C_WHITE="${E}[37m"
C_GREY="${E}[90m"
C_BRED="${E}[91m"

CLEAR="${E}[2J${E}[H"
HIDE_CUR="${E}[?25l"
SHOW_CUR="${E}[?25h"

# ════════════════════════════════════════════════════════════════
#  Menu definition
# ════════════════════════════════════════════════════════════════
MENU_KEYS=(  run    check    clean    logs    tokens    docs    audit    quit   )
MENU_LABEL=( "RUN   " "CHECK " "CLEAN " "LOGS  " "TOKENS" "DOCS  " "AUDIT " "QUIT  " )
MENU_DESC=( "Launch LOVE (640x480)" \
            "Lua syntax check" \
            "Rotate logs" \
            "Tail latest log" \
            "Print design tokens" \
            "List documentation" \
            "Hardcoded fonts/colors audit" \
            "Exit the console" )
MENU_COLOR=( "$C_GREEN" "$C_CYAN" "$C_YELLOW" "$C_BLUE" \
             "$C_MAGENTA" "$C_WHITE" "$C_RED" "$C_GREY" )

# ════════════════════════════════════════════════════════════════
#  Drawing
# ════════════════════════════════════════════════════════════════
BANNER=(
"DOLPHIN RT:CORE for  MUOS  //  v11.5.00-III 'FrontendONE'"
)

draw_header() {
  printf '%s' "$CLEAR"
  printf "${C_CYAN}${C_BOLD}"
  printf '  +--------------------------------------------------------------------+\n'
  printf "${C_RESET}"

  local line
  for line in "${BANNER[@]}"; do
    printf "  ${C_MAGENTA}${C_BOLD}|${C_RESET}${C_CYAN}${C_BOLD}%-68s${C_RESET}${C_MAGENTA}${C_BOLD}|${C_RESET}\n" \
      "$line"
  done

  printf "${C_CYAN}${C_BOLD}"
  printf '  +--------------------------------------------------------------------+\n'
  printf "${C_RESET}"
  printf "  ${C_DIM}%-4s${C_RESET}${C_WHITE}%s${C_RESET}\n" "" \
    "Development Console  -  SPDW Factory Lab"
  printf "  ${C_DIM}%-4s${C_RESET}${C_GREY}%s${C_RESET}\n" "" \
    "Root: $ROOT"
  printf "  ${C_DIM}%-4s${C_RESET}${C_GREY}%s${C_RESET}\n" "" \
    "Log : $LOG_FILE"
  echo
}

# Frames for the animated wave
WAVE_FRAMES=(
"  .  o  O  o  .                       "
"  o  O  o  .  o  O                    "
"  O  o  .  o  O  o  .                 "
"  o  .  o  O  o  .  o  O              "
"  .  o  O  o  .                       "
)

draw_wave() {
  local frame="$1"
  local idx=$(( frame % 4 ))
  printf "${E}[11;4H${C_CYAN}${C_DIM}%s${C_RESET}" "${WAVE_FRAMES[$idx]}"
}

draw_spinner() {
  local frame="$1"
  local spin=('|' '/' '-' '\')
  local s="${spin[$(( frame % 4 ))]}"
  printf "${E}[11;60H${C_GREEN}${C_BOLD} %s ${C_RESET} ${C_GREY}ready${C_RESET}" "$s"
}

draw_menu() {
  local sel="$1"
  local n=${#MENU_KEYS[@]}
  local top=13
  local x=4
  local w=68

  printf "${E}[%d;%dH${C_CYAN}┌─ ${C_BOLD}MENU${C_RESET}${C_CYAN} " \
    "$top" "$x"
  printf '%*s' $(( w - 8 )) '' | tr ' ' '-'
  printf "┐${C_RESET}"

  local i
  for (( i=0; i<n; i++ )); do
    printf "${E}[%d;%dH${C_CYAN}│${C_RESET}" $(( top + 1 + i )) "$x"

    local lbl="${MENU_LABEL[$i]}"
    local desc="${MENU_DESC[$i]}"
    local col="${MENU_COLOR[$i]}"

    if [ "$i" -eq "$sel" ]; then
      printf " ${C_REV}${C_BOLD} > %s ${C_RESET} ${C_BOLD}%s${C_RESET} ${col}%s${C_RESET}${E}[K" \
        "$lbl" "" "$desc"
    else
      printf "   ${C_BOLD}%s${C_RESET} ${C_GREY}%s${C_RESET}${E}[K" \
        "$lbl" "$desc"
    fi

    printf "${E}[%d;%dH${C_CYAN}│${C_RESET}" $(( top + 1 + i )) $(( x + w - 1 ))
  done

  printf "${E}[%d;%dH${C_CYAN}└" $(( top + 1 + n )) "$x"
  printf '%*s' $(( w - 2 )) '' | tr ' ' '-'
  printf "┘${C_RESET}"
}

draw_footer() {
  printf "${E}[22;4H${C_GREY}  up/down navigate  -  enter select  -  q quit${C_RESET}"
}

# ════════════════════════════════════════════════════════════════
#  Input
# ════════════════════════════════════════════════════════════════
read_key() {
  local timeout="${1:-0.15}"
  local k
  if ! IFS= read -rsn1 -t "$timeout" k; then
    echo TIMEOUT
    return
  fi

  if [ "$k" = $'\x1b' ]; then
    local b1="" b2=""
    IFS= read -rsn1 -t 0.01 b1 || true
    IFS= read -rsn1 -t 0.01 b2 || true
    case "${b1}${b2}" in
      '[A') echo UP ;;
      '[B') echo DOWN ;;
      '[C') echo RIGHT ;;
      '[D') echo LEFT ;;
      *)    echo ESC ;;
    esac
    return
  fi

  [ -z "$k" ] && { echo ENTER; return; }

  case "$k" in
    q|Q) echo QUIT ;;
    *)   echo "$k" ;;
  esac
}

# ════════════════════════════════════════════════════════════════
#  Actions
# ════════════════════════════════════════════════════════════════
pause() {
  printf "\n${C_GREY}  Press any key to return to the menu...${C_RESET}"
  IFS= read -rsn1 _ || true
}

screen_title() {
  printf '%s' "$CLEAR"
  printf "  ${C_MAGENTA}${C_BOLD}>>${C_RESET} ${C_WHITE}${C_BOLD}%s${C_RESET}\n\n" "$1"
}

action_run() {
  screen_title "RUN  -  LÖVE"
  if ! command -v love >/dev/null 2>&1; then
    printf "  ${C_RED}love not found in PATH${C_RESET}\n"
    pause; return
  fi
  log_line "action: run LÖVE"
  ( cd "$GAME_DIR" && love . "${@:-640x480}" ) 2>&1 | tee -a "$LOG_FILE"
  printf "\n  ${C_GREEN}LÖVE exited${C_RESET}\n"
  pause
}

action_check() {
  screen_title "CHECK  -  Lua syntax"
  log_line "action: syntax check"

  local CHECK
  if command -v luajit >/dev/null 2>&1; then CHECK="luajit -bl"
  elif command -v luac5.1 >/dev/null 2>&1; then CHECK="luac5.1 -p"
  else CHECK="luac -p"; fi

  local total=0 failed=0
  while IFS= read -r -d '' f; do
    total=$(( total + 1 ))
    if ! $CHECK "$f" >/dev/null 2>&1; then
      printf "  ${C_RED}x${C_RESET} %s\n" "${f#$GAME_DIR/}"
      $CHECK "$f" 2>&1 | head -3 | sed 's/^/      /'
      failed=$(( failed + 1 ))
    fi
  done < <(find "$GAME_DIR" -name '*.lua' -type f -print0)

  echo
  if [ "$failed" = "0" ]; then
    printf "  ${C_GREEN}OK${C_RESET}  all %d Lua files compile\n" "$total"
    log_line "check: OK ($total files)"
  else
    printf "  ${C_RED}FAIL${C_RESET}  %d/%d files with errors\n" "$failed" "$total"
    log_line "check: FAIL ($failed/$total)"
  fi
  pause
}

action_clean() {
  screen_title "CLEAN  -  Rotate logs"
  log_line "action: clean logs"

  if [ -d "$LOG_DIR_GAME" ]; then
    run_and_log find "$LOG_DIR_GAME" -type f -name "*.log" -mtime +7 -delete
    printf "  ${C_GREEN}LÖVE logs >7d cleaned${C_RESET}\n"
  fi

  if [ -d "$PC_LOGS" ]; then
    local current
    current="$(basename "$LOG_FILE")"
    local n
    n=$(ls -1 "$PC_LOGS"/dev_*.log 2>/dev/null | wc -l)
    ls -1t "$PC_LOGS"/dev_*.log 2>/dev/null | tail -n +51 | while read -r f; do
      [ "$(basename "$f")" = "$current" ] && continue
      rm -f "$f"
    done
    printf "  ${C_GREEN}dev.sh logs${C_RESET}  %d total, kept 50 (current preserved)\n" "$n"
  fi
  pause
}

action_logs() {
  screen_title "LOGS  -  Tail latest"
  log_line "action: tail latest log"
  if [ -f "$LATEST" ]; then
    tail -n 60 "$LATEST"
  else
    printf "  ${C_YELLOW}no log yet${C_RESET}\n"
  fi
  pause
}

action_tokens() {
  screen_title "TOKENS  -  Design tokens"
  log_line "action: tokens"
  if [ ! -f "$GAME_DIR/ui/tokens.lua" ]; then
    printf "  ${C_RED}frontend/ui/tokens.lua missing${C_RESET}\n"
    pause; return
  fi
  ( cd "$GAME_DIR" && luajit -e '
    package.path = "./?.lua;./?/init.lua;" .. package.path
    local ok, T = pcall(require, "ui.tokens")
    if not ok then io.stderr:write("load error: " .. tostring(T) .. "\n"); os.exit(1) end
    local function hex(r,g,b) return string.format("#%02X%02X%02X",
      math.floor((r or 0)*255+.5), math.floor((g or 0)*255+.5), math.floor((b or 0)*255+.5)) end
    for theme, pal in pairs(T.palette) do
      print("[" .. theme .. "]")
      local ks = {}; for k in pairs(pal) do ks[#ks+1]=k end; table.sort(ks)
      for _, k in ipairs(ks) do local c = pal[k]
        print(string.format("  %-12s %s", k, hex(c[1],c[2],c[3]))) end
    end
    print("") print("VISOR")
    local vk = {}; for k in pairs(T.visor) do vk[#vk+1]=k end; table.sort(vk)
    for _, k in ipairs(vk) do local c = T.visor[k]
      print(string.format("  %-12s %s", k, hex(c[1],c[2],c[3]))) end
    print("") print("SPACING")
    local sk = {}; for k in pairs(T.spacing) do sk[#sk+1]=k end; table.sort(sk)
    for _, k in ipairs(sk) do print(string.format("  %-5s %d px", k, T.spacing[k])) end
  ' ) 2>&1 | tee -a "$LOG_FILE"
  pause
}

action_docs() {
  screen_title "DOCS  -  Documentation"
  log_line "action: docs"
  if [ ! -d "$ROOT/docs" ]; then
    printf "  ${C_YELLOW}(no docs/ folder)${C_RESET}\n"
    pause; return
  fi
  local n=0
  for f in "$ROOT/docs"/*.md; do
    [ -f "$f" ] || continue
    n=$(( n + 1 ))
    printf "  ${C_CYAN}%-26s${C_RESET} %8s bytes\n" \
      "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"
  done
  printf "\n  ${C_GREY}Total: %d file(s)${C_RESET}\n" "$n"
  pause
}

action_audit() {
  screen_title "AUDIT  -  Hardcoded fonts / colors"
  log_line "action: audit"
  local screens="$GAME_DIR/screens"
  local ui="$GAME_DIR/ui"
  local total_font=0 total_color=0

  echo "  ${C_WHITE}Font calls bypassing F.get / A.title_font:${C_RESET}"
  while IFS= read -r -d '' f; do
    local hits
    hits=$(grep -n 'A\.font("assets/fonts' "$f" 2>/dev/null || true)
    if [ -n "$hits" ]; then
      echo "  ${C_YELLOW}${f#$GAME_DIR/}${C_RESET}"
      echo "$hits" | sed "s/^/    ${C_GREY}/; s/\$/${C_RESET}/"
      total_font=$(( total_font + $(echo "$hits" | wc -l) ))
    fi
  done < <(find "$screens" "$ui" -name '*.lua' -type f -print0)

  echo
  echo "  ${C_WHITE}Hardcoded setColor with 3+ float literals:${C_RESET}"
  while IFS= read -r -d '' f; do
    local rel="${f#$GAME_DIR/}"
    case "$rel" in ui/tokens.lua|theme_*.lua|ui/bg.lua|ui/draw.lua) continue ;; esac
    local hits
    hits=$(grep -nE 'setColor\([0-9]+\.[0-9]+, *[0-9]+\.[0-9]+, *[0-9]+\.[0-9]+' "$f" 2>/dev/null || true)
    if [ -n "$hits" ]; then
      echo "  ${C_YELLOW}${rel}${C_RESET}"
      echo "$hits" | head -5 | sed "s/^/    ${C_GREY}/; s/\$/${C_RESET}/"
      total_color=$(( total_color + $(echo "$hits" | wc -l) ))
    fi
  done < <(find "$screens" "$ui" -name '*.lua' -type f -print0)

  echo
  printf "  ${C_WHITE}Summary${C_RESET}\n"
  printf "    A.font calls    : ${C_YELLOW}%d${C_RESET}\n" "$total_font"
  printf "    setColor calls  : ${C_YELLOW}%d${C_RESET}\n" "$total_color"
  echo
  if [ "$total_font" -eq 0 ] && [ "$total_color" -eq 0 ]; then
    printf "  ${C_GREEN}Clean${C_RESET}\n"
  else
    printf "  ${C_YELLOW}Review recommended${C_RESET}\n"
  fi
  pause
}

# ════════════════════════════════════════════════════════════════
#  Intro animation
# ════════════════════════════════════════════════════════════════
intro_animation() {
  printf '%s%s' "$CLEAR" "$HIDE_CUR"
  local spin=('|' '/' '-' '\')
  local bar_width=40
  local i

  local line
  for line in "${BANNER[@]}"; do
    printf "  ${C_MAGENTA}${C_BOLD}|${C_RESET}${C_CYAN}${C_BOLD}%-68s${C_RESET}${C_MAGENTA}${C_BOLD}|${C_RESET}\n" \
      "$line"
  done
  echo
  printf "  ${C_DIM}%-4s${C_RESET}${C_WHITE}%s${C_RESET}\n\n" "" \
    "Development Console  -  SPDX: SPDW Factory Lab"

  for (( i=0; i<=bar_width; i++ )); do
    local pct=$(( i * 100 / bar_width ))
    local filled=$(printf '█%.0s' $(seq 1 "$i" 2>/dev/null) 2>/dev/null || true)
    local empty=$(printf '░%.0s' $(seq 1 $(( bar_width - i )) 2>/dev/null) 2>/dev/null || true)
    printf "\r  ${C_GREEN}${filled}${C_GREY}${empty}${C_RESET}  ${C_BOLD}%3d%%${C_RESET}  ${C_CYAN}%s${C_RESET}" \
      "$pct" "${spin[$(( i % 4 ))]}"
    sleep 0.02
  done
  printf "\r  ${C_GREEN}%*s${C_RESET}  ${C_BOLD}done${C_RESET}\n" "$bar_width" "" \
    | tr ' ' ' '
  printf "  ${C_GREEN}%s${C_RESET}\n" "$(printf '█%.0s' $(seq 1 $bar_width))"
  sleep 0.25
}

# ════════════════════════════════════════════════════════════════
#  TUI main loop
# ════════════════════════════════════════════════════════════════
run_tui() {
  log_file_header "tui"

  intro_animation

  printf '%s' "$CLEAR"
  draw_header
  draw_footer

  local sel=0
  local n=${#MENU_KEYS[@]}
  local frame=0

  draw_menu "$sel"

  while true; do
    draw_wave "$frame"
    draw_spinner "$frame"
    frame=$(( frame + 1 ))

    local key
    key="$(read_key 0.15)"

    case "$key" in
      TIMEOUT) continue ;;
      UP)      sel=$(( (sel - 1 + n) % n )); draw_menu "$sel" ;;
      DOWN)    sel=$(( (sel + 1) % n ));     draw_menu "$sel" ;;
      ENTER)
        printf '%s%s' "$CLEAR" "$SHOW_CUR"
        local k="${MENU_KEYS[$sel]}"
        case "$k" in
          run)    action_run ;;
          check)  action_check ;;
          clean)  action_clean ;;
          logs)   action_logs ;;
          tokens) action_tokens ;;
          docs)   action_docs ;;
          audit)  action_audit ;;
          quit)   printf '%s' "$CLEAR"; printf "${C_SHOW}${SHOW_CUR}"; break ;;
        esac
        # Redraw main screen
        printf '%s%s' "$CLEAR" "$HIDE_CUR"
        draw_header
        draw_footer
        draw_menu "$sel"
        ;;
      QUIT|ESC)
        printf '%s%s' "$CLEAR" "$SHOW_CUR"
        break
        ;;
    esac
  done

  printf '%s%s' "$CLEAR" "$SHOW_CUR"
  log_line "tui exit"
}

# ════════════════════════════════════════════════════════════════
#  CLI dispatcher (non-TUI mode)
# ════════════════════════════════════════════════════════════════
run_cli() {
  local cmd="$1"; shift || true
  log_file_header "$cmd"

  case "$cmd" in
    run)
      ( cd "$GAME_DIR" && love . "${@:-640x480}" ) 2>&1 | tee -a "$LOG_FILE"
      ;;
    check)
      local CHECK
      command -v luajit >/dev/null 2>&1 && CHECK="luajit -bl" || CHECK="luac -p"
      local total=0 failed=0
      while IFS= read -r -d '' f; do
        total=$(( total + 1 ))
        if ! $CHECK "$f" >/dev/null 2>&1; then
          echo "FAIL: $f"
          $CHECK "$f" 2>&1 | head -3
          failed=$(( failed + 1 ))
        fi
      done < <(find "$GAME_DIR" -name '*.lua' -type f -print0)
      echo "check: $(( total - failed ))/$total OK"
      [ "$failed" -gt 0 ] && return 1
      ;;
    clean)
      [ -d "$LOG_DIR_GAME" ] && find "$LOG_DIR_GAME" -type f -name '*.log' -mtime +7 -delete
      echo "clean: done"
      ;;
    logs)
      [ -f "$LATEST" ] && tail -n 80 "$LATEST" || echo "(no log)"
      ;;
    tokens)
      ( cd "$GAME_DIR" && luajit -e '
        package.path = "./?.lua;./?/init.lua;" .. package.path
        local T = require("ui.tokens")
        for theme, pal in pairs(T.palette) do
          print("[" .. theme .. "]")
          local ks = {}; for k in pairs(pal) do ks[#ks+1]=k end; table.sort(ks)
          for _, k in ipairs(ks) do
            local c = pal[k]
            print(string.format("  %-12s #%02X%02X%02X", k,
              math.floor(c[1]*255+.5), math.floor(c[2]*255+.5), math.floor(c[3]*255+.5)))
          end
        end
      ' ) 2>&1 | tee -a "$LOG_FILE"
      ;;
    docs)
      [ -d "$ROOT/docs" ] && ls -la "$ROOT/docs" || echo "(no docs/)"
      ;;
    audit)
      grep -rn 'A\.font("assets/fonts' "$GAME_DIR/screens" "$GAME_DIR/ui" 2>/dev/null || true
      ;;
    *)
      echo "Unknown: $cmd"
      echo "Usage: $0 [run|check|clean|logs|tokens|docs|audit]"
      return 1
      ;;
  esac
}

# ════════════════════════════════════════════════════════════════
#  Entry point
# ════════════════════════════════════════════════════════════════
if [ $# -eq 0 ]; then
  run_tui
else
  run_cli "$@"
fi
