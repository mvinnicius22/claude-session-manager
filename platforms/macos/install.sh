#!/usr/bin/env bash
# ============================================================
# platforms/macos/install.sh — macOS only
# Called by root install.sh after platform detection.
# Pre-fills wizard defaults from existing config.sh (for reinstall).
# ============================================================

set -uo pipefail

PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$PLATFORM_DIR")")"

source "$PROJECT_DIR/src/defaults.sh"
source "$PROJECT_DIR/src/suggest_times.sh"
source "$PLATFORM_DIR/scheduler.sh"

# Pre-fill defaults from existing config (enables seamless reinstall)
[[ -f "$PROJECT_DIR/config.sh" ]] && source "$PROJECT_DIR/config.sh"

# Normalize numeric fields — if stored value isn't a valid number, reset to default
[[ "${SCHEDULE_DAYS_AHEAD:-}" =~ ^[0-9]+$ ]] || SCHEDULE_DAYS_AHEAD=$DEFAULT_SCHEDULE_DAYS_AHEAD

INSTALL_DIR="$HOME/.local/share/claude-session-manager"

# ── Colours ───────────────────────────────────────────────────
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_GREEN='\033[0;32m'
C_BOLD_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_BOLD_CYAN='\033[1;36m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'

# ── UI helpers ────────────────────────────────────────────────
ok()   { printf "${C_BOLD_GREEN}  ✓${C_RESET}  %s\n" "$1"; }
info() { printf "${C_BLUE}  →${C_RESET}  %s\n" "$1"; }
warn() { printf "${C_YELLOW}  ⚠${C_RESET}  %s\n" "$1"; }
err()  { printf "${C_RED}  ✗${C_RESET}  %s\n" "$1" >&2; }
hr()   { printf "  ${C_DIM}%s${C_RESET}\n" "────────────────────────────────────"; }

step() {   # step <n> <total> <title>
    echo ""
    printf "  ${C_BOLD_CYAN}Step $1/$2${C_RESET}${C_BOLD} — $3${C_RESET}\n"
    hr
}

# Prompt with dimmed default
ask() {
    local prompt="$1" default="$2"
    if [[ -t 0 ]]; then
        local ans
        printf "  ${C_BOLD}%s${C_RESET} ${C_DIM}[%s]${C_RESET}: " "$prompt" "$default" >&2
        read -r ans
        echo "${ans:-$default}"
    else
        echo "$default"
    fi
}

# Yes/no with dimmed default
yn() {
    local prompt="$1" default="${2:-false}"
    local norm_default
    case "$default" in y|Y|yes|true) norm_default="true";; *) norm_default="false";; esac
    local display; [[ "$norm_default" == "true" ]] && display="Y/n" || display="y/N"
    if [[ -t 0 ]]; then
        local ans
        printf "  ${C_BOLD}%s${C_RESET} ${C_DIM}[%s]${C_RESET}: " "$prompt" "$display" >&2
        read -r ans
        case "${ans:-$norm_default}" in
            y|Y|yes|true) echo "true" ;;
            *)             echo "false" ;;
        esac
    else
        echo "$norm_default"
    fi
}

# ── Header ────────────────────────────────────────────────────
echo ""
printf "  ${C_BOLD_CYAN}Claude Session Manager${C_RESET} ${C_DIM}— Setup Wizard${C_RESET}\n"
echo ""
printf "  ${C_DIM}Press Enter on any prompt to accept the [default].${C_RESET}\n"

# ── Step 1: Work hours ────────────────────────────────────────
step 1 5 "Work Hours"
echo ""
printf "  ${C_DIM}Used to calculate the best session start times for your schedule.${C_RESET}\n"
echo ""
USE_INFERENCE=$(yn "Suggest session times from your work hours?" "y")
echo ""
WORK_START=$(ask "Work start  (HH:MM, 24h)" "${WORK_START:-$DEFAULT_WORK_START}")
WORK_END=$(ask   "Work end    (HH:MM, 24h)" "${WORK_END:-$DEFAULT_WORK_END}")

