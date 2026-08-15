import Foundation
import Testing

@testable import StarkitCore

struct SeedingTests {
    @Test("everything the Shelf owns is written again, so the Vocabulary cannot drift")
    func shelfOwned() {
        #expect(Seeding.verdict(for: "src/starkit.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "src/starkit.gleam", destinationExists: false) == .vendor)
        #expect(Seeding.verdict(for: "src/entry.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "src/text.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "gleam.toml", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "SCRIPTING.md", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "test/link_test.gleam", destinationExists: true) == .vendor)
    }

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

    @Test("build/ is not seed content, however deep")
    func generatedIsSkipped() {
        #expect(Seeding.verdict(for: "build/packages/gleam.lock", destinationExists: false) == .skip)
        #expect(Seeding.verdict(for: "build/dev/javascript/starkit/entry.mjs", destinationExists: true) == .skip)
        #expect(Seeding.verdict(for: "build/gleam-prod-javascript.lock", destinationExists: false) == .skip)
    }

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

    @Test("only src/scripts/ is yours, not any directory called scripts")
    func ownershipIsByPath() {
        #expect(Seeding.verdict(for: "test/scripts/clean_test.gleam", destinationExists: true) == .vendor)
        #expect(Seeding.verdict(for: "scripts/work.gleam", destinationExists: true) == .vendor)
    }
}
