#!/bin/bash
# ============================================================
#  scan_load.sh — Regenerate Advanced Options from Load/
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
#  Behaviour:
#    * Skips Load/ subfolders that have NO valid content
#    * Removes orphan subfolders in Advanced Options
#    * Only creates the mirror folder if there is at least
#      one non-hidden subdirectory to toggle
#
#  Rationale:
#    muOS Task Toolkit FREEZES if you press A on an empty
#    folder. So we must NEVER create empty folders.
# ============================================================

EMU="/opt/muos/share/emulator/dolphin"
LOAD_DIR="$EMU/Load"
ADV_DIR="/opt/muos/share/task/Dolphin RtCore/04. Advanced Options"

mkdir -p "$ADV_DIR"

CREATED=0
SKIPPED=0
CLEANED=0

# ── Step 1: identify valid Load/ subfolders ────────────────
VALID_SUBS=""
for load_sub in "$LOAD_DIR"/*/; do
    [ -d "$load_sub" ] || continue
    sub_name=$(basename "$load_sub")
    case "$sub_name" in .*) continue ;; esac

    # Count non-hidden directory entries only
    ENTRY_COUNT=0
    for entry in "$load_sub"*/; do
        [ -d "$entry" ] || continue
        entry_name=$(basename "$entry")
        case "$entry_name" in .*) continue ;; esac
        ENTRY_COUNT=$((ENTRY_COUNT+1))
    done

    if [ "$ENTRY_COUNT" = "0" ]; then
        echo "  [SKIP] $sub_name/ — no content"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    VALID_SUBS="$VALID_SUBS $sub_name"
done

# ── Step 2: remove orphan subfolders in Advanced Options ───
for adv_sub in "$ADV_DIR"/*/; do
    [ -d "$adv_sub" ] || continue
    adv_name=$(basename "$adv_sub")

    case " $VALID_SUBS " in
        *" $adv_name "*) ;;  # valid, keep
        *)
            rm -rf "$adv_sub"
            echo "  [CLEAN] Removed orphan: $adv_name/"
            CLEANED=$((CLEANED+1))
            ;;
    esac
done

# ── Step 3: (re)generate toggles for valid subfolders ──────
gen_toggle_graphicmods() {
    local entry="$1"
    local out="$2"
    cat > "$out" << EOF
#!/bin/sh
# HELP: Toggle $entry | Enable or disable this Graphics Mod.
# ICON: theme
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "\$CONF" ] && . "\$CONF" 2>/dev/null
[ -z "\$GENERAL_SLEEP" ] && GENERAL_SLEEP=3

MOD_DIR="/opt/muos/share/emulator/dolphin/Load/GraphicMods/$entry"
MARKER="\$MOD_DIR/.disabled"

clear
echo "==============================================="
echo "  Graphics Mod: $entry"
echo "==============================================="
echo ""

if [ ! -d "\$MOD_DIR" ]; then
    echo "  [ERR] Mod folder not found."
    STATUS="ERROR"
elif [ -f "\$MARKER" ]; then
    rm -f "\$MARKER"
    echo "  [OK] Mod ENABLED."
    STATUS="ENABLED"
else
    touch "\$MARKER"
    echo "  [OK] Mod DISABLED."
    STATUS="DISABLED"
fi

echo ""
echo "  Mod    : $entry"
echo "  Status : \$STATUS"
echo ""
echo "==============================================="
echo "  End of file - closing in \${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "\$GENERAL_SLEEP"
FRONTEND start task
exit 0
EOF
    chmod +x "$out"
}

gen_toggle_generic() {
    local parent="$1"
    local entry="$2"
    local out="$3"
    cat > "$out" << EOF
#!/bin/sh
# HELP: Toggle $entry | Enable or disable this entry.
# ICON: theme
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "\$CONF" ] && . "\$CONF" 2>/dev/null
[ -z "\$GENERAL_SLEEP" ] && GENERAL_SLEEP=3

PARENT="/opt/muos/share/emulator/dolphin/Load/$parent"
ACTIVE="\$PARENT/$entry"
DISABLED="\$PARENT/.$entry.disabled"

clear
echo "==============================================="
echo "  Toggle: $entry"
echo "==============================================="
echo ""

if [ -d "\$ACTIVE" ]; then
    mv "\$ACTIVE" "\$DISABLED"
    echo "  [OK] Entry DISABLED."
    STATUS="DISABLED"
elif [ -d "\$DISABLED" ]; then
    mv "\$DISABLED" "\$ACTIVE"
    echo "  [OK] Entry ENABLED."
    STATUS="ENABLED"
else
    echo "  [ERR] Entry not found."
    STATUS="ERROR"
fi

echo ""
echo "  Parent : $parent"
echo "  Entry  : $entry"
echo "  Status : \$STATUS"
echo ""
echo "==============================================="
echo "  End of file - closing in \${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "\$GENERAL_SLEEP"
FRONTEND start task
exit 0
EOF
    chmod +x "$out"
}

for sub_name in $VALID_SUBS; do
    load_sub="$LOAD_DIR/$sub_name"
    adv_sub="$ADV_DIR/$sub_name"
    mkdir -p "$adv_sub"

    ENTRIES_IN_SUB=0
    for entry in "$load_sub"*/; do
        [ -d "$entry" ] || continue
        entry_name=$(basename "$entry")
        case "$entry_name" in .*) continue ;; esac

        out="$adv_sub/$entry_name.sh"
        if [ "$sub_name" = "GraphicMods" ]; then
            gen_toggle_graphicmods "$entry_name" "$out"
        else
            gen_toggle_generic "$sub_name" "$entry_name" "$out"
        fi
        ENTRIES_IN_SUB=$((ENTRIES_IN_SUB+1))
    done

    # Bulk actions (still valid because folder has content)
    cat > "$adv_sub/_Disable All.sh" << EOF
