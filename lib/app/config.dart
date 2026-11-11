/// Build-time configuration (passed with --dart-define, Master-Prompt 10.4).
///
/// Defaults are safe for a store release: real store, no verification service
/// configured (= nothing can be bought or unlocked until it exists), Google's
/// official sample ad units. Test builds for devices and CI pass
/// STORE_MODE=demo. `tool/release_check.sh` refuses a production build that
/// still uses sample ad units, the demo store or the debug consent geography.
library;

enum StoreMode { demo, real }

class AppConfig {
  const AppConfig._();

  /// `demo` simulates the store (clearly labelled in the app, nothing is charged).
  static const storeMode =
      String.fromEnvironment('STORE_MODE', defaultValue: 'real') == 'demo' ? StoreMode.demo : StoreMode.real;

  static bool get isDemoStore => storeMode == StoreMode.demo;

  /// Base URL of the shared Kaisa purchase verification service (DECISIONS D3).
  static const verifierUrl = String.fromEnvironment('VERIFIER_URL');

  /// Ads can be switched off completely for special builds (e.g. store screenshots).
  static const adsEnabled = bool.fromEnvironment('ADS_ENABLED', defaultValue: true);

  /// Shows the EEA consent form in test builds regardless of location.
  static const consentDebugEea = bool.fromEnvironment('CONSENT_DEBUG_EEA');

  /// Public pages on the shared app website (DECISIONS D13); the release build must set them.
  static const privacyUrl =
      String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://kaisa-solutions.at/tidy-sudoku-datenschutz');
  static const supportUrl =
      String.fromEnvironment('SUPPORT_URL', defaultValue: 'https://kaisa-solutions.at/apps');

  // Ad units: Google's official sample IDs until the real AdMob IDs are passed.
  static const interstitialAndroid =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');
  static const interstitialIos =
      String.fromEnvironment('ADMOB_INTERSTITIAL_IOS', defaultValue: 'ca-app-pub-3940256099942544/4411468910');
  static const rewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/5224354917');
  static const rewardedIos =
      String.fromEnvironment('ADMOB_REWARDED_IOS', defaultValue: 'ca-app-pub-3940256099942544/1712485313');

  static bool get usesSampleAds =>
      [interstitialAndroid, interstitialIos, rewardedAndroid, rewardedIos].any((id) => id.startsWith(_sample));

  static const _sample = 'ca-app-pub-3940256099942544/';
}
