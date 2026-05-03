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
- `pmset schedule wake` only fires from sleep (S3) — **not from full shutdown (S5)**. The Mac must be sleeping, not powered off. For shutdown support, `pmset schedule poweron` would be needed (not implemented).

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
| `src/defaults.sh` | Canonical default values — `DEFAULT_*` vars + `CLAUDE_MODEL_*` constants |
| `src/ensure-config.sh` | Sources `defaults.sh`; regenerates `config.sh` + cancels stale pmset events if missing |
| `src/config.example.sh` | Human-readable config reference — sources `defaults.sh`, uses `$DEFAULT_*` |
| `platforms/macos/wake.sh` | `is_workday()`, `schedule_upcoming_days()`, `reschedule_wake_events()`, `cancel_our_wake_events()`, `_setup_passwordless_sudo()` |
| `platforms/macos/scheduler.sh` | `generate_plist()`, `load_scheduler()`, `unload_scheduler()` |
| `status.sh` | Shows current config + runtime state (scheduler, last session, next sessions today) |
| `config.sh` | User config — generated/overwritten by install + reconfigure (gitignored) |
| `holidays/<cc>.sh` | Country holiday dates (2026/2027) — sourced by `load_country_holidays()`. Supported: br us uk de fr pt ar mx nl |

## Commands

