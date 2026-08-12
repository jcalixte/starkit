import Foundation
import Testing

@testable import StarkitCore

/// Reading `manifests.json` — F2's whole surface, and the one file that outlives the version of
/// Starkit that wrote it. A decode that throws is a bar with no **Scripts** in it, which looks
/// exactly like the machine state the cache exists to survive.
struct ManifestTests {
    private func read(_ json: String) throws -> [Manifest] {
        try Manifest.all(reply: Data(json.utf8), diagnostics: nil, exitStatus: 0)
    }

    @Test("a cache written before asks existed still lists every Script")
    func olderCacheDecodes() throws {
        let scripts = try read(
            """
            [{"keyword":"work","name":"Work","needs":[]},
             {"keyword":"clean","name":"Clean","needs":["running_apps"]}]
            """
        )
        #expect(scripts.map(\.keyword) == ["work", "clean"])
        // Absent is the same answer as `Decides`, so an older cache lists Youtube and runs it on one
        // ↩ until the first `describe` replaces the file.
        #expect(scripts.allSatisfy { $0.asks == nil })
    }

    @Test("a Script that Asks carries its question, and one that Decides carries nothing")
    func asksCrossesTheWire() throws {
        let scripts = try read(
            """
            [{"keyword":"youtube","name":"Youtube","needs":[],"asks":"YouTube URL"},
             {"keyword":"work","name":"Work","needs":[],"asks":null}]
            """
        )
        #expect(scripts[0].asks == "YouTube URL")
        #expect(scripts[1].asks == nil)
    }

    // The Gleam half writes null rather than "" for exactly this reason: a Script may ask a question
    // with no label, and "" meaning "no question" would run it without asking.
    @Test("an empty question is a question, not the absence of one")
    func emptyQuestionIsStillAQuestion() throws {
        let scripts = try read(#"[{"keyword":"work","name":"Work","needs":[],"asks":""}]"#)
        #expect(scripts[0].asks == "")
    }
}
