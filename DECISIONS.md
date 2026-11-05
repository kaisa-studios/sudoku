# Entscheidungen

Ergänzt Abschnitt 18 des Master-Prompts (`docs/MASTER_PROMPT.md`). Jüngere Entscheidungen des
Auftraggebers haben Vorrang.

## D1 – Bauweg: GitHub Actions (5. Nov. 2026, Auftraggeber)
Wie beim Mandala-Projekt: Die Claude-Arbeitsumgebung kann Flutter und Pakete nicht herunterladen, der
Rechner des Auftraggebers ist Windows. Kompiliert und getestet wird im privaten Repository
`kaisa-studios/sudoku` mit GitHub Actions (Linux für Analyse, Tests und Android; macOS nur auf Abruf für iOS).
Die nativen Projektordner erzeugt `bootstrap.yml` einmalig per `flutter create`.

## D2 – Name und Paket-ID (5. Nov. 2026, Auftraggeber)
Arbeitsname **„Tidy Sudoku“**. „Pure Sudoku“ ist im App Store mehrfach vergeben (u. a. the binary family GmbH,
seit 2014). Geprüft und verworfen: Novem (EU-Wortmarke NOVEM, Kl. 41 „loisirs“), Clear Sudoku, Sudoku Clarity,
Plain Sudoku, Serene Sudoku, True Sudoku, Cozy Sudoku, Sudoku Fun (jeweils in Stores belegt), Lucid Sudoku
(deutsche Wortmarke „Lucid“ für Software und Videospieldienste). „Tidy Sudoku“: keine Marke in EU/DE/AT
(TMview), keine gleichnamige App in App Store und Google Play (AT, US), Stand 5. Nov. 2026.

Paket-/Bundle-ID bewusst namensneutral **`at.kaisasolutions.sudoku`**: Sie ist nach der Store-Anlage nicht
änderbar, der angezeigte App-Name schon. Der Auftraggeber strebt keine eigene Marke an; Ziel ist eine
regelmäßige Spielerbasis (Werbung + Kauf „Werbung entfernen“), ohne fremde Markenrechte zu verletzen.

## D3 – Gemeinsamer Kaufprüfdienst mit Mandala (5. Nov. 2026, Auftraggeber) – Abweichung von 4.3/10.6
Statt eines eigenen Android-Prüfdienstes (Node, signierte Gerätenachweise, Pub/Sub) nutzt die App denselben
kleinen Prüfdienst wie die Mandala-App (Cloudflare Workers, Google und Apple, App-IDs per Freigabeliste;
siehe Mandala `VERIFICATION_SERVICE.md`). Grundsatz unverändert: keine Freischaltung ohne Prüfung.

## D4 – Gleiche Bausteine wie Mandala (5. Nov. 2026)
Riverpod für Zustand, Drift (SQLite) für Speicherung – laut 4.2 als „gleichwertige SQLite-Anbindung“ zulässig –
damit Kauf-, Werbe- und Datenbankcode beider Apps gleich aufgebaut ist und wiederverwendet werden kann.

## D5 – Engine-Bibliothek ohne Flutter (5. Nov. 2026)
`lib/domain/sudoku` importiert nur `dart:core`/`dart:math`. Damit läuft die Engine in einem Isolate und ist
ohne Oberfläche testbar.

## D6 – Generator kalibriert (5. Nov. 2026)
Messlauf in CI (`test/domain/calibration_test.dart`, je 80–150 Rätsel): Symmetrisches Ausdünnen endet bei
≈ 28 Vorgaben und ergibt fast nur „Leicht“. Ab „Mittel“ wird deshalb einzeln ausgedünnt und bei jedem Schritt
unter 4 zulässigen Zellen die mit dem höchsten Logik-Score entfernt („gezielt“). Trefferquote je Versuch:
Mittel ≈ 43 %, Schwer ≈ 4 %, Experte ≈ 26 %, je ≈ 9–12 ms. „Leicht“ bleibt symmetrisch mit mindestens 36 Vorgaben.
Mindestvorgaben: Leicht 36, Mittel 22, Schwer 20, Experte 17 [A]. „Schwer“ ist selten, weil Dreier-Gruppen und
X-Wing seltener der Engpass sind als XY-Wing (Experte); bleibt bei der Einteilung aus 6.1, abgefangen durch
Vorrat und geprüften Ersatzpool (Phase 2). CI: Schwer bis 1,7 s für ein Rätsel.

