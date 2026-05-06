#!/usr/bin/env bash
# ============================================================
# reconfigure.sh — Change settings after install.
# Each option changes only what you pick; everything else is kept.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/ensure-config.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/src/suggest_times.sh"
source "$SCRIPT_DIR/src/utils.sh"
source "$SCRIPT_DIR/src/detect_platform.sh"

[[ "${SCHEDULE_DAYS_AHEAD:-}" =~ ^[0-9]+$ ]] || SCHEDULE_DAYS_AHEAD=$DEFAULT_SCHEDULE_DAYS_AHEAD

PLATFORM=$(detect_platform)
INSTALL_DIR="$HOME/.local/share/claude-session-manager"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_GREEN='\033[0;32m'; C_BOLD_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[0;36m'
C_BOLD_CYAN='\033[1;36m'; C_RED='\033[0;31m'

hr()   { printf "  ${C_DIM}%s${C_RESET}\n" "────────────────────────────────────"; }
ok()   { printf "${C_BOLD_GREEN}  ✓${C_RESET}  %s\n" "$1"; }
warn() { printf "${C_YELLOW}  ⚠${C_RESET}  %s\n" "$1"; }
err()  { printf "${C_RED}  ✗${C_RESET}  %s\n" "$1" >&2; }

ask() {
    local prompt="$1" default="$2"
    if [[ -t 0 ]]; then
        local ans
        printf "  ${C_BOLD}%s${C_RESET} ${C_DIM}[%s]${C_RESET}: " "$prompt" "$default" >&2
        read -r ans; echo "${ans:-$default}"
    else
        echo "$default"
    fi
}

yn_raw() {
    local prompt="$1" default="${2:-false}"
    local norm; case "$default" in y|Y|yes|true) norm="true";; *) norm="false";; esac
    local disp; [[ "$norm" == "true" ]] && disp="Y/n" || disp="y/N"
    if [[ -t 0 ]]; then
        local a
        printf "  ${C_BOLD}%s${C_RESET} ${C_DIM}[%s]${C_RESET}: " "$prompt" "$disp" >&2
        read -r a
        case "${a:-$norm}" in y|Y|yes|true) echo "true";; *) echo "false";; esac
    else
        echo "$norm"
    fi
}

# ── Header ────────────────────────────────────────────────────
echo ""
printf "  ${C_BOLD_CYAN}Claude Session Manager${C_RESET} ${C_DIM}— Reconfigure${C_RESET}\n"
hr

printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s - %s${C_RESET}\n" "Work hours:"    "$WORK_START" "$WORK_END"
printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s${C_RESET}\n"     "Session times:" "${SESSION_TIMES[*]}"
printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s${C_RESET}\n"     "Model:"         "$CLAUDE_MODEL"
printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s${C_RESET}\n"     "Weekends:"      "$([[ ${SCHEDULE_WEEKENDS:-false} == true ]] && echo Yes || echo No)"
printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s${C_RESET}\n"     "Holidays:"      "$([[ ${SCHEDULE_HOLIDAYS:-false} == true ]] && echo Yes || echo No)"
printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s${C_RESET}\n"     "Holiday country:" "${HOLIDAY_COUNTRY:-none}"
printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s days${C_RESET}\n" "Pre-schedule:" "${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}"

echo ""
hr
echo ""
printf "  ${C_BOLD_GREEN}1)${C_RESET}  Session times\n"
printf "  ${C_BOLD_GREEN}2)${C_RESET}  Model\n"
printf "  ${C_BOLD_GREEN}3)${C_RESET}  Weekend / holiday / days-ahead\n"
printf "  ${C_BOLD_GREEN}4)${C_RESET}  Work hours  ${C_DIM}(recalculates suggested session times)${C_RESET}\n"
printf "  ${C_BOLD_GREEN}5)${C_RESET}  Holiday country\n"
printf "  ${C_DIM}0)  Exit${C_RESET}\n"
echo ""
CHOICE=$(ask "Choice" "0")

