#!/usr/bin/env bash
# ============================================================
# src/session.sh — Cross-platform entry point
# Called by the system scheduler (LaunchAgent / systemd / cron).
# Loads the platform-specific wake hook, then triggers Claude.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/detect_platform.sh"

# Make claude findable in launchd/systemd minimal PATH environments
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# Load platform-specific wake scheduler (optional — gracefully absent)
PLATFORM=$(detect_platform)
PLATFORM_WAKE="$PROJECT_DIR/platforms/$PLATFORM/wake.sh"
[[ -f "$PLATFORM_WAKE" ]] && source "$PLATFORM_WAKE"

main() {
    mkdir -p "$STATE_DIR"
    load_country_holidays   # merge HOLIDAY_COUNTRY file into HOLIDAYS[]

    # Respect explicit pause (belt-and-suspenders alongside LaunchAgent unload)
    if [[ -f "$STATE_DIR/paused" ]]; then
        log_warn "Sessions are paused. Run 'bash unpause.sh' to restart."
        exit 0
    fi

    # Check weekend/holiday rules before triggering.
    # The LaunchAgent fires every day — this is what enforces SCHEDULE_WEEKENDS
    # and SCHEDULE_HOLIDAYS. is_workday() is sourced from platforms/*/wake.sh.
    if declare -f is_workday > /dev/null 2>&1; then
        local today; today=$(date '+%Y-%m-%d')
        if ! is_workday "$today"; then
            log_info "Skipping — $(date '+%A') ($today) is not a scheduled workday (weekends=${SCHEDULE_WEEKENDS:-false}, holidays=${SCHEDULE_HOLIDAYS:-false})."
            exit 0
        fi
    fi

    log_info "Session trigger fired at $(date '+%Y-%m-%d %H:%M:%S') [$PLATFORM]"

    if ! session_allowed; then
        log_info "Skipping — session guard active."
        exit 0
    fi

    record_session
    trigger_claude_session
    log_ok "Claude session triggered successfully."

    # Post-session platform hook: reschedule wake events.
    # pmset failures must never abort the session — use || true.
    if declare -f reschedule_wake_events > /dev/null 2>&1; then
        reschedule_wake_events || true
    fi

    if [[ "${AUTO_SLEEP:-false}" == "true" ]]; then
        if declare -f platform_sleep_now > /dev/null 2>&1; then
            platform_sleep_now
        else
            log_warn "AUTO_SLEEP=true but platform_sleep_now not available on $PLATFORM"
        fi
    fi
}

main "$@"
