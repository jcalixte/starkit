#!/usr/bin/env bash
# Turns a notarized build into a release people can install: the tag, the GitHub Release, and the
# cask that `brew install --cask jcalixte/tap/starkit` reads.
#
#   ./scripts/publish.sh 0.4.0            build, notarize, tag, release, cask
#   ./scripts/publish.sh 0.4.0 notes.md   the same, with prose you wrote instead of the generated notes
#   ./scripts/publish.sh --ship-only 0.4.0 [notes.md]   everything after the zip
#
# The notes are written from the commit subjects of everything since the last tag, which works here
# only because the subjects are sentences. `gh --generate-notes` is not what does it: GitHub builds
# that from merged pull requests, and a repo pushed straight to main has none, so it returns a
# compare link and nothing else. Hand it a file when a release deserves paragraphs.
#
# The version bump it will not do for you. Resources/Info.plist is checked, not edited, so the
# subject line that says what the version is *for* stays a commit somebody wrote.
#
# --ship-only exists for the same reason release.sh has --staple-only: Apple's notary queue has no
# SLA, so the half of a release that talks to Apple and the half that talks to GitHub have to be
# separately runnable. It takes the zip already in build/ and never rebuilds — a rebuild re-signs
# with a new timestamp, which is a different app from the one the notary ticket was issued against.
#
# The tap is a checkout, not an API call — the cask is a file in another repo and this pushes it.
# Expected at $STARKIT_TAP, defaulting to the sibling ../homebrew-tap.
set -euo pipefail

cd "$(dirname "$0")/.."

SHIP_ONLY=no
if [ "${1:-}" = "--ship-only" ]; then
	SHIP_ONLY=yes
	shift
fi

VERSION="${1:?usage: ./scripts/publish.sh [--ship-only] <version> <notes-file>}"
VERSION="${VERSION#v}"
NOTES="${2:-}"

TAG="v$VERSION"
REPO="jcalixte/starkit"
APP="build/Starkit.app"
ZIP="build/Starkit-$VERSION.zip"
TAP="${STARKIT_TAP:-$(cd .. && pwd)/homebrew-tap}"
CASK="$TAP/Casks/starkit.rb"
GH="${GH:-gh}"

die() {
	echo "! $*" >&2
	exit 1
}

WORK="$(mktemp -d -t starkit-publish)"
trap 'rm -rf "$WORK"' EXIT

# The release notes, when none were handed over: the subjects of the commits this tag contains.
#
# Only the types that describe what changed for someone deciding whether to upgrade. `chore: 0.4.0`
# and `docs:` are answers to a question they did not ask, and both are one click away under Full
# Changelog — which is the same reason this reads the log rather than every file that moved.
#
# Run after the tag exists, because the range is measured from it.
generate_notes() {
	local previous range changed
	previous="$(git describe --tags --abbrev=0 "$TAG^" 2>/dev/null || true)"
	range="${previous:+$previous..}$TAG"

	changed="$(git log --reverse --format='%s' "$range" |
		sed -n -E 's/^(feat|fix|perf|refactor)(\([^)]+\))?: /- /p')"
	# A release with nothing under those types is a documentation or packaging one, and saying so is
	# better than a heading with nothing under it.
	[ -n "$changed" ] || changed="- Documentation and packaging."

	printf '## What changed\n\n%s\n\n' "$changed"
	printf 'Signed with a Developer ID, notarized and stapled.\n'
	if [ -n "$previous" ]; then
		printf '\n**Full Changelog**: https://github.com/%s/compare/%s...%s\n' \
			"$REPO" "$previous" "$TAG"
	fi
}

# Everything that can be refused before anything is built, tagged or uploaded. A release that fails
# halfway leaves a tag pointing at a commit with no download behind it, which is the one state here
# that has to be cleaned up by hand.
command -v "$GH" >/dev/null || die "gh is not on PATH — set GH=/path/to/gh, or brew install gh."
# Only when one was named. Asked here rather than at the point of use, so a typo'd path is not
# found out after the tag has been pushed.
[ -z "$NOTES" ] || [ -s "$NOTES" ] || die "$NOTES is empty or not there."
[ -f "$CASK" ] || die "No cask at $CASK. Set STARKIT_TAP to your homebrew-tap checkout."

