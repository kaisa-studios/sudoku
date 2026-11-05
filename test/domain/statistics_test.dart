import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/game/game.dart';
import 'package:sudoku/domain/stats/statistics.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';

GameSummary _g({
  required GamePhase phase,
  required GameOutcome outcome,
  required int mistakes,
  int hints = 0,
  int seconds = 0,
  bool continued = false,
  ContinueSource source = ContinueSource.none,
  bool failed = false,
  bool daily = false,
}) =>
    GameSummary(
      difficulty: Difficulty.medium,
      daily: daily,
      phase: phase,
      outcome: outcome,
      mistakes: mistakes,
      hintCount: hints,
      activeMs: seconds * 1000,
      continueUsed: continued,
      continueSource: source,
      failed: failed,
    );

void main() {
  // Master-Prompt 12.3 reference case
  final a = _g(phase: GamePhase.completed, outcome: GameOutcome.won, mistakes: 1, seconds: 120);
  final b = _g(
      phase: GamePhase.completed,
      outcome: GameOutcome.failed,
      mistakes: 4,
      seconds: 240,
      continued: true,
      source: ContinueSource.rewarded,
      failed: true);
  final c = _g(phase: GamePhase.abandoned, outcome: GameOutcome.abandoned, mistakes: 2, seconds: 30);
  final d =
      _g(phase: GamePhase.completed, outcome: GameOutcome.won, mistakes: 0, seconds: 90, hints: 1);
  final e = _g(phase: GamePhase.active, outcome: GameOutcome.undecided, mistakes: 1);

  test('reference case A–E', () {
    final s = Stats.of([a, b, c, d, e]);
    expect(s.started, 5);
    expect(s.won, 2);
    expect(s.failed, 1);
    expect(s.abandonedWithoutFail, 1);
    expect(s.undecided, 1);
    expect(s.started, s.won + s.failed + s.abandonedWithoutFail + s.undecided);
    expect(s.bestMs, 120000);
    expect(s.averageMs, 120000);
    expect(s.averageMistakes, 1.75);
    expect(s.averageMistakes!.toStringAsFixed(1), '1.8');
    expect(s.secondChances, 1);
    expect(s.secondChancesByAd, 1);
    expect(s.finishedAfterSecondChance, 1);
  });

  test('E reaching the third mistake counts as failed at once, average mistakes unchanged', () {
    final e3 = _g(
        phase: GamePhase.awaitingContinue, outcome: GameOutcome.failed, mistakes: 3, failed: true);
    final s = Stats.of([a, b, c, d, e3]);
    expect(s.failed, 2);
    expect(s.undecided, 0);
    expect(s.averageMistakes, 1.75);
  });

  test('empty statistics have no times instead of zero', () {
    final s = Stats.of(const []);
    expect(s.isEmpty, isTrue);
    expect(s.bestMs, isNull);
    expect(s.averageMs, isNull);
    expect(s.averageMistakes, isNull);
  });

  test('daily games are reported separately', () {
    final r = StatsReport([a, _g(phase: GamePhase.completed, outcome: GameOutcome.won, mistakes: 0, daily: true)]);
    expect(r.overall.started, 1);
    expect(r.daily.started, 1);
    expect(r.byLevel[Difficulty.medium]!.won, 1);
  });
}
