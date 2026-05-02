#!/usr/bin/env bash
# ============================================================
# platforms/macos/scheduler.sh — macOS only
# LaunchAgent lifecycle: generate plist, load, unload, status.
# Source this file; do not run directly.
# ============================================================

PLIST_LABEL="com.claude.session.manager"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

# Generate the LaunchAgent plist file.
# $1 = path to session.sh, $2 = path to state dir
generate_plist() {
    local session_script="$1"
    local state_dir="$2"

    mkdir -p "$HOME/Library/LaunchAgents"

    local calendar_entries=""
    for t in "${SESSION_TIMES[@]}"; do
        local h="${t%%:*}"; h="${h#0}"; h="${h:-0}"
        local m="${t##*:}"; m="${m#0}"; m="${m:-0}"
        calendar_entries+="        <dict>
            <key>Hour</key><integer>${h}</integer>
            <key>Minute</key><integer>${m}</integer>
        </dict>
"
    done

    cat > "$PLIST_DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${session_script}</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
${calendar_entries}    </array>

    <key>StandardOutPath</key>
    <string>${state_dir}/launchagent.out</string>

    <key>StandardErrorPath</key>
    <string>${state_dir}/launchagent.err</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST
}

load_scheduler() {
    if launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"; then
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
    fi
    launchctl load "$PLIST_DEST"
}

unload_scheduler() {
    if launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"; then
        launchctl unload "$PLIST_DEST" && return 0
    fi
    return 1
}

scheduler_is_loaded() {
    launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"
}

remove_plist() {
    [[ -f "$PLIST_DEST" ]] && rm "$PLIST_DEST"
}
