# CLAUDE.md — Claude Session Manager

Context for Claude Code sessions working on this project.

## What this project does

Automates Claude Code session triggers via macOS LaunchAgent + pmset wake scheduling. Runs `claude -p "<prompt>" --model <model>` headlessly at scheduled times, even with the MacBook lid closed.

## Architecture

### Platform separation rule
- `src/` and `tests/common/` — **zero OS-specific APIs**. Pure bash + `claude` CLI only.
- `platforms/<os>/` — all OS-specific code (pmset, launchctl, systemd, rtcwake).
- Root entry points (`install.sh`, `uninstall.sh`, `reconfigure.sh`, `pause.sh`, `unpause.sh`) detect the platform via `src/detect_platform.sh` and delegate.
- Files outside `platforms/` are implicitly cross-platform. Enforce this.

### Scripts installed to TCC-safe location
macOS TCC (privacy sandbox) blocks `launchd`'s `/bin/bash` from accessing `~/Documents`. Scripts are copied to `~/.local/share/claude-session-manager/` at install time. The LaunchAgent plist points there, not to the project directory.

### Session guard (dynamic threshold)
`session_allowed()` in `src/utils.sh` computes the threshold as `min_gap_between_sessions / 2`, floored at 60 s. Sessions configured 5 minutes apart both fire correctly. `SESSION_MIN_GAP` is only the fallback for a single-session config.

### Weekend/holiday enforcement
`SCHEDULE_WEEKENDS` and `SCHEDULE_HOLIDAYS` are enforced in **two places**:
1. `schedule_upcoming_days()` — skips scheduling pmset wake events for non-workdays
2. `session.sh` — calls `is_workday(today)` and exits early if it's a non-workday

