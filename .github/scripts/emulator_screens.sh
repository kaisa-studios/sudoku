#!/usr/bin/env bash
# Installs the release APK on the running emulator, operates the app through the
# accessibility tree (uiautomator) like a user would, and stores screenshots.
# Results: it_result.txt (release_app=running|CRASHED, resume_after_restart=yes|no)
set -u
export PATH="$ANDROID_HOME/platform-tools:$PATH"
OUT=${1:-/tmp/emu}
APK=${2:-build/app/outputs/flutter-apk/app-release.apk}
PKG=at.kaisasolutions.sudoku
mkdir -p "$OUT"
log() { echo "[$(date +%T)] $*" | tee -a "$OUT/steps.log" >&2; }
shot() { adb exec-out screencap -p > "$OUT/$1.png" && log "screenshot $1"; }

# prints "x y w h" of the first UI node whose content-desc or text matches (regex)
find_node() {
  local xy="" try
  for try in 1 2 3; do
    rm -f "$OUT/ui.xml"
    adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1
    adb pull /sdcard/ui.xml "$OUT/ui.xml" > /dev/null 2>&1
    [ -s "$OUT/ui.xml" ] || { sleep 1; continue; }
    xy=$(python3 - "$1" "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
pat = re.compile(sys.argv[1])
for n in ET.parse(sys.argv[2]).iter('node'):
    label = (n.get('content-desc') or '') + '|' + (n.get('text') or '')
    if pat.search(label):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
        print((x1 + x2) // 2, (y1 + y2) // 2, x2 - x1, y2 - y1)
        break
PY
)
    [ -n "$xy" ] && break
    sleep 1
  done
  if [ -z "$xy" ]; then log "NOT FOUND: $1"; return 1; fi
  echo "$xy"
}

tap_node() {
  local n
  n=$(find_node "$1") || return 1
  set -- "$1" $n
  adb shell input tap "$2" "$3"
  log "tap '$1' at $2 $3"
}

swipe_up() { adb shell input swipe 540 1800 540 700 300; sleep 1; }

log "install $APK"
adb install -r "$APK" >> "$OUT/steps.log" 2>&1
# German screenshots: per-app language (Android 13+); patterns also accept English
adb shell cmd locale set-app-locales "$PKG" --locales de-DE >> "$OUT/steps.log" 2>&1 || log "per-app locale not available"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity" >> "$OUT/steps.log" 2>&1
sleep 10
shot 01_start
PID=$(adb shell pidof "$PKG" | tr -d '\r')
log "app pid: ${PID:-läuft nicht}"
if [ -n "$PID" ]; then echo "release_app=running" >> "$OUT/it_result.txt"; else echo "release_app=CRASHED" >> "$OUT/it_result.txt"; fi
adb logcat -d -b crash > "$OUT/logcat_crash.txt" 2>&1

# daily sudoku
tap_node '^(Tägliches Sudoku|Daily Sudoku)' && sleep 3 && shot 02_tagesraetsel
tap_node '^(Leicht|Easy), ' && sleep 3
tap_node '^(Zahl|Number) 1' && sleep 1
tap_node '^(Notizen|Notes)' && sleep 1 && tap_node '^(Zahl|Number) 2' && tap_node '^(Zahl|Number) 7' && sleep 1
shot 03_tagesraetsel_spiel
adb shell input keyevent KEYCODE_BACK && sleep 2
adb shell input keyevent KEYCODE_BACK && sleep 2

# regular game: entries, hint, large view
swipe_up
tap_node '^(Spiel starten|Start game)' && sleep 5
shot 04_spiel
tap_node '^(Zahl|Number) 5' && sleep 1 && tap_node '^(Zahl|Number) 3' && sleep 1
tap_node '^(Hinweis|Hint)' && sleep 2
shot 05_spiel_hinweis
tap_node '^(Große Darstellung|Large view)' && sleep 2
tap_node '^(Feld rechts|Cell to the right)' && sleep 1 && tap_node '^(Feld darunter|Cell below)' && sleep 1
shot 06_grosse_darstellung
adb shell input keyevent KEYCODE_BACK && sleep 3

# restart: the game must be continuable with its entries
adb shell am force-stop "$PKG"
sleep 2
adb shell am start -W -n "$PKG/.MainActivity" >> "$OUT/steps.log" 2>&1
sleep 8
shot 07_nach_neustart
if tap_node '^(Spiel fortsetzen|Continue game)'; then
  echo "resume_after_restart=yes" >> "$OUT/it_result.txt"
  sleep 3 && shot 08_fortgesetzt
  adb shell input keyevent KEYCODE_BACK && sleep 3
else
  echo "resume_after_restart=no" >> "$OUT/it_result.txt"
fi

# statistics and settings
swipe_up
tap_node '^(Statistik|Statistics)' && sleep 3 && shot 09_statistik
adb shell input keyevent KEYCODE_BACK && sleep 2
adb shell input swipe 540 700 540 1800 300 && sleep 1
tap_node '^(Einstellungen|Settings)' && sleep 3 && shot 10_einstellungen
# dark mode: switch, look at the game, switch back
tap_node '^(Dunkel|Dark)' && sleep 2
adb shell input keyevent KEYCODE_BACK && sleep 2
tap_node '^(Spiel fortsetzen|Continue game)' && sleep 3 && shot 10b_dunkel_spiel
adb shell input keyevent KEYCODE_BACK && sleep 2
adb shell input swipe 540 700 540 1800 300 && sleep 1
tap_node '^(Einstellungen|Settings)' && sleep 2 && tap_node '^(Wie Gerät|Like device)' && sleep 1
adb shell input keyevent KEYCODE_BACK && sleep 2

# very large system text (200 %): home and game must stay usable
adb shell settings put system font_scale 2.0
adb shell am force-stop "$PKG"
sleep 2
adb shell am start -W -n "$PKG/.MainActivity" >> "$OUT/steps.log" 2>&1
sleep 8
shot 11_schrift200_start
if tap_node '^(Spiel fortsetzen|Continue game)'; then sleep 3; shot 12_schrift200_spiel; fi
PID=$(adb shell pidof "$PKG" | tr -d '\r')
if [ -n "$PID" ]; then echo "large_text=running" >> "$OUT/it_result.txt"; else echo "large_text=CRASHED" >> "$OUT/it_result.txt"; fi
adb shell settings put system font_scale 1.0

adb logcat -d -s flutter:V AndroidRuntime:E > "$OUT/logcat.txt" 2>&1
log "done"
