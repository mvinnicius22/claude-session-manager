#!/usr/bin/env bash
# ============================================================
# src/utils.sh — Cross-platform
# Core utilities: logging, session guard, Claude CLI trigger.
# No OS-specific APIs — those live in platforms/*/
# ============================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/defaults.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────
_log() {
    local level="$1" msg="$2"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ -n "${LOG_FILE:-}" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        printf '[%s] [%s] %s\n' "$ts" "$level" "$msg" >> "$LOG_FILE"
    fi
    case "$level" in
        INFO)  printf "${BLUE}[INFO]${NC}  %s\n" "$msg" ;;
        OK)    printf "${GREEN}[OK]${NC}    %s\n" "$msg" ;;
        WARN)  printf "${YELLOW}[WARN]${NC}  %s\n" "$msg" ;;
        ERROR) printf "${RED}[ERROR]${NC} %s\n" "$msg" >&2 ;;
    esac
}
log_info()  { _log INFO  "$1"; }
log_ok()    { _log OK    "$1"; }
log_warn()  { _log WARN  "$1"; }
log_error() { _log ERROR "$1"; }

# ── Country holiday loader ────────────────────────────────────
# Sources holidays/<country>.sh and merges its HOLIDAYS array
# into the current shell. Call before any is_workday() usage.
load_country_holidays() {
    local country="${HOLIDAY_COUNTRY:-}"
    [[ -z "$country" ]] && return 0

    # utils.sh lives in src/ — holidays/ is one level up
    local utils_dir; utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir; project_dir="$(dirname "$utils_dir")"
    local holiday_file="$project_dir/holidays/${country}.sh"

    if [[ ! -f "$holiday_file" ]]; then
        log_warn "No holiday file for '${country}': $holiday_file"
        local available; available=$(ls "$project_dir/holidays/"*.sh 2>/dev/null \
            | xargs -n1 basename | sed 's/\.sh//' | tr '\n' ' ')
        log_warn "Available countries: ${available:-none}"
        return 1
    fi

    # Source into a subshell, capture HOLIDAYS, then merge into current scope
    local country_holidays
    country_holidays=$(bash -c "source '$holiday_file'; printf '%s\n' \"\${HOLIDAYS[@]}\"" 2>/dev/null)

    if [[ -n "$country_holidays" ]]; then
        while IFS= read -r date; do
            [[ -n "$date" ]] && HOLIDAYS+=("$date")
        done <<< "$country_holidays"
        local upper_country; upper_country=$(echo "$country" | tr '[:lower:]' '[:upper:]')
        local count; count=$(echo "$country_holidays" | wc -l | tr -d ' ')
        log_info "Loaded ${upper_country} holidays (${count} dates)."
    fi
}

# ── Session guard ─────────────────────────────────────────────
# Computes the guard threshold dynamically:
#   - If SESSION_TIMES has multiple entries, threshold = half the smallest
#     gap between consecutive times (minimum 60 s).
#   - Falls back to SESSION_MIN_GAP (default 18000 s) for a single session.
# This way sessions configured 5 minutes apart both fire correctly,
# while still blocking accidental double-triggers of the same slot.
_guard_threshold() {
    local min_gap_sec=0
    local prev_min=-1

    for t in "${SESSION_TIMES[@]:-}"; do
        local h="${t%%:*}"; h="${h#0}"; h="${h:-0}"
        local m="${t##*:}"; m="${m#0}"; m="${m:-0}"
        local cur=$(( h * 60 + m ))
        if (( prev_min >= 0 && cur > prev_min )); then
            local gap_sec=$(( (cur - prev_min) * 60 ))
            if (( min_gap_sec == 0 || gap_sec < min_gap_sec )); then
                min_gap_sec=$gap_sec
            fi
        fi
        prev_min=$cur
    done

    if (( min_gap_sec > 0 )); then
        local half=$(( min_gap_sec / 2 ))
        echo $(( half < 60 ? 60 : half ))   # floor at 60 s
    else
        echo "${SESSION_MIN_GAP:-$DEFAULT_SESSION_MIN_GAP}"
    fi
}

# Returns 0 if a new session is allowed; 1 if too soon.
session_allowed() {
    local min_gap; min_gap=$(_guard_threshold)
    local last_file="${LAST_SESSION_FILE:-$HOME/.claude-session-manager/last_session}"
    local now; now=$(date +%s)

    if [[ -f "$last_file" ]]; then
        local last; last=$(cat "$last_file")
        local diff=$(( now - last ))
        if (( diff < min_gap )); then
            local remaining=$(( (min_gap - diff) / 60 ))
            log_warn "Session guard: last session was $((diff / 60)) min ago. Next in ~${remaining} min (threshold: $((min_gap / 60)) min)."
            return 1
        fi
    fi
    return 0
}

