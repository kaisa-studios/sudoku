// Calibration run: prints how often carving for a level yields exactly that
// level, for several givens floors, plus time per candidate. Never fails;
// the numbers feed the floors in generator.dart (see CI log).
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/logic_solver.dart';
import 'package:sudoku/domain/sudoku/solver.dart';

void main() {
  test('calibration of givens floors', () {
    const samples = 150;
    final floors = {
      Difficulty.easy: [36, 34],
      Difficulty.medium: [30, 28, 26],
      Difficulty.hard: [26, 24, 22, 20],
      Difficulty.expert: [24, 22, 20],
    };
    for (final level in Difficulty.values) {
      for (final floor in floors[level]!) {
        final rng = Random(level.index * 100 + floor);
        final hist = <String, int>{};
        var givensSum = 0;
        final watch = Stopwatch()..start();
        for (var i = 0; i < samples; i++) {
          final p = carve(randomSolution(rng), level, rng, floor: floor);
          final r = rate(p);
          final key = r.level?.name ?? 'beyond';
          hist[key] = (hist[key] ?? 0) + 1;
          givensSum += p.where((v) => v != 0).length;
        }
        final ms = watch.elapsedMilliseconds / samples;
        print('CAL ${level.name} floor=$floor hit=${hist[level.name] ?? 0}/$samples '
            'avgGivens=${(givensSum / samples).toStringAsFixed(1)} '
            'ms/candidate=${ms.toStringAsFixed(1)} hist=$hist');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