## D7 – Tägliches Sudoku mit Serie in V1, Rangliste später (5. Nov. 2026, Auftraggeber)
Ändert Abschnitt 3 und A08 des Master-Prompts (dort ausgeschlossen: tägliche Herausforderungen, Streaks, Ranglisten).

- **Täglich drei Rätsel** (Leicht, Mittel, Schwer), für alle Spieler am selben Kalendertag gleich.
  Damit das auf jedem Gerät exakt gleich und geprüft ist, werden die Tagesrätsel vorab erzeugt und als
  App-Inhalt ausgeliefert (geplant: 2 Jahre = rund 2.200 Rätsel, wenige hundert KB), nicht auf dem Gerät mit
  Zeitbudget erzeugt. Tag = lokales Datum des Geräts. Funktioniert offline.
- **Serie** [A]: Ein Tag zählt, wenn mindestens ein Tagesrätsel fertig gelöst ist (auch nach zweiter Chance).
  Anzeige „Tage in Folge“ und beste Serie. Freundlich gehalten: kein Schuld- oder Verlust-Druck, keine
  Push-Benachrichtigungen in V1; ein verpasster Tag setzt die Serie ohne Hinweisdialog zurück.
- **Werbung** zwischen Tagesrätseln nach derselben zentralen Regel wie zwischen normalen Partien (10.2:
  nur an Übergängen, mindestens 3 Minuten Abstand, höchstens 3 pro Stunde), nie während des Lösens.
- Drei-Fehler-Regel und Statistik gelten wie bei normalen Partien; Tagesrätsel bekommen eine eigene
  Statistikzeile.
- **Rangliste** („wer war heute am schnellsten“): als Update nach dem Start. Offen bis dahin: Server oder
  Game Center/Google Play Games (plattformgetrennt), Spielernamen und Moderation, Schutz gegen gefälschte
  Zeiten, Datenschutz. V1 zeigt nur eigene Bestzeit und eigene Serie.

## D8 – Sprachen: Deutsch und Englisch, sonst Englisch (6. Nov. 2026)
Texte wie bei Mandala zentral in `lib/l10n/strings.dart` (ohne Codegenerator). Abweichend von Mandala fallen
andere Gerätesprachen auf **Englisch** zurück, weil das Sudoku international angeboten wird. In den
Einstellungen wählbar (Wie Gerät / Deutsch / English).

## D9 – Hinweis, große Darstellung, Einstellungen (6. Nov. 2026)
- Hinweis nach 6.2: kostenlos, unbegrenzt; füllt das ausgewählte Feld, wenn es leer oder falsch ist, sonst das
  erste solche Feld; das Feld ist danach geschützt (Glühbirnen-Zeichen), per Rückgängig zurücknehmbar; der
  Zähler bleibt. Spiele mit Hinweis zählen als geschafft, aber nicht für Bestzeit/Durchschnittszeit.
- Große Darstellung nach 8.2: Lupen-Knopf im Spiel (und als Standard einstellbar); Zellen 56 px, Raster scrollt,
  das ausgewählte Feld bleibt sichtbar, Pfeiltasten (je 56 px) und Anzeige „Zeile x, Spalte y“.
  Reicht die Höhe nicht (kleines Handy, große Schrift), scrollt der ganze Spielbildschirm statt abzuschneiden.
- Einstellungen: Darstellung (Wie Gerät/Hell/Dunkel), Sprache, Spielzeit anzeigen (Messung läuft weiter),
  Vibration bei Fehlern (Standard aus), große Darstellung als Standard, lokale Spieldaten löschen
  (mit Bestätigung; Einstellungen bleiben), Version.
