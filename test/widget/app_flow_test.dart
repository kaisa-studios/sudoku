import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/grid.dart';
import 'package:sudoku/features/home/home_screen.dart';
import 'package:sudoku/main.dart';

const _puzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _solution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

Future<GeneratedPuzzle> _fixed(Difficulty d) async => GeneratedPuzzle(
      puzzle: gridFromString(_puzzle),
      solution: gridFromString(_solution),
      difficulty: d,
      seed: 0,
      score: 0,
      steps: 0,
      strategyCounts: const {},
    );

void main() {
  testWidgets('start screen opens a game and digits can be entered', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TidySudokuApp(home: HomeScreen(source: _fixed)));
    expect(find.text('Tidy Sudoku'), findsOneWidget);

    await tester.tap(find.text('Mittel'));
    await tester.pump();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();

    expect(find.text('Mittel'), findsOneWidget); // app bar title
    expect(find.text('Fehler 0/3'), findsOneWidget);

    // first empty cell (row 1, column 3) is selected; its solution is 4
    await tester.tap(find.bySemanticsLabel('Zahl 1'));
    await tester.pump();
    expect(find.text('Fehler 1/3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zahl 4'));
    await tester.pump();
    expect(find.text('Fehler 1/3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Zeile 1, Spalte 3, Eingabe 4$')), findsOneWidget);
  });

  testWidgets('third mistake shows the second-chance dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TidySudokuApp(home: HomeScreen(source: _fixed)));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    for (final d in [1, 2, 3]) {
      await tester.tap(find.bySemanticsLabel('Zahl $d'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Drei Fehler'), findsOneWidget);
    await tester.tap(find.text('Weiterspielen'));
    await tester.pumpAndSettle();
    expect(find.text('Fehler 3/3'), findsOneWidget);
  });
}
