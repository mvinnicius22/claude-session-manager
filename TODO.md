# TODO — Claude Session Manager

Last updated: 2026-05-02

---

## Next session

### Linux support (high priority for open-source reach)
- Implement `platforms/linux/install.sh` — systemd user timer + cron
- Implement `platforms/linux/wake.sh` — `rtcwake` for hardware wake; `systemctl suspend` for sleep
- Implement `platforms/linux/scheduler.sh` — generate/load/unload systemd `.service` + `.timer`
- Implement `tests/platforms/linux/test_dependencies.sh`
- Key difference: GNU `date -d "+1 day"` vs BSD `date -v+1d` (already noted in CLAUDE.md)

### Sleep timer detection in install wizard
- `pmset -g | grep "^sleep"` reveals the system sleep timer (e.g. `sleep: 1` = 1 minute)
- If detected sleep timer ≤ WAKE_OFFSET_SECS, warn the user and suggest adjusting one or the other
- Could auto-set WAKE_OFFSET_SECS = `sleep_timer_seconds / 2`
- This would prevent the race condition that caused 13-minute delays in testing

### Login LaunchAgent for wake-schedule auto-setup on boot
- When the Mac boots after a period of no sessions (vacation, etc.), the rolling window may have gaps
- Solution: a second LaunchAgent (`com.claude.session.wake-refresher.plist`) that runs at login and calls `src/wake-scheduler.sh` for the next 30 days
- Requires passwordless sudo to be set up first

### pmset batching optimisation
- Current: `schedule_upcoming_days(365)` calls sudo ~780 times sequentially (~1 min at install)
- Better: write all commands to a temp script and run with a single `sudo bash /tmp/script.sh`
- Would reduce install time from ~1 min to ~5 s

---

## Pending / deferred

### Holiday files — annual update process
- `holidays/*.sh` currently cover 2026 and 2027 dates
- Moveable feasts (Easter-based) need recalculating each year
- **Action**: add 2028 dates before end of 2027

### Windows support
- Task Scheduler (`schtasks`) replaces LaunchAgent
- `powercfg` for wake management
- Create `platforms/windows/` with contribution guide

### Test: `load_country_holidays()` coverage
- No dedicated test for the holiday loader function
- Add to `tests/common/test_holidays.sh`

### Test: `is_workday()` with various SCHEDULE_WEEKENDS/HOLIDAYS configs
- Currently tested implicitly; should have explicit unit tests

### `status.sh` command
- Show: LaunchAgent loaded/paused, next session times, last session timestamp, pmset wake count
- Planned but not implemented

### More country holiday files
- Currently: br, us, uk, de, fr, pt, ar, mx
- Most-requested: ca, au, jp, es, it, co, cl

---

## Decisions made this session (2026-05-02)

### WAKE_OFFSET_SECS changed from 180s → 60s → 30s (final)
Root cause: with `sleep: 1` (1-minute sleep timer on battery), waking 1 minute early created a race between the idle sleep timer and the LaunchAgent — sometimes sleep won. Solution: 30s offset → LaunchAgent fires at session time, sleep fires 30s later. If user has a longer sleep timer, larger offsets also work.

### Wake time uses seconds precision
Old code used `offset / 60` (integer division) — any offset < 60 s was treated as 0. New code converts to total seconds and formats as `HH:MM:SS`, allowing the 30-second offset to be exact. Change in `_macos_schedule_wake()` in `platforms/macos/wake.sh`.

### SCHEDULE_WEEKENDS/HOLIDAYS enforced in session.sh (not just pmset)
The LaunchAgent fires every day regardless. `is_workday()` check added to `session.sh` before triggering. Without this, sessions fire on weekends/holidays even with `SCHEDULE_WEEKENDS=false`. Both the pmset scheduling AND the runtime check are needed.

### cancel_our_wake_events() in reconfigure + install
Without canceling old events first, changing session times leaves orphan wake events in hardware from the previous schedule. Now: cancel → reschedule every time times change.

### Passwordless sudo integrated into install wizard
`_setup_passwordless_sudo()` offered at end of install wizard. Writes `/etc/sudoers.d/claude-session-manager` with minimal scope. `uninstall.sh` removes it. Standalone: `bash src/setup-sudo.sh`.

### reconfigure.sh is a 4-option menu (not a full wizard)
The 5-step wizard was wrong for reconfigure because changing one thing required going through all 5 steps. Menu lets users change only what they need. Each option writes the COMPLETE config (all values preserved).

### pmset wake confirmed working on battery with lid closed
Test on 2026-05-02: session configured for 15:00, Mac on battery with lid closed, pmset fired at 14:59:30, LaunchAgent fired at 15:00:04. Confirmed end-to-end flow works without AC power.

### 2026-05-01 — Dynamic session guard threshold
Guard threshold = `min_gap_between_sessions / 2`. Sessions 5 min apart both fire. `SESSION_MIN_GAP` is only a fallback.

### 2026-05-01 — Rolling window for pmset (extend by 1 day per session)
`reschedule_wake_events()` adds events only for `today + SCHEDULE_DAYS_AHEAD`. 3 pmset calls per session vs 1095 at install.

### 2026-05-01 — TCC-safe install location
Scripts installed to `~/.local/share/claude-session-manager/` (not `~/Documents`). LaunchAgent plist points there.

### 2026-05-01 — reconfigure.sh is the single UX entry point
All post-install changes go through `reconfigure.sh`. It handles: config rewrite, LaunchAgent reload, pmset cancel+reschedule, session guard reset.