#!/bin/sh
# HELP: Disable All ($sub_name) | Disable every entry in $sub_name.
# ICON: theme
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "\$CONF" ] && . "\$CONF" 2>/dev/null
[ -z "\$GENERAL_SLEEP" ] && GENERAL_SLEEP=3

SUB="$LOAD_DIR/$sub_name"
COUNT=0

if [ "$sub_name" = "GraphicMods" ]; then
    for d in "\$SUB"/*/; do
        [ -d "\$d" ] || continue
        touch "\$d/.disabled" && COUNT=\$((COUNT+1))
    done
else
    for d in "\$SUB"/*/; do
        [ -d "\$d" ] || continue
        name=\$(basename "\$d")
        case "\$name" in .*) continue ;; esac
        mv "\$d" "\$SUB/.\$name.disabled" && COUNT=\$((COUNT+1))
    done
fi

clear
echo "==============================================="
echo "  Disable All: $sub_name"
echo "==============================================="
echo ""
echo "  [OK] \$COUNT entries disabled."
echo ""
echo "==============================================="
echo "  End of file - closing in \${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "\$GENERAL_SLEEP"
FRONTEND start task
exit 0
EOF
    chmod +x "$adv_sub/_Disable All.sh"

    cat > "$adv_sub/_Enable All.sh" << EOF
#!/bin/sh
# HELP: Enable All ($sub_name) | Enable every entry in $sub_name.
# ICON: theme
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "\$CONF" ] && . "\$CONF" 2>/dev/null
[ -z "\$GENERAL_SLEEP" ] && GENERAL_SLEEP=3

SUB="$LOAD_DIR/$sub_name"
COUNT=0

if [ "$sub_name" = "GraphicMods" ]; then
    for d in "\$SUB"/*/; do
        [ -d "\$d" ] || continue
        rm -f "\$d/.disabled" && COUNT=\$((COUNT+1))
    done
else
    for d in "\$SUB"/.*.disabled/; do
        [ -d "\$d" ] || continue
        name=\$(basename "\$d")
        real=\${name#.}
        real=\${real%.disabled}
        mv "\$d" "\$SUB/\$real" && COUNT=\$((COUNT+1))
    done
fi

clear
echo "==============================================="
echo "  Enable All: $sub_name"
echo "==============================================="
echo ""
echo "  [OK] \$COUNT entries enabled."
echo ""
echo "==============================================="
echo "  End of file - closing in \${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "\$GENERAL_SLEEP"
FRONTEND start task
exit 0
EOF
    chmod +x "$adv_sub/_Enable All.sh"

    echo "  [OK] $sub_name/ — $ENTRIES_IN_SUB entries"
    CREATED=$((CREATED+1))
done

echo ""
echo "  Subfolders with content : $CREATED"
echo "  Subfolders skipped      : $SKIPPED"
echo "  Orphan folders cleaned  : $CLEANED"
echo ""
exit 0
