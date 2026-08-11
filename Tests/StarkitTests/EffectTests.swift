import Foundation
import Testing

@testable import StarkitCore

/// Reading what a **Script** answered. Tested because both ways of getting it wrong are silent: a
/// misread reply either performs **Effects** nobody asked for, or **Refuses** a **Script** that did
/// nothing wrong. Neither crashes, and neither announces itself.
///
/// C4's other half — spawning `bun`, holding the 5 s deadline, draining two pipes — is not here and
/// should not be. It is a thin call into Foundation, where a mock would pass while the app was
/// broken, so it is verified by running it (SPEC.md § Testing strategy).
struct EffectTests {
    private func read(
        _ reply: String,
        diagnostics: String? = nil,
        exitStatus: Int32 = 0
    ) throws -> [Effect] {
        try Effect.all(
            inReplyTo: "work",
            reply: Data(reply.utf8),
            diagnostics: diagnostics,
            exitStatus: exitStatus
        )
    }

    // MARK: - The four words of the Vocabulary

    @Test("each Effect arrives under the field name the Vocabulary gave it")
    func everyKind() throws {
        let reply = """
            {"effects":[{"kind":"open","app":"Slack"},{"kind":"kill","app":"Notion"},\
            {"kind":"paste","text":"hello"},{"kind":"notify","message":"nothing to do"}]}
            """
        #expect(
            try read(reply) == [
                .open(app: "Slack"),
                .kill(app: "Notion"),
                .paste(text: "hello"),
                .notify(message: "nothing to do"),
            ]
        )
    }

    // CONTEXT.md: a Script emits Effects *in order*, and the Shelf performs them in order. Work's
    // last Open is the one that ends up frontmost, so a reordering here would be felt rather than
    // seen.
    @Test("Effects keep the order the Script decided on")
    func order() throws {
        let reply = """
            {"effects":[{"kind":"open","app":"Slack"},{"kind":"open","app":"Notion"},\
            {"kind":"open","app":"Ghostty"}]}
            """
        #expect(try read(reply) == [.open(app: "Slack"), .open(app: "Notion"), .open(app: "Ghostty")])
    }

    // T11's whole justification: gleam_json owns the escaping on the two paths that carry arbitrary
    // text, a page title into Paste and an error into Notify. This is the Swift end of that claim.
    @Test("text survives quotes, newlines, backslashes and multi-byte characters")
    func awkwardText() throws {
        let text = "He said \"go\"\n\tC:\\Users — naïve, 日本語, 🌟"
        let reply = try String(
            decoding: JSONSerialization.data(
                withJSONObject: ["effects": [["kind": "paste", "text": text]]]
            ),
            as: UTF8.self
        )
        #expect(try read(reply) == [.paste(text: text)])
    }

    @Test("a Script that decided on nothing answers with no Effects, not a Refusal")
    func nothingDecided() throws {
        #expect(try read(#"{"effects":[]}"#).isEmpty)
        // Not a shape entry.gleam writes — every reply carries one key or the other — but the seeded
        // work.gleam decides on nothing until you fill it in, and that is not a failure.
        #expect(try read("{}").isEmpty)
    }

    // MARK: - Refusals the child wrote itself

    @Test("a Refusal from entry.gleam is passed through in its own words")
    func refusalFromChild() {
        let reply = #"{"refusal":"No Script answers to the Keyword \"wrok\"."}"#
        let refusal = #expect(throws: Refusal.self) { try read(reply) }
        #expect(refusal?.reason == "No Script answers to the Keyword \"wrok\".")
        // Nothing to add: entry.gleam already said which and why, which is the whole of a Refusal.
        #expect(refusal?.detail == nil)
    }

    // run.mjs reports a Refusal twice on purpose — in the reply the Shelf decodes, and in the exit
    // code, for a person running it by hand. Reading the status as failure would turn every Refusal
    // into "the Script crashed" and lose the sentence explaining it.
    @Test("a non-zero exit with a good reply is the Refusal, not a crash")
    func refusalExitsNonZero() {
        let reply = #"{"refusal":"The payload for \"work\" is not the shape the Shelf promised."}"#
        let refusal = #expect(throws: Refusal.self) { try read(reply, exitStatus: 1) }
        #expect(refusal?.reason == "The payload for \"work\" is not the shape the Shelf promised.")
    }

    // MARK: - F12, a run that failed at runtime

    @Test("a Script that wrote nothing is reported with its own stderr")
    func crashedWithDiagnostics() {
        let trace = "error: deliberate\n at run (entry.mjs:124:41)"
        let refusal = #expect(throws: Refusal.self) {
            try read("", diagnostics: trace, exitStatus: 1)
        }
        #expect(refusal?.reason == "The Script \"work\" failed while it was running.")
        // Verbatim. There is nothing Starkit can add to a stack trace, and any paraphrase of one
        // would be worse than passing it through.
        #expect(refusal?.detail == trace)
    }

    @Test("a Script that wrote nothing at all still says something, naming the exit status")
    func crashedSilently() {
        let refusal = #expect(throws: Refusal.self) { try read("", diagnostics: nil, exitStatus: 9) }
        #expect(refusal?.reason == "The Script \"work\" failed while it was running.")
        #expect(refusal?.detail == "bun exited 9 without writing an answer.")
    }

    // MARK: - The two halves of the Vocabulary drifting

    // The Effect vocabulary is spelled twice, in two languages, with no generator between them. This
    // is the case that keeps that affordable: an Effect this Starkit does not know must be a loud
    // Refusal naming the word, never an Effect the Effector silently skips.
    @Test("an Effect this Starkit does not know is a Refusal, and the reply is not half-performed")
    func unknownKind() {
        let reply = """
            {"effects":[{"kind":"open","app":"Slack"},{"kind":"teleport","app":"Slack"}]}
            """
        let refusal = #expect(throws: Refusal.self) { try read(reply) }
        #expect(refusal?.reason == "Starkit could not read what \"work\" answered.")
        #expect(refusal?.detail?.contains("teleport") == true)
    }

    @Test("a reply that is not JSON at all is a Refusal about reading, not about the Script")
    func notJSON() {
        let refusal = #expect(throws: Refusal.self) { try read("Compiling starkit\n") }
        #expect(refusal?.reason == "Starkit could not read what \"work\" answered.")
    }

    @Test("an Effect missing the field its kind requires is a Refusal")
    func missingField() {
        let refusal = #expect(throws: Refusal.self) { try read(#"{"effects":[{"kind":"open"}]}"#) }
        #expect(refusal?.reason == "Starkit could not read what \"work\" answered.")
    }

    // MARK: - What --dry-run prints

    // Rendered as the Script author wrote it, in Gleam, because that is who reads it. Escaping is
    // what makes a Paste of two lines legible as one line of output rather than breaking the list.
    @Test("an Effect prints the way it was written in Gleam")
    func rendering() {
        #expect("\(Effect.open(app: "Slack"))" == #"Open("Slack")"#)
        #expect("\(Effect.kill(app: "Notion"))" == #"Kill("Notion")"#)
        #expect("\(Effect.notify(message: "offline"))" == #"Notify("offline")"#)
        #expect("\(Effect.paste(text: "two\nlines"))" == #"Paste("two\nlines")"#)
    }
}
