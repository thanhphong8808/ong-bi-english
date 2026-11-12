#!/usr/bin/env bash
# tool/ci/smoke_test.sh <apk>
#
# Installs the release APK on an emulator and uses it like a family would:
# first-time setup ("Tải tất cả qua Wi-Fi" incl. Gemma, parent gate), the
# placement choice, a daily lesson (scripted taps, then random taps), the
# study clock while the app is in the background, writing, every parent
# screen, the diagnostics tests and Talk with Bi.
#
# The run FAILS when the app dies, Android records a crash or ANR, any Dart
# error was logged, or the crash guard had to switch an engine off. Driver
# misses (a button not found) are reported but do not fail the run.
set -u
APK="$1"
PKG=vn.ongbi.english
DATA=/data/user/0/$PKG
DB=$DATA/app_flutter/ong_bi_english.sqlite
UI="python3 -u tool/ci/ui.py"
OUT=smoke-out
mkdir -p "$OUT"
PROBLEMS=()

step() { echo; echo "===== $* ====="; }
alive() { adb shell pidof "$PKG" >/dev/null 2>&1; }
check() {
  local pid
  pid=$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r')
  if [ -n "$pid" ]; then
    echo "process alive after: $1 (pid $pid)"
  else
    echo "PROCESS DIED after: $1"
    PROBLEMS+=("app died during: $1")
  fi
}
launch() {
  adb shell am start -n "$PKG/.MainActivity" >/dev/null
  sleep "${1:-12}"
}
restart() {
  adb shell am force-stop "$PKG"; sleep 2
  launch "${1:-15}"
  check "restart"
}
sql() { adb shell "sqlite3 $DB \"$1\"" 2>/dev/null | tr -d '\r'; }
studied() { sql "SELECT COALESCE(SUM(seconds),0) FROM study_days WHERE day = date('now','localtime');"; }
home_gear() { adb shell input tap 996 2264; }

step "Device"
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.release
adb shell cat /proc/meminfo | head -1
# Animations off: Flutter then sees "reduce motion", the app stops its
# decorative loops and uiautomator can read every screen.
adb shell settings get global animator_duration_scale

step "Settle"
sleep 45
$UI list >/dev/null 2>&1 || true

step "Install"
adb install -r -g "$APK" || { echo "INSTALL FAILED"; exit 1; }
adb root >/dev/null 2>&1; sleep 3
adb logcat -G 16M >/dev/null 2>&1 || true
adb logcat -c || true

step "Launch"
launch 25
check "launch"
$UI shot 01-launch

if alive; then
  step "First-time setup (Tải tất cả qua Wi-Fi)"
  $UI setup 45 || PROBLEMS+=("setup did not finish")
  check "downloads"
  $UI shot 02-setup-done
fi

if alive; then
  step "Start learning"
  $UI tap "Vào học" 20 && sleep 6
  check "start"
  $UI shot 03-placement
  $UI tap "Bỏ qua" 20 && sleep 12
  check "home"
  $UI shot 04-home
  $UI list
fi

if alive; then
  step "Daily lesson: scripted taps"
  $UI tap "Học hôm nay" 15 540 1146 && sleep 20
  check "lesson"
  $UI shot 05-lesson
  $UI list
  $UI explore 150 || true
  check "lesson (scripted)"
  $UI shot 06-lesson-later

  step "Study clock: 90 s in the background must not count"
  before=$(studied)
  adb shell input keyevent KEYCODE_HOME
  sleep 90
  during=$(studied)
  launch 20
  after=$(studied)
  echo "study seconds today: before=$before background=$during after-resume=$after"
  if [ -n "$before" ] && [ -n "$during" ] && [ $((during - before)) -gt 40 ]; then
    PROBLEMS+=("study clock counted $((during - before)) s while the app was in the background")
  fi
  check "resume"
fi

if alive; then
  step "Daily lesson: random taps (monkey)"
  adb shell monkey -p "$PKG" --pct-syskeys 0 --pct-nav 0 --pct-majornav 0 --pct-appswitch 0 \
    --pct-anyevent 0 --pct-trackball 0 --pct-touch 75 --pct-motion 25 --throttle 350 -s 7 -v 500 \
    2>&1 | grep -E "CRASH|ANR|Events injected|Monkey aborted|NOT RESPONDING" || true
  check "monkey"
  $UI shot 07-after-monkey
fi

restart 15
if alive; then
  step "Writing"
  $UI tap "Tập viết" 15 540 1900 && sleep 8
  check "writing"
  $UI shot 08-write
  $UI tap "A" 10 && sleep 8
  # Draw a stroke on the tracing canvas.
  adb shell input swipe 400 900 540 1500 600; sleep 2
  adb shell input swipe 680 900 540 1500 600; sleep 4
  check "tracing"
  $UI shot 09-trace
