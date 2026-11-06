import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/sudoku/difficulty.dart';

/// All user-visible texts in German and English (same approach as the Mandala
/// app: hand-written, no code generation; the compiler finds missing texts).
/// Access via `context.s`. Device language German → German, anything else → English.
abstract class S {
  const S();

  /// English first: unsupported device languages fall back to it (DECISIONS D8).
  static const supportedLocales = [Locale('en'), Locale('de')];

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? const StringsEn();

  static S forLanguage(String code) => code == 'de' ? const StringsDe() : const StringsEn();

  String get languageCode;

  // ---- common
  String get appTitle;
  String get tagline;
  String get cancel;
  String get ok;
  String difficulty(Difficulty d);
  String days(int n);
  String decimal(double v) => v.toStringAsFixed(1);
  String monthName(int month);
  String longDate(DateTime d);

  // ---- home
  String get dailyTitle;
  String dailyToday(int done);
  String streakLine(int days);
  String dailyCardLabel(int done, int days);
  String continueGame(String level);
  String get newGame;
  String get startGame;
  String get statistics;
  String get settings;
  String get createFailed;
  String get discardTitle;
  String get discardBody;
  String get discardConfirm;

  // ---- daily
  String get dailyIntro;
  String get streak;
  String get bestStreak;
  String get slotStart;
  String get slotResume;
  String get slotSolved;
  String get slotEnded;
  String get dailyUnavailable;
  String get dailyStreakNote;

  // ---- game
  String dailyGameTitle(String level);
  String mistakes(int n, int limit);
  String mistakesLabel(int n, int limit);
  String timeLabel(String time);
  String get notes;
  String get notesOn;
  String get erase;
  String get undo;
  String get hint;
  String get hintDone;
  String digit(int d);
  String digitDone(int d);
  String get threeMistakesTitle;
  String get threeMistakesBody;
  String get endGame;
  String get later;
  String get keepPlaying;
  String get solvedTitle;
  String get finishedTitle;
  String get failedNote;
  String timeLine(String time);
  String mistakesLine(int n);
  String get done;
  String get toHome;
  String get newSudoku;
  String get largeView;
  String get normalView;
  String position(int row, int col);
  String get moveUp;
  String get moveDown;
  String get moveLeft;
  String get moveRight;

  // ---- cell semantics
  String cellEmpty(int row, int col, List<int> notes);
  String cellGiven(int row, int col, int v);
  String cellHinted(int row, int col, int v);
  String cellEntry(int row, int col, int v, bool wrong);

  // ---- statistics
  String get statsEmpty;
  String get statsOverall;
  String get statsStarted;
  String get statsWon;
  String get statsFailed;
  String get statsBestTime;
  String get statsAverageTime;
  String get statsAverageMistakes;
  String get statsSecondChance;
  String get statsFinishedAfterChance;
  String get statsExplanation;

  // ---- settings
  String get gameHeading;
  String get appearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get language;
  String get languageDevice;
  String get showTimer;
  String get haptics;
  String get hapticsHint;
  String get largeViewDefault;
  String get largeViewHint;
  String get dataHeading;
  String get deleteData;
  String get deleteDataHint;
  String get deleteConfirmTitle;
  String get deleteConfirmBody;
  String get deleteConfirm;
  String get deleteDone;
  String get localStorageNote;
  String version(String v);

  // ---- ads and purchases
  String get threeMistakesBodyVideo;
  String get threeMistakesBodyAdFree;
  String get watchVideo;
  String get videoLoading;
  String get noVideoTitle;
  String get noVideoBody;
  String get tryAgain;
  String get videoClosedEarly;
  String get secondChance;
  String get lockedNote;
  String get endedNote;
  String get nextDaily;
  String get removeAdsHeading;
  String get removeAdsOffer;
  String get removeAdsOwned;
  String get purchasePending;
  String get purchaseVerifying;
  String get paidUnverifiedNote;
  String get checkAgain;
  String get storeUnavailable;
  String get restorePurchases;
  String get revokedNote;
  String get demoStoreNote;
  String get privacyOptions;
  String get msgUnlocked;
  String get msgCanceled;
  String get msgFailed;
  String get msgVerificationFailed;
  String get msgPaidUnverified;
  String get msgCheckUnavailable;
  String get msgRestoredOwned;
  String get msgRestoredNothing;
  String buyFor(String price);
  String get aboutHeading;
  String get privacyPolicy;
  String get supportAndImprint;
  String get licenses;
  String get linkFailed;
}