record_session() {
    local last_file="${LAST_SESSION_FILE:-$HOME/.claude-session-manager/last_session}"
    mkdir -p "$(dirname "$last_file")"
    date +%s > "$last_file"
    log_info "Session timestamp recorded."
}

# ── Claude CLI ────────────────────────────────────────────────
resolve_claude_bin() {
    local bin="${CLAUDE_BIN:-}"
    if [[ -z "$bin" ]]; then
        for c in \
            "$HOME/.local/bin/claude" \
            "/usr/local/bin/claude" \
            "/opt/homebrew/bin/claude" \
            "$(command -v claude 2>/dev/null || true)"; do
            [[ -n "$c" && -x "$c" ]] && { bin="$c"; break; }
        done
    fi
    if [[ -z "$bin" || ! -x "$bin" ]]; then
        log_error "Claude CLI not found. Install: https://claude.ai/code  or set CLAUDE_BIN in config.sh"
        return 1
    fi
    echo "$bin"
}

# Sends INITIAL_PROMPT to Claude via non-interactive mode.
# Runs headless — no terminal, no window required.
trigger_claude_session() {
    local bin; bin=$(resolve_claude_bin) || return 1
    local prompt="${INITIAL_PROMPT:-oi}"
    local model="${CLAUDE_MODEL:-$DEFAULT_CLAUDE_MODEL}"

    # Expand runtime placeholders (%time%, %date%)
    prompt="${prompt//%time%/$(date '+%H:%M:%S')}"
    prompt="${prompt//%date%/$(date '+%Y-%m-%d')}"

    # Build arg array — avoids quoting issues with empty-string args (--tools "")
    local -a args=(-p "$prompt" --model "$model")

    # Append freeform extra flags (word-split; no empty-string args here)
    local extra="${CLAUDE_EXTRA_FLAGS:-$DEFAULT_CLAUDE_EXTRA_FLAGS}"
    if [[ -n "$extra" ]]; then
        local -a _extra_arr
        read -r -a _extra_arr <<< "$extra"
        args+=("${_extra_arr[@]}")
    fi

    # --tools "" must be appended as two separate array elements
    local disable_tools="${CLAUDE_DISABLE_TOOLS:-$DEFAULT_CLAUDE_DISABLE_TOOLS}"
    [[ "$disable_tools" == "true" ]] && args+=(--tools "")

    # JSON output gives us token usage metadata at no extra API cost
    args+=(--output-format json)

    log_info "Running: $bin ${args[*]}"

    local raw_output
    raw_output=$("$bin" "${args[@]}" 2>&1)
    local exit_code=$?

    local _log_file="${LOG_FILE:-/tmp/claude-session.log}"
    mkdir -p "$(dirname "$_log_file")"
    # Write JSON response to log in yellow
    printf '\033[1;33m%s\033[0m\n' "$raw_output" >> "$_log_file"

    # Parse and log token usage from the JSON response (no jq needed)
    # head -1 avoids multi-match: input_tokens appears in usage, iterations, and modelUsage
    if (( exit_code == 0 )) && [[ -n "$raw_output" ]]; then
        local in_tok out_tok cost cost_fmt
        in_tok=$(printf '%s' "$raw_output" | grep -o '"input_tokens":[0-9]*' | head -1 | cut -d: -f2)
        out_tok=$(printf '%s' "$raw_output" | grep -o '"output_tokens":[0-9]*' | head -1 | cut -d: -f2)
        cost=$(printf '%s' "$raw_output" | grep -oE '"total_cost_usd":[0-9eE.+\-]+' | cut -d: -f2)
        cost_fmt=$(printf "%.4f" "${cost:-0}" 2>/dev/null || echo "${cost:-n/a}")
        if [[ -n "$in_tok" ]]; then
            local ts msg
            ts=$(date '+%Y-%m-%d %H:%M:%S')
            msg="Tokens: input=${in_tok} output=${out_tok} cost_usd=${cost_fmt}"
            # Write tokens line to log in green
            printf '\033[0;32m[%s] [INFO]  %s\033[0m\n' "$ts" "$msg" >> "$_log_file"
            # Echo to stdout with normal INFO colour
            printf "${BLUE}[INFO]${NC}  %s\n" "$msg"
        fi
    fi

    (( exit_code != 0 )) && log_error "claude exited $exit_code — see $LOG_FILE"
    return $exit_code
}
