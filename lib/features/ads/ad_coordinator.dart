// private fields from named parameters, as in the Mandala app
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/config.dart';
import '../../data/game_repository.dart';
import '../../domain/game/game.dart';
import 'ad_policy.dart';
import 'ads_backend.dart';

/// The ad-free status as the ad code needs it (implemented by the purchases).
abstract class AdFreeSource implements Listenable {
  /// False until the locally stored purchases are loaded: no ad before that.
  bool get adFreeKnown;
  bool get adFree;

  /// A purchase or restore is being checked: no ads meanwhile, to be safe (10.1).
  bool get suppressAds;
}

enum RewardedOutcome {
  /// The SDK confirmed the reward; the second chance was granted.
  earned,

  /// The video was closed early: the chance stays unused, the game stays locked.
  closedWithoutReward,

  /// Nothing could be loaded or shown (no fill, offline, timeout, not allowed).
  unavailable,
}

/// The one place that decides about ads (Master-Prompt 10.1). Consent, SDK
/// start, interstitials at transitions and the rewarded second chance. No
/// widget loads or shows an ad by itself. Every load and every show checks
/// again: consent allows ads, not ad-free, no purchase check running, app in
/// the foreground, no other full-screen ad.
class AdCoordinator extends ChangeNotifier {
  AdCoordinator({
    required AdsBackend backend,
    required GameRepository store,
    required AdFreeSource purchases,
    DateTime Function()? clock,
    Duration Function()? monotonic,
    this.config = const AdPolicyConfig(),
    this.rewardedLoadTimeout = const Duration(seconds: 10),
    this.lateRewardGrace = const Duration(milliseconds: 800),
    this.openTimeout = const Duration(seconds: 8),
    this.resumeGrace = const Duration(seconds: 3),
    bool? enabled,
  })  : _backend = backend,
        _store = store,
        _purchases = purchases,
        _clock = clock ?? DateTime.now,
        _mono = monotonic ?? (Stopwatch()..start()).elapsedFunction,
        _enabled = enabled ?? AppConfig.adsEnabled;

  final AdsBackend _backend;
  final GameRepository _store;
  final AdFreeSource _purchases;
  final DateTime Function() _clock;
  final Duration Function() _mono;
  final bool _enabled;
  final AdPolicyConfig config;
  final Duration rewardedLoadTimeout;

  /// An ad that was asked to show but never appeared counts as "could not be shown"
  /// after this time (seen on an emulator: no SDK callback at all).
  final Duration openTimeout;

  /// The app is visible again after an opened ad, but the SDK did not report the
  /// close: after this grace time the ad counts as closed. Never closes a running ad.
  final Duration resumeGrace;
  VoidCallback? _onResumedWhileFullscreen;

  /// How long to wait after closing a video for a reward callback that comes late.
  final Duration lateRewardGrace;

  bool consentChecked = false;
  bool canRequestAds = false;
  bool privacyOptionsRequired = false;
  bool initialized = false;

  /// A full-screen ad is on screen (mutual exclusion, 10.1).
  bool get fullscreenActive => _fullscreenActive;
  bool _fullscreenActive = false;

  bool _started = false;
  Future<void>? _consentFlow;
  Future<void>? _ready;
  bool _foreground = true;
  AppLifecycleListener? _lifecycle;

  /// Increased whenever loaded ads become invalid (ad-free, consent withdrawn):
  /// results of loads started before are thrown away.
  int _generation = 0;
  LoadedInterstitial? _interstitial;
  Duration? _interstitialLoadedAt;
  bool _loadingInterstitial = false;

  // policy state; persisted so a restart causes no burst of ads (10.2)
  bool _sessionTransitionDone = false;
  int _finishedGames = 0;
  int _counted = 0;
  DateTime? _lastFullscreenEndWall;
  Duration? _lastFullscreenEndMono;
  List<DateTime> _shownTimes = [];

  static const _kFinished = 'ads.finishedGames';
  static const _kCounted = 'ads.countedTransitions';
  static const _kLastEnd = 'ads.lastFullscreenEnd';
  static const _kShown = 'ads.interstitialTimes';

  bool get mayUseAds =>
      _enabled &&
      initialized &&
      canRequestAds &&
      _purchases.adFreeKnown &&
      !_purchases.adFree &&
      !_purchases.suppressAds;

