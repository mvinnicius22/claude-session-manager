# ADR-003 — Rolling window for pmset scheduling

**Date:** 2026-05-01  
**Status:** Accepted

## Context

`pmset schedule wake` only supports one-time events. To keep the Mac waking at the right times every workday, events must be pre-scheduled.

### Rejected: reschedule everything after each session
Rescheduling all 365 × 3 = 1095 events after every session fire is slow (~1–2 min of sequential sudo calls) and creates duplicates for already-scheduled future dates.

### Rejected: schedule only tomorrow
Too short — if sessions stop firing for a few days (user away, Mac off), the window empties.

## Decision

**Two-tier approach:**

1. **At install / reconfigure**: `schedule_upcoming_days(SCHEDULE_DAYS_AHEAD)` schedules the full N-day window upfront. This runs once per config change, so the 1–2 min cost is acceptable.

2. **After each session fires**: `reschedule_wake_events()` adds events only for `today + SCHEDULE_DAYS_AHEAD` — the new far end of the window. This is exactly 3 pmset calls (one per session time), never creates duplicates, and keeps the window perpetually full.

```
Day 0 (install):  schedule days 0..364
Day 1 (session fires):  add day 365
Day 2 (session fires):  add day 366
...
```

## Consequences

- After install, no user action is needed for pmset — ever, unless they change their session times.
- `reschedule_wake_events || true` in `session.sh` — pmset failures are non-fatal and never abort a session.
- If the Mac is off for an extended period (> SCHEDULE_DAYS_AHEAD days), the user must run `bash src/wake-scheduler.sh` once to refill the window. This is documented in the README troubleshooting section.
- Future optimization: batch all pmset commands into a single sudo subprocess call to reduce install time from ~2 min to ~5 s. Tracked in TODO.md.
