#!/usr/bin/env bash
# ============================================================
# platforms/macos/uninstall.sh — macOS only
# ============================================================

set -uo pipefail

PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$PLATFORM_DIR")")"

source "$PROJECT_DIR/src/ensure-config.sh"
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/src/utils.sh"
source "$PROJECT_DIR/src/detect_platform.sh"
source "$PLATFORM_DIR/scheduler.sh"
source "$PLATFORM_DIR/wake.sh"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_BOLD_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'

ok()   { printf "${C_BOLD_GREEN}  ✓${C_RESET}  %s\n" "$1"; }
warn() { printf "${C_YELLOW}  ⚠${C_RESET}  %s\n" "$1"; }
hr()   { printf "  ${C_DIM}%s${C_RESET}\n" "────────────────────────────────────"; }

echo ""
printf "  ${C_BOLD}Claude Session Manager${C_RESET} ${C_DIM}— Uninstall (macOS)${C_RESET}\n"
hr
echo ""

# ── 1. LaunchAgent ────────────────────────────────────────────
if unload_scheduler 2>/dev/null; then
    ok "LaunchAgent unloaded."
else
    warn "LaunchAgent was not loaded."
fi
remove_plist && ok "LaunchAgent plist removed." || warn "Plist not found."

# ── 2. pmset wake events ──────────────────────────────────────
cancel_our_wake_events

# ── 3. Passwordless sudo rule ─────────────────────────────────
remove_passwordless_sudo

# ── 3. Installed scripts ──────────────────────────────────────
INSTALL_DIR="$HOME/.local/share/claude-session-manager"
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR" && ok "Installed scripts removed."
fi

# ── 4. State & logs (optional) ───────────────────────────────
echo ""
if [[ -t 0 ]]; then
    printf "  ${C_BOLD}Remove state directory & logs?${C_RESET} ${C_DIM}(%s)${C_RESET}\n" "$STATE_DIR"
    printf "  ${C_DIM}(logs, timestamps — say N to keep them for reinstall)${C_RESET}\n"
    printf "  ${C_DIM}[y/N]${C_RESET}: "
    read -r answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        rm -rf "$STATE_DIR" && ok "State directory removed."
    else
        warn "State kept: $STATE_DIR"
    fi
fi

echo ""
hr
ok "Uninstall complete — hardware wake schedule cleared."
echo ""