[ "$(git symbolic-ref --short HEAD)" = "main" ] || die "Not on main."
[ -z "$(git status --porcelain)" ] || die "The working tree is not clean."
git fetch --tags --quiet origin
git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null && die "$TAG already exists."
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
	die "HEAD is not origin/main — push the version bump first."

# The plist is the one place the version lives: build.sh and release.sh both read it, and the zip is
# named from it. Checked rather than written, so what is released is what was committed.
IN_PLIST="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
[ "$IN_PLIST" = "$VERSION" ] ||
	die "Info.plist says $IN_PLIST, not $VERSION. Bump it, commit it, push it, then publish."

[ -z "$(git -C "$TAP" status --porcelain)" ] || die "The tap at $TAP is not clean."
git -C "$TAP" pull --ff-only --quiet

if [ "$SHIP_ONLY" = no ]; then
	./scripts/release.sh
fi

# True on the --ship-only path and false nowhere else, but asked either way: this is what stands
# between a resumed release and one that quietly ships an older build under a newer tag.
[ -f "$ZIP" ] || die "$ZIP is not there. Run without --ship-only, or ./scripts/release.sh."
xcrun stapler validate "$APP" >/dev/null 2>&1 ||
	die "$APP has no notary ticket stapled. ./scripts/release.sh --staple-only finishes that."

# The tag names the commit the build came from, so it is pushed before the release that refers to
# it. One push reaches both remotes — origin carries a pushurl for each.
git tag "$TAG"
git push origin "$TAG"

if [ -z "$NOTES" ]; then
	NOTES="$WORK/notes.md"
	generate_notes >"$NOTES"
	# Printed rather than trusted: what a release says is the only part of it nobody can check by
	# running the app, and this is the last moment before it is public.
	echo "→ notes, from the commits since the last tag:"
	sed 's/^/  /' "$NOTES"
fi

"$GH" release create "$TAG" "$ZIP" --repo "$REPO" \
	--title "Starkit $VERSION" --notes-file "$NOTES"

# Hashed from what GitHub serves rather than from the file on this disk. They are the same bytes
# right up until they are not, and the cask is the only part of a release nobody checks by using it:
# a wrong sha256 fails at `brew install` on someone else's machine, days later.
SERVED="$WORK/served.zip"
curl -fsSL -o "$SERVED" "https://github.com/$REPO/releases/download/$TAG/Starkit-$VERSION.zip"
SHA="$(shasum -a 256 "$SERVED" | cut -d' ' -f1)"
[ "$SHA" = "$(shasum -a 256 "$ZIP" | cut -d' ' -f1)" ] ||
	die "What GitHub is serving is not what was uploaded. The release is up; the cask is not bumped."

# Two lines, and nothing else in the cask moves: the url interpolates #{version}, and the
# dependencies, uninstall, zap and caveats are the same release to release.
sed -i.bak -E \
	-e "s#(version \")[0-9]+\.[0-9]+\.[0-9]+(\")#\1$VERSION\2#" \
	-e "s#(sha256 \")[0-9a-f]{64}(\")#\1$SHA\2#" \
	"$CASK"
rm -f "$CASK.bak"
grep -q "\"$VERSION\"" "$CASK" && grep -q "$SHA" "$CASK" ||
	die "The cask did not take the bump — $CASK is edited but not committed."

git -C "$TAP" add Casks/starkit.rb
git -C "$TAP" commit -m "starkit $VERSION"
git -C "$TAP" push

echo "✓ Starkit $VERSION — https://github.com/$REPO/releases/tag/$TAG"
echo "  brew upgrade --cask starkit reads $SHA"
