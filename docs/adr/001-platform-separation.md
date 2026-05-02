# ADR-001 — Platform separation convention

**Date:** 2026-05-01  
**Status:** Accepted

## Context

The project needs to run on macOS today and Linux/Windows in the future. Early versions mixed platform-specific calls (pmset, launchctl) into shared scripts, making porting difficult and confusing for contributors.

## Decision

Enforce a strict separation:

- `src/` and `tests/common/` — **zero OS-specific APIs**. Only standard POSIX bash, `date`, and the `claude` CLI.
- `platforms/<os>/` — all OS-specific code. Each platform directory is self-contained.
- Root entry points (`install.sh`, `uninstall.sh`, etc.) detect the OS via `src/detect_platform.sh` and delegate to `platforms/<os>/`.

The rule is implicit in the directory name: a file outside `platforms/` is cross-platform by convention.

## Consequences

- Contributors adding Linux/Windows support have a clear boundary — touch only `platforms/<os>/`.
- `src/session.sh` uses `source "$PLATFORM_WAKE"` to load platform hooks at runtime; functions are optional (checked with `declare -f`).
- BSD `date` (macOS) vs GNU `date` (Linux) differences must be handled inside `platforms/*/wake.sh`, not in `src/`.
