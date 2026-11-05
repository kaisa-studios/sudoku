import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/main.dart';

import '../support.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('start, enter digits, leave, continue with the saved state', (tester) async {
    _phone(tester);
    final services = testServices(now: DateTime(2026, 11, 9, 10));
    await tester.pumpWidget(TidySudokuApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('Tidy Sudoku'), findsOneWidget);
    expect(find.textContaining('Spiel fortsetzen'), findsNothing);

    await tester.tap(find.text('Mittel'));
    await tester.pump();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    expect(find.text('Fehler 0/3'), findsOneWidget);

    // first empty cell (row 1, column 3) is selected; its solution is 4
    await tester.tap(find.bySemanticsLabel('Zahl 1'));
    await tester.pump();
    expect(find.text('Fehler 1/3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zahl 4'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp(r'Zeile 1, Spalte 3, Eingabe 4$')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('Spiel fortsetzen'), findsOneWidget);

    await tester.tap(find.textContaining('Spiel fortsetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Fehler 1/3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Zeile 1, Spalte 3, Eingabe 4$')), findsOneWidget);
  });

  testWidgets('third mistake shows the dialog; "Später" keeps the game locked', (tester) async {
    _phone(tester);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: DateTime(2026, 11, 9, 10))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    for (final d in [1, 2, 3]) {
      await tester.tap(find.bySemanticsLabel('Zahl $d'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Drei Fehler'), findsOneWidget);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();

    // back home; continuing offers the decision again instead of a free chance
    await tester.tap(find.textContaining('Spiel fortsetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Drei Fehler'), findsOneWidget);
    await tester.tap(find.text('Weiterspielen'));
    await tester.pumpAndSettle();
    expect(find.text('Fehler 3/3'), findsOneWidget);
  });

  testWidgets('starting a new game asks before discarding the open one', (tester) async {
    _phone(tester);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: DateTime(2026, 11, 9, 10))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    expect(find.text('Neues Sudoku starten?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Spiel fortsetzen'), findsOneWidget);
  });

  testWidgets('daily sudoku: three puzzles, solving one starts the streak', (tester) async {
    _phone(tester);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: DateTime(2026, 11, 9, 10))));
    await tester.pumpAndSettle();
    expect(find.text('Heute 0 von 3 gelöst'), findsOneWidget);
    await tester.tap(find.text('Tägliches Sudoku'));
    await tester.pumpAndSettle();
    expect(find.text('9. November 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Leicht, Starten'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Leicht, Starten'));
    await tester.pumpAndSettle();
    const solution = exampleSolution;
    for (var c = 0; c < 81; c++) {
      if (examplePuzzle[c] != '0') continue;
      await tester.tap(find.bySemanticsLabel(RegExp('^Zeile ${c ~/ 9 + 1}, Spalte ${c % 9 + 1}, ')));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp('^Zahl ${solution[c]}')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Geschafft!'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Leicht, Gelöst'), findsOneWidget);
    expect(find.text('1 Tag'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Heute 1 von 3 gelöst'), findsOneWidget);
  });

  testWidgets('statistics: empty state', (tester) async {
    _phone(tester);
    await tester.pumpWidget(TidySudokuApp(services: testServices(now: DateTime(2026, 11, 9, 10))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Spiele – starte dein erstes Sudoku.'), findsOneWidget);
  });
}
