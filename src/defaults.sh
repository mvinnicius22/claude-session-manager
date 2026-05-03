#!/usr/bin/env bash
# ============================================================
# src/defaults.sh — Canonical default values.
# Source this before wizards, fallbacks, or config generation.
# Never source AFTER config.sh — user values would be overwritten.
# ============================================================

DEFAULT_WORK_START="09:00"
DEFAULT_WORK_END="17:00"

DEFAULT_SESSION_MIN_GAP=18000
DEFAULT_WAKE_OFFSET_SECS=30
DEFAULT_SLEEP_DELAY=60
DEFAULT_AUTO_SLEEP=false

DEFAULT_SCHEDULE_WEEKENDS=false
DEFAULT_SCHEDULE_HOLIDAYS=false
DEFAULT_SCHEDULE_DAYS_AHEAD=365

DEFAULT_HOLIDAY_COUNTRY="br"
DEFAULT_INITIAL_PROMPT="say: 'ok'"

DEFAULT_CLAUDE_MODEL="claude-haiku-4-5-20251001"
CLAUDE_MODEL_HAIKU="claude-haiku-4-5-20251001"
CLAUDE_MODEL_SONNET="claude-sonnet-4-6"
CLAUDE_MODEL_OPUS="claude-opus-4-7"
