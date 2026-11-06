import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/app/services.dart';
import 'package:sudoku/domain/game/game.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/grid.dart';
import 'package:sudoku/features/ads/ad_coordinator.dart';
import 'package:sudoku/features/purchases/purchase_controller.dart';
import 'package:sudoku/features/purchases/store.dart';

import '../support.dart';

Game _game() => Game(
      puzzle: gridFromString(examplePuzzle),
      solution: gridFromString(exampleSolution),
      difficulty: Difficulty.easy,
    );

Game _won() => _game()..phase = GamePhase.completed;

/// Lets the start-up chain (entitlement → consent → SDK) finish.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late FakeAdsBackend backend;
  late Services services;

  Future<void> setUpServices({FakeAdsBackend? ads, Duration timeout = const Duration(seconds: 10)}) async {
    now = DateTime(2026, 11, 9, 10);
    backend = ads ?? FakeAdsBackend();
    services = testServices(
      adsBackend: backend,
      clock: () => now,
      monotonic: () => now.difference(DateTime(2026)),
      rewardedLoadTimeout: timeout,
    );
    await _settle();
  }

  /// One finished game and the tap on "Neues Sudoku".
  Future<bool> finishAndContinue({Game? game}) async {
    services.ads.prepareInterstitial();
    await _settle();
    await services.ads.recordFinishedGame();
    return services.ads.onNewSudoku(game ?? _won());
  }

  test('consent once per start, SDK only when ads may be requested', () async {
    await setUpServices();
    expect(backend.consentRequests, 1);
    expect(backend.initializations, 1);
    expect(services.ads.mayUseAds, isTrue);

    await setUpServices(ads: FakeAdsBackend(canRequestAds: false));
    expect(backend.initializations, 0);
    expect(services.ads.mayUseAds, isFalse);
    expect(await finishAndContinue(), isFalse);
    expect(backend.interstitialLoads, 0, reason: 'nothing is requested without consent');
  });

  test('first game and first transition per session stay ad-free, then every second', () async {
    await setUpServices();
    expect(await finishAndContinue(), isFalse, reason: 'first finished game after install');
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(), isFalse, reason: 'counted 1 – not this time');
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(), isTrue, reason: 'counted 2 – shown');
    expect(backend.interstitials.where((a) => a.shown), hasLength(1));
    now = now.add(const Duration(minutes: 1));
    expect(await finishAndContinue(), isFalse, reason: 'counted 3');
    now = now.add(const Duration(minutes: 1));
    expect(await finishAndContinue(), isFalse, reason: 'counted 4, but within 180 s of the last ad');
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(), isFalse, reason: 'counted 5 – a skipped one is not made up');
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(), isTrue, reason: 'counted 6');
  });

  test('a discarded game (not finally over) never shows an ad and is not counted', () async {
    await setUpServices();
    await finishAndContinue();
    now = now.add(const Duration(minutes: 10));
    final discarded = _game()..abandon();
    expect(await services.ads.onNewSudoku(discarded), isFalse);
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(), isFalse, reason: 'still the first counted transition');
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(), isTrue);
  });

  test('no interstitial after a game with an opened rewarded video', () async {
    await setUpServices();
    await finishAndContinue();
    now = now.add(const Duration(minutes: 10));
    await finishAndContinue();
    now = now.add(const Duration(minutes: 10));
    expect(await finishAndContinue(game: _won()..rewardedAdOpened = true), isFalse);
  });

  test('a restart keeps the counters: no burst of ads', () async {
    await setUpServices();
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(minutes: 10));
      await finishAndContinue();
    }
    // new process: same database, fresh coordinator
    final again = AdCoordinator(
      backend: backend,
      store: services.games,
      purchases: services.purchases,
      clock: () => now,
      lateRewardGrace: Duration.zero,
      enabled: true,
    );
    unawaited(again.start());
    await _settle();
    now = now.add(const Duration(minutes: 1));
    again.prepareInterstitial();
    await _settle();
    expect(await again.onNewSudoku(_won()), isFalse, reason: 'first transition of the new session');
    expect(await again.onNewSudoku(_won()), isFalse, reason: 'counted 3');
    expect(await again.onNewSudoku(_won()), isFalse, reason: 'counted 4, but 180 s since the last ad (stored)');
  });

  test('rewarded: reward and close in any order grant exactly one second chance', () async {
    for (final video in [FakeVideo.earnThenClose, FakeVideo.closeThenEarn, FakeVideo.earnTwice]) {
      await setUpServices(ads: FakeAdsBackend(video: video));
      var grants = 0;
      final outcome = await services.ads.showRewarded(onReward: () async => grants++);
      expect(outcome, RewardedOutcome.earned, reason: '$video');
      expect(grants, 1, reason: '$video');
    }
  });

  test('rewarded: closed early, no fill, show error and load timeout', () async {
    await setUpServices(ads: FakeAdsBackend(video: FakeVideo.closeEarly));
    var grants = 0;
    expect(await services.ads.showRewarded(onReward: () async => grants++), RewardedOutcome.closedWithoutReward);

    await setUpServices(ads: FakeAdsBackend(fill: false));
    expect(await services.ads.showRewarded(onReward: () async => grants++), RewardedOutcome.unavailable);

    await setUpServices(ads: FakeAdsBackend(video: FakeVideo.failToShow));
    expect(await services.ads.showRewarded(onReward: () async => grants++), RewardedOutcome.unavailable);
    expect(grants, 0);
  });

  test('rewarded: a load slower than the timeout ends the attempt; the late ad is thrown away', () async {
    await setUpServices(ads: FakeAdsBackend()..holdRewarded = Completer(), timeout: const Duration(milliseconds: 50));
    var grants = 0;
    expect(await services.ads.showRewarded(onReward: () async => grants++), RewardedOutcome.unavailable);
    final lateAd = FakeRewarded(FakeVideo.earnThenClose);
    backend.holdRewarded!.complete(lateAd);
    await _settle();
    expect(lateAd.disposed, isTrue);
    expect(lateAd.shows, 0);
    expect(grants, 0);
  });

  test('rewarded: an ad that never appears ends the attempt instead of hanging', () async {
    backend = FakeAdsBackend(video: FakeVideo.silent);
    now = DateTime(2026, 11, 9, 10);
    services = testServices(adsBackend: backend, clock: () => now, openTimeout: const Duration(milliseconds: 50));
    await _settle();
    var grants = 0;
    expect(await services.ads.showRewarded(onReward: () async => grants++), RewardedOutcome.unavailable);
    expect(services.ads.fullscreenActive, isFalse);
    expect(grants, 0);
  });

  test('buying "Werbung entfernen" discards loaded ads and stops all ads', () async {
    await setUpServices();
    services.ads.prepareInterstitial();
    await _settle();
    expect(backend.interstitials, hasLength(1));
    await services.purchases.loadProducts();
    await services.purchases.buy();
    await _settle();
    expect(services.purchases.state, RemoveAdsState.owned);
    expect(backend.interstitials.single.disposed, isTrue);
    expect(services.ads.mayUseAds, isFalse);
    expect(await services.ads.showRewarded(onReward: () async {}), RewardedOutcome.unavailable);
    expect(backend.rewardedLoads, 0);
  });

  test('ad-free players are not sent through the consent form again', () async {
    final db = memoryDb();
    final first = testServices(db: db, store: DemoStoreGateway(delay: Duration.zero));
    await _settle();
    await first.purchases.loadProducts();
    await first.purchases.buy();
    await _settle();
    final b = FakeAdsBackend();
    testServices(db: db, adsBackend: b);
    await _settle();
    expect(b.consentRequests, 0);
    expect(b.initializations, 0);
  });
}
