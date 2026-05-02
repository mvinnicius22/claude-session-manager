# ADR-005 — Centralized default values via src/defaults.sh

**Date:** 2026-05-02  
**Status:** Accepted

---

## Context

Default values for config variables (`365` for `SCHEDULE_DAYS_AHEAD`, `18000` for `SESSION_MIN_GAP`, `claude-haiku-4-5-20251001` for `CLAUDE_MODEL`, etc.) were hardcoded in multiple files:

- Wizard prompts in `platforms/macos/install.sh` and `reconfigure.sh`
- Runtime fallbacks (`${VAR:-value}`) in `src/utils.sh`, `platforms/macos/wake.sh`, `platforms/linux/wake.sh`
- Config generation heredocs in `install.sh`, `reconfigure.sh`, `ensure-config.sh`
- `src/config.example.sh`
- Tests

A search for `365` returned 26 matches across 10 files. Changing a default required a coordinated multi-file edit with high risk of drift.

---

## Decision

Introduce `src/defaults.sh` as the single source of truth for all default values. It defines:

- `DEFAULT_*` variables for each config field (e.g. `DEFAULT_SCHEDULE_DAYS_AHEAD=365`)
- `CLAUDE_MODEL_HAIKU`, `CLAUDE_MODEL_SONNET`, `CLAUDE_MODEL_OPUS` constants

Scripts source it early (before config.sh) so `$DEFAULT_*` is available for:
1. **Wizard prompts** — `${WORK_START:-$DEFAULT_WORK_START}` shows the right hint
2. **Config heredocs** — `SESSION_MIN_GAP=${DEFAULT_SESSION_MIN_GAP}` writes the correct value
3. **Runtime fallbacks** — `${SESSION_MIN_GAP:-$DEFAULT_SESSION_MIN_GAP}` in utils.sh/wake.sh

`ensure-config.sh` sources `defaults.sh` unconditionally, so all scripts that use `ensure-config.sh` inherit `$DEFAULT_*` without an explicit source call.

---

## Consequences

- Changing any default is a one-line edit in `src/defaults.sh`.
- `src/config.example.sh` stays in sync automatically — it sources `defaults.sh` and assigns `$DEFAULT_*`.
- Adding a new config variable requires: (1) add to `defaults.sh`, (2) add to all heredocs, (3) add to `config.example.sh`. See CLAUDE.md "Config template" section.
- `defaults.sh` must be sourced **before** `config.sh` — sourcing after would overwrite user values with defaults.
