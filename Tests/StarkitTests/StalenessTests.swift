import Foundation
import Testing

@testable import StarkitCore

/// The four cases ADR 0002 turns on. Tested because the rule is what keeps one broken **Script**
/// from taking the other four down with it, and because a bug here is silent: it does not crash,
/// it just runs an **Artefact** that is not what is on disk, or refuses one that is.
struct StalenessTests {
    private let epoch = Date(timeIntervalSince1970: 1_000_000)
    private func later(_ seconds: TimeInterval) -> Date { epoch.addingTimeInterval(seconds) }

    @Test("an Artefact newer than its source is current, and runs")
    func artefactNewer() {
        #expect(Staleness.of(source: epoch, artefact: later(10)) == .current)
    }

    @Test("a source edited since the build is Stale")
    func sourceNewer() {
        #expect(Staleness.of(source: later(10), artefact: epoch) == .sourceChanged)
    }

    @Test("a shared module newer than the Artefact is Stale, and says which")
    func sharedModuleNewer() {
        let staleness = Staleness.of(
            source: epoch,
            artefact: later(10),
            shared: [
                SharedModule(name: "registry.gleam", modified: epoch),
                SharedModule(name: "starkit.gleam", modified: later(20)),
            ]
        )
        #expect(staleness == .sharedModuleChanged("starkit.gleam"))
    }

    @Test("an Artefact that is not there is Stale")
    func artefactMissing() {
        #expect(Staleness.of(source: epoch, artefact: nil) == .artefactMissing)
    }

    // The boundary is not one of the four, but it is the one a reader will wonder about: Gleam
    // writes the Artefact after reading the source, so identical mtimes mean built-from-this, and
    // treating them as Stale would rebuild every Script on every Summon for no reason.
    @Test("identical mtimes count as current, not Stale")
    func equalTimestamps() {
        #expect(Staleness.of(source: epoch, artefact: epoch) == .current)
    }

    // A Script's own source changing outranks a shared module changing: both are Stale, and the
    // message should name the file the person just edited rather than one they did not touch.
    @Test("a changed source is named ahead of a changed shared module")
    func sourceOutranksShared() {
        let staleness = Staleness.of(
            source: later(30),
            artefact: later(10),
            shared: [SharedModule(name: "starkit.gleam", modified: later(20))]
        )
        #expect(staleness == .sourceChanged)
    }
}
