#!/usr/bin/env bash
# ============================================================
# holidays/br.sh — Brazil / Brasil
# Feriados nacionais obrigatórios (Lei nº 662/1949 e alterações).
#
# NOT included (pontos facultativos, not national holidays):
#   - Carnaval (municipal tradition, no federal law mandate)
#   - Corpus Christi (federal discretionary — ponto facultativo)
#   - Municipal/state holidays — add to HOLIDAYS=() in config.sh
#
# Moveable feasts depend on Easter:
#   Easter 2026: April 5   | Easter 2027: March 28
#
# Sources:
#   Lei nº 662/1949, Lei nº 9.093/1995 (Good Friday),
#   Lei nº 12.599/2012, Lei nº 14.759/2023 (Consciência Negra)
# ============================================================

HOLIDAYS=(
    # ── 2026 ─────────────────────────────────────────────────
    "2026-01-01"   # Confraternização Universal (New Year's Day)
    "2026-04-03"   # Sexta-feira Santa (Good Friday) — Lei nº 9.093/1995
    "2026-04-21"   # Tiradentes
    "2026-05-01"   # Dia do Trabalho (Labor Day)
    "2026-09-07"   # Independência do Brasil
    "2026-10-12"   # Nossa Senhora Aparecida
    "2026-11-02"   # Finados (All Souls' Day)
    "2026-11-15"   # Proclamação da República
    "2026-11-20"   # Dia da Consciência Negra — Lei nº 14.759/2023
    "2026-12-25"   # Natal (Christmas)

    # ── 2027 ─────────────────────────────────────────────────
    "2027-01-01"   # Confraternização Universal
    "2027-03-26"   # Sexta-feira Santa
    "2027-04-21"   # Tiradentes
    "2027-05-01"   # Dia do Trabalho
    "2027-09-07"   # Independência do Brasil
    "2027-10-12"   # Nossa Senhora Aparecida
    "2027-11-02"   # Finados
    "2027-11-15"   # Proclamação da República
    "2027-11-20"   # Dia da Consciência Negra
    "2027-12-25"   # Natal
)
