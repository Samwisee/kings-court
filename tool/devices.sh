#!/bin/bash
# Runs a Flutter integration test on every device this computer can reach,
# one after another, and keeps everything each one says.
#
#   bash tool/devices.sh                     every platform found
#   bash tool/devices.sh chrome safari       only these
#   bash tool/devices.sh --list              what's reachable, then stop
#   bash tool/devices.sh --one-at-a-time     no two platforms at once
#   bash tool/devices.sh --dart-define=K=V   passed to every build (and named
#                                            in the run's folder, to compare)
#
# Platforms:
#   android-chrome  the game in Chrome on an Android phone on the cable
#   android-app     the Android app on that phone
#   iphone          the iOS app on an iPhone on the cable (iOS Safari can't
#                   be driven on a real phone: Apple only allows the Simulator)
#   chrome          Chrome on this computer
#   safari          Safari on this Mac
#   macos           the Mac app
#
# Phones and this computer take turns separately, side by side: a phone
# draws on its own chip, so it runs while this computer runs its own
# platforms (one at a time: they'd share its chip, and a browser behind
# another window slows its frames). This computer's lane runs in a copy of
# the project (in $TMPDIR), so the two builds don't meet.
#
# Each run gets its own folder, build/devices/<date>_<time>/ (and
# build/devices/latest), with:
#   env.txt                   the computer, Flutter, the commit, the browsers
#   devices.json              everything Flutter could see
#   summary.txt               each platform's outcome (and the project's own
#                             summary of the results, if it has one)
#   <platform>/drive.log      flutter drive, verbose: the build, the launch,
#                             the test's own output, and any failure
#   <platform>/console.log    what the app printed (the browser's console on
#                             the web; the app's own output natively)
#   <platform>/device.log     the device's system log while it ran (Android's
#                             logcat, the iPhone's syslog, the Mac's log)
#   <platform>/driver.log     the WebDriver's log (Chrome, Safari)
#   <platform>/device.txt     the device: model, OS, and before and after the
#                             run its battery and temperature, where it says
#   <platform>/result.json    what the test sent back, if it sends anything
#   <platform>/report.txt     the project's report of that, if it has one
#   <platform>/status.txt     passed / failed / timed out, and how long
#
# Per project, tool/devices.conf (or devices.conf) says what to run; every
# setting is optional:
#   TARGET=integration_test/app_test.dart
#   DRIVER=test_driver/integration_test.dart
#   MODE=--profile                        (--debug, --profile or --release)
#   DEFINES=(--dart-define=A=B)
#   RESULT=build/integration_response_data.json   the file the driver writes
#   REPORT="python3 tool/report.py"       given result.json, prints a report
#   SUMMARY="python3 tool/summary.py"     given the run folder and platforms
#   PLATFORMS="chrome safari"             the default set (else all)
#   LIMIT_MIN=30                          minutes before a run is stopped
#   WEB_SIZE=412,915@2                    the browser window, in CSS pixels
#
# Once, per device:
#   Android  Settings > About phone: tap Build number 7 times; Developer
#            options: USB debugging on; plug in and allow this computer.
#            Needs Node (npx) to fetch the ChromeDriver for its Chrome.
#   iPhone   Plug in, unlock, Trust; on iOS 16+ Settings > Privacy &
#            Security > Developer Mode. Needs Xcode and a signing team set in
#            ios/Runner.xcodeproj. The app's iOS minimum must be met.
#            For its system log: brew install libimobiledevice.
#   Safari   Safari > Settings > Advanced: show features for web developers;
#            then Develop > Allow Remote Automation; and once, in a
#            terminal: safaridriver --enable (asks for your password).
#   Chrome   Needs Node (npx), as above.
#   Mac app  Needs Xcode and a macos/ folder.

set -o pipefail
self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
here=$PWD
while [ ! -f pubspec.yaml ] && [ "$PWD" != / ]; do cd ..; done
[ -f pubspec.yaml ] || { cd "$here"; echo "Run this inside a Flutter project."; exit 1; }
project=$PWD