class StringsDe extends S {
  const StringsDe();

  @override
  String get languageCode => 'de';

  @override
  String get appTitle => 'Tidy Sudoku';
  @override
  String get tagline => 'Große Zahlen. Klare Felder.';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get ok => 'OK';
  @override
  String difficulty(Difficulty d) => switch (d) {
        Difficulty.easy => 'Leicht',
        Difficulty.medium => 'Mittel',
        Difficulty.hard => 'Schwer',
        Difficulty.expert => 'Experte',
      };
  @override
  String days(int n) => n == 1 ? '1 Tag' : '$n Tage';
  @override
  String decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  @override
  String monthName(int month) => const [
        'Jänner', 'Februar', 'März', 'April', 'Mai', 'Juni',
        'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
      ][month - 1];
  @override
  String longDate(DateTime d) => '${d.day}. ${monthName(d.month)} ${d.year}';

  @override
  String get dailyTitle => 'Tägliches Sudoku';
  @override
  String dailyToday(int done) => 'Heute $done von 3 gelöst';
  @override
  String streakLine(int n) => 'Serie: ${days(n)}';
  @override
  String dailyCardLabel(int done, int n) => 'Tägliches Sudoku, heute $done von 3 gelöst, Serie ${days(n)}';
  @override
  String continueGame(String level) => 'Spiel fortsetzen · $level';
  @override
  String get newGame => 'Neues Spiel';
  @override
  String get startGame => 'Spiel starten';
  @override
  String get statistics => 'Statistik';
  @override
  String get settings => 'Einstellungen';
  @override
  String get createFailed => 'Das Sudoku konnte nicht erstellt werden. Bitte versuche es erneut.';
  @override
  String get discardTitle => 'Neues Sudoku starten?';
  @override
  String get discardBody => 'Das angefangene Sudoku wird verworfen.';
  @override
  String get discardConfirm => 'Verwerfen und starten';

  @override
  String get dailyIntro => 'Drei Rätsel pro Tag – für alle gleich.';
  @override
  String get streak => 'Serie';
  @override
  String get bestStreak => 'Beste Serie';
  @override
  String get slotStart => 'Starten';
  @override
  String get slotResume => 'Weiterspielen';
  @override
  String get slotSolved => 'Gelöst';
  @override
  String get slotEnded => 'Beendet';
  @override
  String get dailyUnavailable => 'Für heute sind keine Tagesrätsel verfügbar. Bitte aktualisiere die App.';
  @override
  String get dailyStreakNote => 'Ein Tag zählt für die Serie, sobald du mindestens ein Tagesrätsel gelöst hast.';

  @override
  String dailyGameTitle(String level) => 'Tagesrätsel · $level';
  @override
  String mistakes(int n, int limit) => 'Fehler $n/$limit';
  @override
  String mistakesLabel(int n, int limit) => 'Fehler $n von $limit';
  @override
  String timeLabel(String time) => 'Spielzeit $time';
  @override
  String get notes => 'Notizen';
  @override
  String get notesOn => 'Notizen an';
  @override
  String get erase => 'Löschen';
  @override
  String get undo => 'Rückgängig';
  @override
  String get hint => 'Hinweis';
  @override
  String get hintDone => 'Hinweis: Ein Feld wurde richtig eingetragen.';
  @override
  String digit(int d) => 'Zahl $d';
  @override
  String digitDone(int d) => 'Zahl $d, vollständig gesetzt';
  @override
  String get threeMistakesTitle => 'Drei Fehler';
  @override
  String get threeMistakesBody =>
      'Dieses Sudoku zählt jetzt als nicht geschafft. Du kannst es trotzdem zu Ende spielen.';
  @override
  String get endGame => 'Spiel beenden';
  @override
  String get later => 'Später';
  @override
  String get keepPlaying => 'Weiterspielen';
  @override
  String get solvedTitle => 'Geschafft!';
  @override
  String get finishedTitle => 'Sudoku beendet';
  @override
  String get failedNote => 'Zählt als nicht geschafft, weil die zweite Chance genutzt wurde.';
  @override
  String timeLine(String time) => 'Zeit: $time';
  @override
  String mistakesLine(int n) => 'Fehler: $n';
  @override
  String get done => 'Fertig';
  @override
  String get toHome => 'Zur Startseite';
  @override
  String get newSudoku => 'Neues Sudoku';
  @override
  String get largeView => 'Große Darstellung';
  @override
  String get normalView => 'Ganzes Raster';
  @override
  String position(int row, int col) => 'Zeile $row, Spalte $col';
  @override
  String get moveUp => 'Feld darüber';
  @override
  String get moveDown => 'Feld darunter';
  @override
  String get moveLeft => 'Feld links';
  @override
  String get moveRight => 'Feld rechts';

