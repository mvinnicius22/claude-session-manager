#!/usr/bin/env bash
# ============================================================
# holidays/nl.sh — Netherlands / Nederland
# Officiële feestdagen (public holidays).
#
# Bevrijdingsdag (May 5 — Liberation Day):
#   Only a universal public holiday in lustrum years (divisible by 5).
#   Lustrum years near 2026: 2025 (past), 2030 (next).
#   NOT included for 2026 or 2027. Add manually to HOLIDAYS=() in
#   config.sh for lustrum years: "2030-05-05".
#
# Goede Vrijdag (Good Friday) is NOT an official Dutch national
#   holiday — companies may observe it voluntarily.
#
# Koningsdag (King's Day) — April 27. If April 27 falls on a Sunday,
#   it is observed on April 26.
#
# Moveable feasts depend on Easter:
#   Easter 2026: April 5   | Easter 2027: March 28
#
# Sources: Algemene termijnenwet, Burgerlijk Wetboek art. 3:83
# ============================================================

HOLIDAYS=(
    # ── 2026 ─────────────────────────────────────────────────
    "2026-01-01"   # Nieuwjaarsdag (New Year's Day)
    "2026-04-05"   # Eerste Paasdag (Easter Sunday)
    "2026-04-06"   # Tweede Paasdag (Easter Monday)
    "2026-04-27"   # Koningsdag (King's Day) — Monday
    # 2026-05-05   # Bevrijdingsdag — NOT 2026 (lustrum: 2025, next: 2030)
    "2026-05-14"   # Hemelvaartsdag (Ascension Thursday)
    "2026-05-24"   # Eerste Pinksterdag (Whit Sunday)
    "2026-05-25"   # Tweede Pinksterdag (Whit Monday)
    "2026-12-25"   # Eerste Kerstdag (Christmas Day)
    "2026-12-26"   # Tweede Kerstdag (Second Christmas Day)

    # ── 2027 ─────────────────────────────────────────────────
    "2027-01-01"   # Nieuwjaarsdag
    "2027-03-28"   # Eerste Paasdag
    "2027-03-29"   # Tweede Paasdag
    "2027-04-27"   # Koningsdag — Tuesday
    # 2027-05-05   # Bevrijdingsdag — NOT 2027 (lustrum: 2025, next: 2030)
    "2027-05-06"   # Hemelvaartsdag
    "2027-05-16"   # Eerste Pinksterdag
    "2027-05-17"   # Tweede Pinksterdag
    "2027-12-25"   # Eerste Kerstdag
    "2027-12-26"   # Tweede Kerstdag
)