for t in "$WORK_START" "$WORK_END"; do
    if ! [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        err "Invalid time: $t — use HH:MM format (e.g. 09:00)"; exit 1
    fi
done

# ── Step 2: Session times ─────────────────────────────────────
step 2 5 "Session Schedule"
echo ""

if [[ "$USE_INFERENCE" == "true" ]]; then
    SUGGESTED=$(suggest_session_times "$WORK_START" "$WORK_END")
    read -r S1 S2 S3 <<< "$SUGGESTED"
    printf "  ${C_DIM}Suggested for ${C_RESET}${C_BOLD}%s - %s${C_RESET}${C_DIM}:${C_RESET}\n" "$WORK_START" "$WORK_END"
    echo ""
    describe_session_overlap "$WORK_START" "$WORK_END" "$S1" "$S2" "$S3"
    echo ""
    USE_SUGGESTED=$(yn "Use these times?" "y")
    if [[ "$USE_SUGGESTED" == "true" ]]; then
        SESSION_TIMES=("$S1" "$S2" "$S3")
    else
        _current="${SESSION_TIMES[*]:-$S1,$S2,$S3}"
        _current_csv="${_current// /,}"
        while true; do
            CUSTOM=$(ask "Session times  (HH:MM, comma-separated, e.g. 07:00,12:00,17:00)" "$_current_csv")
            IFS=',' read -r -a SESSION_TIMES <<< "$CUSTOM"
            _valid=true
            for _t in "${SESSION_TIMES[@]}"; do
                _t="${_t// /}"
                if ! [[ "$_t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                    err "Invalid time: '$_t' — use HH:MM with a colon, e.g. 10:20  (not 10h20)"
                    _valid=false; break
                fi
            done
            [[ "$_valid" == "true" ]] && break
        done
    fi
else
    _current_csv="${SESSION_TIMES[*]:-}"
    _current_csv="${_current_csv// /,}"
    [[ -z "$_current_csv" ]] && _current_csv="09:00,13:00,17:00"
    while true; do
        CUSTOM=$(ask "Session times  (HH:MM, comma-separated, e.g. 07:00,12:00,17:00)" "$_current_csv")
        IFS=',' read -r -a SESSION_TIMES <<< "$CUSTOM"
        _valid=true
        for _t in "${SESSION_TIMES[@]}"; do
            _t="${_t// /}"
            if ! [[ "$_t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                err "Invalid time: '$_t' — use HH:MM with a colon, e.g. 10:20  (not 10h20)"
                _valid=false; break
            fi
        done
        [[ "$_valid" == "true" ]] && break
    done
fi

# ── Step 3: Model ─────────────────────────────────────────────
step 3 5 "Claude Model"
echo ""
printf "  ${C_DIM}Model used for the trigger prompt. Haiku is cheapest and more than enough.${C_RESET}\n"
echo ""

case "${CLAUDE_MODEL:-}" in
    *sonnet*) _md="2" ;; *opus*) _md="3" ;; *) _md="1" ;;
esac

_row() {   # _row <number> <is_default> <code> <id> <note>
    local num="$1" is_def="$2" code="$3" id="$4" note="$5"
    if [[ "$is_def" == "true" ]]; then
        printf "  ${C_BOLD_GREEN}%s)${C_RESET}  ${C_BOLD}%-8s${C_RESET}  ${C_DIM}%s${C_RESET}  ${C_BOLD_GREEN}%s${C_RESET}\n" \
            "$num" "$code" "$id" "$note"
    else
        printf "  ${C_DIM}%s)${C_RESET}  %-8s  ${C_DIM}%s${C_RESET}\n" "$num" "$code" "$id"
    fi
}

_row 1 "$([[ $_md == 1 ]] && echo true || echo false)" "haiku"  "$CLAUDE_MODEL_HAIKU"   "cheapest — recommended"
_row 2 "$([[ $_md == 2 ]] && echo true || echo false)" "sonnet" "$CLAUDE_MODEL_SONNET"  ""
_row 3 "$([[ $_md == 3 ]] && echo true || echo false)" "opus"   "$CLAUDE_MODEL_OPUS"    ""
echo ""
MODEL_CHOICE=$(ask "Choice" "$_md")
case "$MODEL_CHOICE" in
    2) CLAUDE_MODEL="$CLAUDE_MODEL_SONNET" ;;
    3) CLAUDE_MODEL="$CLAUDE_MODEL_OPUS" ;;
    *) CLAUDE_MODEL="$CLAUDE_MODEL_HAIKU" ;;
