#!/usr/bin/env bash
# ============================================================
# tests/platforms/macos/test_lid_simulation.sh — macOS only
# Simulates headless / lid-closed execution scenarios.
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$TESTS_DIR")")")"
INSTALL_DIR="$HOME/.local/share/claude-session-manager"

source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/src/utils.sh"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }
skip() { printf "\033[1;33m⚠\033[0m %s\n" "$1"; SKIP=$(( SKIP + 1 )); }

export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
MODEL="${CLAUDE_MODEL:-$DEFAULT_CLAUDE_MODEL}"

BIN=$(resolve_claude_bin 2>/dev/null) || {
    fail "Claude CLI not found"
    echo ""; echo "lid_simulation: 0 passed, 1 failed, 0 skipped"; exit 1
}

# 1. stdin = /dev/null
RESULT=$("$BIN" -p "lid-sim" --model "$MODEL" < /dev/null 2>&1)
[[ $? -eq 0 && -n "$RESULT" ]] && ok "stdin=/dev/null (no TTY)" \
    || fail "Failed with stdin=/dev/null: $RESULT"

# 2. stdout redirected
TMP=$(mktemp)
"$BIN" -p "lid-sim" --model "$MODEL" > "$TMP" 2>&1
[[ $? -eq 0 && -s "$TMP" ]] && ok "stdout redirected to file" \
    || fail "Failed with redirected stdout: $(cat "$TMP")"
rm -f "$TMP"

# 3. nohup subprocess (detached from terminal)
DOUT=$(mktemp); DDONE=$(mktemp); rm "$DDONE"
( nohup "$BIN" -p "lid-sim" --model "$MODEL" > "$DOUT" 2>&1; touch "$DDONE" ) &
SPID=$!; WAITED=0
while [[ ! -f "$DDONE" && $WAITED -lt 30 ]]; do sleep 1; (( WAITED++ )); done
if [[ -f "$DDONE" && -s "$DOUT" ]]; then
    ok "nohup subprocess completed in ${WAITED}s (simulates background LaunchAgent)"
else
    fail "nohup subprocess timed out after ${WAITED}s"
    kill "$SPID" 2>/dev/null || true
fi
rm -f "$DOUT" "$DDONE"

# 4. Minimal launchd PATH + session.sh augmentation
FOUND=$(PATH="/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin" \
    command -v claude 2>/dev/null || true)
[[ -x "${FOUND:-}" ]] && ok "Claude reachable with launchd PATH + augmentation" \
    || fail "Claude not found with augmented PATH — set CLAUDE_BIN in config.sh"

# 5. session.sh runs headless (exit 0 = guard blocked or session sent)
if [[ -f "$INSTALL_DIR/src/session.sh" ]]; then
    SESS_LOG=$(mktemp)
    bash "$INSTALL_DIR/src/session.sh" >> "$SESS_LOG" 2>&1
    EXIT=$?
    [[ $EXIT -eq 0 ]] && ok "session.sh ran headless via bash subprocess (exit 0)" \
        || fail "session.sh exited $EXIT — $(tail -3 "$SESS_LOG")"
    rm -f "$SESS_LOG"
else
    skip "Installed session.sh not found — run install.sh first"
fi

# 6. LaunchAgent loaded
launchctl list 2>/dev/null | grep -q "com.claude.session.manager" \
    && ok "LaunchAgent active in launchctl" \
    || fail "LaunchAgent not loaded — run install.sh"

echo ""
echo "macos/lid_simulation: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
