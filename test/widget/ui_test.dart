import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/main.dart';

import '../support.dart';

final _now = DateTime(2026, 11, 9, 10);

void _screen(WidgetTester tester, {Size size = const Size(1080, 2340), double ratio = 3, double text = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hint fills the selected cell, marks it and counts', (tester) async {
    _screen(tester);
    final services = testServices(now: _now);
    await tester.pumpWidget(TidySudokuApp(services: services));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Spiel starten'));
    await tester.tap(find.text('Hinweis'));
    await tester.pump();
    expect(find.bySemanticsLabel('Zeile 1, Spalte 3, Hinweis 4, nicht bearbeitbar'), findsOneWidget);
    expect(find.text('Hinweis: Ein Feld wurde richtig eingetragen.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final open = await services.games.openRegularGame();
    expect(open!.game.hintCount, 1);
  });

  testWidgets('device language English: the whole app speaks English', (tester) async {
    _screen(tester);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: _now, language: null)));
    await tester.pumpAndSettle();
    expect(find.text('Big numbers. Clear grid.'), findsOneWidget);
    expect(find.text('Daily Sudoku'), findsOneWidget);
    await _tapVisible(tester, find.text('Start game'));
    expect(find.text('Mistakes 0/3'), findsOneWidget);
    expect(find.bySemanticsLabel('Number 5'), findsOneWidget);
  });

  testWidgets('settings: language, dark mode and timer are applied and saved', (tester) async {
    _screen(tester, size: const Size(1080, 5400)); // tall: the whole settings list is built
    final services = testServices(now: _now);
    await tester.pumpWidget(TidySudokuApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Dunkel'));
    expect(services.settings.themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Dunkel'))).brightness, Brightness.dark);
    expect(await services.games.setting('theme'), 'dark');

    await _tapVisible(tester, find.text('Spielzeit anzeigen'));
    expect(services.settings.showTimer, isFalse);

    await _tapVisible(tester, find.text('English'));
    expect(find.text('Settings'), findsOneWidget);
    expect(await services.games.setting('language'), 'en');
  });

  testWidgets('settings: deleting game data removes the open game after confirmation', (tester) async {
    _screen(tester, size: const Size(1080, 5400));
    final services = testServices(now: _now);
    await tester.pumpWidget(TidySudokuApp(services: services));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Spiel starten'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Spiel fortsetzen'), findsOneWidget);

    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Lokale Spieldaten löschen'));
    expect(find.text('Alle Spieldaten löschen?'), findsOneWidget);
    await tester.tap(find.text('Endgültig löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Spiel fortsetzen'), findsNothing);
  });

  testWidgets('large view: arrows move the selection, position is announced', (tester) async {
    _screen(tester, size: const Size(960, 1704)); // 320 x 568
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: _now)));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Spiel starten'));
    await tester.tap(find.byTooltip('Große Darstellung'));
    await tester.pumpAndSettle();
    expect(find.text('Zeile 1, Spalte 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Feld rechts'));
    await tester.pumpAndSettle();
    expect(find.text('Zeile 1, Spalte 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Feld darunter'));
    await tester.pumpAndSettle();
    expect(find.text('Zeile 2, Spalte 4'), findsOneWidget);
    // cell (2,4) is a given (1); entering does nothing, no mistake
    await tester.tap(find.bySemanticsLabel('Zahl 9'));
    await tester.pump();
    expect(find.text('Fehler 0/3'), findsOneWidget);
  });

  for (final english in [false, true]) {
    testWidgets('200 % text on a small phone: every screen works without overflow (${english ? 'en' : 'de'})',
        (tester) async {
      _screen(tester, size: const Size(960, 1704), text: 2); // 320 x 568
      await tester.pumpWidget(TidySudokuApp(services: testServices(now: _now, language: english ? 'en' : 'de')));
      await tester.pumpAndSettle();
      final start = find.text(english ? 'Start game' : 'Spiel starten');
      await _tapVisible(tester, start);
      expect(find.bySemanticsLabel(english ? 'Number 1' : 'Zahl 1'), findsOneWidget);
      await tester.tap(find.byTooltip(english ? 'Large view' : 'Große Darstellung'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text(english ? 'Daily Sudoku' : 'Tägliches Sudoku'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text(english ? 'Statistics' : 'Statistik'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byTooltip(english ? 'Settings' : 'Einstellungen'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