  /// Called once at app start, after the purchases started loading.
  Future<void> start() {
    if (_started) return _ready ?? Future.value();
    _started = true;
    _lifecycle = AppLifecycleListener(onStateChange: (s) {
      _foreground = s == AppLifecycleState.resumed;
      if (_foreground) _onResumedWhileFullscreen?.call();
    });
    _purchases.addListener(_onPurchases);
    _ready = _loadPersisted();
    _onPurchases();
    return _ready!;
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchases);
    _lifecycle?.dispose();
    _discardLoaded();
    super.dispose();
  }

  // ------------------------------------------------------- consent & SDK --

  void _onPurchases() {
    if (!_purchases.adFreeKnown) return; // nothing ad-related before the status is known
    if (_purchases.adFree || _purchases.suppressAds) _discardLoaded();
    if (!_enabled) return;
    if (_purchases.adFree) {
      // paying users are not sent through the consent form again; existing
      // privacy choices stay reachable
      if (!consentChecked) {
        unawaited(_backend.currentConsent().then((c) {
          privacyOptionsRequired = c.privacyOptionsRequired;
          notifyListeners();
        }));
      }
      return;
    }
    _consentFlow ??= _runConsent(); // one flow only, even with concurrent callbacks
  }

  Future<void> _runConsent() async {
    final consent = await _backend.gatherConsent();
    consentChecked = true;
    canRequestAds = consent.canRequestAds;
    privacyOptionsRequired = consent.privacyOptionsRequired;
    notifyListeners();
    await _initializeIfAllowed();
  }

  Future<void> _initializeIfAllowed() async {
    if (!canRequestAds || initialized || _purchases.adFree) return;
    try {
      await _backend.initialize();
      initialized = true;
      notifyListeners();
    } on Object {
      // no ads this session; the game is never affected
    }
  }

  /// Settings entry "Datenschutzauswahl".
  Future<void> showPrivacyOptions() async {
    final consent = await _backend.showPrivacyOptions();
    canRequestAds = consent.canRequestAds;
    privacyOptionsRequired = consent.privacyOptionsRequired;
    if (!canRequestAds) _discardLoaded();
    notifyListeners();
    await _initializeIfAllowed();
  }

  void _discardLoaded() {
    _generation++;
    _interstitial?.dispose();
    _interstitial = null;
  }

  // ------------------------------------------------------- interstitials --

  Future<void> _loadPersisted() async {
    try {
      _finishedGames = int.tryParse(await _store.setting(_kFinished) ?? '') ?? 0;
      _counted = int.tryParse(await _store.setting(_kCounted) ?? '') ?? 0;
      final last = int.tryParse(await _store.setting(_kLastEnd) ?? '');
      _lastFullscreenEndWall = last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
      _shownTimes = [
        for (final t in (await _store.setting(_kShown) ?? '').split(','))
          if (int.tryParse(t) case final ms?) DateTime.fromMillisecondsSinceEpoch(ms),
      ];
    } on Object {
      // conservative defaults: counts as a fresh install (first game stays ad-free)
    }
  }

  /// A game screen opened: prepare an interstitial in the background. It can
  /// only ever be shown at the next transition, never over a running game.
  void prepareInterstitial() {
    if (!mayUseAds || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    final generation = _generation;
    _backend.loadInterstitial().then((ad) {
      _loadingInterstitial = false;
      if (ad == null) return;
      if (generation != _generation || !mayUseAds) {
        ad.dispose();
        return;
      }
      _interstitial = ad;
      _interstitialLoadedAt = _mono();
    }, onError: (Object _) {
      _loadingInterstitial = false;
    });
  }

  /// A game reached its end (won or ended after three mistakes).
  Future<void> recordFinishedGame() async {
    await _ready;
    _finishedGames++;
    await _persist(_kFinished, '$_finishedGames');
  }

  /// The player tapped "Neues Sudoku" / "Nächstes Rätsel" in the result view.
  /// Shows an interstitial only if every rule allows it and one is ready;
  /// completes when the player may continue (ad closed, or at once).
  Future<bool> onNewSudoku(Game finished) async {
    await _ready;
    final now = _clock();
    final gameFinal =
        finished.phase == GamePhase.completed || (finished.phase == GamePhase.abandoned && finished.failed);
    final facts = TransitionFacts(
      gameFinal: gameFinal,
      rewardedOpened: finished.rewardedAdOpened,
      firstFinishedGame: _finishedGames <= 1,
      firstTransitionThisSession: !_sessionTransitionDone,
    );
    if (gameFinal) _sessionTransitionDone = true;
    final rewound = (_lastFullscreenEndWall?.isAfter(now) ?? false) || _shownTimes.any((t) => t.isAfter(now));
    final lastMono = _lastFullscreenEndMono;
    final lastWall = _lastFullscreenEndWall;
    final since = lastMono != null ? _mono() - lastMono : (lastWall == null ? null : now.difference(lastWall));
    final decision = decideInterstitial(
      facts: facts,
      countedBefore: _counted,
      sinceLastFullscreen: since,
      shownInLastHour: _shownTimes.where((t) => now.difference(t) < const Duration(hours: 1)).length,
      clockRewound: rewound,
      config: config,
    );
    if (decision.countedAfter != _counted) {
      _counted = decision.countedAfter;
      await _persist(_kCounted, '$_counted');
    }
    if (!decision.show) return false;

    final ad = _interstitial;
    final loadedAt = _interstitialLoadedAt;
    if (ad == null || !mayUseAds || !_foreground || _fullscreenActive) return false;
    _interstitial = null;
    if (loadedAt != null && _mono() - loadedAt > const Duration(minutes: 55)) {
      ad.dispose(); // expired; not made up later
      return false;
    }
    _setFullscreen(true);
    final shown = await _guardedShow((opened) => ad.show(onOpened: opened));
    _setFullscreen(false);
    if (shown) {
      _shownTimes = [..._shownTimes.where((t) => _clock().difference(t) < const Duration(hours: 1)), _clock()];
      await _persist(_kShown, _shownTimes.map((t) => t.millisecondsSinceEpoch).join(','));
      await _fullscreenEnded();
    }
    return shown;
  }

  // ------------------------------------------------------------ rewarded --

  /// Loads and shows the voluntary video for the second chance (10.3).
  /// [onReward] runs only from the SDK's reward callback and must be
  /// idempotent; it may run after this future completed (late callback).
  Future<RewardedOutcome> showRewarded({required Future<void> Function() onReward, VoidCallback? onOpened}) async {
    if (!mayUseAds || _fullscreenActive || !_foreground) return RewardedOutcome.unavailable;
    final generation = _generation;
    final load = _backend.loadRewarded();
    LoadedRewarded? ad;
    try {
      ad = await load.timeout(rewardedLoadTimeout);
    } on TimeoutException {
      // the attempt is over for the user; a late result is thrown away, never shown
      unawaited(load.then<void>((stale) => stale?.dispose(), onError: (Object _) {}));
      return RewardedOutcome.unavailable;
    } on Object {
      return RewardedOutcome.unavailable;
    }
    final loaded = ad;
    if (loaded == null) return RewardedOutcome.unavailable;
    if (generation != _generation || !mayUseAds || !_foreground || _fullscreenActive) {
      loaded.dispose();
      return RewardedOutcome.unavailable;
    }

    var earned = false;
    Future<void>? granting;
    _setFullscreen(true);
    final shown = await _guardedShow(
      (opened) => loaded.show(
        onEarned: () {
          if (earned) return; // duplicate callback
          earned = true;
          granting = onReward();
        },
        onOpened: opened,
      ),
      onOpened: onOpened,
    );
    _setFullscreen(false);
    if (shown) await _fullscreenEnded();
    if (shown && !earned) await Future<void>.delayed(lateRewardGrace);
    await granting;
    if (earned) return RewardedOutcome.earned;
    return shown ? RewardedOutcome.closedWithoutReward : RewardedOutcome.unavailable;
  }

  // -------------------------------------------------------------- helpers --

  /// Shows a full-screen ad and completes exactly once, even if the SDK stays
  /// silent: never opened within [openTimeout] → false; opened and the app is
  /// in the foreground again for [resumeGrace] without a close callback → true.
  Future<bool> _guardedShow(Future<bool> Function(VoidCallback opened) show, {VoidCallback? onOpened}) {
    final done = Completer<bool>();
    var opened = false;
    Timer? openTimer;
    Timer? resumeTimer;
    void finish(bool shown) {
      if (done.isCompleted) return;
      openTimer?.cancel();
      resumeTimer?.cancel();
      _onResumedWhileFullscreen = null;
      done.complete(shown);
    }

    _onResumedWhileFullscreen = () {
      if (!opened) return;
      resumeTimer?.cancel();
      resumeTimer = Timer(resumeGrace, () => finish(true));
    };
    openTimer = Timer(openTimeout, () {
      if (!opened) finish(false);
    });
    show(() {
      opened = true;
      openTimer?.cancel();
      onOpened?.call();
    }).then(finish, onError: (Object _) => finish(false));
    return done.future;
  }

  void _setFullscreen(bool on) {
    _fullscreenActive = on;
    notifyListeners();
  }

  Future<void> _fullscreenEnded() async {
    _lastFullscreenEndMono = _mono();
    _lastFullscreenEndWall = _clock();
    await _persist(_kLastEnd, '${_lastFullscreenEndWall!.millisecondsSinceEpoch}');
  }

  Future<void> _persist(String key, String value) async {
    try {
      await _store.setSetting(key, value);
    } on Object {
      // best effort; the in-memory values still apply in this session
    }
  }
}

extension on Stopwatch {
  Duration Function() get elapsedFunction => () => elapsed;
}