esac

# ── Step 4: Schedule preferences ─────────────────────────────
step 4 5 "Schedule Preferences"
echo ""
printf "  ${C_DIM}Controls which days the Mac wakes and Claude runs.${C_RESET}\n"
echo ""
SCHEDULE_WEEKENDS=$(yn "Include weekends?  (Sat/Sun)" "${SCHEDULE_WEEKENDS:-$DEFAULT_SCHEDULE_WEEKENDS}")
SCHEDULE_HOLIDAYS=$(yn "Include holidays?" "${SCHEDULE_HOLIDAYS:-$DEFAULT_SCHEDULE_HOLIDAYS}")
echo ""
while true; do
    SCHEDULE_DAYS_AHEAD=$(ask "Days to pre-schedule  (30 = 1 month · 365 = 1 year)" "${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}")
    [[ "$SCHEDULE_DAYS_AHEAD" =~ ^[0-9]+$ ]] && (( SCHEDULE_DAYS_AHEAD > 0 )) && break
    err "Must be a positive number, e.g. $DEFAULT_SCHEDULE_DAYS_AHEAD"
done

# ── Step 5: Country holidays ──────────────────────────────────
step 5 5 "Holiday Calendar"
echo ""
printf "  ${C_DIM}Public holidays are skipped automatically. Enter number or code.${C_RESET}\n"
echo ""

_crow() {   # _crow <number> <code> <label> <is_default>
    local num="$1" code="$2" label="$3" is_def="${4:-false}"
    if [[ "$is_def" == "true" ]]; then
        printf "  ${C_BOLD_GREEN}%s)${C_RESET}  ${C_BOLD}%-4s${C_RESET}  ${C_BOLD_GREEN}%-36s${C_RESET}${C_DIM}(default)${C_RESET}\n" \
            "$num" "$code" "$label"
    else
        printf "  ${C_DIM}%s)${C_RESET}  %-4s  %s\n" "$num" "$code" "$label"
    fi
}

_def="${HOLIDAY_COUNTRY:-$DEFAULT_HOLIDAY_COUNTRY}"
_crow 0 ""   "None — manage manually in config.sh"   "$([[ -z $_def ]] && echo true || echo false)"
_crow 1 "br" "Brazil / Brasil"                        "$([[ $_def == br ]] && echo true || echo false)"
_crow 2 "us" "United States"                          "$([[ $_def == us ]] && echo true || echo false)"
_crow 3 "uk" "United Kingdom (England & Wales)"       "$([[ $_def == uk ]] && echo true || echo false)"
_crow 4 "de" "Germany / Deutschland"                  "$([[ $_def == de ]] && echo true || echo false)"
_crow 5 "fr" "France"                                 "$([[ $_def == fr ]] && echo true || echo false)"
_crow 6 "pt" "Portugal"                               "$([[ $_def == pt ]] && echo true || echo false)"
_crow 7 "ar" "Argentina"                              "$([[ $_def == ar ]] && echo true || echo false)"
_crow 8 "mx" "Mexico / Mexico"                        "$([[ $_def == mx ]] && echo true || echo false)"
_crow 9 "nl" "Netherlands / Nederland"                "$([[ $_def == nl ]] && echo true || echo false)"
echo ""

_country_choice=$(ask "Country" "$_def")

case "$_country_choice" in
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
        if [[ -f "$PROJECT_DIR/holidays/${_country_choice}.sh" ]]; then
            HOLIDAY_COUNTRY="$_country_choice"
        else
            warn "Unknown code '${_country_choice}'. Setting to none."
            HOLIDAY_COUNTRY=""
        fi
        ;;
esac

if [[ -n "$HOLIDAY_COUNTRY" ]]; then
    ok "Holidays: holidays/${HOLIDAY_COUNTRY}.sh"
else
    warn "No country selected — add dates manually to HOLIDAYS=() in config.sh"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo ""
printf "  ${C_BOLD}Summary${C_RESET}\n"
hr

