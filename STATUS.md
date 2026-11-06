# Tidy Sudoku – Umsetzungsstand

Stand: 6. November 2026 (Test-APK 5 = Commit f9619bd) · Grundlage: `docs/MASTER_PROMPT.md` (Version 1.2), Entscheidungen in `DECISIONS.md`

| Phase | Stand |
| --- | --- |
| 0 – Bestandsaufnahme | erledigt: Repository, Bauweg (D1), Name/ID (D2), Prüfdienst (D3), Bausteine (D4) |
| 1 – Spielbarer Zwischenstand | erledigt (Test-APK 1) |
| 2 – Vollständige Engine | erledigt: Solver, Generator (kalibriert, D6), Rater mit 10 Strategien; Ersatzpool 4 × 25; Erzeugung im Hintergrund-Isolate mit 2 s Budget, sonst Pool |
| 3 – Spielkern | erledigt: Speichern nach jeder Aktion (SQLite/Drift), Fortsetzen, Verwerfen-Rückfrage, Drei-Fehler-Sperre auch nach Neustart, aktive Spielzeit, Statistik (6.5), Tägliches Sudoku mit Serie (D7), Hinweis (D9) |
| 4 – Bedienung/Assets | weitgehend erledigt: Deutsch/Englisch (D8), Einstellungen (Hell/Dunkel, Sprache, Zeit, Vibration, große Darstellung, Daten löschen), große Darstellung mit Pfeiltasten (D9), 200 % Schrift auf 320 × 568 ohne Abschneiden (Tests DE/EN + Emulator). Kontraste gemessen und nachgeschärft (D10). Offen: App-Symbol, Prüfung mit echtem TalkBack/VoiceOver auf einem Gerät |
| 5 – Monetarisierung | weitgehend erledigt (D11): Einwilligung (UMP), Interstitial nur an Übergängen nach zentraler Regel, zweite Chance per Video (Googles Testvideo auf dem Emulator erfolgreich), werbefreie zweite Chance, Kauf „Werbung entfernen“ mit Demo-Store, Wiederherstellen, Release-Prüfskript. Offen: gemeinsamer Prüfdienst (D3, inkl. `GET /health`), echte AdMob-/Store-Konten, Preis, iOS-StoreKit-2-Prüfung |
| 6–8 | offen |

## Inhalte (Commit e9a75d7)
2.470 Rätsel: Ersatzpool 100 (25 je Stufe) und Tagesrätsel 1. Nov. 2026 – 29. Dez. 2028 (3 pro Tag).
Doppelt geprüft: Dart-Engine (Eindeutigkeit, Einstufung mit Orakel) und unabhängiger Python-Prüfer
(`tool/verify_puzzles.py`): jede Lösung eindeutig, keine Dopplung. 0,5 MB.

## CI und Gerätetest
- CI: Analyse fehlerfrei, **86 Tests bestanden** (neu: Werbe-Regeln, Koordinator inkl. Callback-Reihenfolgen und 10-s-Grenze, Kaufzustände, Werbe-/Kaufabläufe in der App) (zusätzlich: Hinweis, Englisch, Einstellungen, große Darstellung, 200 % Schrift) (Engine, Spielregeln, Statistik-Referenzfall, Serie, Datenbank inkl.
  Neustart-Sperre und veralteter Schreibvorgänge, ausgelieferte Inhalte, App-Abläufe).
- Emulator (Android 13, Release-App, Commit f14f8fe): startet in ≈ 1 s; Tagesrätsel, Spiel, Hinweis, große Darstellung,
  Einstellungen, Dunkelmodus, nach erzwungenem Neustart „Spiel fortsetzen“ mit Eingaben, 200 % Systemschrift
  (`ci-status-emulator`, Auslöser `[emu]`). Test-APK 3 = Commit f14f8fe.

## Bekannte Grenzen
- Werbung und Kauf nur mit Test-Anzeigen und Demo-Store; der echte Store schaltet erst frei, wenn der Prüfdienst steht.
- Android-Rechte durch das Werbe-SDK: Internet, Netzwerkstatus, Werbe-ID (AD_ID, AdServices), Billing, WorkManager (Wake-Lock/Foreground-Service). Für das Datenschutzformular im Play Store relevant.
- Gerätetest auf echtem Android-Handy und iPhone ausstehend.

## Offene Eingaben (siehe Master-Prompt 18.3)
- O01 Name endgültig (Arbeitsname Tidy Sudoku), O02–O09 wie Mandala (gemeinsame Konten)
- Rangliste für das tägliche Sudoku: Update nach dem Start (D7)
