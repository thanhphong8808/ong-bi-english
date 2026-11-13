#!/usr/bin/env bash
# tool/ci/smoke_test.sh <apk>
#
# Installs the release APK on an emulator and uses it like a family would:
# first-time setup ("Tải tất cả qua Wi-Fi" incl. Gemma, parent gate), the
# placement choice, a daily lesson (scripted taps through the stage
# checkpoints, then random taps), the study clock while the app is in the
# background, writing, the sticker and badge album, every parent screen
# (adding a school-book word), the diagnostics tests, Talk with Bi and a
# second lesson that must teach the parent's word.
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
home_gear() { $UI tap "Phụ huynh" 10 || adb shell input tap 1000 150; }

step "Device"
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.release
adb shell cat /proc/meminfo | head -1
# Animations off: Flutter then sees "reduce motion", the app stops its
# decorative loops and uiautomator can read every screen.
adb shell settings get global animator_duration_scale

step "Clock"
# The emulator runs on UTC. Kid mode is only open 6:00-21:00 local time, so
# pick a time zone where it is about 10:00 now (otherwise Bi sleeps and the
# lesson, writing and Talk with Bi are never really tested).
H=$(date -u +%H)
OFF=$(( (10 - 10#$H + 36) % 24 - 12 ))
if [ "$OFF" -ge 0 ]; then TZNAME="Etc/GMT-$OFF"; else TZNAME="Etc/GMT+$(( -OFF ))"; fi
adb root >/dev/null 2>&1; sleep 3
adb shell setprop persist.sys.timezone "$TZNAME"
adb shell "cmd alarm set-timezone $TZNAME" >/dev/null 2>&1 || true
echo "time zone $TZNAME, local time on the emulator: $(adb shell date | tr -d '\r')"

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
  if $UI wait "Bi đi ngủ rồi" 3; then
    PROBLEMS+=("kid mode was locked (Bi sleeping) when the lesson should open")
  fi
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
  step "Writing level by level"
  $UI tap "Tập viết" 15 540 1900 && sleep 8
  check "writing ladder"
  $UI shot 09w-ladder
  $UI list | head -30
  if $UI tapx "1" 10; then
    # Bi reads the words one by one: the word being read lights up.
    sleep 4
    for n in 1 2 3 4 5 6; do adb exec-out screencap -p > "$OUT/karaoke-$n.png"; sleep 0.4; done
    for n in 1 2 3 4 5 6; do echo "BEGIN_PNG 09w-karaoke-$n $(stat -c %s "$OUT/karaoke-$n.png")"; base64 -w0 "$OUT/karaoke-$n.png"; echo; echo END_PNG; done
    sleep 8
    $UI shot 09w-look
    $UI list | head -30
    $UI writeset 300 || echo "WARNING: the writing set did not reach its result"
    check "writing set"
    $UI shot 09w-result
    $UI list | head -30
    echo "writing scores: $(sql "SELECT setting_value FROM settings WHERE setting_key = 'write_best';")"
  else
    echo "WARNING: first writing set not found"
  fi
fi

# A finished lesson yesterday: the honeycomb shows a 2-day streak and the
# home screen celebrates the "first lesson" badge.
adb shell am force-stop "$PKG"; sleep 2
sql "INSERT OR REPLACE INTO study_days (profile_id, day, seconds, lessons_done) VALUES ((SELECT MIN(id) FROM profiles), date('now','localtime','-1 day'), 600, 1);"
launch 15
check "restart with yesterday's lesson"
if alive; then
  step "Honeycomb, badge and album"
  sleep 5
  $UI shot 09b-home-honeycomb
  # Reading the screen closes a badge dialog and prints "badge celebration".
  $UI list | head -20
  $UI shot 09b2-home-after-badge
  echo "study days: $(sql "SELECT day, seconds, lessons_done FROM study_days;" | tr '\n' ' ')"
  echo "badges: $(sql "SELECT sticker_id FROM rewards WHERE sticker_id LIKE 'badge:%';" | tr '\n' ' ')"
  if $UI tap "Quà" 10; then
    sleep 4
    $UI shot 09c-album
    $UI list | head -30
    check "album"
    adb shell input keyevent KEYCODE_BACK; sleep 3
  else
    echo "album button not found"
  fi
fi

restart 15
if alive; then
  step "Parent area"
  home_gear; sleep 3
  $UI gate || PROBLEMS+=("parent gate not solved")
  sleep 3
  $UI shot 10-parent
  $UI list
  # The menu sits below the week's dashboard: scroll to each entry.
  for entry in "Cài đặt học" "Bộ từ của bố mẹ" "Sổ tay của Bi" "Quản lý model" "Kiểm tra hệ thống" "Sao lưu và khôi phục" "Bảng tiến độ" "Hồ sơ của bé" "Nhật ký"; do
    if $UI seek "$entry"; then
      sleep 4
      safe=$(echo "$entry" | tr ' ' '_')
      case "$entry" in
        "Cài đặt học")
          $UI list | head -30
          $UI tap "Đặt lại" 5 && sleep 2 ;;
        "Bộ từ của bố mẹ")
          $UI tap "Thêm từ" 5 && sleep 3
          $UI field 1 && sleep 1 && $UI type "pencil case" && sleep 1
          $UI field 2 && sleep 1 && $UI type "hop but" && sleep 1
          $UI shot 11-word-dialog
          $UI tapx "Lưu" 5 && sleep 3
          words=$(sql "SELECT en FROM custom_words;")
          echo "parent words in the database: ${words:-(none)}"
          [ -z "$words" ] && echo "WARNING: the parent word was not saved (driver or app)"
          $UI list | head -20 ;;
        "Bảng tiến độ")
          $UI list | head -40
          adb shell input swipe 540 1500 540 1000 400; sleep 2
          $UI shot "11-skill-map"
          $UI list | head -40
          $UI wait "Bản đồ kỹ năng" 3 || echo "WARNING: skill map not shown"
          adb shell input swipe 540 1900 540 700 400; sleep 2 ;;
        "Kiểm tra hệ thống")
          # One test at a time: a tap while another test runs is ignored.
          $UI tapright "Thử giọng tiếng Việt" 5 && sleep 20
          $UI tapright "Thử giọng tiếng Anh" 5 && sleep 45
          $UI tapright "Thử nghe bé nói" 5 && sleep 45
          $UI wait "Máy nghe được" 5 || echo "WARNING: the listening test showed no result"
          $UI tapright "Thử bộ não của Bi" 5 && sleep 120
          $UI list | head -40 ;;
        "Sao lưu và khôi phục")
          $UI tap "Sao lưu ra thư mục Download" 5 && sleep 5 ;;
      esac
      $UI shot "11-$safe"
      check "parent: $entry"
      adb shell input keyevent KEYCODE_BACK; sleep 3
    else
      echo "parent entry not found: $entry"; PROBLEMS+=("parent entry not found: $entry")
    fi
  done
  adb shell input keyevent KEYCODE_BACK; sleep 3
