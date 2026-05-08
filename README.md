# Claude Session Manager

> 🍎 **macOS only for now.** Linux and Windows are on the roadmap — [contributions welcome](#contributing).

Automatically triggers Claude Code sessions at scheduled times — headless, no window required, works with the MacBook lid closed.

Designed to maximize your Claude Code usage across multiple 5-hour billing windows per day.

---

## How it works

```
┌─────────────────────────────────────────────────────────────┐
│  pmset schedule wake  →  Mac wakes at 05:29                 │
│  LaunchAgent fires   →  src/session.sh runs at 05:30        │
│  claude -p "oi"      →  triggers the session (headless)     │
│  Mac sleeps again    →  (optional, AUTO_SLEEP=true)         │
└─────────────────────────────────────────────────────────────┘
```

The session script runs `claude -p "<prompt>" --model <model>` — non-interactive mode, no terminal window, no display required. Works with the MacBook lid closed.

---

## Requirements

| Requirement | Notes |
|---|---|
| [Claude Code CLI](https://claude.ai/code) | The `claude` binary must be installed |
| macOS 12+ | Linux support planned (see [Contributing](#contributing)) |
| Claude Subscription | Needed to have multiple usage windows |

---

## Installation

```bash
git clone https://github.com/your-org/claude-session-manager
cd claude-session-manager
bash install.sh
```

The installer detects your OS and runs a 5-step wizard:

1. **Work hours** — e.g. `09:00` to `17:00`
2. **Session times** — auto-suggested based on your work hours, or custom
3. **Model** — default is Haiku (cheapest; perfect for a short trigger prompt)
4. **Schedule preferences** — weekends, holidays, days ahead to pre-schedule
5. **Holiday calendar** — pick your country (`br`, `us`, `uk`, `de`, `fr`, `pt`, `ar`, `mx`, `nl`)

### What gets installed

| Component | Location | Purpose |
|---|---|---|
| Scripts | `~/.local/share/claude-session-manager/` | TCC-safe location (avoids macOS sandbox errors) |
| LaunchAgent | `~/Library/LaunchAgents/com.claude.session.manager.plist` | Fires at scheduled times |
| State & logs | `~/.claude-session-manager/` | Timestamps, session log |

---

## Session time suggestion

Given your work hours, the installer calculates the 3 optimal session start times to maximize overlap with your working day.

**Example: work 09:00–17:00**

```
Session 1 starts: 05:30  →  active during work: 09:00–10:30  (1h30m)
Session 2 starts: 10:30  →  active during work: 10:30–15:30  (5h00m)
Session 3 starts: 15:30  →  active during work: 15:30–17:00  (1h30m)
─────────────────────────────────────────────────────────────
Total work coverage: 8h (entire work day)
```

Sessions are placed symmetrically: the middle session covers the core work day; the two bookends cover the edges.

---

## Configuration

Already ran `install.sh`? The wizard only runs once — use `reconfigure.sh` for any subsequent changes:

```bash
bash reconfigure.sh
```

To edit a value not covered by the menu (e.g. `INITIAL_PROMPT`), open `config.sh` directly.

Options available in `reconfigure.sh`:
1. Session times
2. Model
3. Schedule preferences (weekends, holidays, days ahead)
4. Work hours (recalculates suggested session times)
5. Holiday country

| Variable | Default | Description |
|---|---|---|
| `SESSION_TIMES` | auto-calculated | Array of HH:MM session start times |
| `SESSION_MIN_GAP` | `18000` | Fallback guard gap (s). Overridden automatically when multiple sessions are configured — guard uses half the smallest inter-session gap instead. |
| `CLAUDE_MODEL` | `claude-haiku-4-5-20251001` | Model for trigger prompt |
| `INITIAL_PROMPT` | `reply: ok` | Prompt sent at session start. Minimizes output tokens — change to anything you want (`%time%` and `%date%` are expanded at runtime) |
| `WORK_START` | `09:00` | Used by `reconfigure.sh` for time suggestions |
| `WORK_END` | `17:00` | Used by `reconfigure.sh` for time suggestions |
| `SCHEDULE_WEEKENDS` | `false` | `true` = fire sessions on Sat/Sun |
| `SCHEDULE_HOLIDAYS` | `false` | `true` = fire sessions on holidays |
| `SCHEDULE_DAYS_AHEAD` | `365` | Days ahead to pre-schedule wake events |
| `HOLIDAY_COUNTRY` | `"br"` | Country code for holiday file (`holidays/<country>.sh`) |
| `HOLIDAYS` | `()` | Manual holiday overrides (merged with country file) |
| `AUTO_SLEEP` | `false` | Sleep the Mac after triggering |
| `WAKE_OFFSET_SECS` | `30` | Seconds before session time to schedule the pmset wake. 30 s is enough for sleep-wake (~3 s); increase to 120 s if you power off completely between sessions. Must be less than your macOS system sleep timer (check: `pmset -g | grep "^sleep"`). |
| `CLAUDE_BIN` | auto-detect | Full path to `claude` binary |

---

## Cost

Each session fires one headless `claude -p` call. By default the tool is configured for minimal token usage:

```bash
claude -p "say: 'ok'" \
  --model claude-haiku-4-5-20251001 \
  --no-session-persistence \
  --strict-mcp-config \
  --tools ""
```

| Flag | Effect |
|---|---|
| `--no-session-persistence` | Skips writing session history to disk |
| `--strict-mcp-config` | Ignores all user-configured MCP servers (Notion, Gmail, etc.) |
| `--tools ""` | Removes built-in tool definitions from the system prompt |

Without these flags, `claude -p` loads the full Claude Code context — tool definitions + all MCP servers — which can add 6 000–15 000 input tokens per call regardless of how short the prompt is.

**Typical cost per session (Haiku, default flags):**

| Tokens | Haiku price | Cost |
|---|---|---|
| ~300–500 input | $0.80 / MTok | ~$0.00025–$0.00040 |
| ~5 output | $0.40 / MTok | ~$0.000002 |
| **Total** | | **~$0.0003/session** |

3 sessions/day × 30 days ≈ **$0.03/month**.

In practice, **cost is negligible** — a single trigger never reaches 1% of a Pro plan session. MCP servers are not loaded, no tool definitions are sent, and the prompt itself is just a few tokens. The tool exists to maximize availability of your sessions, not to consume them.

> If your `INITIAL_PROMPT` needs tools or MCP access, set `CLAUDE_DISABLE_TOOLS=false` and `CLAUDE_EXTRA_FLAGS=""` in `config.sh`. Cost will increase proportionally to the number of MCP servers configured.

### Session log

Every session appends two lines to `~/.claude-session-manager/session.log`:

1. **JSON response** (yellow) — the full API response including usage metadata
2. **Tokens summary** (green) — parsed from the JSON, no extra API call

```
{"type":"result","subtype":"success","total_cost_usd":0.00030,"usage":{"input_tokens":312,...},...}
[2026-05-08 05:30:04] [INFO]  Tokens: input=312 output=4 cost_usd=0.00030
```

Watch live:

```bash
tail -f ~/.claude-session-manager/session.log
```

---

## Holiday calendars

Sessions automatically skip public holidays based on your country. Set in `config.sh`:

```bash
HOLIDAY_COUNTRY="br"   # loads holidays/br.sh
```

**Supported countries:**

| Code | Country |
|---|---|
| `br` | Brazil / Brasil |
| `us` | United States |
| `uk` | United Kingdom (England & Wales) |
| `de` | Germany / Deutschland |
| `fr` | France |
| `pt` | Portugal |
| `ar` | Argentina |
| `mx` | Mexico / México |
| `nl` | Netherlands / Nederland (\*) |

> (\*) Bevrijdingsdag (May 5) is included only in lustrum years (2025, 2030…). Add `"<year>-05-05"` to `HOLIDAYS=()` for non-lustrum years if your company observes it.

The country file (e.g. `holidays/br.sh`) is merged with any dates in `HOLIDAYS=()` in `config.sh`. Use `HOLIDAYS=()` for city/state/regional holidays not covered by the country file:

```bash
HOLIDAY_COUNTRY="br"

HOLIDAYS=(
    "2026-07-09"   # São Paulo city anniversary
    "2026-11-02"   # dia do servidor público
)
```

### Adding a new country

1. Create `holidays/<country_code>.sh` following the same format as existing files
2. Set `HOLIDAY_COUNTRY="<country_code>"` in `config.sh`
3. Open a PR — your contribution helps everyone!

---

## Daily workflow

Once installed, `install.sh` never needs to run again. **`reconfigure.sh` is the single command for everything** — it handles session times, model, wake schedule, LaunchAgent reload, and session guard reset in one step.

```bash
# Change anything (times, model, country, weekends, days ahead)
bash reconfigure.sh          # handles pmset + LaunchAgent + guard automatically

# Check session log
tail -f ~/.claude-session-manager/session.log

# Trigger a session immediately (for testing)
launchctl start com.claude.session.manager

# Show current config and runtime status
bash status.sh

# Pause all sessions without uninstalling
bash pause.sh

# Resume after pause
bash unpause.sh

# Reinstall (keeps state/logs, re-runs wizard with current settings as defaults)
bash reinstall.sh
```

---

## Wake schedule

Managed automatically — `reconfigure.sh` cancels and reschedules everything when you change settings. After each session fires, the window extends by one day on its own.

The only time you'd touch this manually is after a long absence (wake events may have lapsed) or if you skipped the sudo step at install:

```bash
bash src/wake-scheduler.sh            # reschedule (requires sudo)
bash src/wake-scheduler.sh dry-run    # preview without applying
```

**pmset requires sleep, not shutdown** — `pmset schedule wake` only fires from sleep state (S3). If you shut the Mac down completely, the wake event is ignored. Keep the Mac sleeping (lid closed) between sessions, not powered off.

**Passwordless sudo** — lets `session.sh` auto-extend the rolling wake window without prompting for a password each time. Set up during install or anytime:

```bash
bash src/setup-sudo.sh          # configure (prompted during install wizard)
bash src/setup-sudo.sh remove   # remove
```

---

## Pause & Resume

Stop sessions temporarily without uninstalling:

```bash
bash pause.sh    # unloads LaunchAgent; Mac may still wake (harmless)
bash unpause.sh   # reloads LaunchAgent + reschedules today's wake events
```

The paused state is stored in `~/.claude-session-manager/paused`. Even if the Mac wakes during pause, `session.sh` checks for this file and exits immediately.

---

## Running tests

```bash
bash tests/run_tests.sh
```

Tests are split into **common** (cross-platform) and **platform-specific**:

```
tests/
├── common/
│   ├── test_session_guard.sh   — guard logic (all platforms)
│   ├── test_suggest_times.sh   — time algorithm (all platforms)
│   └── test_claude_cli.sh      — CLI auth + headless (all platforms)
└── platforms/
    └── macos/
        ├── test_dependencies.sh
        ├── test_permissions.sh
        ├── test_schedule.sh
        └── test_lid_simulation.sh
```

---

## Project structure

```
claude-session-manager/
├── install.sh              ← entry point (detects platform, 5-step wizard)
├── reinstall.sh            ← keep state/logs, re-run wizard
├── uninstall.sh            ← remove everything
├── pause.sh                ← stop sessions without uninstalling
├── unpause.sh              ← restart after pause
├── status.sh               ← show current config + runtime state
├── reconfigure.sh          ← change schedule/model/holidays after install
├── config.sh               ← user config — generated by install.sh (gitignored)
│
├── holidays/               ← public holiday files by country
│   ├── br.sh               ← Brazil (national holidays only)
│   ├── us.sh               ← United States
│   ├── uk.sh               ← United Kingdom
│   ├── de.sh               ← Germany
│   ├── fr.sh               ← France
│   ├── pt.sh               ← Portugal
│   ├── ar.sh               ← Argentina
│   ├── mx.sh               ← Mexico
│   └── nl.sh               ← Netherlands (Bevrijdingsdag: lustrum years only)
│
├── src/                    ← cross-platform core (no OS-specific APIs)
│   ├── detect_platform.sh  ← OS detection
│   ├── session.sh          ← main session trigger (checks is_workday before firing)
│   ├── utils.sh            ← logging, guard, Claude CLI, holiday loader
│   ├── suggest_times.sh    ← optimal time calculation
│   ├── wake-scheduler.sh   ← macOS pmset wrapper (delegates to platforms/)
│   ├── setup-sudo.sh       ← configure passwordless sudo for pmset
│   ├── defaults.sh         ← canonical default values (single source of truth)
│   ├── ensure-config.sh    ← regenerates config.sh from defaults if missing
│   └── config.example.sh   ← human-readable config reference (uses defaults.sh)
│
├── platforms/
│   ├── macos/
│   │   ├── install.sh      ← LaunchAgent + pmset setup
│   │   ├── uninstall.sh
│   │   ├── scheduler.sh    ← LaunchAgent lifecycle functions
│   │   └── wake.sh         ← pmset scheduling + workday filter
│   ├── linux/              ← planned (see Contributing)
│   └── windows/            ← planned
│
└── tests/
    ├── run_tests.sh         ← platform-aware runner
    ├── common/              ← cross-platform tests
    └── platforms/macos/     ← macOS-specific tests
```

**Files in `src/` and `tests/common/` are cross-platform** — they use only standard `bash`, `date`, and the `claude` CLI. Platform-specific APIs (pmset, launchctl, systemd, rtcwake) live exclusively in `platforms/*/`.

---

## Uninstall

```bash
bash uninstall.sh
```

Removes the LaunchAgent, installed scripts, and optionally the state directory and logs.

---

## Contributing

### Implementing Linux or Windows support

The macOS implementation is the canonical reference. A new platform requires:

| File | What it implements |
|---|---|
| `platforms/<os>/install.sh` | 5-step wizard (same flow as macOS), writes config.sh |
| `platforms/<os>/scheduler.sh` | `generate_service()`, `load_scheduler()`, `unload_scheduler()`, `scheduler_is_loaded()`, `remove_service()` |
| `platforms/<os>/wake.sh` | `is_workday()`, `schedule_upcoming_days()`, `reschedule_wake_events()`, `cancel_our_wake_events()`, `platform_sleep_now()` |
| `platforms/<os>/uninstall.sh` | Cancel events, remove service, optional state cleanup |
| `tests/platforms/<os>/` | Minimum: `test_dependencies.sh`, `test_permissions.sh`, `test_schedule.sh` |

**Rules (enforced — do not break them):**
- `src/` files must remain zero OS-specific code
- `reconfigure.sh` is cross-platform — add a new `case "$PLATFORM"` branch, do not fork it
- Wizard UI must use the same color variables and helper functions as macOS install
- All default values come from `src/defaults.sh` — never hardcode `365`, `18000`, model IDs, etc.
- Every test file sources `src/ensure-config.sh` before `config.sh`
- Run `bash tests/run_tests.sh` on macOS — all 84 tests must still pass

**Platform equivalence table:**

| Concept | macOS | Linux | Windows |
|---|---|---|---|
| Scheduler | LaunchAgent (`launchctl`) | systemd user timer (`systemctl --user`) | Task Scheduler (`schtasks`) |
| Hardware wake | `pmset schedule wake` (SMC) | `rtcwake` (S3 only, not S5) | `powercfg /deviceenablewake` |
| Privilege escalation | `sudo` via sudoers.d | `sudo` via sudoers.d | UAC / Administrator |
| Scripts location | `~/.local/share/claude-session-manager/` | same | `%LOCALAPPDATA%\claude-session-manager\` |

See `CLAUDE.md` — "Implementing a new platform" for the full contract, UI rules, edge cases, and pre-PR checklist.

### Adding a country's holidays

1. Create `holidays/<iso2>.sh` following the format of existing files
2. Include at least the current and next year
3. Cite your sources (official government calendars)
4. Open a PR!

---

## Troubleshooting

**LaunchAgent says "Operation not permitted"**
→ Re-run `bash install.sh` — it copies scripts to `~/.local/share/` (not Documents).

**Session guard blocks triggers**
→ The guard threshold is dynamic: half the smallest gap between configured sessions (e.g. 5h sessions → 2.5h threshold). Sessions intentionally set close together (e.g. 5 min apart) fire normally — the threshold adapts.
→ Manual reset: `rm ~/.claude-session-manager/last_session`
→ `reconfigure.sh` clears it automatically when you change session times.

**Mac doesn't wake at scheduled times**
→ The pmset wake is included in `install.sh` / `reconfigure.sh`. If it was skipped, run: `bash src/wake-scheduler.sh`
→ Check your system sleep timer: `pmset -g | grep "^sleep"`. `WAKE_OFFSET_SECS` must be less than this value. Default `WAKE_OFFSET_SECS=30` requires a sleep timer of at least 1 minute.
→ For auto-reschedule without password prompts: `bash src/setup-sudo.sh`

**`claude: command not found` in LaunchAgent**
→ Set `CLAUDE_BIN="/full/path/to/claude"` in `config.sh`. Find it: `which claude`

**Sessions fire on holidays**
→ Check `HOLIDAY_COUNTRY` is set in `config.sh` and `SCHEDULE_HOLIDAYS=false`.
→ Verify the date is in `holidays/<country>.sh`: `grep "YYYY-MM-DD" holidays/br.sh`

---

## License

MIT