case "$CHOICE" in
# ── 1: Session times ─────────────────────────────────────────
1)
    echo ""
    SUGGESTED=$(suggest_session_times "$WORK_START" "$WORK_END")
    read -r S1 S2 S3 <<< "$SUGGESTED"
    printf "  ${C_DIM}Suggested for %s-%s:${C_RESET}  ${C_BOLD}%s  %s  %s${C_RESET}\n" \
        "$WORK_START" "$WORK_END" "$S1" "$S2" "$S3"
    echo ""
    while true; do
        CUSTOM=$(ask "Session times  (HH:MM, comma-separated)" "${SESSION_TIMES[*]// /,}")
        IFS=',' read -r -a SESSION_TIMES <<< "$CUSTOM"
        _ok=true
        for _t in "${SESSION_TIMES[@]}"; do
            _t="${_t// /}"
            [[ "$_t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] || { err "Invalid: '$_t' — use HH:MM"; _ok=false; break; }
        done
        [[ "$_ok" == true ]] && break
    done
    ;;

# ── 2: Model ─────────────────────────────────────────────────
2)
    echo ""
    case "${CLAUDE_MODEL:-}" in *sonnet*) _m="2";; *opus*) _m="3";; *) _m="1";; esac
    printf "  ${C_BOLD_GREEN}1)${C_RESET}  ${C_BOLD}haiku${C_RESET}   ${C_DIM}${CLAUDE_MODEL_HAIKU}${C_RESET}  ${C_BOLD_GREEN}cheapest${C_RESET}\n"
    printf "  ${C_DIM}2)${C_RESET}  sonnet  ${C_DIM}${CLAUDE_MODEL_SONNET}${C_RESET}\n"
    printf "  ${C_DIM}3)${C_RESET}  opus    ${C_DIM}${CLAUDE_MODEL_OPUS}${C_RESET}\n"
    echo ""
    MC=$(ask "Choice" "$_m")
    case "$MC" in
        2) CLAUDE_MODEL="$CLAUDE_MODEL_SONNET" ;;
        3) CLAUDE_MODEL="$CLAUDE_MODEL_OPUS" ;;
        *) CLAUDE_MODEL="$CLAUDE_MODEL_HAIKU" ;;
    esac
    ;;

# ── 3: Schedule preferences ───────────────────────────────────
3)
    echo ""
    SCHEDULE_WEEKENDS=$(yn_raw "Include weekends?  (Sat/Sun)" "${SCHEDULE_WEEKENDS:-$DEFAULT_SCHEDULE_WEEKENDS}")
    SCHEDULE_HOLIDAYS=$(yn_raw "Include holidays?" "${SCHEDULE_HOLIDAYS:-$DEFAULT_SCHEDULE_HOLIDAYS}")
    echo ""
    while true; do
        SCHEDULE_DAYS_AHEAD=$(ask "Days to pre-schedule  (30=1 month · 365=1 year)" "${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}")
        [[ "$SCHEDULE_DAYS_AHEAD" =~ ^[0-9]+$ ]] && (( SCHEDULE_DAYS_AHEAD > 0 )) && break
        err "Must be a positive number, e.g. $DEFAULT_SCHEDULE_DAYS_AHEAD"
    done
    printf "  ${C_DIM}To add holiday dates, edit HOLIDAYS=() in config.sh (YYYY-MM-DD).${C_RESET}\n"
    ;;

