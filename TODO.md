# TODO — Claude Session Manager

Last updated: 2026-05-08 (session 4)

---

## Next session

### Common

#### Custom user-script hooks
Add a `user-scripts/` folder at the project root (gitignored; ship a `user-scripts/example.sh.disabled` as documentation). After `trigger_claude_session()` succeeds, `session.sh` discovers and runs all executable `*.sh` files in the folder alphabetically. Each script runs as a subprocess (not sourced) with a configurable timeout; failures are logged but never abort the session (`|| true`). Session context is exported as env vars: `SESSION_DATE`, `SESSION_TIME`, `CLAUDE_MODEL`, `STATE_DIR`, `LOG_FILE`.

Use cases: Slack/Discord notifications, custom Claude/MCP interactions, git pulls, scheduled messages. Unlike `INITIAL_PROMPT`, these scripts have full shell access and can call any CLI tool.

Design notes:
- `user-scripts/` copied to INSTALL_DIR by `install.sh` and `reconfigure.sh` alongside `src/` and `platforms/`
- New config var `USER_SCRIPTS_TIMEOUT=30` (seconds per script); add to `src/defaults.sh` and all heredocs
- `session.sh` loop: `for _s in "$PROJECT_DIR/user-scripts/"*.sh; do [[ -x "$_s" ]] && timeout "$USER_SCRIPTS_TIMEOUT" "$_s" >> "$LOG_FILE" 2>&1 || true; done`
- Scripts run after Claude session — Claude fires even if a hook would fail

---

### macOS

#### Sleep timer detection in install wizard
`pmset -g | grep "^sleep"` reveals the system sleep timer (e.g. `sleep: 1` = 1 minute). If the detected timer ≤ `WAKE_OFFSET_SECS`, warn the user and suggest adjusting one or the other. Could auto-set `WAKE_OFFSET_SECS = sleep_timer_seconds / 2`. Prevents the race condition where the Mac re-sleeps before the LaunchAgent fires.

#### Login LaunchAgent for wake-schedule auto-setup on boot
When the Mac boots after an extended offline period (vacation, etc.), the rolling pmset window may have gaps between the last scheduled event and today. Solution: a second LaunchAgent (`com.claude.session.wake-refresher.plist`) that runs at login and calls `src/wake-scheduler.sh` for the next 30 days. Requires passwordless sudo to already be set up. Low overhead — only runs at login, exits immediately if the window is still full.

#### pmset batching optimisation
`schedule_upcoming_days(365)` calls `sudo pmset` sequentially ~1095 times at install and on every `reconfigure.sh` save (~1–2 min). Better: collect all `pmset schedule wake "..."` commands into a temp script and run once via `sudo bash /tmp/pmset-batch.sh`. Would reduce scheduling time from ~2 min to ~5 s. Spec: write commands to `mktemp`, run with sudo, delete temp file; preserve tracking file logic.

---

## Pending / deferred

### Common

#### Holiday files — annual update process
`holidays/*.sh` currently cover 2026 and 2027. Moveable feasts (Easter-based) need recalculating each year. **Action**: add 2028 dates before end of 2027.

#### Test: `load_country_holidays()` coverage
No dedicated test for the holiday loader function. Add to `tests/common/test_holidays.sh`.

#### Test: `is_workday()` with various SCHEDULE_WEEKENDS/HOLIDAYS configs
Currently tested implicitly; should have explicit unit tests for all flag combinations.

---

### macOS

#### Wake support from full shutdown (S5)
`pmset schedule wake` only fires from sleep (S3) — confirmed does NOT fire from full shutdown. To support S5:
- Investigate `pmset schedule poweron` (works on Intel; Apple Silicon behavior unconfirmed)
- After a full boot, LaunchAgent may not be loaded yet when `session.sh` fires — evaluate `WaitForNetworkReachability` in the plist or a startup delay
- Post-session: `shutdown -h now` instead of `pmset sleepnow`
- Low priority: most Mac users sleep rather than shut down

---

## Decisions made this session (2026-05-08, session 4)

### install.sh — opt-out of work-hours inference
Added `"Suggest session times from your work hours? [Y/n]"` at the top of Step 1. Default Y preserves the existing flow (ask hours → suggest → confirm). Answering N still collects `WORK_START`/`WORK_END` (needed by reconfigure option 4) but skips the suggestion block and goes straight to custom time input. Closing note added pointing to `bash reconfigure.sh` for future changes.

### reconfigure.sh — persistent menu loop
Wrapped the entire menu in `while true`. Options 1–5 execute, write config, sync scripts, reload the scheduler, print the Done summary, then return to the menu. Option 0 exits. Unknown inputs warn and loop back without writing config.

### status.sh — human-readable countdown
Durations ≥ 60 min now display as `Xh Ymin` (e.g. `3h 29min`). Under 60 min keeps the existing `N min` format.

---

## Decisions made this session (2026-05-06, session 3)

