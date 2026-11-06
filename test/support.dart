import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sudoku/app/services.dart';
import 'package:sudoku/data/app_database.dart';
import 'package:sudoku/data/entitlement_repository.dart';
import 'package:sudoku/data/game_repository.dart';
import 'package:sudoku/features/ads/ad_coordinator.dart';
import 'package:sudoku/features/ads/ads_backend.dart';
import 'package:sudoku/features/purchases/purchase_controller.dart';
import 'package:sudoku/features/purchases/store.dart';
import 'package:sudoku/features/purchases/verifier.dart';
import 'package:sudoku/data/puzzle_content.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/generator.dart';
import 'package:sudoku/domain/sudoku/grid.dart';

const examplePuzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const exampleSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

AppDatabase memoryDb() =>
    AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

GeneratedPuzzle examplePuzzleOf(Difficulty d, {String puzzle = examplePuzzle}) => GeneratedPuzzle(
      puzzle: gridFromString(puzzle),
      solution: gridFromString(exampleSolution),
      difficulty: d,
      seed: 0,
      score: 0,
      steps: 0,
      strategyCounts: const {},
    );

/// Small content set: the example puzzle everywhere, daily range from 2026-11-01.
PuzzleContent testContent() {
  const e = '{"p":"$examplePuzzle","s":"$exampleSolution","seed":1,"score":1}';
  final pool = '{"levels":{"easy":[$e],"medium":[$e],"hard":[$e],"expert":[$e]}}';
  final days = List.filled(60, '[$e,$e,$e]').join(',');
  final daily = '{"start":"2026-11-01","levels":["easy","medium","hard"],"days":[$days]}';
  return PuzzleContent.parse(pool, daily);
}

/// German by default so the checks can use the German texts; pass null to follow the device.
/// Ads: none unless [adsBackend] is given; store: the demo store without delays.
Services testServices({
  DateTime? now,
  DateTime Function()? clock,
  Duration Function()? monotonic,
  Duration rewardedLoadTimeout = const Duration(seconds: 10),
  AppDatabase? db,
  String? language = 'de',
  AdsBackend adsBackend = const NoAdsBackend(),
  StoreGateway? store,
  EntitlementVerifier verifier = const DemoVerifier(),
}) {
  final DateTime Function() time = clock ?? (now == null ? DateTime.now : () => now);
  final database = db ?? memoryDb();
  final games = GameRepository(database, clock: time);
  final purchases = PurchaseController(
    store: store ?? DemoStoreGateway(delay: Duration.zero),
    verifier: verifier,
    entitlements: EntitlementRepository(database, clock: time),
    settings: games,
    restoreSettle: Duration.zero,
  );
  final ads = AdCoordinator(
    backend: adsBackend,
    store: games,
    purchases: purchases,
    clock: time,
    monotonic: monotonic,
    rewardedLoadTimeout: rewardedLoadTimeout,
    lateRewardGrace: Duration.zero,
    enabled: true,
  );
  final services = Services(
    games: games,
    content: testContent(),
    purchases: purchases,
    ads: ads,
    source: (level, avoid) async => examplePuzzleOf(level),
    clock: time,
  );
  services.settings.languageCode = language;
  unawaited(ads.start());
  unawaited(purchases.start());
  return services;
}

// ------------------------------------------------------------------ ad fakes --

enum FakeVideo {
  /// reward callback, then closed
  earnThenClose,

  /// closed first, the reward callback arrives afterwards
  closeThenEarn,

  /// reward callback twice (duplicate delivery)
  earnTwice,

  /// closed early without reward
  closeEarly,

  /// show failed
  failToShow,
}

class FakeInterstitial implements LoadedInterstitial {
  bool shown = false;
  bool disposed = false;
  VoidCallback? whileShowing;

  @override
  Future<bool> show() async {
    shown = true;
    whileShowing?.call();
    return true;
  }

  @override
  void dispose() => disposed = true;
}

class FakeRewarded implements LoadedRewarded {
  FakeRewarded(this.behaviour);

  final FakeVideo behaviour;
  bool disposed = false;
  int shows = 0;

  @override
  Future<bool> show({required VoidCallback onEarned, VoidCallback? onOpened}) async {
    shows++;
    if (behaviour == FakeVideo.failToShow) return false;
    onOpened?.call();
    switch (behaviour) {
      case FakeVideo.earnThenClose:
        onEarned();
      case FakeVideo.earnTwice:
        onEarned();
        onEarned();
      case FakeVideo.closeThenEarn:
        scheduleMicrotask(onEarned);
      default:
        break;
    }
    return true;
  }

  @override
  void dispose() => disposed = true;
}

class FakeAdsBackend implements AdsBackend {
  FakeAdsBackend({this.canRequestAds = true, this.video = FakeVideo.earnThenClose, this.fill = true});

  bool canRequestAds;
  bool privacyOptionsRequired = false;
  FakeVideo video;

  /// false = no fill (nothing to show)
  bool fill;

  /// Completes rewarded loads only when set (for timeout tests).
  Completer<LoadedRewarded?>? holdRewarded;
  int consentRequests = 0;
  int initializations = 0;
  int interstitialLoads = 0;
  int rewardedLoads = 0;
  final interstitials = <FakeInterstitial>[];
  final rewardeds = <FakeRewarded>[];

  ConsentResult get _consent =>
      ConsentResult(canRequestAds: canRequestAds, privacyOptionsRequired: privacyOptionsRequired);

  @override
  Future<ConsentResult> gatherConsent() async {
    consentRequests++;
    return _consent;
  }

  @override
  Future<ConsentResult> currentConsent() async => _consent;

  @override
  Future<ConsentResult> showPrivacyOptions() async => _consent;

  @override
  Future<void> initialize() async => initializations++;

  @override
  Future<LoadedInterstitial?> loadInterstitial() async {
    interstitialLoads++;
    if (!fill) return null;
    final ad = FakeInterstitial();
    interstitials.add(ad);
    return ad;
  }

  @override
  Future<LoadedRewarded?> loadRewarded() async {
    rewardedLoads++;
    final hold = holdRewarded;
    if (hold != null) return hold.future;
    if (!fill) return null;
    final ad = FakeRewarded(video);
    rewardeds.add(ad);
    return ad;
  }
}

class FakeVerifier implements EntitlementVerifier {
  FakeVerifier(this.outcome, {this.isReady = true});

  VerificationOutcome outcome;
  bool isReady;
  int calls = 0;

  @override
  Future<bool> ready() async => isReady;

  @override
  Future<VerificationResult> verify({required String store, required StorePurchase purchase}) async {
    calls++;
    return VerificationResult(outcome);
  }
}