_srow() { printf "  ${C_DIM}%-20s${C_RESET}  ${C_BOLD}%s${C_RESET}\n" "$1" "$2"; }
_srow "Work hours"      "${WORK_START} - ${WORK_END}"
_srow "Session times"   "${SESSION_TIMES[*]}"
_srow "Model"           "$CLAUDE_MODEL"
_srow "Weekends"        "$([[ $SCHEDULE_WEEKENDS == true ]] && echo Yes || echo No)"
_srow "Holidays"        "$([[ $SCHEDULE_HOLIDAYS == true ]] && echo Yes || echo "No${HOLIDAY_COUNTRY:+ (${HOLIDAY_COUNTRY} file)}")"
_srow "Pre-schedule"    "${SCHEDULE_DAYS_AHEAD} days"

hr
echo ""
CONFIRM=$(yn "Confirm and install?" "y")
[[ "$CONFIRM" != "true" ]] && { echo "  Aborted."; exit 0; }

echo ""
printf "  ${C_BOLD}Installing…${C_RESET}\n"
hr
echo ""

# ── Write config.sh ───────────────────────────────────────────
TIMES_STR=""; for t in "${SESSION_TIMES[@]}"; do TIMES_STR+="\"$t\" "; done
TIMES_STR="${TIMES_STR% }"

cat > "$PROJECT_DIR/config.sh" <<CFG
#!/usr/bin/env bash
# Generated by install.sh — edit manually or run: bash reconfigure.sh

SESSION_TIMES=(${TIMES_STR})
SESSION_MIN_GAP=${DEFAULT_SESSION_MIN_GAP}

WORK_START="${WORK_START}"
WORK_END="${WORK_END}"

CLAUDE_MODEL="${CLAUDE_MODEL}"
CLAUDE_BIN="${CLAUDE_BIN:-}"

INITIAL_PROMPT="${INITIAL_PROMPT:-${DEFAULT_INITIAL_PROMPT}}"

# Flags passed to every headless session. Reduce token usage for simple trigger prompts.
# Set CLAUDE_EXTRA_FLAGS="" and CLAUDE_DISABLE_TOOLS=false if your prompt needs tools/MCP.
CLAUDE_EXTRA_FLAGS="${CLAUDE_EXTRA_FLAGS:-${DEFAULT_CLAUDE_EXTRA_FLAGS}}"
CLAUDE_DISABLE_TOOLS=${CLAUDE_DISABLE_TOOLS:-${DEFAULT_CLAUDE_DISABLE_TOOLS}}

AUTO_SLEEP=${AUTO_SLEEP:-${DEFAULT_AUTO_SLEEP}}
SLEEP_DELAY=${SLEEP_DELAY:-${DEFAULT_SLEEP_DELAY}}
WAKE_OFFSET_SECS=${WAKE_OFFSET_SECS:-${DEFAULT_WAKE_OFFSET_SECS}}

# ── Schedule preferences ──────────────────────────────────────
SCHEDULE_WEEKENDS=${SCHEDULE_WEEKENDS}
SCHEDULE_HOLIDAYS=${SCHEDULE_HOLIDAYS}
SCHEDULE_DAYS_AHEAD=${SCHEDULE_DAYS_AHEAD}

# Country code for automatic holiday loading (holidays/<country>.sh).
# Supported: br us uk de fr pt ar mx  — or "" to manage manually.
HOLIDAY_COUNTRY="${HOLIDAY_COUNTRY}"

# Manual overrides: merged with the country file above.
# Add city/state holidays not covered by holidays/<country>.sh.
HOLIDAYS=(
    # "2026-06-15"   # Example: local/municipal holiday
)

STATE_DIR="\$HOME/.claude-session-manager"
LOG_FILE="\$STATE_DIR/session.log"
LAST_SESSION_FILE="\$STATE_DIR/last_session"
CFG
ok "config.sh written."

# ── Install scripts to TCC-safe location ─────────────────────
STATE_DIR="$HOME/.claude-session-manager"
mkdir -p "$STATE_DIR" "$INSTALL_DIR"

for dir in src platforms holidays; do
    rm -rf "$INSTALL_DIR/$dir"
    cp -R "$PROJECT_DIR/$dir" "$INSTALL_DIR/"
done
cp "$PROJECT_DIR/config.sh" "$INSTALL_DIR/"

find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
ok "Scripts installed to: $INSTALL_DIR"

# ── LaunchAgent ───────────────────────────────────────────────
SESSION_TIMES=("${SESSION_TIMES[@]}")
generate_plist "$INSTALL_DIR/src/session.sh" "$STATE_DIR"
load_scheduler
ok "LaunchAgent loaded."