  @override
  String cellEmpty(int row, int col, List<int> notes) =>
      '${position(row, col)}, leer${notes.isEmpty ? '' : ', Notizen ${notes.join(' und ')}'}';
  @override
  String cellGiven(int row, int col, int v) => '${position(row, col)}, vorgegebene $v, nicht bearbeitbar';
  @override
  String cellHinted(int row, int col, int v) => '${position(row, col)}, Hinweis $v, nicht bearbeitbar';
  @override
  String cellEntry(int row, int col, int v, bool wrong) =>
      '${position(row, col)}, Eingabe $v${wrong ? ', falsch' : ''}';

  @override
  String get statsEmpty => 'Noch keine Spiele – starte dein erstes Sudoku.';
  @override
  String get statsOverall => 'Gesamt';
  @override
  String get statsStarted => 'Gestartet';
  @override
  String get statsWon => 'Geschafft';
  @override
  String get statsFailed => 'Nicht geschafft';
  @override
  String get statsBestTime => 'Beste Zeit';
  @override
  String get statsAverageTime => 'Durchschnittszeit';
  @override
  String get statsAverageMistakes => 'Durchschnittliche Fehler';
  @override
  String get statsSecondChance => 'Mit zweiter Chance';
  @override
  String get statsFinishedAfterChance => 'Nach zweiter Chance fertig';
  @override
  String get statsExplanation =>
      'Ab drei Fehlern zählt ein Sudoku als nicht geschafft – auch wenn du es mit der zweiten Chance zu Ende '
      'spielst. Freiwillig verworfene Spiele sind keine Niederlagen. Bestzeit und Durchschnittszeit zählen nur '
      'geschaffte Spiele ohne Hinweise. Durchschnittliche Fehler: über alle beendeten Spiele.';

