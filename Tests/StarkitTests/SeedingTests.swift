import Foundation
import Testing

@testable import StarkitCore

/// Which half of a home an install owns. The rule `install.sh` used to hold in a `case` statement,
/// pinned here because a Cask now applies it too and the two must not drift.
struct SeedingTests {
    @Test("everything the Shelf owns is written again, so the Vocabulary cannot drift")
    func shelfOwned() {
        // Present or absent makes no difference: the content is replaced either way, which is what
        // lets `starkit.gleam` gain a field without anyone merging by hand.
        #expect(Seeding.verdict(for: "src/starkit.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "src/starkit.gleam", destinationExists: false) == .vendor)
        #expect(Seeding.verdict(for: "src/entry.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "src/text.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "gleam.toml", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "SCRIPTING.md", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "test/link_test.gleam", destinationExists: true) == .vendor)
    }

    // The whole promise of an install being safe to run again and again.
    @Test("a Script you have edited is left alone")
    func yoursIsKept() {
        #expect(Seeding.verdict(for: "src/scripts/work.gleam", destinationExists: true) == .keep)
        #expect(Seeding.verdict(for: "src/scripts/clean.gleam", destinationExists: true) == .keep)
    }

    @Test("a Script that is not there yet is seeded once")
    func yoursIsSeeded() {
        #expect(Seeding.verdict(for: "src/scripts/work.gleam", destinationExists: false) == .seed)
        #expect(Seeding.verdict(for: "src/scripts/youtube.gleam", destinationExists: false) == .seed)
    }

    // 3 MB of one machine's Artefacts copied over another home's build/ is how a Script comes to look
    // built when it is not — and `git status` never showed it, because the root .gitignore matches
    // `build/` at any depth.
    @Test("build/ is not seed content, however deep")
    func generatedIsSkipped() {
        #expect(Seeding.verdict(for: "build/packages/gleam.lock", destinationExists: false) == .skip)
        #expect(Seeding.verdict(for: "build/dev/javascript/starkit/entry.mjs", destinationExists: true) == .skip)
        #expect(Seeding.verdict(for: "build/gleam-prod-javascript.lock", destinationExists: false) == .skip)
    }

    // Vendoring one machine's registry into another home would name Scripts that home does not have,
    // and rewriting the module marks every Artefact Stale. It is generated per home, so it is skipped
    // even when a build happens to have left one beside the seed.
    @Test("the registry is generated per home, never seeded")
    func registryIsPerHome() {
        #expect(Seeding.verdict(for: "src/registry.gleam", destinationExists: false) == .skip)
        #expect(Seeding.verdict(for: "src/registry.gleam", destinationExists: true) == .skip)
    }

    @Test(".DS_Store is nobody's content")
    func finderLeftovers() {
        #expect(Seeding.verdict(for: ".DS_Store", destinationExists: false) == .skip)
        #expect(Seeding.verdict(for: "src/scripts/.DS_Store", destinationExists: false) == .skip)
    }

    // `scripts` names the half you own only directly under src/. Anywhere else it is a directory the
    // Shelf happens to have called that, and ownership is decided by path rather than by name.
    @Test("only src/scripts/ is yours, not any directory called scripts")
    func ownershipIsByPath() {
        #expect(Seeding.verdict(for: "test/scripts/clean_test.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "scripts/work.gleam", destinationExists: true) == .vendor)
    }
}