fi

restart 15
if alive; then
  step "Parent area"
  home_gear; sleep 3
  $UI gate || PROBLEMS+=("parent gate not solved")
  sleep 3
  $UI shot 10-parent
  $UI list
  for entry in "Cài đặt học" "Quản lý model" "Kiểm tra hệ thống" "Sao lưu và khôi phục" "Bảng tiến độ" "Hồ sơ của bé" "Nhật ký"; do
    if $UI tap "$entry" 10; then
      sleep 4
      safe=$(echo "$entry" | tr ' ' '_')
      case "$entry" in
        "Cài đặt học")
          $UI list | head -30
          $UI tap "Đặt lại" 5 && sleep 2 ;;
        "Kiểm tra hệ thống")
          $UI tap "Thử giọng tiếng Việt" 5 && sleep 8
          $UI tap "Thử giọng tiếng Anh" 5 && sleep 10
          $UI tap "Thử nghe bé nói" 5 && sleep 20
          $UI tap "Thử bộ não của Bi" 5 && sleep 90
          $UI list | head -40 ;;
        "Sao lưu và khôi phục")
          $UI tap "Sao lưu ra thư mục Download" 5 && sleep 5 ;;
      esac
      $UI shot "11-$safe"
      check "parent: $entry"
      adb shell input keyevent KEYCODE_BACK; sleep 3
    else
      echo "parent entry not found: $entry"
    fi
  done
  adb shell input keyevent KEYCODE_BACK; sleep 3
fi

restart 15
if alive; then
  step "Talk with Bi"
  $UI tap "Nói chuyện với Bi" 15 540 1530 && sleep 6
  $UI shot 12-talk-choose
  $UI tap "Trò chuyện" 15 540 1173
  for i in 1 2 3 4 5 6; do sleep 20; check "talk +$((i * 20)) s"; done
  $UI shot 13-talk
  $UI list
  # The child presses the microphone (the emulator hears silence).
  adb shell input tap 540 2150
  sleep 60
  check "talk reply"
  $UI shot 14-talk-reply
  $UI list
fi

step "Restart once more"
restart 20
$UI shot 15-restart

step "Results the app left behind"
echo "built-in voice files: $(adb shell "find $DATA -path '*audio_cache*' -name '*.wav' | wc -l" | tr -d '\r')"
echo "study_days:"; sql "SELECT * FROM study_days;"
echo "crash guard:"; adb shell "cat $DATA/files/native_guard/native_guard.json 2>/dev/null"; echo
guard=$(adb shell "cat $DATA/files/native_guard/native_guard.json 2>/dev/null" | tr -d '\r')
case "$guard" in *'"disabled":[]'*|'') ;; *) PROBLEMS+=("crash guard switched engines off: $guard") ;; esac
echo "Dart errors recorded by the app:"
dart_errors=$(adb shell "cat $DATA/files/crash/dart.txt 2>/dev/null" | tr -d '\r')
if [ -n "$dart_errors" ]; then
  echo "$dart_errors" | head -150
  PROBLEMS+=("Dart errors were recorded (see above)")
else
  echo "(none)"
fi
pending=$(adb shell "cat $DATA/files/crash/pending.txt 2>/dev/null" | tr -d '\r')
[ -n "$pending" ] && { echo "$pending" | head -60; PROBLEMS+=("Kotlin/Java crash recorded"); }

step "Crash buffer"
crashes=$(adb logcat -d -b crash 2>/dev/null)
echo "$crashes" | tail -80
echo "$crashes" | grep -q "$PKG" && PROBLEMS+=("crash buffer mentions the app")

step "Exit reasons"
exits=$(adb shell dumpsys activity exit-info "$PKG" 2>/dev/null)
echo "$exits" | grep -E "reason=|description=|importance=" | head -40
echo "$exits" | grep -qE "reason=(4|5|6)[^0-9]" && PROBLEMS+=("Android recorded a crash or ANR (exit-info)")

step "App log"
adb logcat -d -v threadtime > "$OUT/logcat.txt" 2>/dev/null || true
grep -E " (E|F) (flutter|AndroidRuntime|DEBUG|libc|vn\.ongbi)" "$OUT/logcat.txt" | tail -80
grep -E "flutter +:" "$OUT/logcat.txt" | tail -60

step "Result"
if [ ${#PROBLEMS[@]} -eq 0 ]; then
  echo "SMOKE TEST: OK"
  exit 0
fi
echo "SMOKE TEST: PROBLEMS FOUND"
for p in "${PROBLEMS[@]}"; do echo " - $p"; done
exit 1
