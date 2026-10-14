#!/bin/zsh
# Builds a Release app, signs it ad hoc for this Mac only (Sparkle included, inside-out, so dyld
# accepts the framework), and installs it in /Applications. For testing; use release.sh to ship.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD="$ROOT/build/local"

echo "▶ Building Release…"
xcodebuild -project "Transcriber.xcodeproj" -scheme "Transcriber" -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$BUILD/DerivedData" build \
  CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" 2>&1 | grep -E "error:|BUILD" || true
APP="$BUILD/DerivedData/Build/Products/Release/Transcriber.app"
[[ -d "$APP" ]] || { echo "Build failed: app not found"; exit 1; }

echo "▶ Signing ad hoc"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
sign() { codesign --force --sign - "$@"; }
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
sign "$APP"
codesign --verify --deep --strict "$APP"

echo "▶ Installing in /Applications"
pkill -x Transcriber || true
rm -rf /Applications/Transcriber.app
ditto "$APP" /Applications/Transcriber.app
echo "Done."
