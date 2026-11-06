import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/features/ads/ad_policy.dart';

TransitionFacts facts({
  bool gameFinal = true,
  bool rewardedOpened = false,
  bool firstFinishedGame = false,
  bool firstTransitionThisSession = false,
}) =>
    TransitionFacts(
      gameFinal: gameFinal,
      rewardedOpened: rewardedOpened,
      firstFinishedGame: firstFinishedGame,
      firstTransitionThisSession: firstTransitionThisSession,
    );

InterstitialDecision decide(
  TransitionFacts f, {
  int counted = 1,
  Duration? since,
  int lastHour = 0,
  bool rewound = false,
}) =>
    decideInterstitial(
      facts: f,
      countedBefore: counted,
      sinceLastFullscreen: since,
      shownInLastHour: lastHour,
      clockRewound: rewound,
    );

void main() {
  test('shows on every second counted transition when all rules hold', () {
    expect(decide(facts(), counted: 0).verdict, InterstitialVerdict.notThisTurn);
    expect(decide(facts(), counted: 0).countedAfter, 1);
    final d = decide(facts(), counted: 1);
    expect(d.show, isTrue);
    expect(d.countedAfter, 2);
    expect(decide(facts(), counted: 2).show, isFalse);
    expect(decide(facts(), counted: 3).show, isTrue);
  });

  test('a voluntary discard never counts and never shows', () {
    final d = decide(facts(gameFinal: false), counted: 1);
    expect(d.verdict, InterstitialVerdict.notFinal);
    expect(d.countedAfter, 1);
  });

  test('first finished game after install and first transition per session are exempt and not counted', () {
    for (final f in [facts(firstFinishedGame: true), facts(firstTransitionThisSession: true)]) {
      final d = decide(f, counted: 1);
      expect(d.verdict, InterstitialVerdict.exempt);
      expect(d.countedAfter, 1);
    }
  });

  test('no interstitial after a game with an opened rewarded video, even after the cooldown', () {
    final d = decide(facts(rewardedOpened: true), counted: 1, since: const Duration(hours: 2));
    expect(d.verdict, InterstitialVerdict.rewardedInGame);
    expect(d.countedAfter, 2, reason: 'counted, and not made up at the next transition');
    expect(decide(facts(), counted: d.countedAfter).show, isFalse);
  });

  test('at least 180 s since the last full-screen ad', () {
    expect(decide(facts(), since: const Duration(seconds: 179)).verdict, InterstitialVerdict.tooSoon);
    expect(decide(facts(), since: const Duration(seconds: 180)).show, isTrue);
    expect(decide(facts(), since: null).show, isTrue);
  });

  test('at most 3 per rolling hour', () {
    expect(decide(facts(), lastHour: 2).show, isTrue);
    expect(decide(facts(), lastHour: 3).verdict, InterstitialVerdict.hourlyCap);
  });

  test('device clock set backwards: no ad, to be safe', () {
    expect(decide(facts(), rewound: true).verdict, InterstitialVerdict.clockRewound);
  });
}
