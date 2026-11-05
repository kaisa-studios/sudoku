import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/puzzle_content.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/logic_solver.dart';
import 'package:sudoku/domain/sudoku/solver.dart';

void main() {
  final content = PuzzleContent.parse(
    File(PuzzleContent.poolAsset).readAsStringSync(),
    File(PuzzleContent.dailyAsset).readAsStringSync(),
  );

  test('shipped pool: 25 puzzles per level, each unique and rated as labelled', () {
    for (final level in Difficulty.values) {
      final pool = content.pool(level);
      expect(pool, hasLength(25));
      for (final p in pool) {
        expect(countSolutions(p.puzzle), 1);
        expect(rate(p.puzzle, oracle: p.solution).level, level);
      }
    }
  });

  test('daily puzzles cover today until the end of 2028', () {
    expect(content.dailyFor(DateTime(2026, 11, 5)), hasLength(3));
    expect(content.dailyFor(DateTime(2028, 12, 31)), hasLength(3));
    expect(content.dailyLevels, [Difficulty.easy, Difficulty.medium, Difficulty.hard]);
  });

  test('random sample of daily puzzles is unique and rated as labelled', () {
    final rng = Random(5);
    for (var i = 0; i < 40; i++) {
      final day = DateTime(2026, 11, 1).add(Duration(days: rng.nextInt(780)));
      for (final p in content.dailyFor(day)!) {
        expect(countSolutions(p.puzzle), 1);
        expect(rate(p.puzzle, oracle: p.solution).level, p.difficulty);
      }
    }
  });
}
