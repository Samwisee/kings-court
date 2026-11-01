#!/bin/bash
# The frame benchmark (integration_test/frames_test.dart) on every platform
# this computer can reach: an Android phone on the USB cable (its Chrome),
# Chrome here, and the Mac app. Each plays every animated scene and times
# each frame, its drawing included, on that platform's own hardware.
#
#     bash tool/perf.sh                  every platform found
#     bash tool/perf.sh android chrome   only these (android, chrome, macos)
#     bash tool/perf.sh --no-blur        a build with every blur turned off
#                                        (lib/skin/effects.dart), to compare
#
# Everything goes to build/perf/: a report a platform (android.txt,
# chrome.txt, macos.txt; -noblur when built so), its raw numbers (.json),
# flutter's own output (-drive.txt), and summary.txt with the platforms
# side by side.
#
# Once, for an Android phone: Settings > About phone, tap Build number
# seven times; Settings > System > Developer options, turn on USB
# debugging; plug it in and allow this computer. Needs Node (npx) to fetch
# the ChromeDriver that matches each Chrome. (An iPhone can't be driven
# like this: Flutter's Safari driving only reaches the Simulator.)
set -uo pipefail
cd "$(dirname "$0")/.."
out=build/perf
mkdir -p "$out" build/drivers

defines=(--dart-define=FRAMES_REAL_DEVICE=true)
tag=""
want=()
for a in "$@"; do
  case "$a" in
    --no-blur) defines+=(--dart-define=NO_BLUR=true); tag="-noblur" ;;
    android|chrome|macos) want+=("$a") ;;
    *) echo "Don't know \"$a\": the platforms are android, chrome and macos; the option --no-blur."; exit 1 ;;
  esac
done
wanted() { [ ${#want[@]} -eq 0 ] || [[ " ${want[*]} " == *" $1 "* ]]; }

ran=()
pids=()
trap 'for p in "${pids[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; command -v adb >/dev/null && adb reverse --remove-all >/dev/null 2>&1' EXIT

# Runs the benchmark with flutter drive's [args]; keeps its numbers as [name].
drive() {
  local name=$1$tag
  shift
  rm -f build/frames.json
  echo "   playing every scene (about 10 minutes); leave it alone"
  flutter drive --profile "$@" "${defines[@]}" \
    --driver=test_driver/frames_driver.dart --target=integration_test/frames_test.dart \
    >"$out/$name-drive.txt" 2>&1
  if [ -f build/frames.json ]; then
    cp build/frames.json "$out/$name.json"
    python3 tool/frames/report.py "$out/$name.json" >"$out/$name.txt"
    echo "   done: $out/$name.txt"
    ran+=("$name")
  else
    echo "   no numbers came back; the end of $out/$name-drive.txt:"
    tail -6 "$out/$name-drive.txt" | sed 's/^/     /'
  fi
}

# The ChromeDriver for Chrome [version], fetched once.
chromedriver_for() {
  command -v npx >/dev/null || return 1
  local d
  d=$(npx --yes @puppeteer/browsers install "chromedriver@$1" --path "$PWD/build/drivers" 2>/dev/null | awk 'END {print $NF}')
  [ -x "$d" ] || d=$(npx --yes @puppeteer/browsers install "chromedriver@${1%%.*}" --path "$PWD/build/drivers" 2>/dev/null | awk 'END {print $NF}')
  [ -x "$d" ] && echo "$d"
}

flutter pub get >/dev/null

# --- An Android phone on the cable --------------------------------------
if wanted android; then
  adb=$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")
  if [ -x "$adb" ]; then
    export PATH="$(dirname "$adb"):$PATH"   # ChromeDriver finds the phone through adb
    state=$(adb devices | awk 'NR>1 && $2 {print $2; exit}')
    if [ "$state" = device ]; then
      model=$(adb shell getprop ro.product.model | tr -d '\r')
      chrome=$(adb shell dumpsys package com.android.chrome | grep -m1 versionName | sed 's/.*versionName=//' | tr -d '\r')
      echo "== Android: $model, Chrome $chrome"
      if driver=$(chromedriver_for "$chrome"); then
        # The phone's 127.0.0.1:8780 is this computer's, over the cable.
        adb reverse tcp:8780 tcp:8780 >/dev/null
        "$driver" --port=4445 >"$out/android-chromedriver.log" 2>&1 &
        pids+=($!)
        sleep 2
        drive android -d web-server --web-hostname 127.0.0.1 --web-port 8780 \
          --browser-name=android-chrome --no-android-emulator --driver-port=4445
      else
        echo "   couldn't fetch a ChromeDriver for it (needs Node's npx)"
      fi
    elif [ "$state" = unauthorized ]; then
      echo "== Android: unlock the phone and allow this computer, then run this again"
    else
      echo "== Android: no phone on the cable"
    fi
  else
    echo "== Android: no adb (Android's platform tools)"
  fi
fi

# --- Chrome on this computer -------------------------------------------------
if wanted chrome; then
  app="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  [ -x "$app" ] || app=$(command -v google-chrome || true)
  if [ -n "$app" ] && [ -x "$app" ]; then
    chrome=$("$app" --version | awk '{print $NF}')
    echo "== Chrome $chrome on this computer, in a phone-sized window"
    if driver=$(chromedriver_for "$chrome"); then
      "$driver" --port=4446 >"$out/chrome-chromedriver.log" 2>&1 &
      pids+=($!)
      sleep 2
      drive chrome -d web-server --web-hostname 127.0.0.1 --web-port 8781 \
        --browser-name=chrome --no-headless --browser-dimension=412,915@2 --driver-port=4446
    else
      echo "   couldn't fetch a ChromeDriver for it (needs Node's npx)"
    fi
  else
    echo "== Chrome: not installed here"
  fi
fi

# --- The Mac app --------------------------------------------------------------
if wanted macos; then
  if [ "$(uname)" = Darwin ] && [ -d macos ]; then
    echo "== The Mac app"
    drive macos -d macos
  else
    echo "== The Mac app: not on a Mac"
  fi
fi

if [ ${#ran[@]} -gt 0 ]; then
  python3 tool/frames/summary.py "$out" "${ran[@]}" | tee "$out/summary.txt"
  echo
  echo "Everything is in $out/: summary.txt, and a report a platform."
else
  echo "Nothing ran: see above."
  exit 1
fi
