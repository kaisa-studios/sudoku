import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:sudoku/app/services.dart';
import 'package:sudoku/data/app_database.dart';
import 'package:sudoku/data/game_repository.dart';
import 'package:sudoku/data/puzzle_content.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/grid.dart';

const examplePuzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const exampleSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

AppDatabase memoryDb() =>
    AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

GeneratedPuzzle examplePuzzleOf(Difficulty d, {String puzzle = examplePuzzle}) => GeneratedPuzzle(
      puzzle: gridFromString(puzzle),
      solution: gridFromString(exampleSolution),
      difficulty: d,
      seed: 0,
      score: 0,
      steps: 0,
      strategyCounts: const {},
    );

/// Small content set: the example puzzle everywhere, daily range from 2026-11-01.
PuzzleContent testContent() {
  const e = '{"p":"$examplePuzzle","s":"$exampleSolution","seed":1,"score":1}';
  final pool = '{"levels":{"easy":[$e],"medium":[$e],"hard":[$e],"expert":[$e]}}';
  final days = List.filled(60, '[$e,$e,$e]').join(',');
  final daily = '{"start":"2026-11-01","levels":["easy","medium","hard"],"days":[$days]}';
  return PuzzleContent.parse(pool, daily);
}

/// German by default so the checks can use the German texts; pass null to follow the device.
Services testServices({DateTime? now, AppDatabase? db, String? language = 'de'}) {
  final clock = now == null ? DateTime.now : () => now;
  final services = Services(
    games: GameRepository(db ?? memoryDb(), clock: clock),
    content: testContent(),
    source: (level, avoid) async => examplePuzzleOf(level),
    clock: clock,
  );
  services.settings.languageCode = language;
  return services;
}
