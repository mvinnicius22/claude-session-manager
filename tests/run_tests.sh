#!/usr/bin/env bash
# ============================================================
# tests/run_tests.sh — Platform-aware test runner
#
# Runs:  tests/common/       (all platforms)
#        tests/platforms/<os>/  (current platform only)
#
# Usage: bash tests/run_tests.sh [--verbose]
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"

source "$PROJECT_DIR/src/detect_platform.sh"
PLATFORM=$(detect_platform)

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_SKIP=0

run_suite() {
    local file="$1"
    local name; name=$(basename "$file" .sh | sed 's/test_//')
    echo ""
    printf "${BOLD}▶ %-32s${NC}\n" "$name"
    echo "  ───────────────────────────────────────"

    local out; out=$(bash "$file" 2>&1)
    local p; p=$(echo "$out" | grep -c "✓" || true)
    local f; f=$(echo "$out" | grep -c "✗" || true)
    local s; s=$(echo "$out" | grep -c "⚠" || true)

    TOTAL_PASS=$(( TOTAL_PASS + p ))
    TOTAL_FAIL=$(( TOTAL_FAIL + f ))
    TOTAL_SKIP=$(( TOTAL_SKIP + s ))

    while IFS= read -r line; do printf "  %s\n" "$line"; done <<< "$out"
}

echo ""
printf "${BOLD}Claude Session Manager — Test Suite${NC}\n"
printf "Platform: ${BOLD}%s${NC}\n" "$PLATFORM"
echo "═══════════════════════════════════════════"

# ── Common tests (all platforms) ─────────────────────────────
echo ""
printf "${BOLD}[ COMMON — all platforms ]${NC}\n"
for f in "$TESTS_DIR/common"/test_*.sh; do
    [[ -f "$f" ]] && run_suite "$f"
done

# ── Platform-specific tests ───────────────────────────────────
PLATFORM_TESTS="$TESTS_DIR/platforms/$PLATFORM"
if [[ -d "$PLATFORM_TESTS" ]]; then
    echo ""
    printf "${BOLD}[ PLATFORM — %s ]${NC}\n" "$PLATFORM"
    for f in "$PLATFORM_TESTS"/test_*.sh; do
        [[ -f "$f" ]] && run_suite "$f"
    done
else
    echo ""
    printf "${Y}⚠ No platform-specific tests for: %s${NC}\n" "$PLATFORM"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
printf "${BOLD}Results:${NC}  ${G}%d passed${NC}  " "$TOTAL_PASS"
(( TOTAL_FAIL > 0 )) && printf "${R}%d failed${NC}  " "$TOTAL_FAIL"
(( TOTAL_SKIP > 0 )) && printf "${Y}%d skipped${NC}  " "$TOTAL_SKIP"
echo ""; echo ""

if (( TOTAL_FAIL > 0 )); then
    printf "${R}${BOLD}FAILED${NC} — fix the issues above.\n\n"; exit 1
else
    printf "${G}${BOLD}ALL TESTS PASSED${NC}\n\n"; exit 0
fi
