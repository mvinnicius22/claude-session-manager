#!/usr/bin/env bash
# config.example.sh — Default configuration reference.
# Run the interactive wizard:  bash install.sh
# Or copy manually:            cp src/config.example.sh config.sh

_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if   [[ -f "$_dir/defaults.sh" ]];     then source "$_dir/defaults.sh"
elif [[ -f "$_dir/src/defaults.sh" ]]; then source "$_dir/src/defaults.sh"
fi
unset _dir

SESSION_TIMES=("09:00" "13:00" "17:00")
SESSION_MIN_GAP=$DEFAULT_SESSION_MIN_GAP

WORK_START="$DEFAULT_WORK_START"
WORK_END="$DEFAULT_WORK_END"

CLAUDE_MODEL="$DEFAULT_CLAUDE_MODEL"
CLAUDE_BIN=""

INITIAL_PROMPT="$DEFAULT_INITIAL_PROMPT"

AUTO_SLEEP=$DEFAULT_AUTO_SLEEP
SLEEP_DELAY=$DEFAULT_SLEEP_DELAY
WAKE_OFFSET_SECS=$DEFAULT_WAKE_OFFSET_SECS

# ── Schedule preferences ──────────────────────────────────────
SCHEDULE_WEEKENDS=$DEFAULT_SCHEDULE_WEEKENDS
SCHEDULE_HOLIDAYS=$DEFAULT_SCHEDULE_HOLIDAYS
SCHEDULE_DAYS_AHEAD=$DEFAULT_SCHEDULE_DAYS_AHEAD

HOLIDAY_COUNTRY="$DEFAULT_HOLIDAY_COUNTRY"

HOLIDAYS=(
    # "2026-06-15"   # Example: local/municipal holiday
)

STATE_DIR="$HOME/.claude-session-manager"
LOG_FILE="$STATE_DIR/session.log"
LAST_SESSION_FILE="$STATE_DIR/last_session"
