#!/usr/bin/env bash
# ============================================================
# src/ensure-config.sh — Guarantees config.sh exists.
# Source this before sourcing config.sh in any script.
# Also makes DEFAULT_* variables available to the caller.
# ============================================================

_ec_src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ec_root="$(dirname "$_ec_src")"

source "$_ec_src/defaults.sh"

if [[ ! -f "$_ec_root/config.sh" ]]; then
    printf '\033[1;33m[WARN]\033[0m  config.sh not found — regenerating from defaults.\n'
    printf '        Run: bash reconfigure.sh  to customize your settings.\n'

    # Cancel any hardware wake events scheduled under the old config.
    # The new config will have different session times (default values),
    # so stale pmset events would fire at wrong times.
    _tracking="$HOME/.claude-session-manager/scheduled_wakes"
    if [[ -f "$_tracking" ]] && command -v pmset &>/dev/null; then
        printf '\033[1;33m[WARN]\033[0m  Cancelling stale hardware wake events...\n'
        while IFS= read -r _event; do
            sudo pmset schedule cancel wake "$_event" 2>/dev/null || true
        done < "$_tracking"
        rm -f "$_tracking"
        printf '\033[1;33m[WARN]\033[0m  Wake events cleared. Run: bash src/wake-scheduler.sh  to reschedule.\n'
    fi

    cat > "$_ec_root/config.sh" <<CFG
#!/usr/bin/env bash
# Regenerated from defaults — run: bash reconfigure.sh to customize

SESSION_TIMES=("09:00" "13:00" "17:00")
SESSION_MIN_GAP=${DEFAULT_SESSION_MIN_GAP}

WORK_START="${DEFAULT_WORK_START}"
WORK_END="${DEFAULT_WORK_END}"

CLAUDE_MODEL="${DEFAULT_CLAUDE_MODEL}"
CLAUDE_BIN=""

INITIAL_PROMPT="${DEFAULT_INITIAL_PROMPT}"

CLAUDE_EXTRA_FLAGS="${DEFAULT_CLAUDE_EXTRA_FLAGS}"
CLAUDE_DISABLE_TOOLS=${DEFAULT_CLAUDE_DISABLE_TOOLS}

AUTO_SLEEP=${DEFAULT_AUTO_SLEEP}
SLEEP_DELAY=${DEFAULT_SLEEP_DELAY}
WAKE_OFFSET_SECS=${DEFAULT_WAKE_OFFSET_SECS}

# ── Schedule preferences ──────────────────────────────────────
SCHEDULE_WEEKENDS=${DEFAULT_SCHEDULE_WEEKENDS}
SCHEDULE_HOLIDAYS=${DEFAULT_SCHEDULE_HOLIDAYS}
SCHEDULE_DAYS_AHEAD=${DEFAULT_SCHEDULE_DAYS_AHEAD}

HOLIDAY_COUNTRY="${DEFAULT_HOLIDAY_COUNTRY}"

HOLIDAYS=(
    # "2026-06-15"   # Example: local/municipal holiday
)

STATE_DIR="\$HOME/.claude-session-manager"
LOG_FILE="\$STATE_DIR/session.log"
LAST_SESSION_FILE="\$STATE_DIR/last_session"
CFG
fi

unset _ec_src _ec_root
