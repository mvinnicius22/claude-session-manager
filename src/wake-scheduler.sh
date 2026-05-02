#!/usr/bin/env bash
# ============================================================
# src/wake-scheduler.sh — macOS only (delegates to platform)
#
# Schedules pmset wake events for the next SCHEDULE_DAYS_AHEAD
# days, filtering out weekends and holidays per config.sh.
#
# Usage:
#   bash src/wake-scheduler.sh            # schedule (requires sudo)
#   bash src/wake-scheduler.sh dry-run    # preview without applying
#   bash src/wake-scheduler.sh --days 30  # override days ahead
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/detect_platform.sh"

PLATFORM=$(detect_platform)

if [[ "$PLATFORM" != "macos" ]]; then
    printf '[ERROR] wake-scheduler.sh only works on macOS.\n' >&2
    printf '        Linux equivalent: rtcwake (see platforms/linux/wake.sh)\n' >&2
    exit 1
fi

source "$PROJECT_DIR/platforms/macos/wake.sh"

load_country_holidays   # merge HOLIDAY_COUNTRY file into HOLIDAYS[]

# Parse args
MODE="run"
DAYS="${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}"
for arg in "$@"; do
    case "$arg" in
        dry-run) MODE="dry-run" ;;
        --days=*) DAYS="${arg#--days=}" ;;
        --days)   shift; DAYS="$1" ;;
    esac
done

BOLD='\033[1m'; NC='\033[0m'
echo ""
printf "${BOLD}Claude Session Manager — Wake Scheduler${NC}\n"
echo "──────────────────────────────────────────"
printf "  Platform:   macOS\n"
printf "  Days ahead: %s\n" "$DAYS"
printf "  Weekends:   %s\n" "${SCHEDULE_WEEKENDS:-false}"
printf "  Holidays:   %s\n" "${SCHEDULE_HOLIDAYS:-false}"
[[ ${#HOLIDAYS[@]:-0} -gt 0 ]] && printf "  Holiday dates: %s\n" "${HOLIDAYS[*]}"
echo ""

if [[ "$MODE" == "dry-run" ]]; then
    echo "DRY RUN — commands that would be executed:"
    echo ""
fi

schedule_upcoming_days "$DAYS" "$MODE"

echo ""
if [[ "$MODE" == "dry-run" ]]; then
    printf "  Run without 'dry-run' to apply (requires sudo).\n"
else
    log_ok "Wake schedule set for the next ${DAYS} days."
    printf "  Tip: add holidays to HOLIDAYS=() in config.sh to skip them.\n"
fi
echo ""
