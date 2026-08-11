import Foundation
import Testing

@testable import StarkitCore

/// The four cases ADR 0002 turns on. Tested because the rule is what keeps one broken **Script**
/// from taking the other four down with it, and because a bug here is silent: it does not crash,
/// it just runs an **Artefact** that is not what is on disk, or refuses one that is.
///
/// The hashes here are stand-ins — the rule only ever asks whether two of them are equal, which is
/// exactly why it can be tested without a filesystem or a compiler.
struct StalenessTests {
    private let built = "aaaa"
    private let edited = "bbbb"

    @Test("a Script whose source has not changed since the build is current, and runs")
    func unchanged() {
        #expect(Staleness.of(source: built, asBuilt: built, artefactExists: true) == .current)
    }

    @Test("a source changed since the build is Stale")
    func sourceChanged() {
        #expect(Staleness.of(source: edited, asBuilt: built, artefactExists: true) == .sourceChanged)
    }

    @Test("a changed shared module is Stale, and says which")
    func sharedModuleChanged() {
        let staleness = Staleness.of(
            source: built,
            asBuilt: built,
            artefactExists: true,
            shared: [
                SharedModule(name: "registry.gleam", source: built, asBuilt: built),
                SharedModule(name: "starkit.gleam", source: edited, asBuilt: built),
            ]
        )
        #expect(staleness == .sharedModuleChanged("starkit.gleam"))
    }

    @Test("an Artefact that is not there is Stale")
    func artefactMissing() {
        #expect(
            Staleness.of(source: built, asBuilt: built, artefactExists: false) == .artefactMissing
        )
    }

    // Not one of the four, but the case the T1.4 defect arrived as. A file that was touched rather
    // than edited hashes the same, so it is current — where the mtime version of this rule saw an
    // edit and refused the Script permanently, because a rebuild had nothing to recompile and so
    // never moved the Artefact's mtime. This is the regression test for that.
    @Test("a source touched but not changed is current")
    func touchedNotEdited() {
        #expect(Staleness.of(source: built, asBuilt: built, artefactExists: true) == .current)
    }

    // A Script the last successful build never saw. It has no Artefact, so artefactMissing answers
    // first; the case exists to pin down that `nil` is not accidentally read as "matches".
    @Test("a Script the last build never compiled is Stale even if an Artefact is there")
    func neverBuilt() {
        #expect(Staleness.of(source: built, asBuilt: nil, artefactExists: true) == .sourceChanged)
    }

    // A Script's own source changing outranks a shared module changing: both are Stale, and the
    // message should name the file the person just edited rather than one they did not touch.
    @Test("a changed source is named ahead of a changed shared module")
    func sourceOutranksShared() {
        let staleness = Staleness.of(
            source: edited,
            asBuilt: built,
            artefactExists: true,
            shared: [SharedModule(name: "starkit.gleam", source: edited, asBuilt: built)]
        )
        #expect(staleness == .sourceChanged)
    }
}