fi

# Three guided talks, free chat and a second lesson take longer than the
# default 20 minutes a day: give the test child an hour.
adb shell am force-stop "$PKG"; sleep 2
sql "INSERT OR REPLACE INTO settings (profile_id, setting_key, setting_value) VALUES (0, 'dailyLimitMinutes', '60');"
launch 15
check "restart with a longer daily limit"
if alive; then
  step "Chào Bi mỗi ngày (the morning hello)"
  $UI list | head -20
  $UI tap "Chào Bi mỗi ngày" 15 && sleep 15
  $UI shot 12h-hello-start
  $UI guided 360 || PROBLEMS+=("the morning hello did not reach its end")
  check "hello"
  sleep 8
  $UI shot 12h-hello-end
  echo "hello: last=$(sql "SELECT setting_value FROM settings WHERE setting_key = 'hello_last';") mission=$(sql "SELECT setting_value FROM settings WHERE setting_key = 'hello_mission';")"
  echo "bi notebook: $(sql "SELECT setting_value FROM settings WHERE setting_key = 'bi_notes';")"
  [ -z "$(sql "SELECT setting_value FROM settings WHERE setting_key = 'hello_last';")" ] && PROBLEMS+=("the morning hello was not saved")
  adb shell input keyevent KEYCODE_BACK; sleep 5
  $UI list | head -20
  $UI shot 12h-home-after-hello
