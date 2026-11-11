#!/usr/bin/env bash
# tool/ci/smoke_test.sh <apk>
# Installs the release APK on an emulator, walks through the first screens
# and prints everything needed to diagnose a crash: process state, crash
# buffer, Android exit reasons, app log and screenshots.
set -u
APK="$1"
PKG=vn.ongbi.english
UI="python3 tool/ci/ui.py"
FAILED=0

alive() { adb shell pidof "$PKG" >/dev/null 2>&1; }
step() { echo; echo "===== $* ====="; }
check() {
  if alive; then echo "process alive after: $1"; else echo "PROCESS DIED after: $1"; FAILED=1; fi
}

step "Device"
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.release

step "Install"
adb install -r -g "$APK" || { echo "INSTALL FAILED"; exit 1; }
adb logcat -c || true

step "Launch"
adb shell am start -W -n "$PKG/.MainActivity"
sleep 25
check "launch"
$UI shot 01-launch
$UI list

if alive; then
  step "Setup: download the required packs (Gemma skipped)"
  $UI setup 25
  check "downloads"
  $UI shot 02-setup-done
fi

if alive; then
  step "Setup -> start"
  $UI tap "Vào học" 30 && sleep 6
  check "start"
  $UI shot 03-placement
  $UI tap "Bỏ qua" 20 && sleep 12
  check "home"
  $UI shot 04-home
  $UI list
fi

if alive; then
  step "Daily lesson"
  $UI tap "Học hôm nay" 30 && sleep 15
  check "lesson"
  $UI shot 05-lesson
  $UI list
  # Answer a few steps by tapping whatever big button is first on screen.
  for i in 1 2 3 4 5 6; do
    $UI tap "Tiếp" 8 || $UI tap "Nghe lại" 4 || true
    sleep 5
  done
  check "lesson steps"
  $UI shot 05b-lesson-later
  adb shell input keyevent KEYCODE_BACK; sleep 3
fi

if alive; then
  step "Writing"
  $UI tap "Tập viết" 30 && sleep 8
  check "writing"
  $UI shot 06-write
  adb shell input keyevent KEYCODE_BACK; sleep 3
fi

if alive; then
  step "Talk with Bi"
  $UI tap "Nói chuyện" 30 && sleep 8
  check "talk"
  $UI shot 07-talk
  adb shell input keyevent KEYCODE_BACK; sleep 3
fi

step "Restart (reads the crash report path)"
adb shell am force-stop "$PKG"; sleep 2
adb shell am start -W -n "$PKG/.MainActivity"; sleep 15
check "restart"
$UI shot 08-restart

step "Crash buffer"
adb logcat -d -b crash || true

step "Exit reasons"
adb shell dumpsys activity exit-info "$PKG" | head -120 || true

step "App log"
adb logcat -d -v time | grep -iE "flutter|AndroidRuntime|ongbi|FATAL|DEBUG +:|libc +:|sherpa|litert|mlkit|tts|audio|crash|exception" | tail -400 || true

step "Result"
if [ "$FAILED" = 1 ]; then echo "SMOKE TEST: APP DIED"; else echo "SMOKE TEST: OK"; fi
exit 0