**Both are required.** The LaunchAgent fires every day (it doesn't know about weekends). Only the `session.sh` check prevents the session from actually running. The pmset check just avoids unnecessary wake events.

### pmset rolling window
- **Install / reconfigure**: `schedule_upcoming_days(N)` schedules N workdays upfront (default 365). Also cancels old events first (`cancel_our_wake_events()`).
- **After each session fires**: `reschedule_wake_events()` adds exactly 1 day at the far end — only 3 pmset calls per session, no duplicates.
- pmset events are tracked in `~/.claude-session-manager/scheduled_wakes` for precise uninstall cleanup.
- pmset events are stored in SMC hardware — survive full power-off.

### WAKE_OFFSET_SECS and the sleep timer
`WAKE_OFFSET_SECS=30` (default). The Mac wakes 30 seconds before the session. **This must be less than the system sleep timer** (`pmset -g | grep "^sleep"`). With `sleep: 1` (1-minute timer), 30 s gives 30 seconds of margin before the Mac re-sleeps.

Wake time uses **seconds precision** in `_macos_schedule_wake()` — `pmset schedule wake "MM/DD/YY HH:MM:SS"` with the full seconds component. Do not reduce to minute-only calculations (the old code used `offset / 60` which lost sub-minute precision for offsets < 60 s).

### Passwordless sudo for pmset
`src/setup-sudo.sh` writes `/etc/sudoers.d/claude-session-manager` with a narrow rule:
```
user ALL=(ALL) NOPASSWD: /usr/bin/pmset schedule wake *, /usr/bin/pmset schedule cancel wake *
```
Offered during install wizard. `uninstall.sh` removes it via `remove_passwordless_sudo()`.

### Holiday loading
`load_country_holidays()` in `src/utils.sh` sources `holidays/<country>.sh` in a subshell, captures the `HOLIDAYS` array, and merges it into the current scope. Always called before `is_workday()`.

## Key files

| File | Role |
|---|---|
| `src/session.sh` | LaunchAgent entry point — workday check → guard → trigger → extend wake window |
| `src/utils.sh` | Logging, session guard, Claude CLI trigger, holiday loader |
| `src/detect_platform.sh` | `detect_platform()` → macos / linux / windows |
| `src/suggest_times.sh` | Algorithm: work hours → 3 optimal session times |
| `src/setup-sudo.sh` | Configure/remove passwordless sudo rule for pmset |
| `platforms/macos/wake.sh` | `is_workday()`, `schedule_upcoming_days()`, `reschedule_wake_events()`, `cancel_our_wake_events()`, `_setup_passwordless_sudo()` |
| `platforms/macos/scheduler.sh` | `generate_plist()`, `load_scheduler()`, `unload_scheduler()` |
| `config.sh` | User config — generated/overwritten by install + reconfigure |
| `holidays/<cc>.sh` | Country holiday dates (2026/2027) — sourced by `load_country_holidays()` |

## Commands

```bash
bash install.sh                        # first-time setup (5-step wizard + passwordless sudo offer)
bash reconfigure.sh                    # menu: session times / model / schedule prefs / work hours
bash reinstall.sh                      # uninstall (keep state) + re-run wizard
bash pause.sh                          # unload LaunchAgent without uninstalling
bash unpause.sh                         # reload LaunchAgent + reschedule today's events
bash uninstall.sh                      # full removal (cancels pmset events + removes sudo rule)
bash src/wake-scheduler.sh             # manually refresh pmset schedule (requires sudo)
bash src/setup-sudo.sh                 # configure passwordless sudo for pmset
bash src/setup-sudo.sh remove          # remove passwordless sudo rule
bash tests/run_tests.sh                # run full test suite (platform-aware)
launchctl start com.claude.session.manager   # trigger session immediately (test)
```

## Testing

84 tests, split into:
- `tests/common/` — cross-platform (session guard, time suggestion, Claude CLI auth + headless)
- `tests/platforms/macos/` — macOS-specific (dependencies, permissions, schedule, lid simulation)

Tests do NOT cover the end-to-end pmset wake → LaunchAgent → session flow (requires hardware). Use `launchctl start` to verify the headless execution path.

Run before committing any change to `src/utils.sh`, `platforms/macos/wake.sh`, or `config.sh`.

## Known bash compatibility notes

- macOS ships bash 3.x — `${var^^}` (uppercase) not available. Use `tr '[:lower:]' '[:upper:]'`.
- `(( n++ ))` returns exit code 1 when n=0 (falsy). Under `set -e`, this kills the script. Always use `n=$(( n + 1 ))`.
- `printf` inside `$(...)` is captured — use `>&2` for interactive prompts in `ask()` / `yn()`.
- En-dash `–` (U+2013) in bash scripts causes `unbound variable` errors in bash 3.x when adjacent to `$VAR` — use regular ASCII hyphen `-`.
- BSD `date` (macOS): `-v+1d` for date arithmetic, `-j -f '%Y-%m-%d'` for parsing.
- GNU `date` (Linux): `-d "+1 day"` — different syntax. Must be abstracted in `platforms/linux/wake.sh`.

## Config template

`config.sh` is generated by `platforms/macos/install.sh` (and `reconfigure.sh`). If adding a new config variable:
1. Add it to the heredoc in `platforms/macos/install.sh`
2. Add it to `reconfigure.sh`'s template
3. Add it to the config table in `README.md`
4. Update `CLAUDE.md` key files table if it changes architecture

## Conventions

- Platform hooks are sourced, not called as subprocesses — functions defined in `platforms/macos/wake.sh` are available in `src/session.sh` after `source`.
- `reschedule_wake_events || true` in `session.sh` — pmset failures must never abort a session.
- `cancel_our_wake_events()` must be called before `schedule_upcoming_days()` in both install and reconfigure — otherwise old sessions leave orphan wake events in hardware.
- `reconfigure.sh` is a menu (4 options), not a full wizard — each option changes only the selected setting and preserves all others.
- The `SCHEDULE_WEEKENDS` / `SCHEDULE_HOLIDAYS` settings must be enforced in `session.sh` (runtime check), not only in pmset scheduling (which only affects wake events, not session execution).
