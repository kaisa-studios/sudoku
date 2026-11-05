/// Difficulty levels and the human solving strategies each level may need
/// (Master-Prompt 6.1).
library;

enum Difficulty { easy, medium, hard, expert }

/// Strategies in the order the logical solver tries them (cheapest first).
enum Strategy {
  nakedSingle(Difficulty.easy, 1),
  hiddenSingle(Difficulty.easy, 1),
  lockedCandidates(Difficulty.medium, 5),
  nakedPair(Difficulty.medium, 6),
  hiddenPair(Difficulty.medium, 8),
  nakedTriple(Difficulty.hard, 12),
  hiddenTriple(Difficulty.hard, 15),
  xWing(Difficulty.hard, 18),
  swordfish(Difficulty.expert, 30),
  xyWing(Difficulty.expert, 30);

  const Strategy(this.level, this.weight);

  /// Lowest difficulty that allows this strategy.
  final Difficulty level;

  /// Contribution to the calibration score per application.
  final int weight;
}

extension DifficultyStrategies on Difficulty {
  /// Strategies allowed at this level (all strategies of this and lower levels).
  List<Strategy> get allowedStrategies =>
      [for (final s in Strategy.values) if (s.level.index <= index) s];
}

/// Version of the rating rules; stored with every puzzle (Master-Prompt 6.1).
const int raterVersion = 1;
