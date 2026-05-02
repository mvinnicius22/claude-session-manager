#!/usr/bin/env bash
# ============================================================
# claude-session-manager — src/suggest_times.sh
# Calculates optimal session start times given work hours.
#
# Algorithm: maximise Claude session overlap with work hours.
# Session 2 (middle) covers the core of the work day; sessions
# 1 and 3 are symmetrical bookends.
#
# Usage (sourced): suggest_session_times "09:00" "17:00"
# Returns: three HH:MM values on one space-separated line
# ============================================================

# Convert HH:MM string to total minutes since midnight.
_to_min() {
    local t="$1"
    local h="${t%%:*}"; h="${h#0}"; h="${h:-0}"
    local m="${t##*:}"; m="${m#0}"; m="${m:-0}"
    echo $(( h * 60 + m ))
}

# Convert minutes since midnight to HH:MM string.
_to_hhmm() {
    local total=$(( $1 % 1440 ))
    (( total < 0 )) && total=$(( total + 1440 ))
    printf '%02d:%02d' "$(( total / 60 ))" "$(( total % 60 ))"
}

suggest_session_times() {
    local work_start="$1"   # HH:MM
    local work_end="$2"     # HH:MM
    local session_dur="${3:-300}"  # minutes (default 5h = 300)

    local ws; ws=$(_to_min "$work_start")
    local we; we=$(_to_min "$work_end")
    local work_dur=$(( we - ws ))

    local s2_start

    if (( work_dur >= session_dur )); then
        # Session 2 fits fully inside the work day.
        # Place it so sessions 1 and 3 each cover equal time at the edges.
        local remaining=$(( work_dur - session_dur ))
        s2_start=$(( ws + remaining / 2 ))
    else
        # Work day shorter than one session — centre session 2 on work midpoint.
        local work_mid=$(( ws + work_dur / 2 ))
        s2_start=$(( work_mid - session_dur / 2 ))
    fi

    local s1_start=$(( s2_start - session_dur ))
    local s3_start=$(( s2_start + session_dur ))

    echo "$(_to_hhmm $s1_start) $(_to_hhmm $s2_start) $(_to_hhmm $s3_start)"
}

# Describe the overlap each session has with the work window (for display).
describe_session_overlap() {
    local work_start="$1" work_end="$2"
    shift 2
    local times=("$@")
    local session_dur=300

    local ws; ws=$(_to_min "$work_start")
    local we; we=$(_to_min "$work_end")

    for t in "${times[@]}"; do
        local ss; ss=$(_to_min "$t")
        local se=$(( ss + session_dur ))

        local overlap_start=$(( ss > ws ? ss : ws ))
        local overlap_end=$(( se < we ? se : we ))
        local overlap=$(( overlap_end > overlap_start ? overlap_end - overlap_start : 0 ))

        if (( overlap > 0 )); then
            printf "  %s  →  work overlap: %s-%s (%dh%02dm)\n" \
                "$t" \
                "$(_to_hhmm $overlap_start)" "$(_to_hhmm $overlap_end)" \
                "$(( overlap / 60 ))" "$(( overlap % 60 ))"
        else
            printf "  %s  →  no overlap with work hours\n" "$t"
        fi
    done
}
