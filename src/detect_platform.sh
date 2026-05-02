#!/usr/bin/env bash
# ============================================================
# src/detect_platform.sh — Cross-platform
# Single source of truth for OS detection.
# ============================================================

detect_platform() {
    case "$(uname -s)" in
        Darwin)                        echo "macos" ;;
        Linux)                         echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*|Windows_NT) echo "windows" ;;
        *)                             echo "unknown" ;;
    esac
}

# Exits with error when running on an unsupported platform.
require_platform() {
    local supported=("$@")   # e.g. "macos" "linux"
    local current; current=$(detect_platform)
    for p in "${supported[@]}"; do
        [[ "$current" == "$p" ]] && return 0
    done
    printf '[ERROR] This feature requires one of: %s (current: %s)\n' \
        "${supported[*]}" "$current" >&2
    exit 1
}
