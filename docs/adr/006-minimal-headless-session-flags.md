# ADR-006 — Minimal headless session flags

**Date:** 2026-05-06  
**Status:** Accepted

---

## Context

`claude -p` (non-interactive / print mode) initializes a full Claude Code session on every call. This includes:

- Claude Code's built-in system prompt with all tool definitions (~10–15K tokens of input)
- All MCP servers configured in `~/.claude/settings.json` (Notion, Gmail, Google Calendar, etc.) — each server adds its own tool definitions
- Session history writes to `~/.claude/sessions/`

For the primary use case of this project — a short trigger prompt like `"say: 'ok'"` to keep the Claude Pro session active — none of this overhead is needed. In testing, even a trivial Haiku prompt consumed ~2% of a Pro plan per session due to this context cost.

`claude --help` reveals flags that reduce this overhead without breaking OAuth authentication:

| Flag | Effect |
|---|---|
| `--no-session-persistence` | Skips writing session history to disk |
| `--strict-mcp-config` | Ignores all user-configured MCP servers (uses only servers from `--mcp-config`, which we don't provide) |
| `--tools ""` | Removes all built-in tool definitions from the system prompt |

Note: `--bare` would be ideal but disables keychain reads, breaking OAuth authentication for users who log in via `claude auth login`. It is not safe as a default.

---

## Decision

Introduce two new config variables with economy-focused defaults:

```bash
CLAUDE_EXTRA_FLAGS="--no-session-persistence --strict-mcp-config"
CLAUDE_DISABLE_TOOLS=true
```

`trigger_claude_session()` in `src/utils.sh` builds a bash **array** (not a string) for the claude arguments. This is required because `--tools ""` must be passed as two separate array elements — string expansion loses the empty string argument:

```bash
# Wrong — "" becomes nothing after word split:
"$bin" -p "$prompt" --tools "" ...

# Correct — array preserves the empty element:
local -a args=(-p "$prompt" --model "$model" ...)
[[ "$disable_tools" == "true" ]] && args+=(--tools "")
"$bin" "${args[@]}"
```

`CLAUDE_EXTRA_FLAGS` is word-split into the array for freeform flags that have no empty-string arguments (`--no-session-persistence`, `--strict-mcp-config`, etc.). `CLAUDE_DISABLE_TOOLS` is a separate boolean to handle the `--tools ""` case safely.

---

## Consequences

- Default sessions use significantly fewer tokens — no tool definitions, no MCP server manifests.
- Users whose `INITIAL_PROMPT` needs tools (file reads, bash, etc.) or MCP (Notion, Gmail) set `CLAUDE_DISABLE_TOOLS=false` and/or `CLAUDE_EXTRA_FLAGS=""` in `config.sh`.
- `--bare` remains documented as an option for users who authenticate via `ANTHROPIC_API_KEY` (API key users only), but is not the default.
- Both vars follow the 7-step config variable process: `src/defaults.sh`, all heredocs, `src/config.example.sh`, `README.md`.