  @override
  String get gameHeading => 'Spiel';
  @override
  String get appearance => 'Darstellung';
  @override
  String get themeSystem => 'Wie Gerät';
  @override
  String get themeLight => 'Hell';
  @override
  String get themeDark => 'Dunkel';
  @override
  String get language => 'Sprache';
  @override
  String get languageDevice => 'Wie Gerät';
  @override
  String get showTimer => 'Spielzeit anzeigen';
  @override
  String get haptics => 'Vibration bei Fehlern';
  @override
  String get hapticsHint => 'Kurzes Vibrieren, wenn eine Zahl falsch ist.';
  @override
  String get largeViewDefault => 'Große Darstellung als Standard';
  @override
  String get largeViewHint => 'Größere Felder mit Pfeiltasten – praktisch auf kleinen Handys.';
  @override
  String get dataHeading => 'Daten';
  @override
  String get deleteData => 'Lokale Spieldaten löschen';
  @override
  String get deleteDataHint => 'Löscht Spielstände, Tagesrätsel-Serie und Statistik auf diesem Gerät.';
  @override
  String get deleteConfirmTitle => 'Alle Spieldaten löschen?';
  @override
  String get deleteConfirmBody =>
      'Spielstände, Serie und Statistik werden endgültig gelöscht. Einstellungen und Käufe bleiben erhalten.';
  @override
  String get deleteConfirm => 'Endgültig löschen';
  @override
  String get deleteDone => 'Spieldaten gelöscht.';
  @override
  String get localStorageNote =>
      'Deine Spiele werden nur auf diesem Gerät gespeichert. Es gibt kein Konto und keine Cloud.';
  @override
  String version(String v) => 'Version $v';
  @override
  String get threeMistakesBodyVideo =>
      'Dieses Sudoku zählt jetzt als nicht geschafft. Mit einem kurzen Video bekommst du eine zweite Chance und kannst es zu Ende spielen.';
  @override
  String get threeMistakesBodyAdFree =>
      'Dieses Sudoku zählt jetzt als nicht geschafft. Du hast eine zweite Chance und kannst es zu Ende spielen.';
  @override
  String get watchVideo =>
      'Video ansehen';
  @override
  String get videoLoading =>
      'Video wird geladen …';
  @override
  String get noVideoTitle =>
      'Kein Video verfügbar';
  @override
  String get noVideoBody =>
      'Zurzeit ist kein Video verfügbar. Du kannst es später erneut versuchen oder das Spiel beenden.';
  @override
  String get tryAgain =>
      'Erneut versuchen';
  @override
  String get videoClosedEarly =>
      'Video vorzeitig beendet – deine zweite Chance bleibt erhalten.';
  @override
  String get secondChance =>
      'Zweite Chance';
  @override
  String get lockedNote =>
      'Drei Fehler – das Spiel ist gesperrt.';
  @override
  String get endedNote =>
      'Zählt als nicht geschafft.';
  @override
  String get nextDaily =>
      'Nächstes Rätsel';
  @override
  String get removeAdsHeading =>
      'Werbung entfernen';
  @override
  String get removeAdsOffer =>
      'Einmal kaufen: alle Werbung entfernen. Die einmalige zweite Chance erhältst du ohne Video.';
  @override
  String get removeAdsOwned =>
      'Werbefrei – danke für deinen Kauf!';
  @override
  String get purchasePending =>
      'Zahlung ausstehend. Die Werbefreiheit gilt, sobald der Store die Zahlung bestätigt.';
  @override
  String get purchaseVerifying =>
      'Kauf wird geprüft …';
  @override
  String get paidUnverifiedNote =>
      'Bezahlt, Prüfung noch ausstehend. Du musst nicht erneut kaufen – die Prüfung folgt, sobald eine Verbindung besteht.';
  @override
  String get checkAgain =>
      'Erneut prüfen';
  @override
  String get storeUnavailable =>
      'Der Store ist gerade nicht erreichbar.';
  @override
  String get restorePurchases =>
      'Käufe wiederherstellen';
  @override
  String get revokedNote =>
      'Dein Kauf wurde erstattet oder widerrufen.';
  @override
  String get demoStoreNote =>
      'Demo-Store: Testversion, es wird nichts berechnet.';
  @override
  String get privacyOptions =>
      'Datenschutzauswahl für Werbung';
  @override
  String get msgUnlocked =>
      'Danke! Die Werbung ist entfernt.';
  @override
  String get msgCanceled =>
      'Kauf abgebrochen.';
  @override
  String get msgFailed =>
      'Das hat nicht geklappt. Bitte versuche es später erneut.';
  @override
  String get msgVerificationFailed =>
      'Der Kauf konnte nicht bestätigt werden. Es wurde nichts freigeschaltet.';
  @override
  String get msgPaidUnverified =>
      'Bezahlt – die Prüfung folgt, sobald eine Verbindung besteht.';
  @override
  String get msgCheckUnavailable =>
      'Kaufen ist gerade nicht möglich, weil die Kaufprüfung nicht erreichbar ist. Bitte versuche es später erneut. Spielen kannst du weiterhin kostenlos.';
  @override
  String get msgRestoredOwned =>
      'Kauf wiederhergestellt – werbefrei.';
  @override
  String get msgRestoredNothing =>
      'Für dieses Store-Konto wurde kein Kauf gefunden. Ohne Internetverbindung kann nichts wiederhergestellt werden.';
  @override
  String buyFor(String price) => 'Für $price kaufen';
  @override
  String get aboutHeading => 'Über die App';
  @override
  String get privacyPolicy => 'Datenschutzerklärung';
  @override
  String get supportAndImprint => 'Support und Impressum';
  @override
  String get licenses => 'Lizenzen';
  @override
  String get linkFailed => 'Der Link konnte nicht geöffnet werden.';
}

