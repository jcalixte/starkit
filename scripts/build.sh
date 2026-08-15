#!/usr/bin/env bash
# Compiles Starkit and assembles build/Starkit.app.
#
# Signs with a Developer ID Application identity if the keychain holds one, and with the self-signed
# certificate from setup-signing.sh otherwise. Set STARKIT_IDENTITY to override both, e.g. with an
# "Apple Development: …" certificate you already have. Any stable identity works; the only thing that
# matters is that it does not change between builds, so TCC keeps the Accessibility grant that Paste
# needs — and changing which identity signs costs one re-tick in System Settings.
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${STARKIT_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
	# A Developer ID when the machine has one, because its designated requirement is the same on
	# every machine and across every release, where "Starkit Self-Signed" is one keychain's only.
	#
	# `find-identity -v` rather than `find-certificate`, because a Developer ID is trusted and shows
	# up there — which is exactly what the self-signed certificate does not do (see
	# setup-signing.sh), and why the two are looked for in different ways.
	found="$(security find-identity -v -p codesigning 2>/dev/null |
		sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p')"
	if [ "$(printf '%s' "$found" | grep -c . || true)" -gt 1 ]; then
		echo "! This keychain holds more than one Developer ID Application identity:" >&2
		echo "$found" | sed 's/^/    /' >&2
		echo "  Set STARKIT_IDENTITY to the one that signs Starkit. Picking for you would risk" >&2
		echo "  changing the app's designated requirement, which drops the Accessibility grant." >&2
		exit 1
	fi
	IDENTITY="${found:-Starkit Self-Signed}"
fi

# What notarization requires and the self-signed path cannot have: a secure timestamp, so the
# signature outlives the certificate, and the hardened runtime. Kept off the self-signed path
# deliberately — there is no timestamp authority a self-signed certificate can reach, and turning
# the runtime on there would change the designated requirement for nothing gained.
case "$IDENTITY" in
"Developer ID Application:"*) SIGN_OPTIONS=(--options runtime --timestamp) ;;
*) SIGN_OPTIONS=(--timestamp=none) ;;
esac

APP="build/Starkit.app"
CONFIGURATION="${1:-release}"
# Read from Info.plist rather than repeated here: the bundle identifier appears in the app's
# designated requirement, so a copy that drifted from the plist would change the requirement and
# silently invalidate the Accessibility grant.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"

swift build -c "$CONFIGURATION"
BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/Starkit"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Starkit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' >"$APP/Contents/PkgInfo"

# The seed content, carried inside the bundle so a copy nobody ran install.sh for can still set up a
# home (Slice 8). Before codesign for the same reason the icon is: a file dropped in afterwards
# invalidates the signature.
#
# `build/` is excluded here rather than by Seeding's rule alone, so 3 MB of one machine's Artefacts
# never reaches a signed bundle in the first place — the rule is the guarantee, this is the size.
#
# src/registry.gleam is excluded for a different reason: it is generated per home, not committed, and
# a copy of one machine's would name Scripts the home being set up does not have. Seeding skips it
# too, so a bundle that somehow carried one would still not vendor it.
rsync -a --delete --exclude 'build/' --exclude '.DS_Store' --exclude 'src/registry.gleam' \
	seed/ "$APP/Contents/Resources/seed/"

# The icon, drawn by the app itself from the same path the bar's mark uses, then packed by iconutil —
# the only tool that writes .icns. Before codesign, because an unsigned file dropped into the bundle
# afterwards invalidates the signature. The iconset goes away once packed: what matters is inside the
# bundle, and a stale PNG left in build/ is a file nothing rebuilds.
ICONSET="build/Starkit.iconset"
rm -rf "$ICONSET"
"$BINARY" icon "$ICONSET" >/dev/null
iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/Starkit.icns"
rm -rf "$ICONSET"

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
	codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "${SIGN_OPTIONS[@]}" "$APP"
	echo "✓ Signed with '$IDENTITY' — the Accessibility grant survives rebuilds."
else
	codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
	echo "! No '$IDENTITY' certificate found, so this build is signed ad-hoc."
	echo "  Every rebuild will reset Accessibility, so Paste will stop working."
	echo "  Run scripts/setup-signing.sh once to fix that."
fi

echo "→ $APP"
