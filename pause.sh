#!/usr/bin/env bash
# ============================================================
# pause.sh — Temporarily stop all sessions without uninstalling.
# The LaunchAgent is unloaded; wake events remain but are harmless
# (Mac wakes, nothing runs, goes back to sleep).
# Run 'bash unpause.sh' to restart.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/detect_platform.sh"
source "$SCRIPT_DIR/src/ensure-config.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/src/utils.sh"

PLATFORM=$(detect_platform)
PAUSED_FILE="$STATE_DIR/paused"

if [[ -f "$PAUSED_FILE" ]]; then
    log_warn "Sessions are already paused (since $(cat "$PAUSED_FILE"))."
    log_info "Run 'bash unpause.sh' to restart."
    exit 0
fi

case "$PLATFORM" in
    macos)
        source "$SCRIPT_DIR/platforms/macos/scheduler.sh"
        if scheduler_is_loaded; then
            unload_scheduler && log_ok "LaunchAgent unloaded — sessions paused."
        else
            log_info "LaunchAgent was already unloaded."
        fi
        ;;
    linux)
        log_warn "Linux: stop your systemd timer manually:"
        log_warn "  systemctl --user stop claude-session.timer"
        ;;
    *)
        log_error "Unsupported platform: $PLATFORM"; exit 1 ;;
esac

mkdir -p "$STATE_DIR"
date '+%Y-%m-%d %H:%M:%S' > "$PAUSED_FILE"
echo ""
log_ok "Sessions paused."
log_info "Run 'bash unpause.sh' to restart sessions."
echo ""
