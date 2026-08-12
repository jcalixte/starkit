#!/usr/bin/env bash
# Builds Starkit, installs it into /Applications, seeds $STARKIT_HOME (default ~/.starkit), and
# launches it.
#
# Meant to be run again and again. The two halves of ~/.starkit are treated differently: Shelf-owned
# files are vendored on every run so the Vocabulary upgrades without a hand merge, and src/scripts/ —
# the half you write — is only ever written when a file is absent. **An install never touches a
# Script you have edited.**
#
# Set STARKIT_HOME to install the Scripts somewhere else, which is also how this script gets
# exercised against a machine that has never had Starkit without disturbing your real one.
set -euo pipefail

cd "$(dirname "$0")/.."

STARKIT_HOME="${STARKIT_HOME:-$HOME/.starkit}"
export STARKIT_HOME # `Starkit registry` reads it too, and both must agree on which home is being set up.
CONFIGURATION="${1:-release}"
DEST="/Applications/Starkit.app"

# Named, not just missing: a bare "command not found" from three lines down would blame the wrong
# thing.
#
# Resolves from the invoking shell's PATH, which is *not* how the app does it — a login-launched app
# gets a minimal PATH and asks the login shell instead (DESIGN.md §4, F9). The two can disagree, and
# only the app's answer matters at Summon time; this fails the install clearly, it does not stand in
# for C12.
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

# Boot (F9). Asked for here rather than at first launch, because an install is the moment the whole
# promise was asked for — where a launch that registered itself would overrule someone who had just
# turned it off from the menu.
#
# Through the *installed* bundle, never build/'s copy: SMAppService registers whichever bundle the
# calling executable sits in, and that one is a build artefact this script deletes.
if ! "$DEST/Contents/MacOS/Starkit" start-at-login on; then
	echo "! Starkit is installed, but it will not come back after a reboot." >&2
	echo "  Turn 'Start at Login' on from the menu bar item, or allow it in" >&2
	echo "  System Settings > General > Login Items." >&2
fi

# One rule, applied by path: src/scripts/ is yours, everything else under seed/ is the Shelf's.
# Derived from the directory rather than a list, so a file added to seed/ later is vendored anyway.
#
# Vendored files are compared before being written, so an identical file keeps its mtime. No longer
# load-bearing — the Stale rule compares content now (ADR 0002) — but kept so an install does not
# touch what it did not change. Same reasoning as the registry's write-only-on-a-difference rule.
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
# seed/build/ is pruned, and it is the one exception to "a file added to seed/ later is vendored
# anyway". It is not seed content: `gleam build` puts it there when a measurement runs against seed/
# as a scratch $STARKIT_HOME (DESIGN.md §8), and 3 MB of one machine's compiled artefacts and .cache
# files would otherwise be copied straight over the build/ directory of the home being installed to.
# That is how a **Script** comes to look built when it is not. Invisible to `git status` — the root
# .gitignore's `build/` matches at any depth — so nothing else would have caught it.
done < <(cd seed && find . -path './build' -prune -o -type f ! -name '.DS_Store' -print |
	sed 's|^\./||' | LC_ALL=C sort)

echo "= $STARKIT_HOME: $vendored vendored, $seeded seeded, $kept of yours left alone"

# Through the installed bundle, and before the first build, because a fresh $STARKIT_HOME has no
# registry.gleam at all and `gleam build` would fail on the missing module. C6 does this on every save
# once Starkit is running; this is the one moment nothing is watching yet.
"$DEST/Contents/MacOS/Starkit" registry

# The first build: the one that pays for resolving dependencies, and that proves the seeded Scripts
# actually compile.
echo "Building the Scripts…"
build_status=0
(cd "$STARKIT_HOME" && gleam build) || build_status=$?

open "$DEST"

if [ "$build_status" -ne 0 ]; then
	# Installed and launched regardless: an app in the menu bar that refuses the broken Script is
	# more useful than no app at all (DESIGN.md §4, F10). Still exits as a failed install.
	echo "! Starkit is installed and running, but your Scripts do not compile — see above." >&2
	exit 1
fi

echo "✓ Starkit is installed and running. ⌃⌘K summons the bar — type a Keyword and press ↩."
