#!/usr/bin/env bash
# ============================================================
# tests/platforms/macos/test_dependencies.sh — macOS only
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$TESTS_DIR")")")"
source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }
skip() { printf "\033[1;33m⚠\033[0m %s\n" "$1"; SKIP=$(( SKIP + 1 )); }

[[ "$(uname)" == "Darwin" ]] && ok "macOS confirmed" || { fail "Not macOS"; exit 1; }

for cmd in bash launchctl pmset date plutil; do
    command -v "$cmd" &>/dev/null && ok "Command: $cmd" || fail "Missing: $cmd"
done

[[ -d "$HOME/Library/LaunchAgents" ]] && ok "LaunchAgents dir exists" || fail "LaunchAgents dir missing"

# Platform scheduler functions available
source "$PROJECT_DIR/platforms/macos/scheduler.sh" 2>/dev/null
for fn in generate_plist load_scheduler unload_scheduler scheduler_is_loaded; do
    declare -f "$fn" > /dev/null 2>&1 && ok "Function: $fn()" || fail "Missing function: $fn()"
done

# Platform wake functions available
source "$PROJECT_DIR/platforms/macos/wake.sh" 2>/dev/null
for fn in schedule_wake_today reschedule_wake_events platform_sleep_now; do
    declare -f "$fn" > /dev/null 2>&1 && ok "Function: $fn()" || fail "Missing function: $fn()"
done

echo ""
echo "macos/dependencies: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
