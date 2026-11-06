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

## D10 – Farbkontraste gemessen (6. Nov. 2026)
WCAG-Kontraste der Rasterfarben berechnet (hell/dunkel): alle Ziffern und Notizen auf jedem Feldhintergrund
(normal, ausgewählt, Zeile/Spalte/Block, gleiche Zahl) mindestens 5,5 : 1; dicke Linien ≥ 9 : 1, dünne Linien
≥ 3 : 1 zum Hintergrund. Das ausgewählte Feld hat zusätzlich einen Rahmen in der Akzentfarbe, damit die Auswahl
nicht nur über einen hellen Farbton erkennbar ist. Falsche Eingaben: Farbe plus Kreuz-Symbol plus Ansage „falsch“.

## D11 – Werbung und „Werbung entfernen“ umgesetzt (6. Nov. 2026)
Nach Master-Prompt 10/11, Bausteine aus der Mandala-App übernommen (Store, Prüfdienst-Anbindung, Consent).
- **Ein Koordinator** (`AdCoordinator`) lädt und zeigt alle Anzeigen; die Regeln stehen als reine, getestete
  Funktion in `ad_policy.dart`. Keine Banner, keine Native-/App-Open-Anzeigen.
- **Interstitial** nur nach Tippen auf „Neues Sudoku“ bzw. „Nächstes Rätsel“ (Tagesrätsel) in der Ergebnisansicht
  einer wirklich beendeten Partie (gewonnen oder nach drei Fehlern beendet). Werbefrei: die erste beendete Partie
  nach Installation und der erste solche Übergang je App-Start. Danach jeder 2. gezählte Übergang, frühestens
  180 s nach der letzten Vollbildanzeige (auch Video), höchstens 3 pro Stunde, nie nach einer Partie mit
  geöffnetem Video, nie bei zurückgestellter Uhr. Zähler und Zeiten überstehen einen Neustart.
- **Zweite Chance per Video** (Rewarded): freigeschaltet nur durch den Belohnungs-Callback des SDK, sofort
  gespeichert (Quelle `rewarded`); doppelte oder verspätete Callbacks schalten nichts zusätzlich frei.
  Laden höchstens 10 s, danach gilt der Versuch als gescheitert und ein später geladenes Video wird verworfen.
  Kein Video: Hinweistext aus 10.3 mit „Erneut versuchen / Später / Spiel beenden“. Video vorzeitig
  geschlossen: Chance bleibt, gesperrtes Spiel mit Knopf „Zweite Chance“. **Grenze (dokumentiert):** stirbt die
  App genau zwischen Belohnung und Speichern, ist die Belohnung verloren, die Chance aber nicht verbraucht.
- **Werbefreie Nutzer** bekommen die zweite Chance ohne Video (Quelle `adFree`), es wird nichts geladen und sie
  sehen kein neues Einwilligungsformular; vorhandene Datenschutzauswahl bleibt erreichbar.
- **Einwilligung (UMP)** bei jedem Start; Anzeigen nur, wenn das SDK es erlaubt. Einstellungen zeigen
  „Datenschutzauswahl für Werbung“, wenn erforderlich.
- **Kauf** `remove_ads_lifetime` (Google: einmalig, nie konsumiert; Apple: Non-Consumable), Preis immer live
  aus dem Store. Zustände unknown/notOwned/pending/verifying/owned/revoked/error. Ausstehende Zahlung schaltet
  nichts frei. Vor dem Kauf wird der Prüfdienst angefragt (`GET /health`); ist er nicht eingerichtet oder nicht
  erreichbar, öffnet sich kein Kaufdialog. Bezahlt, aber Prüfung nicht möglich: „Bezahlt, Prüfung noch
  ausstehend“ (auch nach Neustart), kein zweiter Kauf, Anzeigen vorsorglich aus. Netzfehler nehmen nie einen
  Kauf weg, nur ein bestätigter Widerruf. Werbefreiheit gilt offline ohne Ablauf. „Käufe wiederherstellen“
  in den Einstellungen.
- **Prüfdienst:** der gemeinsame Kaisa-Dienst (D3) braucht zusätzlich `GET /health` und die App-ID
  `at.kaisasolutions.sudoku`. Bis er steht, kann der echte Store nichts freischalten (sichere Voreinstellung).
- **Testbuilds** (CI, Test-APKs): Googles offizielle Test-Anzeigen und der Demo-Store (in der App als
  „Demo-Store … es wird nichts berechnet“ gekennzeichnet). `tool/build_release.sh` baut die Store-Version nur mit
  echten IDs, echtem Store, ohne Debug-Geografie und mit Prüfdienst-URL.

## D12 – App-Symbol: Richtung B „Spielfeld“ (6. Nov. 2026, Auftraggeber)
Heller Hintergrund, Ausschnitt des Spielfelds (3 × 3 Felder) mit hervorgehobenem Mittelfeld „9“ in der
Auswahlfarbe der App, dazu „1“ und „5“. Verworfen: A „Kacheln“, C „Ziffer“ (wirkte wie ein Kalender).
Erzeugt mit `tool/make_icon.py` (alle iOS-Größen, Android klassisch und adaptiv, Store-Symbole 512/1024 px
in `assets/store/`). Schrift: Inter (SIL Open Font License).

## D13 – Datenschutz, Support und Lizenzen in den Einstellungen (6. Nov. 2026)
Abschnitt „Über die App“: Datenschutzerklärung und „Support und Impressum“ öffnen die gemeinsame App-Website im
Browser (vorläufig `kaisa-solutions.at/apps/tidy-sudoku/…`, per Build-Einstellung `PRIVACY_URL`/`SUPPORT_URL`
änderbar; `tool/build_release.sh` verlangt beide), „Lizenzen“ zeigt die Lizenzen aller verwendeten Bausteine.
Die Seiten müssen vor der Veröffentlichung online sein (Texte im Dokument „Store-Texte und Datenschutz“).

## D14 – Kaufprüfdienst geschrieben, Inbetriebnahme nach Freigabe (6. Nov. 2026)
`services/verify`: Cloudflare Worker in TypeScript, gemeinsam für Tidy Sudoku und Orbella, umgesetzt nach
`mandala-studio/VERIFICATION_SERVICE.md` (gleiche Schnittstelle, die Orbella-App braucht nur die erweiterte
Bereitschaftsprüfung `GET /health?store=…&appId=…`). Google: `productsv2.getproductpurchasev2` mit Dienstkonto
(signiertes JWT, nur als Cloudflare-Geheimnis). Apple: StoreKit-2-JWS mit Prüfung der Zertifikatskette bis zur
Apple Root CA G3. Zustandslos (keine Datenbank, keine gespeicherten Tokens), Rate Limit 30/min, Test- und
Produktionsumgebung getrennt. 12 Tests (Workflow „Prüfdienst“). Signierte Berechtigungsnachweise und der
Rückerstattungsabgleich folgen als zweiter Schritt. Online erst nach Freigabe von Cloudflare durch den
Auftraggeber; danach `VERIFIER_URL` im Release-Build setzen. Er liegt vorerst im Sudoku-Repository und kann
in ein eigenes Repository umziehen.
