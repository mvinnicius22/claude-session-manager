#!/usr/bin/env bash
# ============================================================
# tests/platforms/macos/test_permissions.sh — macOS only
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$TESTS_DIR")")")"
source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }
skip() { printf "\033[1;33m⚠\033[0m %s\n" "$1"; SKIP=$(( SKIP + 1 )); }

# Script executability
for f in \
    "$PROJECT_DIR/src/session.sh" \
    "$PROJECT_DIR/src/utils.sh" \
    "$PROJECT_DIR/src/detect_platform.sh" \
    "$PROJECT_DIR/src/suggest_times.sh" \
    "$PROJECT_DIR/platforms/macos/wake.sh" \
    "$PROJECT_DIR/platforms/macos/scheduler.sh"; do
    [[ -x "$f" ]] && ok "Executable: ${f##*/}" || fail "Not executable: $f  (chmod +x $f)"
done

# State dir writable
mkdir -p "$STATE_DIR"
touch "$STATE_DIR/.write_test_$$" 2>/dev/null && rm "$STATE_DIR/.write_test_$$" \
    && ok "State dir writable: $STATE_DIR" || fail "State dir not writable: $STATE_DIR"

# Log file writable
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" 2>/dev/null \
    && ok "Log file writable: $LOG_FILE" || fail "Cannot write: $LOG_FILE"

# LaunchAgent plist
PLIST="$HOME/Library/LaunchAgents/com.claude.session.manager.plist"
if [[ -f "$PLIST" ]]; then
    ok "LaunchAgent plist exists"
    plutil -lint "$PLIST" &>/dev/null && ok "LaunchAgent plist valid XML" \
        || fail "LaunchAgent plist has errors: plutil -lint $PLIST"
else
    skip "LaunchAgent plist not found (run install.sh first)"
fi

# LaunchAgent loaded
launchctl list 2>/dev/null | grep -q "com.claude.session.manager" \
    && ok "LaunchAgent loaded in launchctl" \
    || skip "LaunchAgent not loaded (run install.sh)"

# pmset readable
pmset -g 2>/dev/null | grep -q "hibernatemode\|Sleep On Power Button\|autopoweroff" \
    && ok "pmset is functional" \
    || skip "pmset read inconclusive"

# Installed dir exists
INSTALL_DIR="$HOME/.local/share/claude-session-manager"
[[ -d "$INSTALL_DIR" ]] && ok "Install dir exists: $INSTALL_DIR" \
    || skip "Install dir not found (run install.sh)"

echo ""
echo "macos/permissions: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