# ── 4: Work hours ─────────────────────────────────────────────
4)
    echo ""
    WORK_START=$(ask "Work start (HH:MM)" "$WORK_START")
    WORK_END=$(ask   "Work end   (HH:MM)" "$WORK_END")
    SUGGESTED=$(suggest_session_times "$WORK_START" "$WORK_END")
    read -r S1 S2 S3 <<< "$SUGGESTED"
    echo ""
    printf "  ${C_DIM}Suggested for %s-%s:${C_RESET}\n" "$WORK_START" "$WORK_END"
    describe_session_overlap "$WORK_START" "$WORK_END" "$S1" "$S2" "$S3"
    echo ""
    USE=$(yn_raw "Use suggested times?" "y")
    if [[ "$USE" == "true" ]]; then
        SESSION_TIMES=("$S1" "$S2" "$S3")
    else
        while true; do
            CUSTOM=$(ask "Session times  (HH:MM, comma-separated)" "${SESSION_TIMES[*]// /,}")
            IFS=',' read -r -a SESSION_TIMES <<< "$CUSTOM"
            _ok=true
            for _t in "${SESSION_TIMES[@]}"; do
                _t="${_t// /}"
                [[ "$_t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] || { err "Invalid: '$_t'"; _ok=false; break; }
            done
            [[ "$_ok" == true ]] && break
        done
    fi
    ;;

# ── 5: Holiday country ───────────────────────────────────────
5)
    echo ""
    _crow() {
        local num="$1" code="$2" label="$3" is_def="${4:-false}"
        if [[ "$is_def" == "true" ]]; then
            printf "  ${C_BOLD_GREEN}%s)${C_RESET}  ${C_BOLD}%-4s${C_RESET}  ${C_BOLD_GREEN}%s${C_RESET} ${C_DIM}(current)${C_RESET}\n" "$num" "$code" "$label"
        else
            printf "  ${C_DIM}%s)${C_RESET}  %-4s  %s\n" "$num" "$code" "$label"
        fi
    }
    _cur="${HOLIDAY_COUNTRY:-}"
    _crow 0 ""   "None — manage manually in config.sh"  "$([[ -z $_cur ]] && echo true || echo false)"
    _crow 1 "br" "Brazil / Brasil"                       "$([[ $_cur == br ]] && echo true || echo false)"
    _crow 2 "us" "United States"                         "$([[ $_cur == us ]] && echo true || echo false)"
    _crow 3 "uk" "United Kingdom (England & Wales)"      "$([[ $_cur == uk ]] && echo true || echo false)"
    _crow 4 "de" "Germany / Deutschland"                 "$([[ $_cur == de ]] && echo true || echo false)"
    _crow 5 "fr" "France"                                "$([[ $_cur == fr ]] && echo true || echo false)"
    _crow 6 "pt" "Portugal"                              "$([[ $_cur == pt ]] && echo true || echo false)"
    _crow 7 "ar" "Argentina"                             "$([[ $_cur == ar ]] && echo true || echo false)"
    _crow 8 "mx" "Mexico / Mexico"                       "$([[ $_cur == mx ]] && echo true || echo false)"
    _crow 9 "nl" "Netherlands / Nederland"               "$([[ $_cur == nl ]] && echo true || echo false)"
    echo ""
    _cc=$(ask "Country" "${_cur:-0}")
    case "$_cc" in
        0|none|"") HOLIDAY_COUNTRY="" ;;
        1|br)      HOLIDAY_COUNTRY="br" ;;
        2|us)      HOLIDAY_COUNTRY="us" ;;
        3|uk)      HOLIDAY_COUNTRY="uk" ;;
        4|de)      HOLIDAY_COUNTRY="de" ;;
        5|fr)      HOLIDAY_COUNTRY="fr" ;;
        6|pt)      HOLIDAY_COUNTRY="pt" ;;
        7|ar)      HOLIDAY_COUNTRY="ar" ;;
        8|mx)      HOLIDAY_COUNTRY="mx" ;;
        9|nl)      HOLIDAY_COUNTRY="nl" ;;
        *)
            if [[ -f "$SCRIPT_DIR/holidays/${_cc}.sh" ]]; then
                HOLIDAY_COUNTRY="$_cc"
            else
                err "Unknown code '${_cc}'. Country unchanged."
                exit 1
            fi
            ;;
    esac
    [[ -n "$HOLIDAY_COUNTRY" ]] \
        && ok "Holiday country set to: $HOLIDAY_COUNTRY" \
        || warn "No country — add dates manually to HOLIDAYS=() in config.sh"
    ;;

# ── 0: Exit ───────────────────────────────────────────────────
*)
    echo "  Nothing changed."; exit 0
    ;;
esac

# ── Write complete config (ALL values, not just changed ones) ─
TIMES_STR=""; for t in "${SESSION_TIMES[@]}"; do TIMES_STR+="\"$t\" "; done
TIMES_STR="${TIMES_STR% }"

