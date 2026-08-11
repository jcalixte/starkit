#!/usr/bin/env bash
# Compiles Starkit and assembles build/Starkit.app.
#
# Set STARKIT_IDENTITY to sign with a different identity, e.g. an "Apple Development: …"
# certificate you already have. Any stable identity works; the only thing that matters is that it
# does not change between builds, so TCC keeps the Accessibility grant that Paste needs.
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${STARKIT_IDENTITY:-Starkit Self-Signed}"
APP="build/Starkit.app"
CONFIGURATION="${1:-release}"
# Read from Info.plist rather than repeated here. The bundle identifier appears in the app's
# designated requirement, so a copy that drifted from the plist would change the requirement and
# silently invalidate the Accessibility grant — the exact failure signing a stable identity is
# meant to prevent.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"

# `--product Starkit`, because the package also holds the throwaway PasteSpike target (T0.5) and a
# plain `swift build` would compile it into every Starkit build. Harmless to drop again once the
# spike is deleted at Checkpoint A.
swift build -c "$CONFIGURATION" --product Starkit
BINARY="$(swift build -c "$CONFIGURATION" --product Starkit --show-bin-path)/Starkit"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Starkit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' >"$APP/Contents/PkgInfo"

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
	codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" --timestamp=none "$APP"
	echo "✓ Signed with '$IDENTITY' — the Accessibility grant survives rebuilds."
else
	codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
	echo "! No '$IDENTITY' certificate found, so this build is signed ad-hoc."
	echo "  Every rebuild will reset Accessibility, so Paste will stop working."
	echo "  Run scripts/setup-signing.sh once to fix that."
fi

echo "→ $APP"
