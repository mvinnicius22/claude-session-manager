#!/usr/bin/env bash
# ============================================================
# unpause.sh — Restart sessions after 'bash pause.sh'.
# Reloads the LaunchAgent and refreshes today's wake events.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/detect_platform.sh"
source "$SCRIPT_DIR/src/ensure-config.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/src/utils.sh"

PLATFORM=$(detect_platform)
PAUSED_FILE="$STATE_DIR/paused"
INSTALL_DIR="$HOME/.local/share/claude-session-manager"

if [[ ! -f "$PAUSED_FILE" ]]; then
    log_info "Sessions are not paused — nothing to resume."
    launchctl list 2>/dev/null | grep -q "com.claude.session.manager" \
        && log_ok "LaunchAgent is already active." \
        || log_warn "LaunchAgent is not loaded. Run 'bash install.sh' first."
    exit 0
fi

PAUSED_SINCE=$(cat "$PAUSED_FILE")

case "$PLATFORM" in
    macos)
        source "$SCRIPT_DIR/platforms/macos/scheduler.sh"
        source "$INSTALL_DIR/platforms/macos/wake.sh"

        load_scheduler && log_ok "LaunchAgent loaded — sessions active."

        # Refresh wake events from now onward (events during pause may have lapsed)
        log_info "Refreshing wake schedule…"
        for t in "${SESSION_TIMES[@]}"; do schedule_wake_today "$t" run; done
        log_ok "Today's wake events rescheduled."
        ;;
    linux)
        log_warn "Linux: restart your systemd timer manually:"
        log_warn "  systemctl --user start claude-session.timer"
        ;;
    *)
        log_error "Unsupported platform: $PLATFORM"; exit 1 ;;
esac

rm -f "$PAUSED_FILE"
echo ""
log_ok "Sessions resumed (were paused since: $PAUSED_SINCE)."
log_info "Next sessions: ${SESSION_TIMES[*]}"
echo ""
