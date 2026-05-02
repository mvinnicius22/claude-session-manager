#!/usr/bin/env bash
# ============================================================
# install.sh — Platform-detecting entry point
# Detects the OS and delegates to platforms/*/install.sh.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/detect_platform.sh"

PLATFORM=$(detect_platform)

echo ""
echo "  Detected platform: $PLATFORM"
echo ""

case "$PLATFORM" in
    macos)
        bash "$SCRIPT_DIR/platforms/macos/install.sh" "$@"
        ;;
    linux)
        bash "$SCRIPT_DIR/platforms/linux/install.sh" "$@"
        ;;
    windows)
        printf '[ERROR] Windows support is not yet implemented.\n' >&2
        printf '        Track progress: https://github.com/your-org/claude-session-manager/issues\n' >&2
        exit 1
        ;;
    *)
        printf '[ERROR] Unknown platform: %s (uname -s: %s)\n' "$PLATFORM" "$(uname -s)" >&2
        exit 1
        ;;
esac
