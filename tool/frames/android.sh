#!/bin/bash
# The frame benchmark (integration_test/frames_test.dart) on an Android
# phone, in its Chrome, driven from this computer over the USB cable:
# every scene played and each frame timed on the phone, its drawing
# included. The phone loads the game from this computer over the cable
# (adb reverse), so no Wi-Fi is needed.
#
# Once, on the phone: Settings > About phone, tap Build number seven times
# (Developer options); then Settings > System > Developer options, turn on
# USB debugging; plug it in and allow this computer when it asks.
# Needs Node (npx) here, to fetch the ChromeDriver that matches the phone's
# Chrome.
#
# Then, from the repository:  bash tool/frames/android.sh
# The report is build/android-frames.txt (the raw numbers build/frames.json).
set -uo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/drivers

adb=$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")
[ -x "$adb" ] || { echo "No adb: install Android's platform tools."; exit 1; }
export PATH="$(dirname "$adb"):$PATH"   # ChromeDriver finds the phone through adb

state=$(adb devices | awk 'NR>1 && $2 {print $2; exit}')
case "$state" in
  device) ;;
  unauthorized) echo "Unlock the phone and allow this computer (USB debugging), then run this again."; exit 1 ;;
  *) echo "No phone: plug it in, with USB debugging on (see the top of this file)."; exit 1 ;;
esac

chrome=$(adb shell dumpsys package com.android.chrome | grep -m1 versionName | sed 's/.*versionName=//' | tr -d '\r')
[ -n "$chrome" ] || { echo "No Chrome on the phone."; exit 1; }
echo "The phone's Chrome is $chrome; fetching the ChromeDriver for it."
command -v npx >/dev/null || { echo "Needs Node's npx to fetch ChromeDriver."; exit 1; }
driver=$(npx --yes @puppeteer/browsers install "chromedriver@$chrome" --path "$PWD/build/drivers" 2>/dev/null | awk 'END {print $NF}')
if [ ! -x "$driver" ]; then
  driver=$(npx --yes @puppeteer/browsers install "chromedriver@${chrome%%.*}" --path "$PWD/build/drivers" 2>/dev/null | awk 'END {print $NF}')
fi
[ -x "$driver" ] || { echo "Couldn't fetch a ChromeDriver for Chrome $chrome."; exit 1; }

# The phone's 127.0.0.1:8780 is this computer's, over the cable. (The
# address, not "localhost": here that can mean IPv6, which adb doesn't
# forward to.)
adb reverse tcp:8780 tcp:8780 || { echo "adb couldn't forward the port to the phone."; exit 1; }
adb reverse --list | grep -q 8780 || { echo "The port isn't forwarded to the phone."; exit 1; }
"$driver" --port=4445 >build/chromedriver.log 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null; adb reverse --remove tcp:8780 >/dev/null 2>&1' EXIT
sleep 2

echo "The game opens in Chrome on the phone. Leave it alone until it's done (about 10 minutes)."
flutter pub get >/dev/null
flutter drive --profile -d web-server --web-hostname 127.0.0.1 --web-port 8780 \
  --browser-name=android-chrome --driver-port=4445 \
  --dart-define=FRAMES_REAL_DEVICE=true \
  --driver=test_driver/frames_driver.dart --target=integration_test/frames_test.dart \
  2>&1 | tee build/android-drive.txt

if [ -f build/frames.json ]; then
  python3 tool/frames/report.py build/frames.json | tee build/android-frames.txt
else
  echo "No numbers came back: the end of build/android-drive.txt says why."
fi
