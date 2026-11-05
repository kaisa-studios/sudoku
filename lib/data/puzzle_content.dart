import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/daily/streak.dart';
import '../domain/sudoku/difficulty.dart';
import '../domain/sudoku/generator.dart';
import '../domain/sudoku/grid.dart';

/// Shipped, doubly verified puzzles: fallback pool and daily puzzles.
class PuzzleContent {
  PuzzleContent({
    required Map<Difficulty, List<GeneratedPuzzle>> pool,
    required this.dailyStart,
    required this.dailyLevels,
    required List<List<GeneratedPuzzle>> daily,
  })  : _pool = pool,
        _daily = daily;

  final Map<Difficulty, List<GeneratedPuzzle>> _pool;
  final DateTime dailyStart;
  final List<Difficulty> dailyLevels;
  final List<List<GeneratedPuzzle>> _daily;

  static const poolAsset = 'assets/puzzles/pool.json';
  static const dailyAsset = 'assets/puzzles/daily.json';

  static Future<PuzzleContent> load(AssetBundle bundle) async =>
      parse(await bundle.loadString(poolAsset), await bundle.loadString(dailyAsset));

  static GeneratedPuzzle _entry(Map<String, Object?> e, Difficulty level) => GeneratedPuzzle(
        puzzle: gridFromString(e['p']! as String),
        solution: gridFromString(e['s']! as String),
        difficulty: level,
        seed: e['seed'] as int? ?? 0,
        score: e['score'] as int? ?? 0,
        steps: 0,
        strategyCounts: const {},
      );

  static PuzzleContent parse(String poolJson, String dailyJson) {
    final pool = jsonDecode(poolJson) as Map<String, Object?>;
    final levels = pool['levels']! as Map<String, Object?>;
    final daily = jsonDecode(dailyJson) as Map<String, Object?>;
    final dailyLevels = [
      for (final l in daily['levels']! as List) Difficulty.values.byName(l as String),
    ];
    final start = (daily['start']! as String).split('-').map(int.parse).toList();
    return PuzzleContent(
      pool: {
        for (final d in Difficulty.values)
          d: [
            for (final e in (levels[d.name] as List? ?? const []))
              _entry(e as Map<String, Object?>, d),
          ],
      },
      dailyStart: DateTime.utc(start[0], start[1], start[2]),
      dailyLevels: dailyLevels,
      daily: [
        for (final day in daily['days']! as List)
          [
            for (var i = 0; i < dailyLevels.length; i++)
              _entry((day as List)[i] as Map<String, Object?>, dailyLevels[i]),
          ],
      ],
    );
  }

  List<GeneratedPuzzle> pool(Difficulty level) => _pool[level] ?? const [];

  /// The three daily puzzles of the local calendar day of [date], or null if
  /// outside the shipped range.
  List<GeneratedPuzzle>? dailyFor(DateTime date) {
    final key = dayKey(date).split('-').map(int.parse).toList();
    final index = DateTime.utc(key[0], key[1], key[2]).difference(dailyStart).inDays;
    if (index < 0 || index >= _daily.length) return null;
    return _daily[index];
  }
}
