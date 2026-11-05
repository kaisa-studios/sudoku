// Calibration run: prints how often each carving method yields exactly the
// target level, plus givens and time per candidate. Never fails; the numbers
// choose the generator settings (see CI log, lines starting with "CAL").
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/logic_solver.dart';
import 'package:sudoku/domain/sudoku/solver.dart';

void main() {
  test('calibration of carving methods', () {
    const samples = 80;
    final methods = <String, List<int> Function(List<int>, Difficulty, Random)>{
      'single': (s, l, r) => carveGreedy(s, l, r, floor: 17, sample: 1),
      'greedy4': (s, l, r) => carveGreedy(s, l, r, floor: 17, sample: 4),
      'greedy12': (s, l, r) => carveGreedy(s, l, r, floor: 17, sample: 12),
    };
    for (final level in [Difficulty.medium, Difficulty.hard, Difficulty.expert]) {
      for (final m in methods.entries) {
        final rng = Random(level.index * 1000 + m.key.length);
        final hist = <String, int>{};
        var givensSum = 0;
        final watch = Stopwatch()..start();
        for (var i = 0; i < samples; i++) {
          final p = m.value(randomSolution(rng), level, rng);
          final r = rate(p);
          final key = r.level?.name ?? 'beyond';
          hist[key] = (hist[key] ?? 0) + 1;
          givensSum += p.where((v) => v != 0).length;
        }
        final ms = watch.elapsedMilliseconds / samples;
        print('CAL ${level.name} ${m.key} hit=${hist[level.name] ?? 0}/$samples '
            'avgGivens=${(givensSum / samples).toStringAsFixed(1)} '
            'ms/candidate=${ms.toStringAsFixed(1)} hist=$hist');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
