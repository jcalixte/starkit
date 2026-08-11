#!/usr/bin/env bash
# Compiles Starkit and assembles build/Starkit.app.
#
# Signing is ad-hoc here. That is fine until Paste exists: Accessibility grants are tied to a
# code signature, and an ad-hoc signature changes on every build, so every rebuild would drop the
# grant. scripts/setup-signing.sh replaces this with a stable identity (T0.2).
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/Starkit.app"
CONFIGURATION="${1:-release}"

swift build -c "$CONFIGURATION"
BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/Starkit"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Starkit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' >"$APP/Contents/PkgInfo"

codesign --force --sign - --identifier dev.jclab.starkit "$APP"

echo "→ $APP"
