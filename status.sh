#!/usr/bin/env bash
# ============================================================
# status.sh — Show current configuration and runtime status.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/detect_platform.sh"
source "$SCRIPT_DIR/src/ensure-config.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/src/utils.sh"

PLATFORM=$(detect_platform)
INSTALL_DIR="$HOME/.local/share/claude-session-manager"
PAUSED_FILE="$STATE_DIR/paused"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_GREEN='\033[0;32m'; C_BOLD_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[0;36m'
C_BOLD_CYAN='\033[1;36m'; C_RED='\033[0;31m'
C_BLUE='\033[0;34m'

hr()     { printf "  ${C_DIM}%s${C_RESET}\n" "────────────────────────────────────"; }
row()    { printf "  ${C_DIM}%-22s${C_RESET}  ${C_BOLD}%s${C_RESET}\n" "$1" "$2"; }
rowdim() { printf "  ${C_DIM}%-22s  %s${C_RESET}\n" "$1" "$2"; }

# ── Header ────────────────────────────────────────────────────
echo ""
printf "  ${C_BOLD_CYAN}Claude Session Manager${C_RESET} ${C_DIM}— Status${C_RESET}\n"
hr

# ── Configuration ─────────────────────────────────────────────
echo ""
printf "  ${C_BOLD}Configuration${C_RESET}\n"
echo ""

row "Work hours"     "${WORK_START} – ${WORK_END}"
row "Session times"  "${SESSION_TIMES[*]}"
row "Model"          "${CLAUDE_MODEL}"

_weekend_label="$([[ ${SCHEDULE_WEEKENDS:-$DEFAULT_SCHEDULE_WEEKENDS} == true ]] && echo Yes || echo No)"
_holiday_label="$([[ ${SCHEDULE_HOLIDAYS:-$DEFAULT_SCHEDULE_HOLIDAYS} == true ]] && echo Yes || echo "No${HOLIDAY_COUNTRY:+ (${HOLIDAY_COUNTRY})}")"
row "Weekends"       "$_weekend_label"
row "Holidays"       "$_holiday_label"
row "Pre-schedule"   "${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD} days"

if [[ -n "${INITIAL_PROMPT:-}" ]]; then
    row "Initial prompt" "${INITIAL_PROMPT}"
fi

if [[ -n "${CLAUDE_BIN:-}" ]]; then
    row "Claude binary"  "${CLAUDE_BIN}"
fi

# ── Runtime status ────────────────────────────────────────────
echo ""
hr
echo ""
printf "  ${C_BOLD}Runtime${C_RESET}\n"
echo ""

# Paused?
if [[ -f "$PAUSED_FILE" ]]; then
    _paused_since=$(cat "$PAUSED_FILE")
    printf "  ${C_YELLOW}  ⚠${C_RESET}  %-20s  ${C_YELLOW}Paused${C_RESET} ${C_DIM}(since %s)${C_RESET}\n" "Scheduler:" "$_paused_since"
    printf "  ${C_DIM}     Run 'bash unpause.sh' to restart.${C_RESET}\n"
else
    case "$PLATFORM" in
        macos)
            source "$SCRIPT_DIR/platforms/macos/scheduler.sh"
            if scheduler_is_loaded 2>/dev/null; then
                printf "  ${C_BOLD_GREEN}  ✓${C_RESET}  %-20s  ${C_BOLD_GREEN}Active${C_RESET}\n" "Scheduler:"
            else
                printf "  ${C_RED}  ✗${C_RESET}  %-20s  ${C_RED}Not loaded${C_RESET} ${C_DIM}— run 'bash install.sh'${C_RESET}\n" "Scheduler:"
            fi
            ;;
        linux)
            if systemctl --user is-active --quiet claude-session.timer 2>/dev/null; then
                printf "  ${C_BOLD_GREEN}  ✓${C_RESET}  %-20s  ${C_BOLD_GREEN}Active${C_RESET}\n" "Scheduler:"
            else
                printf "  ${C_RED}  ✗${C_RESET}  %-20s  ${C_RED}Not active${C_RESET}\n" "Scheduler:"
            fi
            ;;
        *)
            rowdim "Scheduler:" "Unknown platform" ;;
    esac
