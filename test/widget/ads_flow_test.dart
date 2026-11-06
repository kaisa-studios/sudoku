import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/app/services.dart';
import 'package:sudoku/data/entitlement_repository.dart';
import 'package:sudoku/domain/game/game.dart';
import 'package:sudoku/features/purchases/store.dart';
import 'package:sudoku/main.dart';

import '../support.dart';

void _phone(WidgetTester tester, {double height = 2340}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

/// Starts a game and makes three mistakes in the first empty cell (solution 4).
Future<void> _threeMistakes(WidgetTester tester, Services services) async {
  await tester.pumpWidget(TidySudokuApp(services: services));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text('Spiel starten'));
  await tester.pumpAndSettle();
  for (final d in [1, 2, 3]) {
    await tester.tap(find.bySemanticsLabel('Zahl $d'));
    await tester.pumpAndSettle();
  }
  expect(find.text('Drei Fehler'), findsOneWidget);
}

final _now = DateTime(2026, 11, 9, 10);

/// Waits for a database future inside the widget test's fake time.
Future<T> _wait<T>(WidgetTester tester, Future<T> future) async {
  late T result;
  var done = false;
  future.then((v) {
    result = v;
    done = true;
  });
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done, isTrue);
  return result;
}

void main() {
  testWidgets('second chance with a video: only the reward callback unlocks, saved as "rewarded"', (tester) async {
    _phone(tester);
    final ads = FakeAdsBackend(video: FakeVideo.earnThenClose);
    final services = testServices(now: _now, adsBackend: ads);
    await _threeMistakes(tester, services);
    await tester.tap(find.text('Video ansehen'));
    await tester.pumpAndSettle();
    expect(ads.rewardeds.single.shows, 1);
    expect(find.text('Drei Fehler'), findsNothing);
    expect(find.text('Fehler 3/3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zahl 4'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp(r'Zeile 1, Spalte 3, Eingabe 4$')), findsOneWidget);

    final saved = (await _wait(tester, services.games.openRegularGame()))!;
    expect(saved.game.continueSource, ContinueSource.rewarded);
    expect(saved.game.rewardedAdOpened, isTrue);
  });

  testWidgets('no video available: the exact message, retry, later keeps the chance', (tester) async {
    _phone(tester);
    final ads = FakeAdsBackend(fill: false);
    await _threeMistakes(tester, testServices(now: _now, adsBackend: ads));
    await tester.tap(find.text('Video ansehen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Zurzeit ist kein Video verfügbar. Du kannst es später erneut versuchen oder das Spiel beenden.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(ads.rewardedLoads, 2);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Spiel fortsetzen'), findsOneWidget);
    await _tapVisible(tester, find.textContaining('Spiel fortsetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Drei Fehler'), findsOneWidget, reason: 'still locked, chance unused');
  });

  testWidgets('video closed early: locked game with the way back to the decision', (tester) async {
    _phone(tester);
    await _threeMistakes(tester, testServices(now: _now, adsBackend: FakeAdsBackend(video: FakeVideo.closeEarly)));
    await tester.tap(find.text('Video ansehen'));
    await tester.pumpAndSettle();
    expect(find.text('Video vorzeitig beendet – deine zweite Chance bleibt erhalten.'), findsOneWidget);
    expect(find.text('Fehler 3/3'), findsOneWidget);
    await tester.tap(find.text('Zweite Chance'));
    await tester.pumpAndSettle();
    expect(find.text('Drei Fehler'), findsOneWidget);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
  });

  testWidgets('ad-free: second chance without any video', (tester) async {
    _phone(tester);
    final db = memoryDb();
    await _wait(tester, EntitlementRepository(db).grant(productId: removeAdsProductId, store: 'demo'));
    final ads = FakeAdsBackend();
    final services = testServices(now: _now, db: db, adsBackend: ads);
    await _threeMistakes(tester, services);
    expect(find.text('Video ansehen'), findsNothing);
    await tester.tap(find.text('Weiterspielen'));
    await tester.pumpAndSettle();
    expect(find.text('Fehler 3/3'), findsOneWidget);
    expect(ads.rewardedLoads, 0);
    expect(ads.interstitialLoads, 0);
    final saved = (await _wait(tester, services.games.openRegularGame()))!;
    expect(saved.game.continueSource, ContinueSource.adFree);
  });

  testWidgets('ending after three mistakes leads to the result view with "Neues Sudoku"', (tester) async {
    _phone(tester);
    await _threeMistakes(tester, testServices(now: _now));
    await tester.tap(find.text('Spiel beenden'));
    await tester.pumpAndSettle();
    expect(find.text('Sudoku beendet'), findsOneWidget);
    expect(find.text('Zählt als nicht geschafft.'), findsOneWidget);
    await tester.tap(find.text('Neues Sudoku'));
    await tester.pumpAndSettle();
    expect(find.text('Fehler 0/3'), findsOneWidget);
  });

  testWidgets('settings: buy "Werbung entfernen" in the demo store', (tester) async {
    _phone(tester, height: 5400);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: _now)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Einmal kaufen: alle Werbung entfernen. Die einmalige zweite Chance erhältst du ohne Video.'),
      findsOneWidget,
    );
    expect(find.text('Demo-Store: Testversion, es wird nichts berechnet.'), findsOneWidget);
    await tester.tap(find.text('Für 1,99 € kaufen'));
    await tester.pumpAndSettle();
    expect(find.text('Werbefrei – danke für deinen Kauf!'), findsOneWidget);
    expect(find.text('Danke! Die Werbung ist entfernt.'), findsOneWidget);
  });

  testWidgets('settings: privacy policy, support and licenses are reachable', (tester) async {
    _phone(tester, height: 5400);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: _now)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lizenzen'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Datenschutzerklärung'), findsOneWidget);
    expect(find.text('Support und Impressum'), findsOneWidget);
    await tester.tap(find.text('Lizenzen'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