# ── pmset wake schedule ───────────────────────────────────────
echo ""
info "Wake schedule: ${SCHEDULE_DAYS_AHEAD} days · weekends: ${SCHEDULE_WEEKENDS} · holidays: ${SCHEDULE_HOLIDAYS}"
echo ""

if [[ -t 0 ]]; then
    APPLY=$(yn "Apply wake schedule now?  (requires sudo)" "y")
    if [[ "$APPLY" == "true" ]]; then
        source "$INSTALL_DIR/config.sh"
        source "$INSTALL_DIR/src/utils.sh"
        source "$INSTALL_DIR/platforms/macos/wake.sh"
        cancel_our_wake_events   # clear any events from a previous install
        schedule_upcoming_days "$SCHEDULE_DAYS_AHEAD" run
        ok "Wake events scheduled for ${SCHEDULE_DAYS_AHEAD} days."
    else
        warn "Skipped. Run anytime: bash src/wake-scheduler.sh"
    fi
else
    warn "Non-interactive: skipping pmset. Run: bash src/wake-scheduler.sh"
fi

# ── Passwordless sudo for pmset (optional) ───────────────────
# Allows session.sh to auto-extend the rolling wake window without
# prompting for a password every time.
if [[ -t 0 ]]; then
    echo ""
    printf "  ${C_DIM}Without passwordless sudo, the rolling wake window cannot extend${C_RESET}\n"
    printf "  ${C_DIM}automatically after each session — you'd need to run${C_RESET}\n"
    printf "  ${C_DIM}'bash src/wake-scheduler.sh' manually once a year.${C_RESET}\n"
    echo ""
    SETUP_SUDO=$(yn "Set up passwordless sudo for pmset?  (recommended)" "y")
    if [[ "$SETUP_SUDO" == "true" ]]; then
        _setup_passwordless_sudo
    else
        warn "Skipped. Run anytime: bash src/setup-sudo.sh"
    fi
fi

# ── Clear stale session guard ─────────────────────────────────
rm -f "${STATE_DIR}/last_session"

# ── Done ──────────────────────────────────────────────────────
echo ""
hr
printf "  ${C_BOLD_GREEN}Installation complete!${C_RESET}\n"
hr
echo ""
printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Sessions:"      "${SESSION_TIMES[*]}"
printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Model:"         "$CLAUDE_MODEL"
printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Schedule:"      "${SCHEDULE_DAYS_AHEAD} days ahead"
printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Log:"           "$STATE_DIR/session.log"
echo ""

# Warn if any session's wake time is less than 10 minutes away — too tight for pmset
_now_min=$(( 10#$(date '+%H') * 60 + 10#$(date '+%M') ))
_offset_min=$(( ${WAKE_OFFSET_SECS:-$DEFAULT_WAKE_OFFSET_SECS} / 60 ))
for _t in "${SESSION_TIMES[@]}"; do
    _sh="${_t%%:*}"; _sh="${_sh#0}"; _sh="${_sh:-0}"
    _sm="${_t##*:}"; _sm="${_sm#0}"; _sm="${_sm:-0}"
    _sess_min=$(( _sh * 60 + _sm ))
    _wake_min=$(( _sess_min - _offset_min ))
    (( _wake_min < 0 )) && _wake_min=$(( _wake_min + 1440 ))
    _mins_until_wake=$(( _wake_min - _now_min ))
    if (( _mins_until_wake > 0 && _mins_until_wake < 10 )); then
        warn "Session ${_t}: wake event is only ${_mins_until_wake} min away — pmset may not fire in time."
        warn "For reliable wake, configure sessions at least 15 min in the future."
    fi
done

printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Test now:"   "launchctl start com.claude.session.manager"
printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Run tests:"  "bash tests/run_tests.sh"
printf "  ${C_DIM}%-22s${C_RESET}  %s\n" "Uninstall:"  "bash uninstall.sh"
echo ""
hr
printf "  ${C_BOLD}Para qualquer alteração futura — horários, modelo, feriados — use:${C_RESET}\n"
echo ""
printf "  ${C_BOLD_CYAN}    bash reconfigure.sh${C_RESET}\n"
echo ""