fi

# Last session
if [[ -f "${LAST_SESSION_FILE:-}" ]]; then
    _last=$(cat "$LAST_SESSION_FILE")
    row "Last session"  "$_last"
else
    rowdim "Last session"   "No session recorded yet"
fi

# Installed copy
if [[ -d "$INSTALL_DIR" ]]; then
    printf "  ${C_BOLD_GREEN}  ✓${C_RESET}  %-20s  ${C_DIM}%s${C_RESET}\n" "Install dir:" "$INSTALL_DIR"
else
    printf "  ${C_YELLOW}  ⚠${C_RESET}  %-20s  ${C_DIM}Not found — run 'bash install.sh'${C_RESET}\n" "Install dir:"
fi

# Passwordless sudo (macOS only)
if [[ "$PLATFORM" == "macos" ]]; then
    if [[ -f "/etc/sudoers.d/claude-session-manager" ]]; then
        printf "  ${C_BOLD_GREEN}  ✓${C_RESET}  %-20s  ${C_DIM}Configured${C_RESET}\n" "Passwordless sudo:"
    else
        printf "  ${C_DIM}  –${C_RESET}  %-20s  ${C_DIM}Not configured — run 'bash src/setup-sudo.sh'${C_RESET}\n" "Passwordless sudo:"
    fi
fi

# Log file
if [[ -f "${LOG_FILE:-}" ]]; then
    _lines=$(wc -l < "$LOG_FILE" | tr -d ' ')
    row "Log"           "$LOG_FILE  ($_lines lines)"
else
    rowdim "Log"           "${LOG_FILE:-~/.claude-session-manager/session.log}  (empty)"
fi

# ── Next sessions (today) ─────────────────────────────────────
echo ""
hr
echo ""
printf "  ${C_BOLD}Next sessions today${C_RESET}\n"
echo ""

_now_h=$(date '+%H'); _now_h="${_now_h#0}"; _now_h="${_now_h:-0}"
_now_m=$(date '+%M'); _now_m="${_now_m#0}"; _now_m="${_now_m:-0}"
_now_min=$(( _now_h * 60 + _now_m ))
_found_next=false

for _t in "${SESSION_TIMES[@]}"; do
    _sh="${_t%%:*}"; _sh="${_sh#0}"; _sh="${_sh:-0}"
    _sm="${_t##*:}"; _sm="${_sm#0}"; _sm="${_sm:-0}"
    _sess_min=$(( _sh * 60 + _sm ))
    _wake_min=$(( _sess_min - ${WAKE_OFFSET_SECS:-$DEFAULT_WAKE_OFFSET_SECS} / 60 ))
    if (( _sess_min > _now_min )); then
        _mins_until=$(( _sess_min - _now_min ))
        if (( _mins_until >= 60 )); then
            _fmt_h=$(( _mins_until / 60 ))
            _fmt_m=$(( _mins_until % 60 ))
            _fmt="${_fmt_h}h ${_fmt_m}min"
        else
            _fmt="${_mins_until} min"
        fi
        printf "  ${C_BOLD_GREEN}  →${C_RESET}  ${C_BOLD}%s${C_RESET}  ${C_DIM}(in %s)${C_RESET}\n" "$_t" "$_fmt"
        _found_next=true
    else
        printf "  ${C_DIM}     %s  (passed)${C_RESET}\n" "$_t"
    fi
done

if [[ "$_found_next" == false ]]; then
    printf "  ${C_DIM}     All sessions have passed for today.${C_RESET}\n"
fi

# ── Paths ─────────────────────────────────────────────────────
echo ""
hr
echo ""
printf "  ${C_DIM}%-22s${C_RESET}  ${C_DIM}%s${C_RESET}\n" "Config:"  "$SCRIPT_DIR/config.sh"
printf "  ${C_DIM}%-22s${C_RESET}  ${C_DIM}%s${C_RESET}\n" "State:"   "${STATE_DIR}"
printf "  ${C_DIM}%-22s${C_RESET}  ${C_DIM}%s${C_RESET}\n" "Log:"     "${LOG_FILE}"
echo ""
printf "  ${C_DIM}bash reconfigure.sh${C_RESET}   to change settings\n"
echo ""
