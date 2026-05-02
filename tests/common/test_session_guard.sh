#!/usr/bin/env bash
# ============================================================
# tests/common/test_session_guard.sh — Cross-platform
#
# The guard threshold is DYNAMIC: half the smallest gap between
# configured SESSION_TIMES, floored at 60 s.
# With default sessions 5 h apart → threshold = 2.5 h = 9000 s.
# With sessions 5 min apart       → threshold = 2.5 min = 150 s.
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$TESTS_DIR")")"

source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/src/utils.sh"

PASS=0; FAIL=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }

TMP_LAST=$(mktemp)
export LAST_SESSION_FILE="$TMP_LAST"
export LOG_FILE="/dev/null"
cleanup() { rm -f "$TMP_LAST"; }
trap cleanup EXIT

# ── Determine the effective threshold for current SESSION_TIMES ───
# (mirrors _guard_threshold logic so we can assert correctly)
_effective_threshold() {
    local min_gap=0 prev=-1
    for t in "${SESSION_TIMES[@]:-}"; do
        local h="${t%%:*}"; h="${h#0}"; h="${h:-0}"
        local m="${t##*:}"; m="${m#0}"; m="${m:-0}"
        local cur=$(( h * 60 + m ))
        if (( prev >= 0 && cur > prev )); then
            local g=$(( (cur - prev) * 60 ))
            (( min_gap == 0 || g < min_gap )) && min_gap=$g
        fi
        prev=$cur
    done
    if (( min_gap > 0 )); then
        local half=$(( min_gap / 2 ))
        echo $(( half < 60 ? 60 : half ))
    else
        echo "${SESSION_MIN_GAP:-$DEFAULT_SESSION_MIN_GAP}"
    fi
}

THRESHOLD=$(_effective_threshold)
THRESHOLD_MIN=$(( THRESHOLD / 60 ))

# ── Tests ─────────────────────────────────────────────────────

# 1. No file → always allowed
rm -f "$TMP_LAST"
session_allowed 2>/dev/null && ok "Allowed: no previous session file" \
    || fail "Should allow when no file exists"

# 2. Just ran (0s ago) → blocked
date +%s > "$TMP_LAST"
session_allowed 2>/dev/null && fail "Should block: 0s ago (below threshold ${THRESHOLD}s)" \
    || ok "Blocked: 0s ago (below threshold ${THRESHOLD}s)"

# 3. Within threshold → blocked  (use threshold/2 as test point)
echo $(( $(date +%s) - THRESHOLD / 2 )) > "$TMP_LAST"
session_allowed 2>/dev/null && fail "Should block: $((THRESHOLD/2))s ago (half threshold)" \
    || ok "Blocked: $((THRESHOLD/2))s ago (within threshold)"

# 4. At exactly threshold → allowed
echo $(( $(date +%s) - THRESHOLD )) > "$TMP_LAST"
session_allowed 2>/dev/null && ok "Allowed: exactly at threshold (${THRESHOLD}s ago)" \
    || fail "Should allow: exactly at threshold"

# 5. Well past threshold → allowed  (use threshold × 1.5)
echo $(( $(date +%s) - THRESHOLD * 3 / 2 )) > "$TMP_LAST"
session_allowed 2>/dev/null && ok "Allowed: 1.5× threshold ago" \
    || fail "Should allow: past threshold"

# 6. record_session writes current timestamp
rm -f "$TMP_LAST"
record_session 2>/dev/null
if [[ -f "$TMP_LAST" ]]; then
    ts=$(cat "$TMP_LAST"); now=$(date +%s); diff=$(( now - ts ))
    (( diff >= 0 && diff <= 2 )) && ok "record_session: correct Unix timestamp (delta: ${diff}s)" \
        || fail "record_session: wrong timestamp (delta: ${diff}s)"
else
    fail "record_session: file not created"
fi

# 7. Verify threshold adapts to close sessions
# Temporarily override SESSION_TIMES with 5-minute-apart sessions
export SESSION_TIMES=("10:00" "10:05")
close_threshold=$(_effective_threshold)
ok "Dynamic threshold for 5-min sessions: ${close_threshold}s (expected ~150s)"
(( close_threshold <= 180 && close_threshold >= 60 )) \
    && ok "Threshold in valid range for 5-min sessions [60, 180]s" \
    || fail "Threshold out of range: ${close_threshold}s"

# With 5-min sessions: timestamp 3min ago → blocked (3min < 2.5min threshold? wait, 3min > 2.5min)
# Actually 150s threshold, 180s ago → allowed
echo $(( $(date +%s) - 180 )) > "$TMP_LAST"
session_allowed 2>/dev/null && ok "5-min sessions: 180s ago → allowed (> ${close_threshold}s threshold)" \
    || fail "5-min sessions: 180s ago should be allowed (threshold: ${close_threshold}s)"

# 60s ago → blocked (below 150s threshold)
echo $(( $(date +%s) - 60 )) > "$TMP_LAST"
session_allowed 2>/dev/null && fail "5-min sessions: 60s ago should be blocked (threshold: ${close_threshold}s)" \
    || ok "5-min sessions: 60s ago → blocked (< ${close_threshold}s threshold)"

# Restore
source "$PROJECT_DIR/config.sh"

echo ""
echo "session_guard: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
