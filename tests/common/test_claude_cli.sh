#!/usr/bin/env bash
# ============================================================
# tests/common/test_claude_cli.sh — Cross-platform
# Tests Claude CLI binary: discovery, auth, headless execution.
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$TESTS_DIR")")"

source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/src/utils.sh"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }
skip() { printf "\033[1;33m⚠\033[0m %s\n" "$1"; SKIP=$(( SKIP + 1 )); }

export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
MODEL="${CLAUDE_MODEL:-$DEFAULT_CLAUDE_MODEL}"

# ── Binary discovery ──────────────────────────────────────────
BIN=$(resolve_claude_bin 2>/dev/null) || BIN=""
[[ -n "$BIN" ]] && ok "Claude CLI found: $BIN" || { fail "Claude CLI not found — install: https://claude.ai/code"; exit 1; }

# ── Version ───────────────────────────────────────────────────
VERSION=$("$BIN" --version 2>&1 | head -1)
[[ -n "$VERSION" ]] && ok "Version: $VERSION" || fail "claude --version returned empty"

# ── Authentication (real API call) ────────────────────────────
AUTH_RESULT=$("$BIN" -p "ping" --model "$MODEL" 2>&1)
if [[ $? -eq 0 && -n "$AUTH_RESULT" ]]; then
    ok "Authenticated and responding (model: $MODEL)"
else
    fail "Not authenticated or API error: $AUTH_RESULT"
fi

# ── Headless: stdin = /dev/null ───────────────────────────────
RESULT=$("$BIN" -p "test" --model "$MODEL" < /dev/null 2>&1)
[[ $? -eq 0 && -n "$RESULT" ]] \
    && ok "Headless: works with stdin=/dev/null" \
    || fail "Headless: failed with stdin=/dev/null: $RESULT"

# ── Headless: stdout redirected ───────────────────────────────
TMP=$(mktemp)
"$BIN" -p "test" --model "$MODEL" > "$TMP" 2>&1
[[ $? -eq 0 && -s "$TMP" ]] \
    && ok "Headless: works with stdout redirected to file" \
    || fail "Headless: failed with redirected stdout: $(cat "$TMP")"
rm -f "$TMP"

# ── Headless: nohup subprocess ───────────────────────────────
DOUT=$(mktemp); DDONE=$(mktemp); rm "$DDONE"
( nohup "$BIN" -p "test" --model "$MODEL" > "$DOUT" 2>&1; touch "$DDONE" ) &
SPID=$!
WAITED=0
while [[ ! -f "$DDONE" && $WAITED -lt 30 ]]; do sleep 1; (( WAITED++ )); done
if [[ -f "$DDONE" && -s "$DOUT" ]]; then
    ok "Headless: works in nohup subprocess (${WAITED}s)"
else
    fail "Headless: nohup subprocess timed out or empty after ${WAITED}s"
    kill "$SPID" 2>/dev/null || true
fi
rm -f "$DOUT" "$DDONE"

# ── PATH augmentation mirrors session.sh ─────────────────────
LAUNCHD_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
FOUND=$(PATH="$LAUNCHD_PATH:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin" \
    command -v claude 2>/dev/null || true)
[[ -x "${FOUND:-}" ]] \
    && ok "Claude reachable with session.sh PATH augmentation" \
    || fail "Claude not found even with augmented PATH — set CLAUDE_BIN in config.sh"

echo ""
echo "claude_cli: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
