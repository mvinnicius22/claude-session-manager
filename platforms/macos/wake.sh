#!/usr/bin/env bash
# ============================================================
# platforms/macos/wake.sh — macOS only
# pmset-based wake scheduling with workday/holiday filtering.
# Sourced by src/session.sh and src/wake-scheduler.sh.
#
# Design:
#   install / reconfigure  → schedule_upcoming_days(N)  — full window
#   after each session     → reschedule_wake_events()   — extend by 1 day
#
# This keeps the rolling window alive with only 3 pmset calls
# per session (not N*3), avoiding duplicates and slowness.
# ============================================================

_wake_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$(dirname "$_wake_dir")")/src/defaults.sh"
unset _wake_dir

# Flag to suppress repeated sudo warnings — reset by schedule_upcoming_days() each run.
_PMSET_SUDO_WARNED=""

# ── Core: schedule a single pmset wake event ─────────────────
# $1 = HH:MM session time
# $2 = MM/DD/YY date string (pmset format)
# $3 = "dry-run" or "run"
_macos_schedule_wake() {
    local time="$1" date_str="$2" mode="${3:-run}"
    local offset="${WAKE_OFFSET_SECS:-$DEFAULT_WAKE_OFFSET_SECS}"

    if ! [[ "$time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        log_warn "wake.sh: invalid time format '$time' — expected HH:MM (e.g. 10:20, not 10h20). Skipping."
        return 1
    fi
    local h="${time%%:*}"; h="${h#0}"; h="${h:-0}"
    local m="${time##*:}"; m="${m#0}"; m="${m:-0}"
    # Work in seconds so sub-minute offsets (e.g. WAKE_OFFSET_SECS=30) are exact
    local sess_sec=$(( h * 3600 + m * 60 ))
    local wake_sec=$(( sess_sec - offset ))
    (( wake_sec < 0 )) && wake_sec=$(( wake_sec + 86400 ))
    local wake_h=$(( wake_sec / 3600 ))
    local wake_m=$(( (wake_sec % 3600) / 60 ))
    local wake_s=$(( wake_sec % 60 ))
    local wake_time; wake_time=$(printf '%02d:%02d:%02d' "$wake_h" "$wake_m" "$wake_s")

    if [[ "$mode" == "dry-run" ]]; then
        printf '  sudo pmset schedule wake "%s %s"\n' "$date_str" "$wake_time"
    else
        if sudo pmset schedule wake "${date_str} ${wake_time}" 2>/dev/null; then
            # Track every event we schedule so uninstall can cancel exactly these
            local tracking="${STATE_DIR:-$HOME/.claude-session-manager}/scheduled_wakes"
            mkdir -p "$(dirname "$tracking")"
            echo "${date_str} ${wake_time}" >> "$tracking"
        else
            if [[ -z "${_PMSET_SUDO_WARNED:-}" ]]; then
                _PMSET_SUDO_WARNED=1
                log_warn "pmset: needs sudo — configure once: bash src/setup-sudo.sh  (then: bash src/wake-scheduler.sh)"
            fi
        fi
    fi
}

# ── Workday filter ────────────────────────────────────────────
# Returns 0 if a session should fire on the given date, 1 if it should be skipped.
is_workday() {
    local ymd="$1"

    local dow
    dow=$(date -j -f '%Y-%m-%d' "$ymd" '+%u' 2>/dev/null) || return 1

    # Skip weekends unless opted in
    if [[ "${SCHEDULE_WEEKENDS:-false}" != "true" ]] && (( dow > 5 )); then
        return 1
    fi

    # Skip holidays unless opted in
    if [[ "${SCHEDULE_HOLIDAYS:-false}" != "true" ]] && (( ${#HOLIDAYS[@]:-0} > 0 )); then
        for holiday in "${HOLIDAYS[@]}"; do
            [[ "$ymd" == "$holiday" ]] && return 1
        done
    fi

    return 0
}

# ── Full window scheduler ─────────────────────────────────────
# Used by install.sh and reconfigure.sh to set the initial N-day window.
# $1 = days ahead   $2 = "dry-run" | "run"
schedule_upcoming_days() {
    _PMSET_SUDO_WARNED=""   # reset per scheduling run
    local days="${1:-${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}}"
    local mode="${2:-run}"
    if ! [[ "$days" =~ ^[0-9]+$ ]] || (( days == 0 )); then
        log_warn "schedule_upcoming_days: invalid days value '$days', using $DEFAULT_SCHEDULE_DAYS_AHEAD"
        days=$DEFAULT_SCHEDULE_DAYS_AHEAD
    fi
    local scheduled skipped_weekend skipped_holiday skipped_past
    scheduled=0; skipped_weekend=0; skipped_holiday=0; skipped_past=0

    local now_min; now_min=$(( 10#$(date '+%H') * 60 + 10#$(date '+%M') ))

    for (( i=0; i<days; i++ )); do
        local ymd; ymd=$(date -v+${i}d '+%Y-%m-%d')
        local pmset_date; pmset_date=$(date -v+${i}d '+%m/%d/%y')
        local dow; dow=$(date -v+${i}d '+%u')

        if ! is_workday "$ymd"; then
            if (( dow > 5 )); then
                skipped_weekend=$(( skipped_weekend + 1 ))
            else
                skipped_holiday=$(( skipped_holiday + 1 ))
            fi
            continue
        fi

        for t in "${SESSION_TIMES[@]}"; do
            # For today: skip if the WAKE time (session - offset) is already past.
            # Scheduling a past pmset event silently fails and wastes a sudo call.
            if (( i == 0 )); then
                local sh="${t%%:*}"; sh="${sh#0}"; sh="${sh:-0}"
                local sm="${t##*:}"; sm="${sm#0}"; sm="${sm:-0}"
                local sess_min=$(( sh * 60 + sm ))
                local wake_min=$(( sess_min - ${WAKE_OFFSET_SECS:-$DEFAULT_WAKE_OFFSET_SECS} / 60 ))
                (( wake_min < 0 )) && wake_min=$(( wake_min + 1440 ))
                if (( wake_min <= now_min )); then
                    skipped_past=$(( skipped_past + 1 ))
                    continue
                fi
            fi
            _macos_schedule_wake "$t" "$pmset_date" "$mode"
        done
        scheduled=$(( scheduled + 1 ))
    done

    if [[ "$mode" != "dry-run" ]]; then
        log_info "Scheduled: ${scheduled} workdays | Skipped: weekends=${skipped_weekend} holidays=${skipped_holiday} past_today=${skipped_past}"
        if [[ -n "${_PMSET_SUDO_WARNED:-}" ]]; then
            log_warn "Wake events were NOT scheduled (sudo required). Fix with: bash src/setup-sudo.sh"
            log_warn "Then refresh: bash src/wake-scheduler.sh"
        fi
    fi
}

# ── Rolling window extension ──────────────────────────────────
# Called by session.sh after each trigger.
# Adds events only for (today + SCHEDULE_DAYS_AHEAD) — the new end of the window.
# Only 3 pmset calls, never duplicates, keeps the window perpetually full.
reschedule_wake_events() {
    command -v pmset &>/dev/null || return 0

    local days="${SCHEDULE_DAYS_AHEAD:-$DEFAULT_SCHEDULE_DAYS_AHEAD}"
    local target_ymd; target_ymd=$(date -v+${days}d '+%Y-%m-%d')
    local target_pmset; target_pmset=$(date -v+${days}d '+%m/%d/%y')

    if is_workday "$target_ymd"; then
        log_info "Extending wake window to ${target_ymd}…"
        for t in "${SESSION_TIMES[@]}"; do
            _macos_schedule_wake "$t" "$target_pmset" run
        done
    fi
}

# ── Passwordless sudo for pmset ──────────────────────────────
# Writes a sudoers drop-in that allows the current user to run
# `pmset schedule wake` and `pmset schedule cancel` without a password.
# This enables session.sh to auto-extend the rolling wake window.
_setup_passwordless_sudo() {
    local sudoers_file="/etc/sudoers.d/claude-session-manager"
    local user; user=$(whoami)
    # Scope is intentionally narrow: only pmset schedule wake/cancel
    local rule="${user} ALL=(ALL) NOPASSWD: /usr/bin/pmset schedule wake *, /usr/bin/pmset schedule cancel wake *"

    printf '%s\n' "$rule" | sudo tee "$sudoers_file" > /dev/null || {
        log_error "Could not write $sudoers_file — check sudo access."
        return 1
    }
    sudo chmod 440 "$sudoers_file"

    # Validate the file before leaving it in place
    if sudo visudo -c -f "$sudoers_file" &>/dev/null; then
        log_ok "Passwordless sudo configured: $sudoers_file"
        log_info "From now on, session.sh extends the wake window automatically."
    else
        sudo rm -f "$sudoers_file"
        log_error "visudo validation failed — removed. Rule was: $rule"
        return 1
    fi
}

remove_passwordless_sudo() {
    local sudoers_file="/etc/sudoers.d/claude-session-manager"
    if [[ -f "$sudoers_file" ]]; then
        sudo rm -f "$sudoers_file" && log_ok "Passwordless sudo rule removed." || true
    else
        log_info "No passwordless sudo rule found."
    fi
}

# ── Uninstall: cancel all wake events we scheduled ───────────
# Reads the tracking file written by _macos_schedule_wake().
# Falls back to cancelling all events attributed to 'pmset' if no
# tracking file exists (safe — system events always have 'com.apple.' labels).
cancel_our_wake_events() {
    local tracking="${STATE_DIR:-$HOME/.claude-session-manager}/scheduled_wakes"
    local cancelled=0

    if [[ -f "$tracking" ]]; then
        local total; total=$(wc -l < "$tracking" | tr -d ' ')
        log_info "Cancelling ${total} tracked wake events…"
        while IFS= read -r event; do
            sudo pmset schedule cancel wake "$event" 2>/dev/null && \
                cancelled=$(( cancelled + 1 )) || true
        done < "$tracking"
        if (( cancelled == 0 && total > 0 )); then
            log_warn "No wake events cancelled — sudo not configured. Fix: bash src/setup-sudo.sh"
        else
            rm -f "$tracking"
        fi
    else
        # Fallback: cancel all events attributed to bare 'pmset'
        # (those are always ours — macOS system events use 'com.apple.*' labels)
        log_info "No tracking file — cancelling all pmset-attributed wake events…"
        while IFS= read -r line; do
            if [[ "$line" =~ wake\ at\ ([0-9/]+)\ ([0-9:]+)\ by\ \'pmset\' ]]; then
                sudo pmset schedule cancel wake \
                    "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" 2>/dev/null && \
                    cancelled=$(( cancelled + 1 )) || true
            fi
        done < <(pmset -g sched 2>/dev/null)
    fi

    if (( cancelled > 0 )); then
        log_ok "Cancelled ${cancelled} wake event(s)."
    else
        log_info "No wake events to cancel."
    fi
}

# ── Convenience ───────────────────────────────────────────────
schedule_wake_today() {
    local time="$1" mode="${2:-run}"
    _macos_schedule_wake "$time" "$(date '+%m/%d/%y')" "$mode"
}

# ── Sleep ─────────────────────────────────────────────────────
platform_sleep_now() {
    local delay="${SLEEP_DELAY:-$DEFAULT_SLEEP_DELAY}"
    log_info "Sleeping in ${delay}s…"
    sleep "$delay"
    pmset sleepnow
}
