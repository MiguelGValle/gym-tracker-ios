#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 tools/generate_project.py
mkdir -p build
DEVICE_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); phones=[p["udid"] for devices in d["devices"].values() for p in devices if "iPhone" in p["name"]]; assert phones, "No iPhone simulator is installed"; print(phones[0])')"
xcodebuild -project GymTracker.xcodeproj -scheme GymTracker -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -parallel-testing-enabled NO \
  -resultBundlePath "build/Tests-$(date +%s).xcresult" \
  CODE_SIGNING_ALLOWED=NO test
