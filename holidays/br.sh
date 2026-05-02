#!/usr/bin/env bash
# ============================================================
# holidays/br.sh — Brazil / Brasil
# National public holidays (feriados nacionais).
#
# Moveable feasts depend on Easter:
#   Easter 2026: April 5   | Easter 2027: March 28
#
# Municipal/state holidays are NOT included (too many to list).
# Add your city's holidays to HOLIDAYS=() in config.sh manually.
#
# Sources:
#   Lei nº 662/1949, Lei nº 6.802/1980, Lei nº 12.599/2012
#   Lei nº 14.759/2023 (Consciência Negra — national since 2024)
# ============================================================

HOLIDAYS=(
    # ── 2026 ─────────────────────────────────────────────────
    "2026-01-01"   # Confraternização Universal (New Year's Day)
    "2026-02-16"   # Segunda-feira de Carnaval
    "2026-02-17"   # Terça-feira de Carnaval
    "2026-04-03"   # Sexta-feira Santa (Good Friday)
    "2026-04-21"   # Tiradentes
    "2026-05-01"   # Dia do Trabalho (Labor Day)
    "2026-06-04"   # Corpus Christi
    "2026-09-07"   # Independência do Brasil
    "2026-10-12"   # Nossa Senhora Aparecida
    "2026-11-02"   # Finados (All Souls' Day)
    "2026-11-15"   # Proclamação da República
    "2026-11-20"   # Dia da Consciência Negra
    "2026-12-25"   # Natal (Christmas)

    # ── 2027 ─────────────────────────────────────────────────
    "2027-01-01"   # Confraternização Universal
    "2027-02-08"   # Segunda-feira de Carnaval
    "2027-02-09"   # Terça-feira de Carnaval
    "2027-03-26"   # Sexta-feira Santa
    "2027-04-21"   # Tiradentes
    "2027-05-01"   # Dia do Trabalho
    "2027-05-27"   # Corpus Christi
    "2027-09-07"   # Independência do Brasil
    "2027-10-12"   # Nossa Senhora Aparecida
    "2027-11-02"   # Finados
    "2027-11-15"   # Proclamação da República
    "2027-11-20"   # Dia da Consciência Negra
    "2027-12-25"   # Natal
)
