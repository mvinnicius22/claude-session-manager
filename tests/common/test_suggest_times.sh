#!/usr/bin/env bash
# ============================================================
# tests/common/test_suggest_times.sh — Cross-platform
# Validates the session time suggestion algorithm.
# ============================================================

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$TESTS_DIR")")"

source "$PROJECT_DIR/src/suggest_times.sh"

PASS=0; FAIL=0
ok()   { printf "\033[0;32m✓\033[0m %s\n" "$1"; PASS=$(( PASS + 1 )); }
fail() { printf "\033[0;31m✗\033[0m %s\n" "$1"; FAIL=$(( FAIL + 1 )); }

# Helper: convert HH:MM to minutes
to_min() {
    local h="${1%%:*}"; h="${h#0}"; h="${h:-0}"
    local m="${1##*:}"; m="${m#0}"; m="${m:-0}"
    echo $(( h * 60 + m ))
}

# Helper: verify 3 times are 5h apart and cover the work day
check_coverage() {
    local label="$1" ws="$2" we="$3" s1="$4" s2="$5" s3="$6"
    local session_dur=300

    local ws_m; ws_m=$(to_min "$ws")
    local we_m; we_m=$(to_min "$we")
    local s1_m; s1_m=$(to_min "$s1")
    local s2_m; s2_m=$(to_min "$s2")
    local s3_m; s3_m=$(to_min "$s3")

    # Sessions must be 5h apart
    local gap12=$(( s2_m - s1_m )) gap23=$(( s3_m - s2_m ))

    if (( gap12 == session_dur && gap23 == session_dur )); then
        ok "$label: sessions 5h apart ($s1 / $s2 / $s3)"
    else
        fail "$label: gaps wrong — $s1→$s2 gap=${gap12}m, $s2→$s3 gap=${gap23}m (expected 300m each)"
        return
    fi

    # Full work day coverage: union of sessions must span ws..we
    local coverage_start=$(( s1_m > ws_m ? s1_m : ws_m ))
    local s3_end=$(( s3_m + session_dur ))
    local coverage_end=$(( s3_end < we_m ? s3_end : we_m ))
    local covered=$(( coverage_end - coverage_start ))
    local work_dur=$(( we_m - ws_m ))

    if (( covered >= work_dur )); then
        ok "$label: full work day covered ($ws-$we)"
    else
        fail "$label: only ${covered}/${work_dur} min of work day covered"
    fi
}

# ── Standard 8h workday (09:00-17:00) ────────────────────────
read -r S1 S2 S3 <<< "$(suggest_session_times "09:00" "17:00")"
[[ "$S1" == "05:30" && "$S2" == "10:30" && "$S3" == "15:30" ]] \
    && ok "09:00-17:00 → 05:30/10:30/15:30 (reference case)" \
    || fail "09:00-17:00 → expected 05:30/10:30/15:30, got $S1/$S2/$S3"
check_coverage "09:00-17:00" "09:00" "17:00" "$S1" "$S2" "$S3"

# ── Early start (06:00-14:00) ─────────────────────────────────
read -r S1 S2 S3 <<< "$(suggest_session_times "06:00" "14:00")"
check_coverage "06:00-14:00" "06:00" "14:00" "$S1" "$S2" "$S3"
ok "06:00-14:00 → $S1/$S2/$S3"

# ── Long day (08:00-20:00) ────────────────────────────────────
read -r S1 S2 S3 <<< "$(suggest_session_times "08:00" "20:00")"
check_coverage "08:00-20:00" "08:00" "20:00" "$S1" "$S2" "$S3"
ok "08:00-20:00 → $S1/$S2/$S3"

# ── Short day (10:00-13:00, shorter than 5h) ─────────────────
read -r S1 S2 S3 <<< "$(suggest_session_times "10:00" "13:00")"
for t in "$S1" "$S2" "$S3"; do
    [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] \
        && ok "Short day: valid time $t" \
        || fail "Short day: invalid time $t"
done

# ── Output format validation (all times HH:MM) ───────────────
for ws_we in "07:00 15:00" "09:30 18:30" "00:00 08:00"; do
    ws="${ws_we% *}"; we="${ws_we#* }"
    read -r T1 T2 T3 <<< "$(suggest_session_times "$ws" "$we")"
    for t in "$T1" "$T2" "$T3"; do
        [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] \
            && ok "Format OK ($ws-$we): $t" \
            || fail "Bad format ($ws-$we): '$t'"
    done
done

echo ""
echo "suggest_times: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
