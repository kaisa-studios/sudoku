import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/config.dart';

class ConsentResult {
  const ConsentResult({required this.canRequestAds, required this.privacyOptionsRequired});

  /// Only true when Google's consent SDK (UMP) allows ad requests (11.1).
  final bool canRequestAds;

  /// The user must be able to reopen the privacy choices (settings entry).
  final bool privacyOptionsRequired;

  static const none = ConsentResult(canRequestAds: false, privacyOptionsRequired: false);
}

abstract class LoadedInterstitial {
  /// Shows the ad once. [onOpened] fires when it is on screen. Completes exactly
  /// once when it was closed (true) or could not be shown (false).
  Future<bool> show({VoidCallback? onOpened});
  void dispose();
}

abstract class LoadedRewarded {
  /// Shows the ad once. [onOpened] fires when the ad is on screen, [onEarned]
  /// only from the SDK's reward callback – before or after the returned future
  /// completes (both orders happen). The future completes exactly once when the
  /// ad was closed (true) or could not be shown (false).
  Future<bool> show({required VoidCallback onEarned, VoidCallback? onOpened});
  void dispose();
}

/// Everything the app needs from the ad SDK; replaceable in tests.
abstract class AdsBackend {
  /// Refreshes the consent status (every app start) and shows Google's form if required.
  Future<ConsentResult> gatherConsent();
  Future<ConsentResult> currentConsent();

  /// Reopens the privacy choices form; returns the new status.
  Future<ConsentResult> showPrivacyOptions();
  Future<void> initialize();
  Future<LoadedInterstitial?> loadInterstitial();
  Future<LoadedRewarded?> loadRewarded();
}

/// No ads at all (tests, special builds).
class NoAdsBackend implements AdsBackend {
  const NoAdsBackend();

  @override
  Future<ConsentResult> gatherConsent() async => ConsentResult.none;
  @override
  Future<ConsentResult> currentConsent() async => ConsentResult.none;
  @override
  Future<ConsentResult> showPrivacyOptions() async => ConsentResult.none;
  @override
  Future<void> initialize() async {}
  @override
  Future<LoadedInterstitial?> loadInterstitial() async => null;
  @override
  Future<LoadedRewarded?> loadRewarded() async => null;
}

/// Google Mobile Ads with Google's User Messaging Platform for consent.
class GoogleAdsBackend implements AdsBackend {
  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  String get _interstitialUnit => _ios ? AppConfig.interstitialIos : AppConfig.interstitialAndroid;
  String get _rewardedUnit => _ios ? AppConfig.rewardedIos : AppConfig.rewardedAndroid;

  @override
  Future<ConsentResult> currentConsent() async {
    try {
      final can = await ConsentInformation.instance.canRequestAds();
      final options = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return ConsentResult(
        canRequestAds: can,
        privacyOptionsRequired: options == PrivacyOptionsRequirementStatus.required,
      );
    } on Object {
      return ConsentResult.none;
    }
  }

  @override
  Future<ConsentResult> gatherConsent() {
    final done = Completer<ConsentResult>();
    final params = ConsentRequestParameters(
      consentDebugSettings: AppConfig.consentDebugEea
          ? ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea)
          : null,
    );
    void finish() {
      if (!done.isCompleted) done.complete(currentConsent());
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () => ConsentForm.loadAndShowConsentFormIfRequired((_) => finish()),
        // no update possible (e.g. offline): only what the SDK itself reports applies
        (_) => finish(),
      );
    } on Object {
      finish();
    }
    return done.future;
  }

  @override
  Future<ConsentResult> showPrivacyOptions() async {
    final done = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    } on Object {
      // fall through: report the current status
    }
    return currentConsent();
  }

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<LoadedInterstitial?> loadInterstitial() {
    final done = Completer<LoadedInterstitial?>();
    InterstitialAd.load(
      adUnitId: _interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => done.complete(_GoogleInterstitial(ad)),
        onAdFailedToLoad: (_) => done.complete(null),
      ),
    ).catchError((Object _) {
      if (!done.isCompleted) done.complete(null);
    });
    return done.future;
  }

  @override
  Future<LoadedRewarded?> loadRewarded() {
    final done = Completer<LoadedRewarded?>();
    RewardedAd.load(
      adUnitId: _rewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => done.complete(_GoogleRewarded(ad)),
        onAdFailedToLoad: (_) => done.complete(null),
      ),
    ).catchError((Object _) {
      if (!done.isCompleted) done.complete(null);
    });
    return done.future;
  }
}

class _GoogleInterstitial implements LoadedInterstitial {
  _GoogleInterstitial(this._ad);

  final InterstitialAd _ad;
  var _used = false;

  @override
  Future<bool> show({VoidCallback? onOpened}) {
    final done = Completer<bool>();
    if (_used) return Future.value(false);
    _used = true;
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onOpened?.call(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _ad.show().catchError((Object _) {
      if (!done.isCompleted) done.complete(false);
    });
    return done.future;
  }

  @override
  void dispose() {
    if (!_used) _ad.dispose();
  }
}

class _GoogleRewarded implements LoadedRewarded {
  _GoogleRewarded(this._ad);

  final RewardedAd _ad;
  var _used = false;

  @override
  Future<bool> show({required VoidCallback onEarned, VoidCallback? onOpened}) {
    final done = Completer<bool>();
    if (_used) return Future.value(false);
    _used = true;
    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onOpened?.call(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _ad.show(onUserEarnedReward: (_, _) => onEarned()).catchError((Object _) {
      if (!done.isCompleted) done.complete(false);
    });
    return done.future;
  }

  @override
  void dispose() {
    if (!_used) _ad.dispose();
  }
}
