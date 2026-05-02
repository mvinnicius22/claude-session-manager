#!/usr/bin/env bash
# ============================================================
# platforms/linux/install.sh — Linux (NOT YET IMPLEMENTED)
# ============================================================
# Linux support is planned. This file is a contribution guide.
#
# What needs to be implemented:
#
# 1. SCHEDULER  — replace LaunchAgent with a systemd user timer:
#
#    ~/.config/systemd/user/claude-session.service
#    ~/.config/systemd/user/claude-session.timer
#
#    systemctl --user enable --now claude-session.timer
#
# 2. WAKE       — replace pmset with rtcwake:
#
#    sudo rtcwake -m no -s <seconds_until_wake>
#    (requires root or /etc/sudoers entry for rtcwake)
#
# 3. SLEEP      — replace pmset sleepnow with:
#
#    systemctl suspend   OR   loginctl suspend
#
# 4. DATE ARITHMETIC — replace BSD `date -v+1d` with GNU date:
#
#    date -d "+1 day" '+%Y-%m-%d'
#
# Want to contribute? Open a PR:
# https://github.com/your-org/claude-session-manager
# ============================================================

printf '[ERROR] Linux support is not yet implemented.\n' >&2
printf '        See platforms/linux/install.sh for the contribution guide.\n' >&2
exit 1
