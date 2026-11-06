#!/usr/bin/env bash
# Builds the public store version and refuses to do so if a production value is
# missing or a test value is still set (Master-Prompt 10.4):
# sample ad units, demo store, debug consent geography, ads switched off.
#
#   VERIFIER_URL=https://… ADMOB_APP_ID_ANDROID=ca-app-pub-…~… ADMOB_APP_ID_IOS=ca-app-pub-…~… \
#   ADMOB_INTERSTITIAL_ANDROID=… ADMOB_INTERSTITIAL_IOS=… ADMOB_REWARDED_ANDROID=… ADMOB_REWARDED_IOS=… \
#   BUILD_NAME=1.0.0 BUILD_NUMBER=1 tool/build_release.sh android|ios|check
#
# None of these values is secret. Signing keys are NOT handled here.
set -euo pipefail

target=${1:-check}
sample='ca-app-pub-3940256099942544'
fail=0
need() {
  local name=$1 value=${!1:-}
  if [ -z "$value" ]; then echo "FEHLT: $name"; fail=1; return; fi
  if [[ "$value" == *"$sample"* ]]; then echo "TEST-ID statt echter ID: $name"; fail=1; fi
}
unit() { # ad unit ids contain "/", app ids "~" – never mix them up
  need "$1"
  [[ "${!1:-}" == ca-app-pub-*/* ]] || { echo "Keine Anzeigenblock-ID (ca-app-pub-…/…): $1"; fail=1; }
}
app() {
  need "$1"
  [[ "${!1:-}" == ca-app-pub-*~* ]] || { echo "Keine App-ID (ca-app-pub-…~…): $1"; fail=1; }
}

need VERIFIER_URL
[[ "${VERIFIER_URL:-}" == https://* ]] || { echo "VERIFIER_URL muss mit https:// beginnen"; fail=1; }
for v in ADMOB_INTERSTITIAL_ANDROID ADMOB_INTERSTITIAL_IOS ADMOB_REWARDED_ANDROID ADMOB_REWARDED_IOS; do unit "$v"; done
case "$target" in
  android) app ADMOB_APP_ID_ANDROID ;;
  ios) app ADMOB_APP_ID_IOS ;;
  check) app ADMOB_APP_ID_ANDROID; app ADMOB_APP_ID_IOS ;;
  *) echo "Ziel: android | ios | check"; exit 2 ;;
esac
need BUILD_NAME
need BUILD_NUMBER
for v in PRIVACY_URL SUPPORT_URL; do
  need "$v"
  [[ "${!v:-}" == https://* ]] || { echo "$v muss mit https:// beginnen"; fail=1; }
done
[ "${STORE_MODE:-real}" = real ] || { echo "STORE_MODE muss real sein (kein Demo-Store)"; fail=1; }
[ -z "${CONSENT_DEBUG_EEA:-}" ] || { echo "CONSENT_DEBUG_EEA darf im Produktionsbuild nicht gesetzt sein"; fail=1; }
[ "${ADS_ENABLED:-true}" = true ] || { echo "ADS_ENABLED=false ist nur für Sonderbuilds"; fail=1; }
grep -q "defaultValue: 'real'" lib/app/config.dart || { echo "config.dart: Standard muss der echte Store sein"; fail=1; }
if [ "$fail" != 0 ]; then echo "Release-Prüfung NICHT bestanden – nichts gebaut."; exit 1; fi
echo "Release-Prüfung bestanden."
[ "$target" = check ] && exit 0

defines=(
  --dart-define=STORE_MODE=real
  --dart-define=VERIFIER_URL="$VERIFIER_URL"
  --dart-define=ADMOB_INTERSTITIAL_ANDROID="$ADMOB_INTERSTITIAL_ANDROID"
  --dart-define=ADMOB_INTERSTITIAL_IOS="$ADMOB_INTERSTITIAL_IOS"
  --dart-define=ADMOB_REWARDED_ANDROID="$ADMOB_REWARDED_ANDROID"
  --dart-define=ADMOB_REWARDED_IOS="$ADMOB_REWARDED_IOS"
  --dart-define=BUILD_NAME="$BUILD_NAME"
  --dart-define=PRIVACY_URL="$PRIVACY_URL"
  --dart-define=SUPPORT_URL="$SUPPORT_URL"
  --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
)

if [ "$target" = android ]; then
  # the AdMob app id goes into the manifest via a Gradle property
  flutter build appbundle --release "${defines[@]}" -PADMOB_APP_ID="$ADMOB_APP_ID_ANDROID"
else
  plist=ios/Runner/Info.plist
  /usr/libexec/PlistBuddy -c "Set :GADApplicationIdentifier $ADMOB_APP_ID_IOS" "$plist"
  flutter build ipa --release "${defines[@]}"
fi
