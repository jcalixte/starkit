#!/usr/bin/env bash
# Signs, notarizes and staples build/Starkit.app, then writes the zip that would be distributed.
#
# What this buys: Gatekeeper accepts the app on a machine that has never seen it, with no
# right-click-open and no `xattr -d`. What it does not buy: anything at all for a local install,
# which is why it is a separate script rather than a step in install.sh — nobody building their own
# copy needs Apple's opinion of it.
#
# Requires a Developer ID Application certificate (build.sh finds it) and notary credentials stored
# once under a keychain profile. Set STARKIT_NOTARY_PROFILE to use a different one.
set -euo pipefail

cd "$(dirname "$0")/.."

PROFILE="${STARKIT_NOTARY_PROFILE:-starkit-notary}"
CONFIGURATION="${1:-release}"
APP="build/Starkit.app"
# The version people will refer to the download by, read from the one place that already holds it.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ZIP="build/Starkit-$VERSION.zip"

# Named before anything is built or uploaded: the alternative is a submission that fails minutes
# later for a reason the notary service reports as an authentication error.
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
	echo "! No notary credentials are stored under the profile '$PROFILE'." >&2
	echo "  Store them once, with an app-specific password from appleid.apple.com:" >&2
	echo "    xcrun notarytool store-credentials $PROFILE \\" >&2
	echo "      --apple-id <your Apple ID> --team-id <your Team ID> --password <app-specific>" >&2
	exit 1
fi

./scripts/build.sh "$CONFIGURATION"

# Refused here rather than by Apple: notarization takes a Developer ID signature with a secure
# timestamp and the hardened runtime, and nothing else. build.sh already decides which identity
# signs, so this only reads back what it chose — an ad-hoc or self-signed build is a mistake worth
# catching before a five-minute round trip.
AUTHORITY="$(codesign -dv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
case "$AUTHORITY" in
"Developer ID Application:"*) ;;
*)
	echo "! $APP is signed by '$AUTHORITY', which notarization will not accept." >&2
	echo "  A Developer ID Application certificate has to be in the keychain — see build.sh." >&2
	exit 1
	;;
esac

# `ditto -c -k --sequesterRsrc --keepParent` is the documented way to zip a bundle for the notary
# service, and the only one that keeps the symlinks and resource forks a signed bundle needs in order
# to still verify at the other end.
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if ! xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait; then
	echo "! Notarization was refused. Read why with the submission id printed above:" >&2
	echo "    xcrun notarytool log <submission-id> --keychain-profile $PROFILE" >&2
	exit 1
fi

# The ticket is stapled into the *bundle*, so the zip that was submitted is not the zip that can be
# distributed — it has to be made again from the stapled app. Skipping this is how a download ends
# up needing the notary service to be reachable on first launch.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# The two questions a person downloading this would ask: is the ticket really attached, and would
# Gatekeeper open it. Asked of the app rather than the zip, because that is what gets launched.
xcrun stapler validate "$APP"
spctl -a -vvv --type exec "$APP"

echo "→ $ZIP (notarized and stapled)"
