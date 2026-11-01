#!/bin/bash
# The frame benchmark (integration_test/frames_test.dart) on a real iPhone,
# in its Safari, driven from this Mac by Apple's safaridriver: every scene
# played and each frame timed on the phone, its drawing included (CI has
# no GPU, so only a real phone shows that).
#
# Once, before the first run:
#   - on the iPhone: Settings > Safari > Advanced: turn on Web Inspector
#     and Remote Automation; plug it into the Mac, unlock it, and trust
#     the Mac if it asks; keep it on the same Wi-Fi as the Mac;
#   - on the Mac: safaridriver --enable   (asks for your password)
#
# Then, from the repository:  bash tool/frames/iphone.sh
# The report is build/iphone-frames.txt (the raw numbers build/frames.json).
# macOS may ask whether to let dart accept incoming connections: allow it,
# so the iPhone can load the game from this Mac.
set -uo pipefail
cd "$(dirname "$0")/../.."

ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
if [ -z "$ip" ]; then
  echo "This Mac has no Wi-Fi address: the iPhone needs to reach it over the same network."
  exit 1
fi
mkdir -p build

if ! pgrep -x safaridriver >/dev/null; then
  safaridriver -p 4444 >build/safaridriver.log 2>&1 &
  driver=$!
  trap 'kill $driver 2>/dev/null' EXIT
  sleep 2
fi

echo "Serving the game from $ip; it opens in Safari on the iPhone. Leave the phone alone until it's done (about 10 minutes)."
flutter pub get >/dev/null
flutter drive --profile -d web-server --web-hostname "$ip" --web-port 8780 \
  --browser-name=ios-safari --driver-port=4444 \
  --dart-define=FRAMES_REAL_DEVICE=true \
  --driver=test_driver/frames_driver.dart --target=integration_test/frames_test.dart \
  2>&1 | tee build/iphone-drive.txt

if [ -f build/frames.json ]; then
  python3 tool/frames/report.py build/frames.json | tee build/iphone-frames.txt
else
  echo "No numbers came back: the end of build/iphone-drive.txt says why."
fi
