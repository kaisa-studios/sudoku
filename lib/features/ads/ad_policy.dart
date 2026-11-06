/// When an interstitial may be shown (Master-Prompt 10.2), as pure logic.
///
/// Only at one moment: the player tapped "Neues Sudoku" (or "Nächstes Rätsel"
/// for the daily puzzles, D7) in the result view of a game that is finally
/// over. All of these must hold at the same time:
///
/// * the old game is really over (won, or ended after three mistakes) – a
///   voluntary discard never leads to an ad
/// * not the first finished game after installing and not the first such
///   transition in this app session (= process start)
/// * every 2nd counted transition; a transition skipped for lack of an ad is
///   not made up later
/// * at least 180 s since the end of the last full-screen ad (also rewarded)
/// * at most 3 interstitials in a rolling hour
/// * no rewarded video was opened for that game
/// * the device clock did not run backwards (then: no ad, to be safe)
///
/// The caller additionally checks: ad already loaded, app in the foreground,
/// no other overlay, ads allowed (consent, not ad-free).
library;

class AdPolicyConfig {
  const AdPolicyConfig({
    this.everyNthTransition = 2,
    this.minFullscreenInterval = const Duration(seconds: 180),
    this.maxPerRollingHour = 3,
  });

  final int everyNthTransition;
  final Duration minFullscreenInterval;
  final int maxPerRollingHour;
}

/// What is known about the finished game at the transition.
class TransitionFacts {
  const TransitionFacts({
    required this.gameFinal,
    required this.rewardedOpened,
    required this.firstFinishedGame,
    required this.firstTransitionThisSession,
  });

  /// Won, or finally ended after three mistakes (not discarded early).
  final bool gameFinal;
  final bool rewardedOpened;

  /// The game was the first one ever finished on this installation.
  final bool firstFinishedGame;
  final bool firstTransitionThisSession;
}

enum InterstitialVerdict {
  show,
  notFinal,
  exempt,
  notThisTurn,
  rewardedInGame,
  clockRewound,
  tooSoon,
  hourlyCap,
}

class InterstitialDecision {
  const InterstitialDecision(this.verdict, this.countedAfter);

  final InterstitialVerdict verdict;

  /// The new value of the persisted transition counter.
  final int countedAfter;

  bool get show => verdict == InterstitialVerdict.show;
}

/// [countedBefore]: counted (non-exempt) transitions so far.
/// [sinceLastFullscreen]: time since the last full-screen ad ended, null if never.
/// [shownInLastHour]: interstitials actually shown during the last 60 minutes.
InterstitialDecision decideInterstitial({
  required TransitionFacts facts,
  required int countedBefore,
  required Duration? sinceLastFullscreen,
  required int shownInLastHour,
  required bool clockRewound,
  AdPolicyConfig config = const AdPolicyConfig(),
}) {
  if (!facts.gameFinal) return InterstitialDecision(InterstitialVerdict.notFinal, countedBefore);
  if (facts.firstFinishedGame || facts.firstTransitionThisSession) {
    return InterstitialDecision(InterstitialVerdict.exempt, countedBefore);
  }
  final counted = countedBefore + 1;
  if (counted % config.everyNthTransition != 0) return InterstitialDecision(InterstitialVerdict.notThisTurn, counted);
  if (facts.rewardedOpened) return InterstitialDecision(InterstitialVerdict.rewardedInGame, counted);
  if (clockRewound) return InterstitialDecision(InterstitialVerdict.clockRewound, counted);
  final since = sinceLastFullscreen;
  if (since != null && since < config.minFullscreenInterval) {
    return InterstitialDecision(InterstitialVerdict.tooSoon, counted);
  }
  if (shownInLastHour >= config.maxPerRollingHour) return InterstitialDecision(InterstitialVerdict.hourlyCap, counted);
  return InterstitialDecision(InterstitialVerdict.show, counted);
}
