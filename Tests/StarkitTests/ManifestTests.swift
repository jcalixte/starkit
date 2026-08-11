import Foundation
import Testing

@testable import StarkitCore

/// Reading `manifests.json` — which is F2's whole surface, and the one file that outlives the
/// version of Starkit that wrote it.
///
/// Tested because the failure is silent in the way F2 exists to prevent: the cache is read at launch
/// before anything else, and a decode that throws is a bar with no **Scripts** in it. That looks
/// exactly like a machine where nothing compiles, which is the state the cache is there to survive.
/// `asks` arrived at T5.1 and is the first field this file has ever gained, so it is also the first
/// time the question could be asked at all.
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
        // Absent is the same answer as `Decides`, which is what makes the upgrade silent in the
        // right direction: an older cache lists Youtube and runs it on one ↩ until the first
        // `describe` replaces the file.
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
    // with no label, and an empty string that meant "no question" would run it without asking.
    @Test("an empty question is a question, not the absence of one")
    func emptyQuestionIsStillAQuestion() throws {
        let scripts = try read(#"[{"keyword":"work","name":"Work","needs":[],"asks":""}]"#)
        #expect(scripts[0].asks == "")
    }
}
