#!/usr/bin/env bash
# ============================================================
# platforms/linux/scheduler.sh — Linux (NOT YET IMPLEMENTED)
#
# Linux equivalent of platforms/macos/scheduler.sh.
# Replace LaunchAgent with systemd user timers:
#
#   ~/.config/systemd/user/claude-session.service
#   ~/.config/systemd/user/claude-session.timer
#
#   systemctl --user enable --now claude-session.timer
#   systemctl --user status claude-session.timer
# ============================================================

generate_plist()     { printf '[ERROR] Use systemd on Linux — see platforms/linux/scheduler.sh\n' >&2; return 1; }
load_scheduler()     { printf '[ERROR] Not implemented on Linux.\n' >&2; return 1; }
unload_scheduler()   { printf '[ERROR] Not implemented on Linux.\n' >&2; return 1; }
scheduler_is_loaded(){ return 1; }
remove_plist()       { return 0; }