class StringsEn extends S {
  const StringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get appTitle => 'Tidy Sudoku';
  @override
  String get tagline => 'Big numbers. Clear grid.';
  @override
  String get cancel => 'Cancel';
  @override
  String get ok => 'OK';
  @override
  String difficulty(Difficulty d) => switch (d) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
        Difficulty.expert => 'Expert',
      };
  @override
  String days(int n) => n == 1 ? '1 day' : '$n days';
  @override
  String monthName(int month) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][month - 1];
  @override
  String longDate(DateTime d) => '${monthName(d.month)} ${d.day}, ${d.year}';

  @override
  String get dailyTitle => 'Daily Sudoku';
  @override
  String dailyToday(int done) => 'Today: $done of 3 solved';
  @override
  String streakLine(int n) => 'Streak: ${days(n)}';
  @override
  String dailyCardLabel(int done, int n) => 'Daily Sudoku, today $done of 3 solved, streak ${days(n)}';
  @override
  String continueGame(String level) => 'Continue game · $level';
  @override
  String get newGame => 'New game';
  @override
  String get startGame => 'Start game';
  @override
  String get statistics => 'Statistics';
  @override
  String get settings => 'Settings';
  @override
  String get createFailed => 'The puzzle could not be created. Please try again.';
  @override
  String get discardTitle => 'Start a new Sudoku?';
  @override
  String get discardBody => 'The unfinished Sudoku will be discarded.';
  @override
  String get discardConfirm => 'Discard and start';

  @override
  String get dailyIntro => 'Three puzzles a day – the same for everyone.';
  @override
  String get streak => 'Streak';
  @override
  String get bestStreak => 'Best streak';
  @override
  String get slotStart => 'Start';
  @override
  String get slotResume => 'Continue';
  @override
  String get slotSolved => 'Solved';
  @override
  String get slotEnded => 'Ended';
  @override
  String get dailyUnavailable => 'No daily puzzles are available for today. Please update the app.';
  @override
  String get dailyStreakNote => 'A day counts towards your streak once you have solved at least one daily puzzle.';

  @override
  String dailyGameTitle(String level) => 'Daily · $level';
  @override
  String mistakes(int n, int limit) => 'Mistakes $n/$limit';
  @override
  String mistakesLabel(int n, int limit) => 'Mistakes $n of $limit';
  @override
  String timeLabel(String time) => 'Playing time $time';
  @override
  String get notes => 'Notes';
  @override
  String get notesOn => 'Notes on';
  @override
  String get erase => 'Erase';
  @override
  String get undo => 'Undo';
  @override
  String get hint => 'Hint';
  @override
  String get hintDone => 'Hint: one cell was filled in correctly.';
  @override
  String digit(int d) => 'Number $d';
  @override
  String digitDone(int d) => 'Number $d, all placed';
  @override
  String get threeMistakesTitle => 'Three mistakes';
  @override
  String get threeMistakesBody => 'This Sudoku now counts as not solved. You can still finish it.';
  @override
  String get endGame => 'End game';
  @override
  String get later => 'Later';
  @override
  String get keepPlaying => 'Keep playing';
  @override
  String get solvedTitle => 'Solved!';
  @override
  String get finishedTitle => 'Sudoku finished';
  @override
  String get failedNote => 'Counts as not solved because the second chance was used.';
  @override
  String timeLine(String time) => 'Time: $time';
  @override
  String mistakesLine(int n) => 'Mistakes: $n';
  @override
  String get done => 'Done';
  @override
  String get toHome => 'Home';
  @override
  String get newSudoku => 'New Sudoku';
  @override
  String get largeView => 'Large view';
  @override
  String get normalView => 'Whole grid';
  @override
  String position(int row, int col) => 'Row $row, column $col';
  @override
  String get moveUp => 'Cell above';
  @override
  String get moveDown => 'Cell below';
  @override
  String get moveLeft => 'Cell to the left';
  @override
  String get moveRight => 'Cell to the right';

  @override
  String cellEmpty(int row, int col, List<int> notes) =>
      '${position(row, col)}, empty${notes.isEmpty ? '' : ', notes ${notes.join(' and ')}'}';
  @override
  String cellGiven(int row, int col, int v) => '${position(row, col)}, given $v, not editable';
  @override
  String cellHinted(int row, int col, int v) => '${position(row, col)}, hint $v, not editable';
  @override
  String cellEntry(int row, int col, int v, bool wrong) =>
      '${position(row, col)}, entry $v${wrong ? ', wrong' : ''}';

  @override
  String get statsEmpty => 'No games yet – start your first Sudoku.';
  @override
  String get statsOverall => 'Overall';
  @override
  String get statsStarted => 'Started';
  @override
  String get statsWon => 'Solved';
  @override
  String get statsFailed => 'Not solved';
  @override
  String get statsBestTime => 'Best time';
  @override
  String get statsAverageTime => 'Average time';
  @override
  String get statsAverageMistakes => 'Average mistakes';
  @override
  String get statsSecondChance => 'With second chance';
  @override
  String get statsFinishedAfterChance => 'Finished after second chance';
  @override
  String get statsExplanation =>
      'From three mistakes on, a Sudoku counts as not solved – even if you finish it with the second chance. '
      'Games you discard yourself are not losses. Best and average time only count solved games without hints. '
      'Average mistakes: across all finished games.';

  @override
  String get gameHeading => 'Game';
  @override
  String get appearance => 'Appearance';
  @override
  String get themeSystem => 'Like device';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get language => 'Language';
  @override
  String get languageDevice => 'Like device';
  @override
  String get showTimer => 'Show playing time';
  @override
  String get haptics => 'Vibrate on mistakes';
  @override
  String get hapticsHint => 'A short vibration when a number is wrong.';
  @override
  String get largeViewDefault => 'Large view by default';
  @override
  String get largeViewHint => 'Bigger cells with arrow buttons – handy on small phones.';
  @override
  String get dataHeading => 'Data';
  @override
  String get deleteData => 'Delete local game data';
  @override
  String get deleteDataHint => 'Deletes games, daily streak and statistics on this device.';
  @override
  String get deleteConfirmTitle => 'Delete all game data?';
  @override
  String get deleteConfirmBody =>
      'Games, streak and statistics will be deleted for good. Settings and purchases are kept.';
  @override
  String get deleteConfirm => 'Delete for good';
  @override
  String get deleteDone => 'Game data deleted.';
  @override
  String get localStorageNote => 'Your games are stored only on this device. There is no account and no cloud.';
  @override
  String version(String v) => 'Version $v';
  @override
  String get threeMistakesBodyVideo =>
      'This Sudoku now counts as not solved. Watch a short video for a second chance and finish it.';
  @override
  String get threeMistakesBodyAdFree =>
      'This Sudoku now counts as not solved. You have a second chance and can finish it.';
  @override
  String get watchVideo =>
      'Watch video';
  @override
  String get videoLoading =>
      'Loading video …';
  @override
  String get noVideoTitle =>
      'No video available';
  @override
  String get noVideoBody =>
      'No video is available right now. You can try again later or end the game.';
  @override
  String get tryAgain =>
      'Try again';
  @override
  String get videoClosedEarly =>
      'Video closed early – your second chance is kept.';
  @override
  String get secondChance =>
      'Second chance';
  @override
  String get lockedNote =>
      'Three mistakes – the game is locked.';
  @override
  String get endedNote =>
      'Counts as not solved.';
  @override
  String get nextDaily =>
      'Next puzzle';
  @override
  String get removeAdsHeading =>
      'Remove ads';
  @override
  String get removeAdsOffer =>
      'Buy once: remove all ads. You get the one-time second chance without a video.';
  @override
  String get removeAdsOwned =>
      'Ad-free – thank you for your purchase!';
  @override
  String get purchasePending =>
      'Payment pending. Ads are removed as soon as the store confirms the payment.';
  @override
  String get purchaseVerifying =>
      'Checking the purchase …';
  @override
  String get paidUnverifiedNote =>
      'Paid, check still outstanding. You do not need to buy again – it is checked as soon as there is a connection.';
  @override
  String get checkAgain =>
      'Check again';
  @override
  String get storeUnavailable =>
      'The store cannot be reached right now.';
  @override
  String get restorePurchases =>
      'Restore purchases';
  @override
  String get revokedNote =>
      'Your purchase was refunded or revoked.';
  @override
  String get demoStoreNote =>
      'Demo store: test version, nothing is charged.';
  @override
  String get privacyOptions =>
      'Privacy choices for ads';
  @override
  String get msgUnlocked =>
      'Thank you! Ads are removed.';
  @override
  String get msgCanceled =>
      'Purchase canceled.';
  @override
  String get msgFailed =>
      'That did not work. Please try again later.';
  @override
  String get msgVerificationFailed =>
      'The purchase could not be confirmed. Nothing was unlocked.';
  @override
  String get msgPaidUnverified =>
      'Paid – the check follows as soon as there is a connection.';
  @override
  String get msgCheckUnavailable =>
      'Buying is not possible right now because the purchase check cannot be reached. Please try again later. You can keep playing for free.';
  @override
  String get msgRestoredOwned =>
      'Purchase restored – ad-free.';
  @override
  String get msgRestoredNothing =>
      'No purchase was found for this store account. Nothing can be restored without an internet connection.';
  @override
  String buyFor(String price) => 'Buy for $price';
  @override
  String get aboutHeading => 'About';
  @override
  String get privacyPolicy => 'Privacy policy';
  @override
  String get supportAndImprint => 'Support and legal notice';
  @override
  String get licenses => 'Licenses';
  @override
  String get linkFailed => 'The link could not be opened.';
}

class AppStringsDelegate extends LocalizationsDelegate<S> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => const ['de', 'en'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture<S>(S.forLanguage(locale.languageCode));

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

extension AppStringsContext on BuildContext {
  S get s => S.of(this);
}
