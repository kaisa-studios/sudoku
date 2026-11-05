/// Puzzle generator: random complete grid, symmetric removal of givens while
/// the puzzle stays unique and solvable with the target level's strategies,
/// then a final rating that must match the target exactly.
library;

import 'dart:math';

import 'difficulty.dart';
import 'grid.dart';
import 'logic_solver.dart';
import 'solver.dart';

const int generatorVersion = 1;

/// Comfort floor per level [A]: never fewer givens than this. Difficulty itself
/// is decided by the strategies needed (Master-Prompt 6.1), the floor only
/// keeps easy puzzles short and friendly.
const Map<Difficulty, int> minGivens = {
  Difficulty.easy: 36,
  Difficulty.medium: 30,
  Difficulty.hard: 26,
  Difficulty.expert: 22,
};

class GeneratedPuzzle {
  GeneratedPuzzle({
    required this.puzzle,
    required this.solution,
    required this.difficulty,
    required this.seed,
    required this.score,
    required this.steps,
    required this.strategyCounts,
  });

  final List<int> puzzle;
  final List<int> solution;
  final Difficulty difficulty;
  final int seed;
  final int score;
  final int steps;
  final Map<Strategy, int> strategyCounts;

  int get givens => puzzle.where((v) => v != 0).length;
  String get fingerprint => gridToString(puzzle);

  Map<String, Object> toJson() => {
        'puzzle': gridToString(puzzle),
        'solution': gridToString(solution),
        'difficulty': difficulty.name,
        'seed': seed,
        'score': score,
        'steps': steps,
        'strategies': {
          for (final e in strategyCounts.entries)
            if (e.value > 0) e.key.name: e.value,
        },
        'generatorVersion': generatorVersion,
        'raterVersion': raterVersion,
      };

  static GeneratedPuzzle fromJson(Map<String, Object?> j) => GeneratedPuzzle(
        puzzle: gridFromString(j['puzzle']! as String),
        solution: gridFromString(j['solution']! as String),
        difficulty: Difficulty.values.byName(j['difficulty']! as String),
        seed: j['seed']! as int,
        score: j['score']! as int,
        steps: j['steps']! as int,
        strategyCounts: {
          for (final e in (j['strategies']! as Map).entries)
            Strategy.values.byName(e.key as String): e.value as int,
        },
      );
}

/// Removes givens from [solution] in symmetric pairs while the puzzle stays
/// unique and solvable with the strategies of [target].
List<int> carve(List<int> solution, Difficulty target, Random rng) {
  final puzzle = List.of(solution);
  final order = List<int>.generate(41, (i) => i)..shuffle(rng); // 40 pairs + centre
  var givens = cellCount;
  final floor = minGivens[target]!;
  for (final i in order) {
    final j = 80 - i;
    final removing = i == j ? 1 : 2;
    if (givens - removing < floor) continue;
    final vi = puzzle[i], vj = puzzle[j];
    puzzle[i] = 0;
    puzzle[j] = 0;
    if (hasUniqueSolution(puzzle) && solveLogically(puzzle, target).solved) {
      givens -= removing;
    } else {
      puzzle[i] = vi;
      puzzle[j] = vj;
    }
  }
  return puzzle;
}

/// Tries up to [maxCandidates] grids or [budget] time, whichever ends first.
/// Returns null if no puzzle of exactly [target] was found; the caller then
/// falls back to the verified pool (never to an unverified puzzle).
GeneratedPuzzle? generate(
  Difficulty target, {
  required int seed,
  int maxCandidates = 50,
  Duration budget = const Duration(seconds: 2),
}) {
  final rng = Random(seed);
  final watch = Stopwatch()..start();
  for (var attempt = 0; attempt < maxCandidates; attempt++) {
    if (watch.elapsed > budget) break;
    final solution = randomSolution(rng);
    final puzzle = carve(solution, target, rng);
    final rating = rate(puzzle);
    if (rating.level != target) continue;
    return GeneratedPuzzle(
      puzzle: puzzle,
      solution: solution,
      difficulty: target,
      seed: seed,
      score: rating.result.score,
      steps: rating.result.steps,
      strategyCounts: rating.result.counts,
    );
  }
  return null;
}
