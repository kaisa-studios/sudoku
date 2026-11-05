// Generates the shipped puzzle content (Master-Prompt 7, DECISIONS D7):
//   assets/puzzles/pool.json   – verified fallback pool, 25 per level
//   assets/puzzles/daily.json  – three daily puzzles (easy, medium, hard) per day
// Every puzzle is generated from a fixed seed without a time budget, so the
// output is reproducible. Run: dart run tool/build_content.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/grid.dart';
import 'package:sudoku/domain/sudoku/logic_solver.dart';
import 'package:sudoku/domain/sudoku/solver.dart';

const poolPerLevel = 25;
final dailyStart = DateTime.utc(2026, 11, 1);
const dailyDays = 790; // 1 Nov 2026 – 29 Dec 2028
const dailyLevels = [Difficulty.easy, Difficulty.medium, Difficulty.hard];

final _seen = <String>{};

GeneratedPuzzle _make(Difficulty level, int seed) {
  for (var s = seed;; s += 7919) {
    final g = generate(level, seed: s, maxCandidates: 20000, budget: const Duration(hours: 1));
    if (g == null) continue;
    if (!_seen.add(g.fingerprint)) continue; // never ship the same puzzle twice
    // first verification path (the Python checker is the second one)
    if (countSolutions(g.puzzle) != 1) throw StateError('not unique: ${g.fingerprint}');
    final r = rate(g.puzzle, oracle: g.solution);
    if (r.level != level || r.result.oracleViolations != 0) {
      throw StateError('rating mismatch: ${g.fingerprint}');
    }
    return g;
  }
}

Map<String, Object> _compact(GeneratedPuzzle g) => {
      'p': gridToString(g.puzzle),
      's': gridToString(g.solution),
      'seed': g.seed,
      'score': g.score,
    };

void main() {
  final watch = Stopwatch()..start();
  Directory('assets/puzzles').createSync(recursive: true);

  final pool = <String, List<Object>>{};
  for (final level in Difficulty.values) {
    pool[level.name] = [
      for (var i = 0; i < poolPerLevel; i++) _compact(_make(level, 100000 * (level.index + 1) + i)),
    ];
    print('pool ${level.name}: ${pool[level.name]!.length} (${watch.elapsed.inSeconds}s)');
  }
  File('assets/puzzles/pool.json').writeAsStringSync(jsonEncode({
    'generatorVersion': generatorVersion,
    'raterVersion': raterVersion,
    'levels': pool,
  }));

  final days = <Object>[];
  for (var d = 0; d < dailyDays; d++) {
    final date = dailyStart.add(Duration(days: d));
    final ymd = date.year * 10000 + date.month * 100 + date.day;
    days.add([for (final level in dailyLevels) _compact(_make(level, ymd * 10 + level.index))]);
    if (d % 50 == 0) print('daily $d/$dailyDays (${watch.elapsed.inSeconds}s)');
  }
  File('assets/puzzles/daily.json').writeAsStringSync(jsonEncode({
    'generatorVersion': generatorVersion,
    'raterVersion': raterVersion,
    'start': '${dailyStart.year}-${dailyStart.month.toString().padLeft(2, '0')}-${dailyStart.day.toString().padLeft(2, '0')}',
    'levels': [for (final l in dailyLevels) l.name],
    'days': days,
  }));
  print('done: ${_seen.length} puzzles in ${watch.elapsed.inSeconds}s');
}
