#!/usr/bin/env bash
# tool/ci/smoke_test.sh <apk>
# Installs the release APK on an emulator and does what a parent and child
# would do: first-time setup ("Tải tất cả qua Wi-Fi", parent gate), start,
# daily lesson, writing, Talk with Bi. Prints process state, the crash
# buffer, Android's exit reasons, the app's own log and screenshots.
set -u
APK="$1"
PKG=vn.ongbi.english
UI="python3 -u tool/ci/ui.py"
OUT=smoke-out
mkdir -p "$OUT"
FAILED=0

alive() { adb shell pidof "$PKG" >/dev/null 2>&1; }
step() { echo; echo "===== $* ====="; }
check() {
  local pid
  pid=$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r')
  if [ -n "$pid" ]; then
    echo "process alive after: $1 (pid $pid)"
    echo "$pid" >> "$OUT/pids"
  else
    echo "PROCESS DIED after: $1"
    FAILED=1
  fi
}
restart() {
  adb shell am force-stop "$PKG"; sleep 2
  adb shell am start -n "$PKG/.MainActivity" >/dev/null; sleep "${1:-15}"
  check "restart"
}

step "Device"
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.release
adb shell cat /proc/meminfo | head -2

step "Settle"
# The emulator's own apps are still starting right after boot.
sleep 45
$UI list >/dev/null 2>&1 || true

step "Install"
adb install -r -g "$APK" || { echo "INSTALL FAILED"; exit 1; }
adb logcat -G 16M || true
adb logcat -c || true

step "Launch"
adb shell am start -n "$PKG/.MainActivity" >/dev/null
sleep 25
check "launch"
$UI shot 01-launch

if alive; then
  step "First-time setup (Tải tất cả qua Wi-Fi)"
  $UI setup 25
  check "downloads"
  $UI shot 02-setup-done
fi

if alive; then
  step "Start learning"
  $UI tap "Vào học" 20 && sleep 6
  check "start"
  $UI shot 03-placement
  $UI tap "Bỏ qua" 20 && sleep 15
  check "home"
  $UI shot 04-home
  $UI list
fi

if alive; then
  step "Daily lesson"
  $UI tap "Học hôm nay" 10 540 1146 && sleep 25
  check "lesson"
  $UI shot 05-lesson
  # Answer a few steps: tap where answer cards and the big button sit.
  for xy in "540 1500" "300 1500" "780 1500" "540 2100" "540 1800" "300 1800" "780 1800" "540 2100"; do
    adb shell input tap $xy; sleep 6
  done
  check "lesson steps"
  $UI shot 06-lesson-later
fi

restart 15
if alive; then
  step "Writing"
  $UI tap "Tập viết" 10 540 1900 && sleep 10
  check "writing"
  $UI shot 07-write
  $UI list
fi

restart 15
if alive; then
  step "Talk with Bi"
  $UI tap "Nói chuyện" 10 540 1530 && sleep 10
  $UI shot 08-talk-choose
  $UI tap "Trò chuyện" 20
  for i in 1 2 3; do sleep 15; check "talk +$((i*15))s"; done
  $UI shot 09-talk
  $UI list
fi

step "Restart once more"
restart 20
$UI shot 10-restart

step "What the app produced (root on the emulator)"
adb root >/dev/null 2>&1; sleep 3
DATA=/data/user/0/$PKG
echo "built-in voice files (sherpa-onnx TTS):"
adb shell "find $DATA -path '*audio_cache*' -name '*.wav' | wc -l" || true
adb shell "find $DATA -path '*audio_cache*' -name '*.wav' | head -5" || true
echo "crash-guard state:"
adb shell "ls -la $DATA/files/native_guard 2>/dev/null; cat $DATA/files/native_guard/native_guard.json 2>/dev/null" || true
adb shell "ls $DATA/files/crash 2>/dev/null" || true
adb logcat -d -v threadtime > "$OUT/logcat.txt" 2>/dev/null || true

step "Crash buffer"
adb logcat -d -b crash || true

step "Exit reasons"
adb shell dumpsys activity exit-info "$PKG" | head -80 || true

step "App log (app processes only)"
PIDS=$(sort -u "$OUT/pids" 2>/dev/null | tr '\n' '|' | sed 's/|$//')
grep -E "Start proc [0-9]+:$PKG|Process $PKG|Fatal signal|FATAL EXCEPTION|F DEBUG" "$OUT/logcat.txt" | tail -40
if [ -n "$PIDS" ]; then
  awk -v pids="$PIDS" 'BEGIN{n=split(pids,a,"|"); for(i=1;i<=n;i++) want[a[i]]=1} want[$3]' "$OUT/logcat.txt" \
    | grep -vE " (EGL_emulation|HWUI|Choreographer|ProfileInstaller|nativeloader|OpenGLRenderer|gralloc|ion|RenderThread|ResourcesManager|CompatChangeReporter|AppCompatDelegate|InsetsController|VRI\[|BLASTBufferQueue|SurfaceView|ViewRootImpl)" \
    | tail -700
fi

step "Result"
if [ "$FAILED" = 1 ]; then echo "SMOKE TEST: APP DIED"; else echo "SMOKE TEST: OK"; fi
exit 0