fi

restart 15
if alive; then
  step "Câu bỏ túi (pocket phrases)"
  $UI tap "Câu bỏ túi" 15 && sleep 8
  $UI shot 12p-pocket
  $UI list | head -24
  if $UI tap "Luyện tập" 10; then
    sleep 20
    $UI shot 12p-practice
    for i in 1 2 3 4 5; do
      $UI tap "Micro" 10 || true
      sleep 22
    done
    $UI shot 12p-practice-end
    $UI list | head -20
  else
    PROBLEMS+=("pocket practice button not found")
  fi
  echo "pocket progress: $(sql "SELECT setting_value FROM settings WHERE setting_key = 'pocket_v1';")"
  check "pocket"
fi

restart 15
if alive; then
  step "Talk with Bi: a guided chat (Hằng ngày)"
  $UI tap "Nói chuyện với Bi" 15 540 1530 && sleep 6
  $UI shot 12-talk-home
  $UI tap "Trò chuyện" 10 && sleep 4
  $UI shot 12-talk-topics
  $UI tap "Hằng ngày" 10 && sleep 4
  $UI shot 12-talk-chats
  $UI list | head -20
  $UI tap "Chào buổi sáng" 10 && sleep 20
  $UI shot 13-guided-start
  $UI guided 420 || PROBLEMS+=("the guided chat did not reach its end")
  check "guided chat"
  $UI shot 13-guided-end
  $UI list | head -30
fi

restart 15
if alive; then
  step "Talk with Bi: role-play, the child picks a role"
  $UI tap "Nói chuyện với Bi" 15 540 1530 && sleep 6
  $UI tap "Đóng vai" 10 && sleep 4
  $UI tap "Ăn uống" 10 && sleep 4
  $UI tap "Ở quán phở" 10 && sleep 4
  $UI shot 13-role-pick
  $UI tapx "Khách" 10 && sleep 20
  $UI shot 13-role-start
  $UI guided 420 || PROBLEMS+=("the role-play did not reach its end")
  check "role-play"
  $UI shot 13-role-end
fi

restart 15
if alive; then
  step "Talk with Bi: a fable"
  $UI tap "Nói chuyện với Bi" 15 540 1530 && sleep 6
  $UI tap "Nghe kể chuyện" 10 && sleep 4
  $UI shot 13-stories
  $UI tap "Rùa và Thỏ" 10 && sleep 25
  $UI shot 13-story-start
  $UI guided 480 || PROBLEMS+=("the story did not reach its end")
  check "story"
  sleep 15
  $UI shot 13-story-end
  $UI list | head -30
  echo "talks finished: $(sql "SELECT setting_value FROM settings WHERE setting_key = 'talk_done';")"
fi