```bash
bash install.sh                        # first-time setup (5-step wizard + passwordless sudo offer)
bash reconfigure.sh                    # menu: session times / model / schedule prefs / work hours
bash reinstall.sh                      # uninstall (keep state) + re-run wizard
bash status.sh                         # show current config + runtime state
bash pause.sh                          # unload LaunchAgent without uninstalling
bash unpause.sh                        # reload LaunchAgent + reschedule today's events
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

`config.sh` is generated by `platforms/macos/install.sh` (and `reconfigure.sh`), and auto-regenerated by `src/ensure-config.sh` if accidentally deleted. If adding a new config variable:
1. Add its default to `src/defaults.sh` as `DEFAULT_<VAR_NAME>`
2. Add it to the heredoc in `platforms/macos/install.sh` using `${DEFAULT_<VAR_NAME>}`
3. Add it to `reconfigure.sh`'s heredoc
4. Add it to `src/ensure-config.sh`'s heredoc
5. Add it to `src/config.example.sh` using `$DEFAULT_<VAR_NAME>`
6. Add it to the config table in `README.md`
7. Update `CLAUDE.md` key files table if it changes architecture

## config.sh lifecycle

- **gitignored** — never committed; user-specific
- **auto-generated** — by `ensure-config.sh` on first run of any script, using defaults from `src/defaults.sh`
- **wizard-generated** — by `install.sh` / `reconfigure.sh` with user's choices
- **on deletion** — `ensure-config.sh` detects the missing file, cancels stale pmset wake events (via tracking file), and regenerates from defaults. User must re-run `reconfigure.sh` and `bash src/wake-scheduler.sh`.

## Conventions

- Platform hooks are sourced, not called as subprocesses — functions defined in `platforms/macos/wake.sh` are available in `src/session.sh` after `source`.
- `reschedule_wake_events || true` in `session.sh` — wake scheduling failures must never abort a session.
- `cancel_our_wake_events()` must be called before `schedule_upcoming_days()` in both install and reconfigure — otherwise old sessions leave orphan wake events in hardware.
- `reconfigure.sh` is a menu (5 options), not a full wizard — each option changes only the selected setting and preserves all others.
- The `SCHEDULE_WEEKENDS` / `SCHEDULE_HOLIDAYS` settings must be enforced in `session.sh` (runtime check), not only in wake scheduling (which only affects wake events, not session execution).
- All default values live exclusively in `src/defaults.sh`. Never hardcode a default anywhere else — use `$DEFAULT_*`.
- Every script that sources `config.sh` must source `src/ensure-config.sh` immediately before it.

---

## Implementing a new platform

**Read this entire section before writing a single line of code.** The macOS implementation is the canonical reference. New platforms must mirror its structure and behavior exactly — users should experience the same wizard flow, the same reconfigure menu, the same commands, regardless of OS.

### Platform separation: the absolute rule

```
src/           — zero OS-specific code. Pure bash + claude CLI only.
platforms/     — all OS-specific code goes here, nowhere else.
```

**Never add `if [[ "$PLATFORM" == "linux" ]]` inside `src/`.** If a generic interface is needed, add a function stub to each platform's wake.sh and call it from session.sh generically. See how `platform_sleep_now()` and `reschedule_wake_events()` work.

### Required function contracts

Every `platforms/<os>/wake.sh` **must** implement these exact function signatures:

```bash
is_workday(ymd)               # returns 0 if session should fire on this date
schedule_upcoming_days(days, mode)  # schedule N workdays; mode="run"|"dry-run"
reschedule_wake_events()      # extend rolling window by 1 day after each session
cancel_our_wake_events()      # cancel all tracked events (called by uninstall)
platform_sleep_now()          # sleep machine after session (if AUTO_SLEEP=true)
```

Every `platforms/<os>/scheduler.sh` **must** implement:

```bash
generate_plist()    # or generate_service() — create the scheduler config file
load_scheduler()    # activate the scheduler (launchctl / systemctl / schtasks)
unload_scheduler()  # deactivate
scheduler_is_loaded()  # returns 0 if the scheduler is currently active
remove_plist()      # or remove_service() — delete the scheduler config file
```

If a function is not applicable (e.g. hardware wake not supported), implement it as a stub that logs a warning and returns 0. **Never leave a function undefined** — `session.sh` calls them unconditionally.

### install.sh for the new platform

Model: `platforms/macos/install.sh`. The wizard must:

1. Source `$PROJECT_DIR/src/defaults.sh` **first**, before anything else
2. Pre-fill from existing config: `[[ -f "$PROJECT_DIR/config.sh" ]] && source "$PROJECT_DIR/config.sh"`
3. Normalize SCHEDULE_DAYS_AHEAD: `[[ "${SCHEDULE_DAYS_AHEAD:-}" =~ ^[0-9]+$ ]] || SCHEDULE_DAYS_AHEAD=$DEFAULT_SCHEDULE_DAYS_AHEAD`
4. Run the exact same 5-step wizard (Work Hours → Session Schedule → Model → Schedule Prefs → Country Holidays)
5. Use the same UI helpers (`ok()`, `warn()`, `err()`, `hr()`, `step()`, `ask()`, `yn()`) with the same color variables
6. Write `config.sh` via heredoc using `$DEFAULT_*` for non-user-chosen fields
7. Install scripts to the same TCC-safe location: `~/.local/share/claude-session-manager/`
8. Offer the platform equivalent of passwordless privilege if applicable

**Wizard step order is fixed.** Do not reorder, skip, or merge steps. Users across platforms must have the same mental model.

### reconfigure.sh — already cross-platform

`reconfigure.sh` at the project root handles all platforms. It is a 5-option menu:
1. Session times
2. Model
3. Weekend / holiday / days-ahead
4. Work hours (recalculates suggested session times)
5. Holiday country

It writes `config.sh` and then has a `case "$PLATFORM"` block to reload the scheduler and reschedule wake events. When adding a new platform, add a `linux)` / `windows)` branch to that block. Do not create a separate `platforms/<os>/reconfigure.sh`.

When adding a new country holiday file, add its code to the `_crow` list and `case` block in **both** `platforms/macos/install.sh` (Step 5) and `reconfigure.sh` (option 5). The two lists must always be in sync.

### UI consistency rules

Copy these color variables verbatim into every platform's `install.sh`:

```bash
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_GREEN='\033[0;32m'; C_BOLD_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[0;36m'
C_BOLD_CYAN='\033[1;36m'; C_RED='\033[0;31m'; C_BLUE='\033[0;34m'
```

Copy these helper functions verbatim (already identical across install.sh and reconfigure.sh):

```bash
ok()   { printf "${C_BOLD_GREEN}  ✓${C_RESET}  %s\n" "$1"; }
info() { printf "${C_BLUE}  →${C_RESET}  %s\n" "$1"; }
warn() { printf "${C_YELLOW}  ⚠${C_RESET}  %s\n" "$1"; }
err()  { printf "${C_RED}  ✗${C_RESET}  %s\n" "$1" >&2; }
hr()   { printf "  ${C_DIM}%s${C_RESET}\n" "────────────────────────────────────"; }
step() { echo ""; printf "  ${C_BOLD_CYAN}Step $1/$2${C_RESET}${C_BOLD} — $3${C_RESET}\n"; hr; }
ask()  { ... }   # prompt with dimmed default — copy from install.sh
yn()   { ... }   # yes/no with dimmed default — copy from install.sh
```

Header format is always: `printf "  ${C_BOLD_CYAN}Claude Session Manager${C_RESET} ${C_DIM}— <Subtitle>${C_RESET}\n"`

### Config generation — use defaults.sh

The heredoc in `platforms/<os>/install.sh` must use `$DEFAULT_*` for every field not directly chosen by the wizard. Never hardcode a numeric or string default. Example:

```bash
cat > "$PROJECT_DIR/config.sh" <<CFG
SESSION_MIN_GAP=${DEFAULT_SESSION_MIN_GAP}
WAKE_OFFSET_SECS=${DEFAULT_WAKE_OFFSET_SECS}
...
CFG
```

If the platform doesn't support hardware wake (e.g. a VM), `WAKE_OFFSET_SECS` is still written — it's ignored at runtime if `reschedule_wake_events()` is a stub.

### Cross-platform regression rules

1. **Run `bash tests/run_tests.sh` after every change.** Common tests run on all platforms. A macOS regression on a Linux branch is a blocker.
2. **Never modify `src/utils.sh` for platform-specific behavior.** It is loaded by all platforms.
3. **`session.sh` calls functions by name** — if your platform's wake.sh doesn't define them, the session fails silently.
4. **config.sh variables are the interface** — if you add a new config variable, follow the 7-step checklist in "Config template" above. Partial additions break all platforms.
5. **`src/ensure-config.sh`'s heredoc must stay in sync** with `install.sh`'s heredoc — both generate `config.sh` from scratch.

### Testing requirements for a new platform

Minimum test suite in `tests/platforms/<os>/`:

| File | What to test |
|---|---|
| `test_dependencies.sh` | Required commands exist; platform functions are defined |
| `test_permissions.sh` | Script executability; state dir writable; scheduler service valid |
| `test_schedule.sh` | SESSION_TIMES format/gaps; CLAUDE_MODEL in VALID_MODELS; work hours set; wake events exist |
| `test_wake.sh` (optional) | If hardware wake is supported, verify scheduling round-trip |

Rules:
- Source `$PROJECT_DIR/src/ensure-config.sh` before `config.sh` in every test file
- Use `$CLAUDE_MODEL_HAIKU`, `$CLAUDE_MODEL_SONNET`, `$CLAUDE_MODEL_OPUS` from defaults.sh for VALID_MODELS — never hardcode model IDs
- Use `$DEFAULT_*` for expected values in assertions — never hardcode `365`, `18000`, etc.
- Mirror the macOS test structure: PASS/FAIL counters, `ok()` / `fail()` / `skip()` helpers, same exit code convention

Add the new test directory to `tests/run_tests.sh`'s platform detection block.

### Known edge cases and pitfalls

**Linux-specific:**
- `rtcwake` can wake from S3 (suspend) but **not** from S5 (powered off). Document this clearly — it's a hardware limitation.
- systemd timers may fire missed events on resume (catchup). The session guard in `src/utils.sh` prevents double-firing — do not add redundant guards.
- `date -d` (GNU) vs `date -v` (BSD/macOS) — all date arithmetic must stay in `platforms/linux/wake.sh`. Never use `date -v` in shared code.
- `/dev/rtc0` requires root on most distros. `rtcwake` needs sudo, same as pmset. Offer passwordless sudo in the install wizard for the specific rtcwake command.

**Windows-specific:**
- `schtasks` and `powercfg` require Administrator rights. Handle UAC elevation in `platforms/windows/install.sh`.
- Git Bash / WSL have different PATH behavior — `detect_platform.sh` must distinguish WSL (Linux) from native Windows.
- `powercfg /waketimers` tracks wake timers but cancellation is less precise than pmset — design `cancel_our_wake_events()` accordingly.

**General:**
- **Session fires at wrong time after config.sh deletion**: `ensure-config.sh` cancels stale pmset/rtcwake events and regenerates config with defaults. User must then run `reconfigure.sh` + `src/wake-scheduler.sh`. Document in `--help` or first-run messages.
- **Multiple sessions in quick succession**: always rely on the dynamic guard in `src/utils.sh`. Do not implement a separate guard in platform code.
- **SCHEDULE_WEEKENDS/HOLIDAYS ignored**: must be enforced in TWO places — `schedule_upcoming_days()` (skips scheduling) AND `session.sh`'s `is_workday()` check. If only one is enforced, sessions fire on holidays or vice versa.
- **Wake offset vs system sleep timer**: if `WAKE_OFFSET_SECS` ≥ system sleep timer, the machine re-sleeps before the session fires. On macOS, check `pmset -g | grep "^sleep"`. Warn the user in the install wizard if offset ≥ detected timer.

### Checklist before opening a PR for a new platform

- [ ] `platforms/<os>/install.sh` — 5-step wizard, sources defaults.sh, writes config.sh via heredoc
- [ ] `platforms/<os>/scheduler.sh` — all 5 required functions implemented
- [ ] `platforms/<os>/wake.sh` — all 5 required functions implemented; sources defaults.sh
- [ ] `platforms/<os>/uninstall.sh` — sources ensure-config.sh, cancels events, removes service
- [ ] `reconfigure.sh` — new platform branch added to the `case "$PLATFORM"` block
- [ ] `install.sh` (root) — new platform branch added
- [ ] `tests/platforms/<os>/` — minimum 3 test files
- [ ] `tests/run_tests.sh` — new platform detection added
- [ ] `tests/run_tests.sh` on macOS passes (all 84 common + macOS tests still green)
- [ ] `src/defaults.sh`, `src/utils.sh`, `src/session.sh` — unchanged
- [ ] `docs/adr/` — new ADR for any architectural decision specific to the platform
- [ ] `CLAUDE.md` and `README.md` — updated with platform-specific notes
