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
