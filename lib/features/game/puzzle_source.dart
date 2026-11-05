import 'dart:isolate';
import 'dart:math';

import '../../domain/sudoku/difficulty.dart';
import '../../domain/sudoku/generator.dart';

/// Supplies a new verified puzzle for a difficulty. Injected so widget tests
/// can use fixed puzzles.
typedef PuzzleSource = Future<GeneratedPuzzle> Function(Difficulty level);

/// Generates on a background isolate so the UI never blocks (Master-Prompt 4.2).
/// Phase 1: retries with fresh seeds; the verified fallback pool follows in Phase 2.
Future<GeneratedPuzzle> generatePuzzle(Difficulty level) async {
  final seed = Random().nextInt(1 << 31);
  final result = await Isolate.run(() {
    for (var i = 0; i < 20; i++) {
      final g = generate(level, seed: seed + i);
      if (g != null) return g.toJson();
    }
    return null;
  });
  if (result == null) {
    throw StateError('no ${level.name} puzzle found');
  }
  return GeneratedPuzzle.fromJson(result);
}
