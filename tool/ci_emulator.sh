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
if adb shell dumpsys activity activities | grep -E "mResumedActivity|mFocusedActivity" | grep -q "$PKG"; then
  log "LAUNCH_FOREGROUND=PASS"
else
  log "LAUNCH_FOREGROUND=FAIL"; adb shell dumpsys activity activities | grep -E "mResumedActivity|mFocusedActivity" | tee -a "$OUT"
fi
if adb shell ps | tr -d '\r' | grep -q "malaysia_radio"; then log "LAUNCH_PROCESS=PASS"; else log "LAUNCH_PROCESS=FAIL"; fi
if adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime: Process: $PKG" > build/crash.txt; then
  log "LAUNCH_CRASH=YES"; cat build/crash.txt | head -40 | tee -a "$OUT"
else
  log "LAUNCH_CRASH=NO"
fi
adb shell screencap -p /sdcard/launch.png && adb pull /sdcard/launch.png build/emulator-launch.png >/dev/null 2>&1
adb shell am force-stop $PKG
adb uninstall $PKG >/dev/null 2>&1 || true

log "== integration tests (debug build, real network streams)"
: > build/integration.log
adb logcat -c
(
  # IT_MARKER lines are printed by `flutter test` (stdout), so watch its log file.
  tail -n +1 -F build/integration.log 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *IT_MARKER:background_ready*)
        echo "[driver] pressing HOME" | tee -a build/driver.log; adb shell input keyevent KEYCODE_HOME ;;
      *IT_MARKER:net_ready*)
        echo "[driver] network OFF" | tee -a build/driver.log; adb emu gsm data off; adb shell svc data disable; adb shell svc wifi disable
        sleep 3; echo "[driver] ping after OFF: $(adb shell ping -c 1 -W 2 8.8.8.8 2>&1 | grep -E 'received|unreachable' | tr -d '\r')" | tee -a build/driver.log ;;
      *IT_MARKER:net_lost*)
        sleep 5; echo "[driver] network ON" | tee -a build/driver.log; adb emu gsm data on; adb shell svc data enable; adb shell svc wifi enable ;;
    esac
  done
) &
WATCHER=$!
flutter test integration_test/playback_test.dart --dart-define=HOST_DRIVER=true -d emulator-5554 \
  --reporter expanded 2>&1 | tee -a build/integration.log | grep --line-buffered -E "\[driver\]|IT_|\+[0-9]+" 
RC=${PIPESTATUS[0]}
kill $WATCHER 2>/dev/null || true
adb emu gsm data on; adb shell svc data enable; adb shell svc wifi enable
log "== host driver actions"; cat build/driver.log 2>/dev/null | tee -a "$OUT"
grep -E "IT_RESULT" build/integration.log | sort -u | tee -a "$OUT"
log "== player/TLS errors from logcat"
adb logcat -d -v brief '*:W' | grep -iE "ExoPlayer|SSL|Handshake|AudioPlayer|HttpDataSource|CertPath" | sort | uniq -c | sort -rn | head -40 | tee -a "$OUT"
grep -E "^\s*[0-9:]+ \+[0-9]+.*(~[0-9]+)?(-[0-9]+)?:" build/integration.log | tail -1 | tee -a "$OUT"
log "INTEGRATION_EXIT=$RC"
exit 0