cat > "$SCRIPT_DIR/config.sh" <<CFG
#!/usr/bin/env bash
# Generated by reconfigure.sh — edit manually or run: bash reconfigure.sh

SESSION_TIMES=(${TIMES_STR})
SESSION_MIN_GAP=${DEFAULT_SESSION_MIN_GAP}

WORK_START="${WORK_START}"
WORK_END="${WORK_END}"

CLAUDE_MODEL="${CLAUDE_MODEL}"
CLAUDE_BIN="${CLAUDE_BIN:-}"

INITIAL_PROMPT="${INITIAL_PROMPT:-${DEFAULT_INITIAL_PROMPT}}"

CLAUDE_EXTRA_FLAGS="${CLAUDE_EXTRA_FLAGS:-${DEFAULT_CLAUDE_EXTRA_FLAGS}}"
CLAUDE_DISABLE_TOOLS=${CLAUDE_DISABLE_TOOLS:-${DEFAULT_CLAUDE_DISABLE_TOOLS}}

AUTO_SLEEP=${AUTO_SLEEP:-${DEFAULT_AUTO_SLEEP}}
SLEEP_DELAY=${SLEEP_DELAY:-${DEFAULT_SLEEP_DELAY}}
WAKE_OFFSET_SECS=${WAKE_OFFSET_SECS:-${DEFAULT_WAKE_OFFSET_SECS}}

SCHEDULE_WEEKENDS=${SCHEDULE_WEEKENDS:-${DEFAULT_SCHEDULE_WEEKENDS}}
SCHEDULE_HOLIDAYS=${SCHEDULE_HOLIDAYS:-${DEFAULT_SCHEDULE_HOLIDAYS}}
SCHEDULE_DAYS_AHEAD=${SCHEDULE_DAYS_AHEAD:-${DEFAULT_SCHEDULE_DAYS_AHEAD}}

HOLIDAY_COUNTRY="${HOLIDAY_COUNTRY:-}"

HOLIDAYS=(
    # "2026-06-15"   # Example: local/municipal holiday
)

STATE_DIR="\$HOME/.claude-session-manager"
LOG_FILE="\$STATE_DIR/session.log"
LAST_SESSION_FILE="\$STATE_DIR/last_session"
CFG

echo ""
hr
ok "config.sh updated."

# Sync all scripts + config to the installed location
if [[ -d "$INSTALL_DIR" ]]; then
    for _dir in src platforms holidays; do
        rm -rf "$INSTALL_DIR/$_dir"
        cp -R "$SCRIPT_DIR/$_dir" "$INSTALL_DIR/$_dir"
    done
    cp "$SCRIPT_DIR/config.sh" "$INSTALL_DIR/config.sh"
    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
    ok "Scripts synced to $INSTALL_DIR"
fi

# ── Reload platform ───────────────────────────────────────────
case "$PLATFORM" in
    macos)
        source "$SCRIPT_DIR/platforms/macos/scheduler.sh"
        source "$SCRIPT_DIR/platforms/macos/wake.sh"
        generate_plist "$INSTALL_DIR/src/session.sh" "$HOME/.claude-session-manager"
        load_scheduler && ok "LaunchAgent reloaded."
        cancel_our_wake_events
        load_country_holidays 2>/dev/null || true
        schedule_upcoming_days "${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}" run
        ok "Wake events updated."
        ;;
    linux)
        warn "Reload manually: systemctl --user restart claude-session.timer"
        ;;
esac

rm -f "${LAST_SESSION_FILE:-$HOME/.claude-session-manager/last_session}"
ok "Session guard reset."

echo ""
hr
printf "  ${C_BOLD_GREEN}Done.${C_RESET}  ${C_DIM}Sessions:${C_RESET} ${C_BOLD}${SESSION_TIMES[*]}${C_RESET}  ${C_DIM}Model:${C_RESET} ${C_BOLD}${CLAUDE_MODEL}${C_RESET}  ${C_DIM}Country:${C_RESET} ${C_BOLD}${HOLIDAY_COUNTRY:-none}${C_RESET}\n"
echo ""
