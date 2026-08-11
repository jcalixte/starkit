#!/usr/bin/env bash
# Builds Starkit, installs it into /Applications, seeds $STARKIT_HOME (default ~/.starkit), and
# launches it.
#
# Meant to be run again and again — after a Vocabulary change, after a rebuild, after nothing at
# all. The two halves of ~/.starkit are treated differently and that difference is the whole point
# of this script: the Shelf-owned files are vendored on every run so the Vocabulary can be upgraded
# without asking you to merge it by hand, and src/scripts/ — the half you write — is only ever
# written when a file is absent. An install never touches a Script you have edited.
#
# Set STARKIT_HOME to install the Scripts somewhere else, which is also how this script gets
# exercised against a machine that has never had Starkit without disturbing your real one.
set -euo pipefail

cd "$(dirname "$0")/.."

STARKIT_HOME="${STARKIT_HOME:-$HOME/.starkit}"
export STARKIT_HOME # gen-registry.sh reads it too, and both must agree on which home is being set up.
CONFIGURATION="${1:-release}"
DEST="/Applications/Starkit.app"

# Named, not just missing. Everything below needs the Toolchain, and a bare "command not found"
# from three lines down would blame the wrong thing.
#
# This resolves from the invoking shell's PATH, which is not how the app does it — a login-launched
# app gets a minimal PATH and asks the login shell instead (DESIGN.md §4, F9). The two can disagree,
# and only the app's answer matters at Summon time; this check exists to fail the install clearly,
# not to stand in for C12.
for tool in gleam bun; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "! The Toolchain is incomplete: '$tool' is not on this shell's PATH." >&2
		echo "  Install it, then run this again. If it is installed but your shell hides it," >&2
		echo "  $STARKIT_HOME/starkit.toml holds an override for exactly that case." >&2
		exit 1
	fi
done

./scripts/build.sh "$CONFIGURATION"

# A running bundle cannot be replaced underneath itself — the copy would swap out the executable
# the kernel is paging from. Quitting first also guarantees the instance running at the end is the
# one just installed, rather than the previous build still holding ⌃⌘K.
if pgrep -x Starkit >/dev/null 2>&1; then
	echo "Quitting the running Starkit…"
	pkill -x Starkit || true
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		pgrep -x Starkit >/dev/null 2>&1 || break
		sleep 0.2
	done
fi

# Removed rather than copied over: `ditto` merges directories, so a file dropped from the bundle
# would linger in the installed copy forever. `ditto` rather than `cp -R` because it is the
# documented way to copy a bundle with its metadata intact, and the code signature is the one thing
# here that must survive the trip (T0.2).
rm -rf "$DEST"
ditto build/Starkit.app "$DEST"
codesign --verify --strict "$DEST"
echo "→ $DEST (signature verified)"

# One rule, applied by path: src/scripts/ is yours, everything else under seed/ is the Shelf's.
# Derived from the directory rather than a list, so a file added to seed/ later is vendored without
# anyone having to remember this script exists.
#
# Vendored files are compared before being written. Copying an identical file would still move its
# mtime, and starkit.gleam is a shared module — a moved mtime there marks every Script Stale and
# makes the next Summon rebuild all five for no reason. Same reasoning as gen-registry.sh.
vendored=0
kept=0
seeded=0
while IFS= read -r rel; do
	src="seed/$rel"
	dst="$STARKIT_HOME/$rel"
	mkdir -p "$(dirname "$dst")"

	case "$rel" in
	src/scripts/*)
		if [ -e "$dst" ]; then
			kept=$((kept + 1))
			continue
		fi
		cp "$src" "$dst"
		echo "+ $rel seeded"
		seeded=$((seeded + 1))
		;;
	*)
		if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
			continue
		fi
		cp "$src" "$dst"
		echo "→ $rel vendored"
		vendored=$((vendored + 1))
		;;
	esac
done < <(cd seed && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | LC_ALL=C sort)

echo "= $STARKIT_HOME: $vendored vendored, $seeded seeded, $kept of yours left alone"

./scripts/gen-registry.sh

# The first build. Warm on every install afterwards, so this is the one that pays for resolving
# dependencies — and the one that proves the seeded Scripts actually compile.
echo "Building the Scripts…"
build_status=0
(cd "$STARKIT_HOME" && gleam build) || build_status=$?

open "$DEST"

if [ "$build_status" -ne 0 ]; then
	# Installed and launched regardless. An app in the menu bar that refuses the broken Script is
	# more useful than no app at all, and being visibly broken is the design's answer to this
	# (DESIGN.md §4, F10). Still a failed install, so it exits like one.
	echo "! Starkit is installed and running, but your Scripts do not compile — see above." >&2
	exit 1
fi

echo "✓ Starkit is installed and running. ⌃⌘K summons it once slice 2 lands."