### Minimal headless session flags (`CLAUDE_EXTRA_FLAGS` / `CLAUDE_DISABLE_TOOLS`)
`claude -p` loads Claude Code's full context on every call: built-in tool definitions (~10–15K tokens) + all user-configured MCP servers (Notion, Gmail, etc.). Even a trivial "say: 'ok'" prompt consumed ~2% of a Pro plan per session due to this overhead.

New config vars added to `src/defaults.sh` and all config heredocs:
- `CLAUDE_EXTRA_FLAGS="--no-session-persistence --strict-mcp-config"` — skips session history writes and ignores user MCP servers
- `CLAUDE_DISABLE_TOOLS=true` — appends `--tools ""` as two separate array elements (empty-string arg requires array, not string expansion)

`trigger_claude_session()` in `src/utils.sh` now builds a bash array (`local -a args`) to avoid quoting issues with `--tools ""`. Users who need tools or MCP in their `INITIAL_PROMPT` set `CLAUDE_EXTRA_FLAGS=""` and `CLAUDE_DISABLE_TOOLS=false` in `config.sh`.

### `reconfigure.sh` syncs all scripts to INSTALL_DIR
Previously `reconfigure.sh` only copied `config.sh` to `~/.local/share/claude-session-manager/`. Updated scripts (`src/`, `platforms/`, `holidays/`) required `reinstall.sh` to take effect. Now `reconfigure.sh` copies all three directories + config before reloading the LaunchAgent — a `git pull` + `bash reconfigure.sh` is sufficient to update the running installation.

### Warning deduplication in `_macos_schedule_wake`
When passwordless sudo is not configured, the old code emitted one `[WARN]` per scheduled event (up to 1095 lines for 365 days × 3 sessions). Now a module-level `_PMSET_SUDO_WARNED` flag (reset by `schedule_upcoming_days` at the start of each run) limits the warning to one line, followed by a summary at the end of the run.

### `cancel_our_wake_events` preserves tracking file on total sudo failure
Previously `rm -f "$tracking"` ran unconditionally — if all `sudo pmset cancel` calls failed (sudo not configured), the tracking file was deleted with no events actually cancelled. Old events remained in hardware with no record for future cleanup. Now: if `cancelled == 0` and events existed, the tracking file is preserved and a clear warning is shown. Next run (after sudo is fixed) retries cancellation with the intact file.

---

## Decisions made this session (2026-05-02, session 2)

### Centralized defaults via `src/defaults.sh`
All hardcoded default values (`365`, `18000`, `claude-haiku-*`, etc.) consolidated into `src/defaults.sh` as `DEFAULT_*` variables and `CLAUDE_MODEL_*` constants. Every script that needs a default now references `$DEFAULT_*` instead of a literal. Single place to change any default.

### `src/ensure-config.sh` — shared guard replacing duplicated inline blocks
Seven scripts had identical 4-line `if [[ ! -f config.sh ]]; then ... fi` blocks. Extracted into `src/ensure-config.sh`, which (a) sources `defaults.sh`, (b) regenerates `config.sh` from a heredoc if missing, and (c) cancels stale pmset wake events before regenerating.

### `resume.sh` → `unpause.sh`
Renamed for symmetry with `pause.sh`. All references updated.

### `status.sh` implemented
Shows: configuration table, runtime state (scheduler loaded/paused, last session, sudo rule), next sessions today with countdown, file paths.

### `config.sh` gitignored
User config is machine-specific and wizard-generated. Added `src/config.example.sh` and `src/ensure-config.sh` as the recovery path.

### WAKE_OFFSET_SECS changed from 180s → 30s (final)
Root cause: with `sleep: 1` (1-minute sleep timer on battery), waking 1 minute early created a race between the idle sleep timer and the LaunchAgent. 30s offset → LaunchAgent fires at session time, sleep fires 30s later.

### Wake time uses seconds precision
Old code used `offset / 60` (integer division) — offsets < 60 s were treated as 0. New code formats as `HH:MM:SS` for exact sub-minute precision.

### SCHEDULE_WEEKENDS/HOLIDAYS enforced in both `session.sh` and pmset scheduling
The LaunchAgent fires every day regardless. `is_workday()` added to `session.sh` as runtime guard. Both layers required.

### Dynamic session guard threshold
Guard threshold = `min_gap_between_sessions / 2`. Sessions 5 min apart both fire. `SESSION_MIN_GAP` is fallback only.

### Rolling window for pmset (extend by 1 day per session)
`reschedule_wake_events()` adds events only for `today + SCHEDULE_DAYS_AHEAD`. 3 pmset calls per session vs 1095 at install.

### TCC-safe install location
Scripts installed to `~/.local/share/claude-session-manager/`. LaunchAgent plist points there, not to `~/Documents`.

### pmset wake confirmed working on battery with lid closed
Test on 2026-05-02: session configured for 15:00, Mac on battery, lid closed. pmset fired at 14:59:30, LaunchAgent at 15:00:04. `pmset schedule wake` only fires from sleep (S3), not full shutdown (S5).