TARGET=""
DRIVER=""
MODE=--profile
DEFINES=()
RESULT=""
REPORT=""
SUMMARY=""
PLATFORMS=""
LIMIT_MIN=30
WEB_SIZE=412,915@2
for c in tool/devices.conf devices.conf; do [ -f "$c" ] && . "./$c" && break; done
[ -n "$TARGET" ] || TARGET=$(ls integration_test/*_test.dart 2>/dev/null | head -1)
[ -n "$DRIVER" ] || DRIVER=test_driver/integration_test.dart
[ -f "$TARGET" ] || { echo "No integration test to run (set TARGET in tool/devices.conf)."; exit 1; }
[ -f "$DRIVER" ] || { echo "No driver at $DRIVER (set DRIVER in tool/devices.conf)."; exit 1; }

all="android-chrome android-app iphone chrome safari macos"
want=()
listing=""
tag=""
into=""        # the run's folder, when this is the computer's lane of a run
lanes=1
cli_defines=()
next=""
for a in "$@"; do
  if [ "$next" = into ]; then into=$a; next=""; continue; fi
  case "$a" in
    --list) listing=1 ;;
    --one-at-a-time) lanes="" ;;
    --into) next=into ;;
    --dart-define=*) DEFINES+=("$a"); cli_defines+=("$a"); d=${a#--dart-define=}; tag="$tag-${d%%=*}" ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [[ " $all " == *" $a "* ]]; then want+=("$a"); else
         echo "Don't know \"$a\". Platforms: $all; options: --list, --one-at-a-time, --dart-define=K=V."; exit 1; fi ;;
  esac
done
[ ${#want[@]} -gt 0 ] || want=(${PLATFORMS:-$all})
wanted() { [[ " ${want[*]} " == *" $1 "* ]]; }

mac() { [ "$(uname)" = Darwin ]; }
adb=$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")
[ -x "$adb" ] && export PATH="$(dirname "$adb"):$PATH"   # ChromeDriver finds phones through adb

# --- What's reachable ---------------------------------------------------------
drivers=${DEVICES_DRIVERS:-$project/build/drivers}
if [ -n "$into" ]; then
  run=$into
  found=$run/devices-computer.json
else
  run=build/devices/$(date +%Y-%m-%d_%H%M%S)$tag
  found=$run/devices.json
  mkdir -p build/devices
  ln -sfn "$(basename "$run")" build/devices/latest
  echo "Looking for devices…"
fi
mkdir -p "$run" "$drivers"
flutter devices --machine >"$found" 2>/dev/null
# id, platform, emulator, supported, sdk, name: one line a device
devices() {
  python3 - "$found" <<'EOF'
import json, sys
text = open(sys.argv[1]).read()
try:
    found = json.loads(text[text.find('['):]) if '[' in text else []
except ValueError:
    found = []
for d in found:
    print('\t'.join([d.get('id', ''), d.get('targetPlatform', ''), str(d.get('emulator', False)).lower(),
                     str(d.get('isSupported', True)).lower(), d.get('sdk', ''), d.get('name', '')]))
EOF
}

phone=""; phone_state=""
if [ -x "$adb" ]; then
  phone=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
  [ -n "$phone" ] || phone_state=$(adb devices | awk 'NR>1 && $2 {print $2; exit}')
fi
iphone=$(devices | awk -F'\t' '$2 ~ /^ios/ && $3 == "false" {print; exit}')
chrome_app=""
if mac; then [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ] && chrome_app="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
else chrome_app=$(command -v google-chrome || command -v chromium || true); fi
safari=""; mac && [ -x /usr/bin/safaridriver ] && safari=/usr/bin/safaridriver
macos_app=""; mac && [ -d macos ] && command -v xcodebuild >/dev/null && macos_app=1

# Says why [platform] can't run, or nothing when it can.
why_not() {
  case $1 in
    android-chrome|android-app)
      [ -x "$adb" ] || { echo "no adb (Android's platform tools)"; return; }
      [ -n "$phone" ] && { [ "$1" = android-app ] && [ ! -d android ] && echo "no android/ folder"; return; }
      [ "$phone_state" = unauthorized ] && { echo "the phone hasn't allowed this computer: unlock it and accept"; return; }
      echo "no Android phone on the cable" ;;
    iphone)
      [ -n "$iphone" ] || { mac && echo "no iPhone on the cable (unlocked and trusted?)" || echo "needs a Mac"; return; }
      [ -d ios ] || { echo "no ios/ folder"; return; }
      local sdk need major
      sdk=$(echo "$iphone" | cut -f5)
      need=$(grep -m1 -o 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*' ios/Runner.xcodeproj/project.pbxproj 2>/dev/null | awk '{print $3}')
      major=$(echo "$sdk" | grep -o '[0-9][0-9]*' | head -1)
      if [ -n "$need" ] && [ -n "$major" ] && [ "$major" -lt "${need%%.*}" ]; then
        echo "it runs $sdk; the app needs iOS $need or later"; return
      fi
      [ "$(echo "$iphone" | cut -f4)" = true ] || echo "Flutter says it isn't supported ($sdk)" ;;
    chrome) [ -n "$chrome_app" ] || echo "Chrome isn't installed here" ;;
    safari) [ -n "$safari" ] || echo "Safari is only on a Mac" ;;
    macos) [ -n "$macos_app" ] || { mac && echo "needs Xcode and a macos/ folder" || echo "not on a Mac"; } ;;
  esac
}

phones=()
computer=()
for p in "${want[@]}"; do
  w=$(why_not "$p")
  [ -n "$into" ] || { if [ -z "$w" ]; then echo "  ✓ $p"; else echo "  · $p: $w"; fi; }
  [ -n "$w" ] && continue
  case $p in android-*|iphone) phones+=("$p") ;; *) computer+=("$p") ;; esac
done
[ -n "$listing" ] && { rm -rf "$run"; exit 0; }

# --- The run's surroundings ---------------------------------------------------
[ -n "$into" ] || {
  echo "started   $(date)"
  echo "project   $project"
  echo "commit    $(git rev-parse HEAD 2>/dev/null) $(git status --porcelain 2>/dev/null | grep -q . && echo '(with uncommitted changes)')"
  echo "branch    $(git branch --show-current 2>/dev/null)"
  echo "test      $TARGET, driver $DRIVER, $MODE ${DEFINES[*]}"
  echo "computer  $(uname -a)"
  mac && sw_vers 2>/dev/null
  mac && sysctl -n machdep.cpu.brand_string 2>/dev/null
  mac && pmset -g batt 2>/dev/null | tail -1
  [ -n "$chrome_app" ] && echo "chrome    $("$chrome_app" --version 2>/dev/null)"
  [ -n "$safari" ] && echo "safari    $(defaults read /Applications/Safari.app/Contents/Info CFBundleShortVersionString 2>/dev/null)"
  command -v node >/dev/null && echo "node      $(node --version)"
  echo
  flutter --version 2>&1
  echo
  flutter doctor -v 2>&1
} >"$run/env.txt" 2>&1

flutter pub get >"$run/pub-get${into:+-computer}.log" 2>&1 || { echo "flutter pub get failed: $run/pub-get.log"; exit 1; }

# --- Helpers ------------------------------------------------------------------
bg_pids=()
bg() { "$@" & bg_pids+=($!); }
stop_bg() {
  for p in "${bg_pids[@]}"; do kill "$p" 2>/dev/null; done
  sleep 1
  for p in "${bg_pids[@]}"; do kill -9 "$p" 2>/dev/null; done
  bg_pids=()
}
lane=""
cleanup() { stop_bg; [ -n "$lane" ] && kill "$lane" 2>/dev/null; [ -x "$adb" ] && [ -n "$phone" ] && adb -s "$phone" reverse --remove-all >/dev/null 2>&1; }
trap cleanup EXIT
trap 'echo; echo "Stopped. What ran is in $run/"; exit 130' INT

# The ChromeDriver for Chrome [version], fetched once.
chromedriver_for() {
  command -v npx >/dev/null || return 1
  local d
  d=$(npx --yes @puppeteer/browsers install "chromedriver@$1" --path "$drivers" 2>/dev/null | awk 'END {print $NF}')
  [ -x "$d" ] || d=$(npx --yes @puppeteer/browsers install "chromedriver@${1%%.*}" --path "$drivers" 2>/dev/null | awk 'END {print $NF}')
  [ -x "$d" ] && echo "$d"
}

# The browser's console, out of ChromeDriver's verbose log.
console_from_chromedriver() {
  python3 - "$1" <<'EOF'
import json, re, sys
lines = open(sys.argv[1], errors='replace').read().split('\n')
stamp = re.compile(r'^\[[\d.:\-T ]+\]')
i = 0
while i < len(lines):
    line = lines[i]
    if 'Runtime.consoleAPICalled' in line or 'Log.entryAdded' in line or 'Runtime.exceptionThrown' in line:
        start = line.find('{')
        body = [line[start:]] if start >= 0 else []
        i += 1
        while i < len(lines) and not stamp.match(lines[i]):
            body.append(lines[i])
            i += 1
        try:
            e = json.loads('\n'.join(body))
        except ValueError:
            continue
        if 'args' in e:
            text = ' '.join(str(a.get('value', a.get('description', ''))) for a in e['args'])
            print(f"{e.get('type', 'log'):7} {text}")
        elif 'entry' in e:
            print(f"{e['entry'].get('level', 'log'):7} {e['entry'].get('text', '')}")
        elif 'exceptionDetails' in e:
            d = e['exceptionDetails']
            print(f"error   {d.get('exception', {}).get('description', d.get('text', ''))}")
        continue
    i += 1
EOF
}

android_info() {
  echo "== $(date)"
  for k in ro.product.manufacturer ro.product.model ro.build.version.release ro.build.version.sdk ro.hardware ro.board.platform; do
    echo "$k=$(adb -s "$phone" shell getprop $k | tr -d '\r')"
  done
  echo "screen: $(adb -s "$phone" shell wm size | tr -d '\r'), $(adb -s "$phone" shell wm density | tr -d '\r')"
  echo "refresh: $(adb -s "$phone" shell dumpsys display | grep -m3 -o 'fps=[0-9.]*\|renderFrameRate [0-9.]*' | tr '\n' ' ')"
  adb -s "$phone" shell dumpsys battery | grep -E 'level|temperature|status|AC powered|USB powered' | tr -d '\r'
  adb -s "$phone" shell dumpsys thermalservice 2>/dev/null | grep -E 'Thermal Status|mType=|mStatus' | head -20 | tr -d '\r'
  echo "chrome: $(adb -s "$phone" shell dumpsys package com.android.chrome | grep -m1 versionName | tr -d '\r ')"
}

# Runs flutter drive with [args] for [platform], stopped after LIMIT_MIN.
drive() {
  local p=$1
  shift
  local dir=$run/$p
  local out=${RESULT:-build/integration_response_data.json}
  rm -f "$out"
  echo "   running (stopped after $LIMIT_MIN minutes); leave the device alone"
  local t0=$SECONDS
  flutter drive -v $MODE "$@" "${DEFINES[@]}" --driver="$DRIVER" --target="$TARGET" >"$dir/drive.log" 2>&1 &
  local pid=$!
  ( sleep $((LIMIT_MIN * 60)) && { echo timedout >"$dir/.timedout"; kill "$pid" 2>/dev/null; } ) 2>/dev/null &
  local dog=$!
  wait "$pid"
  local rc=$?
  pkill -P "$dog" 2>/dev/null; kill "$dog" 2>/dev/null
  local took=$(( SECONDS - t0 ))
  local how
  if [ -f "$dir/.timedout" ]; then how="timed out"; rm -f "$dir/.timedout"
  elif [ $rc -eq 0 ]; then how=passed
  else how="failed (exit $rc)"; fi
  echo "$how in $((took / 60))m$((took % 60))s" >"$dir/status.txt"
  if [ -f "$out" ]; then
    cp "$out" "$dir/result.json"
    [ -n "$REPORT" ] && $REPORT "$dir/result.json" >"$dir/report.txt" 2>&1
  fi
  echo "   $how in $((took / 60))m$((took % 60))s: $dir/"
  if [ "$how" != passed ]; then
    grep -E -i 'error|exception|failed|unable|could not|timed out|denied|remote automation|signing|provision' "$dir/drive.log" \
      | grep -v -i 'debug\]\|0 errors' | tail -8 | sed 's/^/     /'
  fi
  ran+=("$p")
}

here_too=("${phones[@]}" "${computer[@]}")
if [ -z "$into" ] && [ -n "$lanes" ] && [ ${#phones[@]} -gt 0 ] && [ ${#computer[@]} -gt 0 ]; then
  # This computer's platforms in a copy of the project, beside the phones.
  copy=${TMPDIR:-/tmp}/devices-$(basename "$project")
  copy=${copy%/}
  echo "Phones and this computer side by side; this computer's lines start [here]."
  if command -v rsync >/dev/null; then
    rsync -a --delete --exclude /build --exclude /.dart_tool --exclude /.git ./ "$copy/"
  else
    rm -rf "$copy" && mkdir -p "$copy"
    tar -cf - --exclude ./build --exclude ./.dart_tool --exclude ./.git . | tar -C "$copy" -xf -
  fi
  ( cd "$copy" && DEVICES_DRIVERS="$drivers" bash "$self" --into "$project/$run" "${cli_defines[@]}" "${computer[@]}" 2>&1 \
      | while IFS= read -r l; do echo "[here] $l"; done ) &
  lane=$!
  here_too=("${phones[@]}")
fi

ran=()
for p in "${here_too[@]}"; do
  dir=$run/$p
  mkdir -p "$dir"
  case $p in
    android-chrome)
      chrome=$(adb -s "$phone" shell dumpsys package com.android.chrome | grep -m1 versionName | sed 's/.*versionName=//' | tr -d '\r')
      echo "== $p: $(adb -s "$phone" shell getprop ro.product.model | tr -d '\r'), Chrome $chrome"
      android_info >"$dir/device.txt" 2>&1
      if driver=$(chromedriver_for "$chrome"); then
        adb -s "$phone" logcat -c
        bg sh -c "exec adb -s '$phone' logcat -v threadtime >'$dir/device.log' 2>&1"
        adb -s "$phone" reverse tcp:8780 tcp:8780 >/dev/null
        bg "$driver" --port=4445 --verbose --log-path="$dir/driver.log"
        sleep 2
        drive "$p" -d web-server --web-hostname 127.0.0.1 --web-port 8780 \
          --browser-name=android-chrome --no-android-emulator --driver-port=4445
        stop_bg
        console_from_chromedriver "$dir/driver.log" >"$dir/console.log" 2>&1
        android_info >>"$dir/device.txt" 2>&1
      else
        echo "   couldn't fetch a ChromeDriver for Chrome $chrome (needs Node's npx)" | tee "$dir/status.txt"
      fi ;;
    android-app)
      echo "== $p: $(adb -s "$phone" shell getprop ro.product.model | tr -d '\r')"
      android_info >"$dir/device.txt" 2>&1
      adb -s "$phone" logcat -c
      bg sh -c "exec adb -s '$phone' logcat -v threadtime >'$dir/device.log' 2>&1"
      drive "$p" -d "$phone"
      stop_bg
      grep -E ' (flutter|DartVM|Flutter|AndroidRuntime) *:|FATAL|ANR' "$dir/device.log" >"$dir/console.log"
      android_info >>"$dir/device.txt" 2>&1 ;;
    iphone)
      id=$(echo "$iphone" | cut -f1)
      echo "== $p: $(echo "$iphone" | cut -f6), $(echo "$iphone" | cut -f5)"
      { echo "$iphone" | tr '\t' '\n'; echo; xcrun devicectl device info details --device "$id" 2>&1; } >"$dir/device.txt"
      if command -v idevicesyslog >/dev/null; then
        bg sh -c "exec idevicesyslog -u '$id' >'$dir/device.log' 2>&1"
      else
        echo "For the iPhone's own log: brew install libimobiledevice" >"$dir/device.log"
      fi
      drive "$p" -d "$id"
      stop_bg
      grep -E 'flutter: |Dart|EXC_|crash|Terminated' "$dir/drive.log" >"$dir/console.log" ;;
    chrome)
      chrome=$("$chrome_app" --version | awk '{print $NF}')
      echo "== $p $chrome on this computer, $WEB_SIZE"
      echo "Chrome $chrome" >"$dir/device.txt"
      if driver=$(chromedriver_for "$chrome"); then
        bg "$driver" --port=4446 --verbose --enable-chrome-logs --log-path="$dir/driver.log"
        sleep 2
        drive "$p" -d web-server --web-hostname 127.0.0.1 --web-port 8781 \
          --browser-name=chrome --no-headless --browser-dimension="$WEB_SIZE" --driver-port=4446
        stop_bg
        console_from_chromedriver "$dir/driver.log" >"$dir/console.log" 2>&1
      else
        echo "   couldn't fetch a ChromeDriver for Chrome $chrome (needs Node's npx)" | tee "$dir/status.txt"
      fi ;;
    safari)
      echo "== $p $(defaults read /Applications/Safari.app/Contents/Info CFBundleShortVersionString 2>/dev/null) on this Mac"
      echo "Safari $(defaults read /Applications/Safari.app/Contents/Info CFBundleShortVersionString 2>/dev/null)" >"$dir/device.txt"
      logs=$HOME/Library/Logs/com.apple.WebDriver
      before=$(ls "$logs" 2>/dev/null)
      bg /usr/bin/safaridriver --port 4447 --diagnose
      sleep 2
      drive "$p" -d web-server --web-hostname 127.0.0.1 --web-port 8782 \
        --browser-name=safari --driver-port=4447 --browser-dimension="$WEB_SIZE"
      stop_bg
      : >"$dir/driver.log"
      for f in $(ls "$logs" 2>/dev/null); do
        echo "$before" | grep -qx "$f" || { echo "== $f"; cat "$logs/$f"; } >>"$dir/driver.log"
      done
      echo "Safari's WebDriver doesn't pass on the page's console; see drive.log for the test's own output." >"$dir/console.log"
      if grep -q -i 'remote automation\|safaridriver --enable' "$dir/drive.log"; then
        echo "   Safari needs, once: Develop > Allow Remote Automation, and in a terminal: safaridriver --enable"
      fi ;;
    macos)
      name=$(grep -m1 '^PRODUCT_NAME' macos/Runner/Configs/AppInfo.xcconfig 2>/dev/null | sed 's/.*= *//')
      echo "== $p: the Mac app${name:+ ($name)}"
      { sw_vers; sysctl -n machdep.cpu.brand_string; system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Chipset|Resolution|Refresh|Type'; pmset -g therm 2>/dev/null; } >"$dir/device.txt" 2>&1
      [ -n "$name" ] && bg sh -c "exec log stream --style compact --level debug --predicate 'process == \"$name\"' >'$dir/device.log' 2>&1"
      drive "$p" -d macos
      stop_bg
      grep -E 'flutter: |Dart|crash|EXC_' "$dir/drive.log" >"$dir/console.log"
      pmset -g therm >>"$dir/device.txt" 2>&1 ;;
  esac
done

[ -n "$lane" ] && { wait "$lane"; lane=""; }
[ -n "$into" ] && exit 0

# --- The summary ----------------------------------------------------------------
done_here=()
for p in "${want[@]}"; do [ -f "$run/$p/result.json" ] && done_here+=("$p"); done
{
  echo "$(date): $TARGET, $MODE ${DEFINES[*]}"
  echo
  for p in "${want[@]}"; do
    if [ -f "$run/$p/status.txt" ]; then printf '  %-15s %s\n' "$p" "$(head -1 "$run/$p/status.txt")"
    else w=$(why_not "$p"); printf '  %-15s %s\n' "$p" "${w:+skipped: }${w:-did not finish: see its folder and the lines above}"; fi
  done
  if [ -n "$SUMMARY" ] && [ ${#done_here[@]} -gt 0 ]; then echo; $SUMMARY "$run" "${done_here[@]}"; fi
} >"$run/summary.txt" 2>&1
echo
cat "$run/summary.txt"
echo
echo "Everything is in $project/$run/ (also build/devices/latest/)."
[ ${#done_here[@]} -gt 0 ] || exit 1
