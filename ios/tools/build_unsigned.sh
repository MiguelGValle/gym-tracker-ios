#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v xcodebuild >/dev/null || { echo 'Requires macOS with Xcode.' >&2; exit 1; }
python3 tools/generate_project.py
BUILD_DIR="$ROOT/build"
mkdir -p "$BUILD_DIR"
xcodebuild -project GymTracker.xcodeproj -scheme GymTracker -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -archivePath "$BUILD_DIR/GymTracker.xcarchive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive
APP="$BUILD_DIR/GymTracker.xcarchive/Products/Applications/GymTracker.app"
test -f "$APP/GymTracker"
ARCHS="$(xcrun lipo -archs "$APP/GymTracker")"
case " $ARCHS " in
  *" arm64 "*) ;;
  *) echo "Device binary does not contain arm64 (found: $ARCHS)." >&2; exit 1 ;;
esac
PACKAGE_DIR="$(mktemp -d "$BUILD_DIR/package.XXXXXX")"
mkdir "$PACKAGE_DIR/Payload"
ditto "$APP" "$PACKAGE_DIR/Payload/GymTracker.app"
(cd "$PACKAGE_DIR" && /usr/bin/zip -qr "$PACKAGE_DIR/GymTracker-unsigned.ipa" Payload)
mv "$PACKAGE_DIR/GymTracker-unsigned.ipa" "$BUILD_DIR/GymTracker-unsigned.ipa"
python3 - "$BUILD_DIR/GymTracker-unsigned.ipa" <<'PY'
import plistlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as package:
    info = plistlib.loads(package.read('Payload/GymTracker.app/Info.plist'))
    assert info['CFBundleIdentifier'] == 'com.codex.gymtracker'
    assert 'Payload/GymTracker.app/GymTracker' in package.namelist()
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
print('IPA checked: device binary; not signed. Sign with your own Apple account before installing.')
PY
shasum -a 256 "$BUILD_DIR/GymTracker-unsigned.ipa" > "$BUILD_DIR/GymTracker-unsigned.ipa.sha256"
printf 'Output: %s\n' "$BUILD_DIR/GymTracker-unsigned.ipa"

