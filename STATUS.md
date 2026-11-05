# Tidy Sudoku – Umsetzungsstand

Stand: 5. November 2026 · Grundlage: `docs/MASTER_PROMPT.md` (Version 1.2)

| Phase | Stand |
| --- | --- |
| 0 – Bestandsaufnahme | erledigt: Repository, Bauweg (D1), Name/ID (D2), Prüfdienst (D3), Bausteine (D4) |
| 1 – Spielbarer Zwischenstand | **erledigt** (Commit 4aa9441): Startseite, 4 Stufen, Raster, Zahlenfeld, Notizen, Löschen, Rückgängig, Fehler, Drei-Fehler-Dialog |
| 2 – Vollständige Engine | in Arbeit: Solver, Generator, Rater fertig und getestet; offen: Ersatzpool (100), Vorrat, Isolate-Puffer |
| 3–8 | offen |

## CI (5. Nov. 2026, Commit 4aa9441)
Analyse fehlerfrei, **20 Tests bestanden** (Engine: Eindeutigkeit, Seed-Reproduzierbarkeit, Einstufung exakt je Stufe,
Orakel-Prüfung aller Strategien an 60 Rätseln; Spielregeln; App-Ablauf), Test-APK arm64 18,1 MB auf Branch `ci-apk`.

## Bekannte Grenzen des Zwischenstands
- Zweite Chance ist noch ohne Werbung (Platzhalter bis Phase 5); keine Speicherung, kein Timer, keine Statistik.
- Nur Deutsch; Hinweis-Funktion, große Darstellung, Einstellungen folgen.
- „Schwer“ dauert in CI bis 1,7 s (Vorrat/Ersatzpool folgen).

## Offene Eingaben (siehe Master-Prompt 18.3)
- O01 Name endgültig (Arbeitsname Tidy Sudoku), O02–O09 wie Mandala (gemeinsame Konten)
- Neu: Entscheidung „Tägliches Sudoku mit Serie und Rangliste“ (Vorschlag Auftraggeber, 5. Nov. 2026)
