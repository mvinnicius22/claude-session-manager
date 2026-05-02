# ADR-004 — TCC-safe install location for scripts

**Date:** 2026-05-01  
**Status:** Accepted

## Context

macOS TCC (Transparency, Consent, and Control) controls which processes can access protected directories. `~/Documents`, `~/Desktop`, and `~/Downloads` are TCC-protected. A LaunchAgent's `/bin/bash` process running without a user session does not inherit TCC grants from Terminal.app, so it gets `Operation not permitted` when trying to read scripts from `~/Documents`.

Symptom: `launchctl start com.claude.session.manager` succeeds but `launchagent.err` shows `/bin/bash: /Users/x/Documents/.../session.sh: Operation not permitted`.

## Decision

At install time, copy the entire project tree (`src/`, `platforms/`, `holidays/`, `config.sh`) to `~/.local/share/claude-session-manager/`. The LaunchAgent plist points to that location, not to the original project directory.

`~/.local/share/` is not TCC-protected and is the standard XDG base directory for user-specific application data on Unix-like systems.

## Consequences

- Project files can live anywhere (`~/Documents`, iCloud Drive, external disk) without affecting functionality.
- `reconfigure.sh` must `cp config.sh ~/.local/share/claude-session-manager/config.sh` whenever config changes.
- `platforms/macos/install.sh` copies `src/`, `platforms/`, and `holidays/` during install and reinstall.
- No sed-patching of paths needed — `session.sh` uses `BASH_SOURCE[0]` to find its own location and navigates to config/utils from there at runtime.
