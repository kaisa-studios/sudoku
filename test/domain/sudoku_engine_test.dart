import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/grid.dart';
import 'package:sudoku/domain/sudoku/logic_solver.dart';
import 'package:sudoku/domain/sudoku/solver.dart';

// Well-known example puzzle (Wikipedia) and its unique solution.
const _wikiPuzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _wikiSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

void main() {
  group('grid', () {
    test('units and peers', () {
      expect(units.length, 27);
      for (final u in units) {
        expect(u.toSet().length, 9);
      }
      for (var c = 0; c < cellCount; c++) {
        expect(peers[c].length, 20);
        expect(peers[c].contains(c), isFalse);
      }
    });

    test('validation', () {
      expect(isValidGrid(gridFromString(_wikiPuzzle)), isTrue);
      expect(isSolvedGrid(gridFromString(_wikiSolution)), isTrue);
      final dup = gridFromString(_wikiPuzzle)..[1] = 5; // two 5s in row 0
      expect(isValidGrid(dup), isFalse);
      expect(isValidGrid([1, 2, 3]), isFalse);
      expect(isValidGrid(List.filled(81, 10)), isFalse);
    });
  });

  group('exact solver', () {
    test('solves the example puzzle uniquely', () {
      final p = gridFromString(_wikiPuzzle);
      expect(countSolutions(p), 1);
      expect(gridToString(solve(p)!), _wikiSolution);
    });

    test('detects multiple and zero solutions', () {
      expect(countSolutions(List.filled(81, 0)), 2);
      final dup = gridFromString(_wikiPuzzle)..[1] = 5;
      expect(countSolutions(dup), 0);
      // remove two givens that leave the example ambiguous? use an almost empty grid
      final sparse = List.filled(81, 0)..[0] = 1;
      expect(hasUniqueSolution(sparse), isFalse);
    });

    test('random solutions are valid and seed-reproducible', () {
      final a = randomSolution(Random(7));
      final b = randomSolution(Random(7));
      expect(isSolvedGrid(a), isTrue);
      expect(a, b);
      expect(randomSolution(Random(8)), isNot(a));
    });
  });

  group('logical solver', () {
    test('example puzzle needs only singles', () {
      final r = rate(gridFromString(_wikiPuzzle), oracle: gridFromString(_wikiSolution));
      expect(r.level, Difficulty.easy);
      expect(gridToString(r.result.grid), _wikiSolution);
      expect(r.result.oracleViolations, 0);
    });

    test('never removes the true digit (oracle check on many puzzles)', () {
      final rng = Random(2026);
      var checked = 0;
      for (var i = 0; i < 60; i++) {
        final solution = randomSolution(rng);
        // carve with expert strategies to exercise every technique
        final puzzle = i.isEven
            ? carve(solution, Difficulty.expert, rng)
            : carveGreedy(solution, Difficulty.expert, rng, sample: 4);
        final r = LogicSolver(puzzle, oracle: solution).run(Strategy.values);
        expect(r.oracleViolations, 0, reason: gridToString(puzzle));
        expect(r.contradiction, isFalse, reason: gridToString(puzzle));
        if (r.solved) expect(r.grid, solution);
        checked++;
      }
      expect(checked, 60);
    });
  });

  group('generator', () {
    final stats = <Difficulty, List<int>>{};

    for (final level in Difficulty.values) {
      test('produces unique ${level.name} puzzles rated exactly ${level.name}', () {
        final seeds = level == Difficulty.expert ? [1, 2, 3] : [1, 2, 3, 4, 5];
        for (final seed in seeds) {
          final watch = Stopwatch()..start();
          final g = generate(level,
              seed: seed, maxCandidates: 400, budget: const Duration(seconds: 30));
          watch.stop();
          expect(g, isNotNull, reason: 'seed $seed');
          stats.putIfAbsent(level, () => []).add(watch.elapsedMilliseconds);
          final p = g!.puzzle;
          expect(isValidGrid(p), isTrue);
          expect(isSolvedGrid(g.solution), isTrue);
          for (var c = 0; c < cellCount; c++) {
            if (p[c] != 0) expect(p[c], g.solution[c]);
          }
          expect(countSolutions(p), 1);
          expect(g.givens, greaterThanOrEqualTo(minGivens[level]!));
          final r = rate(p, oracle: g.solution);
          expect(r.level, level);
          expect(r.result.oracleViolations, 0);
          // reproducible from the seed
          final again = generate(level,
              seed: seed, maxCandidates: 400, budget: const Duration(seconds: 30));
          expect(again!.fingerprint, g.fingerprint);
          // JSON round trip
          final back = GeneratedPuzzle.fromJson(g.toJson());
          expect(back.fingerprint, g.fingerprint);
          expect(back.difficulty, level);
        }
      }, timeout: const Timeout(Duration(minutes: 5)));
    }

    tearDownAll(() {
      // calibration output for the CI log
      for (final e in stats.entries) {
        final ms = e.value;
        // ignore: avoid_print
        print('generation ${e.key.name}: ${ms.join(", ")} ms');
      }
    });
  });
}
