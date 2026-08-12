import Foundation
import Testing

@testable import StarkitCore

/// The payload a **Script** is handed, which is C8's half of the wire.
///
/// A **Need** under the wrong key, or a slice that arrives empty where it should be absent, produces
/// a **Script** that runs and decides from nothing — and `entry.gleam` cannot tell that apart from a
/// machine with nothing on it.
struct PayloadTests {
    /// Untyped on the way out because `#expect(throws:)` takes a closure.
    private func needs(_ declared: [String], for keyword: String) throws -> Set<Need> {
        try Need.all(declared, for: keyword)
    }

    private func json(_ payload: Payload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    @Test("a slice nobody declared is absent from the payload, not empty in it")
    func undeclaredSlicesAreAbsent() throws {
        let payload = Payload(input: "")
        #expect(try json(payload) == #"{"input":""}"#)
    }

    @Test("a declared slice arrives under the name entry.gleam decodes it by")
    func declaredSliceCrossesTheWire() throws {
        let payload = Payload(input: "", runningApps: ["Safari", "Zed"])
        #expect(try json(payload) == #"{"input":"","running_apps":["Safari","Zed"]}"#)
    }

    /// A **Script** that declares a **Need** and asks a question carries both, and neither field
    /// knows about the other — an **Input** is not a **Need** (T13).
    @Test("the Input and the Context travel together and separately")
    func inputAndContextAreBothCarried() throws {
        let payload = Payload(input: "everything", runningApps: ["Finder"])
        #expect(try json(payload) == #"{"input":"everything","running_apps":["Finder"]}"#)
    }

    @Test("declaring nothing needs nothing gathered")
    func nothingDeclaredGathersNothing() throws {
        #expect(try needs([], for: "work").isEmpty)
    }

    @Test("a declared Need is read under the name it crosses the wire by")
    func declaredNeedIsRecognised() throws {
        #expect(try needs(["running_apps"], for: "clean") == [.runningApps])
    }

    @Test("the same slice declared twice is gathered once")
    func repeatedNeedIsGatheredOnce() throws {
        #expect(try needs(["running_apps", "running_apps"], for: "clean") == [.runningApps])
    }

    /// Loud, not skipped: a **Script** handed nothing where it declared something still runs, and
    /// decides from an empty **Context** with no way to know that is not the truth about the machine.
    @Test("a Need this Starkit cannot gather is a Refusal naming the word and the Script")
    func unknownNeedIsRefused() throws {
        let refusal = #expect(throws: Refusal.self) { try needs(["windows"], for: "tidy") }
        #expect(refusal?.reason.contains("\"windows\"") == true)
        #expect(refusal?.reason.contains("\"tidy\"") == true)
        #expect(refusal?.detail?.contains("reinstall") == true)
    }

    /// One unknown word refuses the whole run: half a **Context** is not a smaller **Context**, it
    /// is a **Script** deciding on a machine that does not exist.
    @Test("a known Need beside an unknown one does not rescue the run")
    func oneUnknownNeedRefusesTheWholeRun() throws {
        #expect(throws: Refusal.self) {
            try needs(["running_apps", "windows"], for: "tidy")
        }
    }
}
