#!/usr/bin/env bash
# ============================================================
# ping.sh — Trigger one Claude session immediately.
# Bypasses all guards: no schedule, no workday check, no session
# guard. Uses whatever is set in config.sh. For testing only.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/src/ensure-config.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/src/utils.sh"

export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

echo ""
printf "  Model:   %s\n" "${CLAUDE_MODEL:-$DEFAULT_CLAUDE_MODEL}"
printf "  Prompt:  %s\n" "${INITIAL_PROMPT:-oi}"
echo ""

trigger_claude_session
exit_code=$?

echo ""
if (( exit_code == 0 )); then
    printf "  Done. Check log: %s\n" "${LOG_FILE:-/tmp/claude-session.log}"
else
    printf "  Failed (exit %s). Check log: %s\n" "$exit_code" "${LOG_FILE:-/tmp/claude-session.log}"
fi
echo ""

exit $exit_code