restart 15
if alive; then
  step "Chat với Bi: the brain hears, thinks and answers"
  $UI tap "Nói chuyện với Bi" 15 540 1530 && sleep 6
  $UI shot 13c-talk-home
  $UI tap "Chat với Bi" 10 && sleep 5
  # Gemma loads on the emulator CPU; Bi greets, then helps a silent child
  # (an easier question, then a sentence to copy), then waits for a tap.
  for i in 1 2 3 4 5 6 7 8 9; do sleep 20; check "chat +$((i * 20)) s"; done
  $UI shot 13c-chat-silence
  $UI list | head -40
  if $UI tap "Gõ chữ" 10; then
    sleep 3
    $UI field 1 && sleep 1 && $UI type "I like cats" && sleep 1
    $UI tap "Gửi" 5 || adb shell input keyevent KEYCODE_ENTER
    for i in 1 2 3 4 5 6 7 8 9; do sleep 20; check "chat reply +$((i * 20)) s"; done
    $UI shot 13c-chat-reply
    $UI list | head -50
  else
    PROBLEMS+=("chat keyboard button not found")
  fi
  echo "chat lines: $(sql "SELECT role || ': ' || content FROM chat_logs WHERE session_id LIKE 'chat-%' ORDER BY id;" | tr '\n' ' / ')"
  echo "bi notebook: $(sql "SELECT setting_value FROM settings WHERE setting_key = 'bi_notes';")"
  # Bi's own answers after "I like cats" (not the fixed fallback lines).
  replies=$(sql "SELECT COUNT(*) FROM chat_logs WHERE session_id LIKE 'chat-%' AND role = 'bi' AND id > (SELECT COALESCE(MAX(id), 0) FROM chat_logs WHERE session_id LIKE 'chat-%' AND role = 'kid' AND content LIKE '%cats%') AND content NOT LIKE 'Hmm!%' AND content NOT LIKE 'Let''s talk about something fun%';")
  echo "Bi's answers from its brain after the typed message: ${replies:-0}"
  [ "${replies:-0}" -ge 1 ] || PROBLEMS+=("the chat with Bi produced no answer from the model")
  adb logcat -d -s flutter 2>/dev/null | grep -iE "llm|gemma|speech:" | tail -20 || true
  adb shell input keyevent KEYCODE_BACK; sleep 4

  step "Talk with Bi: free chat inside a topic"
  $UI tap "Trò chuyện" 10 && sleep 4
  $UI tap "Hằng ngày" 10 && sleep 4
  $UI tap "Nói tự do với Bi" 10 || echo "WARNING: free chat not offered (brain not installed?)"
  $UI wait "breakfast" 20 || echo "WARNING: the daily-life chat did not open with its breakfast question"
  for i in 1 2 3 4 5 6; do sleep 20; check "talk +$((i * 20)) s"; done
  $UI shot 13-talk
  $UI list | head -30
  check "talk reply"
  $UI shot 14-talk-reply
fi

restart 15
if alive; then
  step "Second lesson: the parent's word is taught"
  $UI tap "Học hôm nay" 15 540 1146 && sleep 20
  check "lesson 2"
  $UI explore 300 "pencil case" || true
  check "lesson 2 (scripted)"
  $UI shot 14b-lesson2
  pw=$(sql "SELECT item_id, skill, box FROM item_progress WHERE item_id LIKE 'P-%';" | tr '\n' ' ')
  echo "parent word progress: ${pw:-(none)}"
  [ -z "$pw" ] && echo "WARNING: the parent's word was not practised in the second lesson"
  echo "speech turns: $(sql "SELECT source, COUNT(*) FROM speech_turns GROUP BY source;" | tr '\n' ' ')"
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

step "Words light up with the voice"
# SpeechOutput logs one line per English sentence it plays: how many audio
# positions moved the highlight. All zero means the words never light up.
grep -E "speech progress:" "$OUT/logcat.txt" | tail -12
lit=$(grep -cE "speech progress: ms=[1-9][0-9]* updates=[1-9]" "$OUT/logcat.txt")
echo "sentences with a moving highlight: $lit"
[ "${lit:-0}" -ge 3 ] || PROBLEMS+=("the word highlight never followed the voice (speech progress)")

step "Result"
if [ ${#PROBLEMS[@]} -eq 0 ]; then
  echo "SMOKE TEST: OK"
  exit 0
fi
echo "SMOKE TEST: PROBLEMS FOUND"
for p in "${PROBLEMS[@]}"; do echo " - $p"; done
exit 1
