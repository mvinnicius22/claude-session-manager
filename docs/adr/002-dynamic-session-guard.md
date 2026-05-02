# ADR-002 — Dynamic session guard threshold

**Date:** 2026-05-01  
**Status:** Accepted

## Context

The session guard prevents a session from firing twice at the same scheduled time (e.g. if launchd glitches and fires twice at 05:30). The original implementation used a hardcoded `SESSION_MIN_GAP=18000` (5 hours).

This caused a UX problem: if a user configured sessions close together for testing (e.g. 16:05 and 16:10), the second session was always blocked because 5 minutes < 5 hours. The user had to manually edit `SESSION_MIN_GAP` — violating the principle that `reconfigure.sh` is the only needed command.

## Decision

`_guard_threshold()` in `src/utils.sh` computes the guard dynamically:

```
threshold = min_gap_between_consecutive_SESSION_TIMES / 2
           floored at 60 s
           fallback to SESSION_MIN_GAP if only one session is configured
```

Examples:
- Sessions 5 h apart → threshold = 2.5 h = 9000 s
- Sessions 5 min apart → threshold = 2.5 min = 150 s
- Single session → threshold = SESSION_MIN_GAP (default 18000 s)

## Consequences

- Sessions configured at any interval fire correctly without manual tuning.
- `SESSION_MIN_GAP` is now only a fallback, not the primary gate.
- `reconfigure.sh` also clears `last_session` after any schedule change, so stale timestamps never block the new schedule.
- Tests in `tests/common/test_session_guard.sh` derive the expected threshold from `_effective_threshold()` (same logic as `_guard_threshold()`), so they remain correct across config changes.
