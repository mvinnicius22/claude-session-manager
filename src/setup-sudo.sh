#!/usr/bin/env bash
# ============================================================
# src/setup-sudo.sh — Configure passwordless sudo for pmset.
#
# Allows session.sh to automatically extend the rolling wake
# window after each session, without prompting for a password.
#
# Scope is minimal: only pmset schedule wake and cancel.
#
# Usage:
#   bash src/setup-sudo.sh          # install rule
#   bash src/setup-sudo.sh remove   # remove rule
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/src/utils.sh"
source "$PROJECT_DIR/src/detect_platform.sh"
source "$PROJECT_DIR/platforms/macos/wake.sh"

require_platform "macos"

if [[ "${1:-}" == "remove" ]]; then
    remove_passwordless_sudo
else
    echo ""
    printf "\033[1mClaude Session Manager — Passwordless sudo setup\033[0m\n"
    printf "\033[2m──────────────────────────────────────────────────\033[0m\n"
    echo ""
    printf "  Adds a rule to \033[1m/etc/sudoers.d/claude-session-manager\033[0m\n"
    printf "  allowing \033[1m$(whoami)\033[0m to run:\n"
    echo ""
    printf "    sudo pmset schedule wake  ...\n"
    printf "    sudo pmset schedule cancel wake  ...\n"
    echo ""
    printf "  Nothing else is granted.\n"
    echo ""
    _setup_passwordless_sudo
    echo ""
    printf "  To remove: bash src/setup-sudo.sh remove\n"
    echo ""
fi
