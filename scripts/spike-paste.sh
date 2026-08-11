#!/usr/bin/env bash
# Throwaway — T0.5. Builds, signs and launches the Paste spike, then follows its log.
#
# Signed with the same identity as Starkit for the same reason (T0.2): an Accessibility grant is
# bound to the signature, and an ad-hoc one changes on every build, so the spike would ask for
# permission again every time and never prove that the grant survives a rebuild. Its bundle
# identifier is its own, so the grant it collects is its own too.
#
# Delete this script, Sources/PasteSpike/ and the target in Package.swift at Checkpoint A.
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${STARKIT_IDENTITY:-Starkit Self-Signed}"
APP="build/PasteSpike.app"
BUNDLE_ID="dev.apoena.starkit-paste-spike"
LOG="/tmp/starkit-paste-spike.log"

swift build -c release --product PasteSpike
BINARY="$(swift build -c release --product PasteSpike --show-bin-path)/PasteSpike"

if pgrep -x PasteSpike >/dev/null 2>&1; then
	pkill -x PasteSpike || true
	for _ in 1 2 3 4 5; do
		pgrep -x PasteSpike >/dev/null 2>&1 || break
		sleep 0.2
	done
fi

# Rebuilt in place at the same path on every run: TCC keys the grant on the identifier and the
# signature, and keeping the path stable too removes the one variable that would muddy the result.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BINARY" "$APP/Contents/MacOS/PasteSpike"
printf 'APPL????' >"$APP/Contents/PkgInfo"

# Written here rather than kept in Resources/: nothing about this bundle should outlive the spike.
cat >"$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>PasteSpike</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleName</key><string>PasteSpike</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.0.0</string>
	<key>LSUIElement</key><true/>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
PLIST

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
	codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" --timestamp=none "$APP"
else
	echo "! No '$IDENTITY' certificate — run scripts/setup-signing.sh first, or this spike" >&2
	echo "  will re-ask for Accessibility on every build and prove nothing about the grant." >&2
	exit 1
fi

: >"$LOG"
# `open`, not the inner binary: launching the Mach-O from a shell makes the terminal the
# responsible process, so the Accessibility prompt would ask for the terminal instead — and a grant
# given to the terminal says nothing about what a bundle can do.
open "$APP"

cat <<'STEPS'

Paste spike running — ⌘V in the menu bar.

  1. If macOS asks for Accessibility, grant PasteSpike. No relaunch needed: the first run of
     this spike showed the grant reaching a process already running.
  2. Open TextEdit and put the caret in an empty document.
  3. Menu bar ⌘V → "Summon — activating". The panel should take the keyboard: type into it,
     which the non-activating mode cannot do.
  4. Press ↩. The text should land in TextEdit, and the log should show what handing
     activation back to TextEdit cost.
  5. Press ⌘V by hand — it should repeat, because the clipboard is deliberately not restored.
  6. For contrast, "Summon — non-activating": nothing can be typed, and the log shows
     `panel key = false`. That is the mode the Shelf cannot use.

Log below (^C to stop, `pkill -x PasteSpike` to quit the spike):

STEPS

tail -f "$LOG"
