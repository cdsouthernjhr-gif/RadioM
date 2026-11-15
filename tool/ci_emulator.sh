#!/usr/bin/env bash
# Runs on the Android 6.0 (API 23) emulator in CI.
#  1. Installs the RELEASE APK and launches it (installation / startup test).
#  2. Runs integration_test/playback_test.dart (real streams) while a watcher
#     reacts to IT_MARKER lines: presses HOME (background test) and toggles the
#     network (disconnect / reconnect test).
# Results are written to build/emulator-report.txt.
set -u
APK=${1:-build/app/outputs/flutter-apk/app-release.apk}
PKG=my.radiom.malaysia_radio_player
OUT=build/emulator-report.txt
mkdir -p build
: > "$OUT"
log() { echo "$*" | tee -a "$OUT"; }

log "== device"
log "sdk=$(adb shell getprop ro.build.version.sdk | tr -d '\r') release=$(adb shell getprop ro.build.version.release | tr -d '\r') abi=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"

log "== install release APK"
if adb install -r "$APK" 2>&1 | tee -a "$OUT" | grep -q Success; then log "INSTALL=PASS"; else log "INSTALL=FAIL"; fi
adb logcat -c
adb shell am start -W -n $PKG/.MainActivity 2>&1 | tee -a "$OUT"
sleep 20
if adb shell ps | grep -q "$PKG"; then log "LAUNCH_PROCESS=PASS"; else log "LAUNCH_PROCESS=FAIL"; fi
if adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime: Process: $PKG" > build/crash.txt; then
  log "LAUNCH_CRASH=YES"; cat build/crash.txt | head -40 | tee -a "$OUT"
else
  log "LAUNCH_CRASH=NO"
fi
adb shell screencap -p /sdcard/launch.png && adb pull /sdcard/launch.png build/emulator-launch.png >/dev/null 2>&1
adb shell am force-stop $PKG
adb uninstall $PKG >/dev/null 2>&1 || true

log "== integration tests (debug build, real network streams)"
adb logcat -c
(
  adb logcat -v brief flutter:I '*:S' | while IFS= read -r line; do
    case "$line" in
      *IT_MARKER:background_ready*)
        echo "[driver] pressing HOME" ; adb shell input keyevent KEYCODE_HOME ;;
      *IT_MARKER:net_ready*)
        echo "[driver] network OFF"; adb shell svc data disable; adb shell svc wifi disable ;;
      *IT_MARKER:net_lost*)
        sleep 5; echo "[driver] network ON"; adb shell svc data enable; adb shell svc wifi enable ;;
    esac
  done
) &
WATCHER=$!
flutter test integration_test/playback_test.dart --dart-define=HOST_DRIVER=true -d emulator-5554 \
  --reporter expanded 2>&1 | tee build/integration.log
RC=${PIPESTATUS[0]}
kill $WATCHER 2>/dev/null || true
adb shell svc data enable; adb shell svc wifi enable
grep -E "IT_RESULT|IT_MARKER|\[driver\]" build/integration.log | tee -a "$OUT"
adb logcat -d -v brief flutter:I '*:S' | grep -E "IT_RESULT|IT_MARKER" | tee -a "$OUT"
grep -E "^\s*[0-9:]+ \+[0-9]+.*(~[0-9]+)?(-[0-9]+)?:" build/integration.log | tail -1 | tee -a "$OUT"
log "INTEGRATION_EXIT=$RC"
exit 0
