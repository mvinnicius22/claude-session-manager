#!/usr/bin/env bash
# ============================================================
# reinstall.sh — Reinstall, keeping current state & logs.
#
# Difference from uninstall + install:
#   - State files and logs are preserved (~/.claude-session-manager/)
#   - The install wizard pre-fills defaults from your current config.sh
#
# Usage: bash reinstall.sh
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/detect_platform.sh"

PLATFORM=$(detect_platform)

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }

echo ""
printf "${BOLD}Claude Session Manager — Reinstall${NC}\n"
echo "════════════════════════════════════════"
echo "  State files and logs will be preserved."
echo ""

case "$PLATFORM" in
    macos)
        # Unload LaunchAgent and remove installed scripts,
        # but do NOT remove state dir or config.sh
        source "$SCRIPT_DIR/platforms/macos/scheduler.sh"
        unload_scheduler 2>/dev/null && ok "LaunchAgent unloaded." || warn "LaunchAgent was not loaded."
        remove_plist && ok "Plist removed."

        INSTALL_DIR="$HOME/.local/share/claude-session-manager"
        [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR" && ok "Installed scripts removed."

        echo ""
        warn "Your config.sh and logs are untouched."
        warn "The wizard will use your current settings as defaults."
        echo ""
        ;;
    linux)
        printf '[ERROR] Linux support not yet implemented.\n' >&2
        exit 1
        ;;
    *)
        printf '[ERROR] Unsupported platform: %s\n' "$PLATFORM" >&2
        exit 1
        ;;
esac

echo "Running installer…"
echo ""
bash "$SCRIPT_DIR/install.sh"
