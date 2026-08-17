# Starkit dev tasks — run `just` to list them.

# The homebrew-tap checkout the cask is written to (the real `brew install` source). Defaults to the
# sibling ../homebrew-tap; override with the STARKIT_TAP env var.
tap := env_var_or_default("STARKIT_TAP", justfile_directory() / ".." / "homebrew-tap")

_default:
    @just --list

# The registry is generated and never committed, so the seed does not typecheck until it has been
# written — the same order install.sh and CI use.

# The pure rules, in Swift and in Gleam, then the contract between them.
test:
    swift format lint --recursive Sources Tests Package.swift
    swift test
    swift build
    STARKIT_HOME="{{justfile_directory()}}/seed" "$(swift build --show-bin-path)/Starkit" registry
    cd seed && gleam format --check src test && gleam test
    STARKIT_HOME="{{justfile_directory()}}/seed" "$(swift build --show-bin-path)/Starkit" describe

# build/Starkit.app, signed with whatever identity this keychain holds.
build:
    ./scripts/build.sh debug

# Signed with the Developer ID, notarized, stapled, zipped.
release:
    ./scripts/release.sh

# Finish a submission Apple accepted after the wait died, without rebuilding.
staple:
    ./scripts/release.sh --staple-only

# The version has to be committed in Info.plist and pushed first. The notes are written from the
# commit subjects since the last tag; pass a file to say it yourself — see scripts/publish.sh.

# Build, notarize, tag, release, cask: `just publish 0.4.0`.
publish version notes="":
    STARKIT_TAP="{{tap}}" ./scripts/publish.sh {{version}} {{notes}}

# The half after the zip, for a release whose notarization outlived the wait.
ship version notes="":
    STARKIT_TAP="{{tap}}" ./scripts/publish.sh --ship-only {{version}} {{notes}}
