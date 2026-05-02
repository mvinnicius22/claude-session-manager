#!/usr/bin/env bash
# ============================================================
# tests/platforms/macos/test_schedule.sh — macOS only
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$TESTS_DIR")")")"
source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/src/suggest_times.sh"

PASS=0; FAIL=0; SKIP=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }
skip() { printf "\033[1;33m⚠\033[0m %s\n" "$1"; SKIP=$(( SKIP + 1 )); }

# SESSION_TIMES count and format
(( ${#SESSION_TIMES[@]} > 0 )) && ok "${#SESSION_TIMES[@]} session time(s) configured" \
    || fail "SESSION_TIMES is empty"

for t in "${SESSION_TIMES[@]}"; do
    [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] && ok "Valid HH:MM: $t" \
        || fail "Invalid time format: '$t'"
done

# Gaps
if (( ${#SESSION_TIMES[@]} >= 2 )); then
    min_gap_min=$(( SESSION_MIN_GAP / 60 ))
    prev_min=-1
    for t in "${SESSION_TIMES[@]}"; do
        h="${t%%:*}"; h="${h#0}"; h="${h:-0}"
        m="${t##*:}"; m="${m#0}"; m="${m:-0}"
        cur_min=$(( h * 60 + m ))
        if (( prev_min >= 0 )); then
            gap=$(( cur_min - prev_min ))
            (( gap >= min_gap_min )) && ok "Gap OK: ${gap} min ≥ ${min_gap_min} min" \
                || fail "Gap too small: ${gap} min < ${min_gap_min} min"
        fi
        prev_min=$cur_min
    done
fi

# Model valid
VALID_MODELS=("$CLAUDE_MODEL_HAIKU" "$CLAUDE_MODEL_SONNET" "$CLAUDE_MODEL_OPUS")
MODEL_OK=false
for m in "${VALID_MODELS[@]}"; do [[ "${CLAUDE_MODEL:-}" == "$m" ]] && MODEL_OK=true; done
$MODEL_OK && ok "CLAUDE_MODEL=${CLAUDE_MODEL}" \
    || fail "CLAUDE_MODEL='${CLAUDE_MODEL:-<empty>}' not a known model"

# Work hours
[[ -n "${WORK_START:-}" && -n "${WORK_END:-}" ]] \
    && ok "Work hours: $WORK_START-$WORK_END" \
    || fail "WORK_START/WORK_END not set"

# Suggest algorithm smoke test
if [[ -n "${WORK_START:-}" && -n "${WORK_END:-}" ]]; then
    read -r SG1 SG2 SG3 <<< "$(suggest_session_times "$WORK_START" "$WORK_END")"
    for st in "$SG1" "$SG2" "$SG3"; do
        [[ "$st" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] && ok "Suggested time valid: $st" \
            || fail "Suggested time invalid: $st"
    done
fi

# LaunchAgent plist entry count matches config
PLIST="$HOME/Library/LaunchAgents/com.claude.session.manager.plist"
if [[ -f "$PLIST" ]]; then
    plist_count=$(grep -c "<key>Hour</key>" "$PLIST" || true)
    config_count=${#SESSION_TIMES[@]}
    (( plist_count == config_count )) \
        && ok "LaunchAgent: $plist_count entries match config ($config_count)" \
        || fail "LaunchAgent: $plist_count entries ≠ config $config_count — re-run install.sh"
else
    skip "LaunchAgent plist not found — run install.sh"
fi

# pmset wake events
wake_count=$(pmset -g sched 2>/dev/null | grep -ci "wake" || true)
(( wake_count > 0 )) && ok "pmset: $wake_count wake event(s) scheduled" \
    || skip "No pmset wake events — run: bash src/wake-scheduler.sh"

echo ""
echo "macos/schedule: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
