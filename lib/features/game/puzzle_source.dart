import 'dart:isolate';
import 'dart:math';

import '../../data/puzzle_content.dart';
import '../../domain/sudoku/difficulty.dart';
import '../../domain/sudoku/generator.dart';

/// Supplies a new verified puzzle for a difficulty, avoiding the given
/// fingerprints. Injected so widget tests can use fixed puzzles.
typedef PuzzleSource = Future<GeneratedPuzzle> Function(Difficulty level, Set<String> avoid);

/// Generates on a background isolate (never blocks the UI, 4.2) with a 2 s
/// budget; returns null if nothing of exactly [level] was found in time.
Future<GeneratedPuzzle?> tryGenerate(Difficulty level) async {
  final seed = Random().nextInt(1 << 31);
  final json = await Isolate.run(() => generate(level, seed: seed, maxCandidates: 400)?.toJson());
  return json == null ? null : GeneratedPuzzle.fromJson(json);
}

/// Live generation first; otherwise a verified pool puzzle not played
/// recently; as last resort (offline, pool exhausted) any pool puzzle (6.1).
/// Never an unverified puzzle.
PuzzleSource puzzleSourceWith(PuzzleContent content) => (level, avoid) async {
      final fresh = await tryGenerate(level).catchError((_) => null);
      if (fresh != null && !avoid.contains(fresh.fingerprint)) return fresh;
      final pool = content.pool(level);
      if (pool.isEmpty) throw StateError('no ${level.name} puzzle available');
      final unused = [for (final p in pool) if (!avoid.contains(p.fingerprint)) p];
      final from = unused.isNotEmpty ? unused : pool;
      return from[Random().nextInt(from.length)];
    };
