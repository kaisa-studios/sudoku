/// Statistics with the exact definitions of Master-Prompt 6.5.
library;

import '../game/game.dart';
import '../sudoku/difficulty.dart';

class GameSummary {
  const GameSummary({
    required this.difficulty,
    required this.daily,
    required this.phase,
    required this.outcome,
    required this.mistakes,
    required this.hintCount,
    required this.activeMs,
    required this.continueUsed,
    required this.continueSource,
    required this.failed,
  });

  final Difficulty difficulty;
  final bool daily;
  final GamePhase phase;
  final GameOutcome outcome;
  final int mistakes;
  final int hintCount;
  final int activeMs;
  final bool continueUsed;
  final ContinueSource continueSource;

  /// Third mistake reached (counts as "not solved" from that moment on).
  final bool failed;

  bool get isFinal => phase == GamePhase.completed || phase == GamePhase.abandoned;
}

class Stats {
  Stats({
    required this.started,
    required this.won,
    required this.failed,
    required this.abandonedWithoutFail,
    required this.undecided,
    required this.bestMs,
    required this.averageMs,
    required this.averageMistakes,
    required this.secondChances,
    required this.secondChancesByAd,
    required this.finishedAfterSecondChance,
  });

  /// started = won + failed + abandonedWithoutFail + undecided
  final int started;
  final int won;
  final int failed;
  final int abandonedWithoutFail;
  final int undecided;

  /// Won games without hints only; null if there are none.
  final int? bestMs;
  final double? averageMs;

  /// Over finished games (completed or abandoned); null if there are none.
  final double? averageMistakes;
  final int secondChances;
  final int secondChancesByAd;
  final int finishedAfterSecondChance;

  bool get isEmpty => started == 0;

  static Stats of(Iterable<GameSummary> games) {
    final list = games.toList();
    final timed = [
      for (final g in list)
        if (g.outcome == GameOutcome.won && g.hintCount == 0) g.activeMs,
    ];
    final finals = [for (final g in list) if (g.isFinal) g];
    return Stats(
      started: list.length,
      won: list.where((g) => g.outcome == GameOutcome.won).length,
      failed: list.where((g) => g.failed).length,
      abandonedWithoutFail:
          list.where((g) => !g.failed && g.phase == GamePhase.abandoned).length,
      undecided: list.where((g) => !g.failed && !g.isFinal).length,
      bestMs: timed.isEmpty ? null : timed.reduce((a, b) => a < b ? a : b),
      averageMs: timed.isEmpty ? null : timed.reduce((a, b) => a + b) / timed.length,
      averageMistakes: finals.isEmpty
          ? null
          : finals.fold<int>(0, (s, g) => s + g.mistakes) / finals.length,
      secondChances: list.where((g) => g.continueUsed).length,
      secondChancesByAd:
          list.where((g) => g.continueUsed && g.continueSource == ContinueSource.rewarded).length,
      finishedAfterSecondChance: list
          .where((g) =>
              g.continueUsed && g.phase == GamePhase.completed && g.outcome == GameOutcome.failed)
          .length,
    );
  }
}

/// Statistics per difficulty plus the overall view; daily games separately.
class StatsReport {
  StatsReport(List<GameSummary> games)
      : overall = Stats.of(games.where((g) => !g.daily)),
        daily = Stats.of(games.where((g) => g.daily)),
        byLevel = {
          for (final d in Difficulty.values)
            d: Stats.of(games.where((g) => !g.daily && g.difficulty == d)),
        };

  final Stats overall;
  final Stats daily;
  final Map<Difficulty, Stats> byLevel;
}
