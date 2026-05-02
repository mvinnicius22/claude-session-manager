#!/usr/bin/env bash
# ============================================================
# platforms/linux/wake.sh — Linux (NOT YET IMPLEMENTED)
#
# Linux equivalent of platforms/macos/wake.sh.
# Replace pmset with rtcwake:
#
#   sudo rtcwake -m no -t $(date -d "tomorrow 05:29" +%s)
#
# reschedule_wake_events() and platform_sleep_now() must be
# implemented here so src/session.sh can call them generically.
# ============================================================

_lwake_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$(dirname "$_lwake_dir")")/src/defaults.sh"
unset _lwake_dir

reschedule_wake_events() {
    printf '[WARN] reschedule_wake_events not implemented on Linux.\n' >&2
}

platform_sleep_now() {
    local delay="${SLEEP_DELAY:-$DEFAULT_SLEEP_DELAY}"
    sleep "$delay"
    systemctl suspend 2>/dev/null || loginctl suspend 2>/dev/null || \
        printf '[ERROR] Cannot suspend on this Linux system.\n' >&2
}
