# Tidy Sudoku

Ruhiges, klassisches 9×9-Sudoku für iOS und Android (Kaisa Games). Arbeitsname „Tidy Sudoku“,
Paket-/Bundle-ID `at.kaisasolutions.sudoku` (bewusst namensneutral, siehe DECISIONS.md D2).

Grundlage ist der Entwicklungsauftrag in `docs/MASTER_PROMPT.md`. Entscheidungen und Abweichungen
stehen in `DECISIONS.md`, der Arbeitsstand in `STATUS.md`.

## Bauen und Testen

Gebaut und getestet wird in GitHub Actions (wie beim Mandala-Projekt):

| Workflow | Auslöser | Ergebnis |
| --- | --- | --- |
| `bootstrap.yml` | Änderung an `.ci/bootstrap` | erzeugt `android/` und `ios/`, löst Paketversionen auf |
| `ci.yml` | Push auf `main` | Analyse, Tests, Android-Test-APK; Bericht auf Branch `ci-status-android`, APK auf `ci-apk` |

Lokal (mit installiertem Flutter): `flutter pub get`, `flutter test`, `flutter run`.

## Aufbau

```
lib/
  domain/sudoku/   Engine ohne UI: Raster, Solver, Generator, Schwierigkeits-Rater
  features/        Bildschirme (Start, Spiel, …)
  app/             App-Rahmen, Thema
test/              Unit- und Widget-Tests
docs/              Master-Prompt
```
