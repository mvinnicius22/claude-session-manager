#!/usr/bin/env bash
# ============================================================
# uninstall.sh — Platform-detecting entry point
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/detect_platform.sh"

PLATFORM=$(detect_platform)

case "$PLATFORM" in
    macos)   bash "$SCRIPT_DIR/platforms/macos/uninstall.sh" "$@" ;;
    linux)   bash "$SCRIPT_DIR/platforms/linux/uninstall.sh" "$@" ;;
    *)
        printf '[ERROR] Unsupported platform: %s\n' "$PLATFORM" >&2
        exit 1
        ;;
esac
