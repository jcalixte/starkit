import Foundation
import StarkitCore

/// C4 — run one **Artefact** and collect what it decided.
///
/// A fresh `bun` per run, and nothing kept between runs — no lifecycle in it at all. 22.7 ms
/// median, 3 ms over F5; the warm-process alternative (T3) and what it would have cost are in
/// DESIGN.md §9. A cold spawn also keeps a fresh module cache every run, so an edited **Script**
/// is always the one that runs, and 0 MB held while idle (G4).
struct Runner {
    /// F14. A **Script** may not hold the bar longer than this, and SPEC lists outliving it among
    /// the things Starkit never does — so the deadline is enforced with `SIGKILL` rather than by
    /// asking. `terminate()` is `SIGTERM`, which is a request, and a request is not a guarantee.
    static let deadline: DispatchTimeInterval = .seconds(5)

    let toolchain: Toolchain
    let home: URL

    /// The **Effects** this **Script** decided on, or a **Refusal** naming what happened instead.
    ///
    /// Every failure here is a **Refusal**, never a **Notify** — including a **Script** that
    /// crashed or hung, since dying is not deciding. `entry.gleam` takes the same view from inside
    /// the child: an unknown **Keyword** and an undecodable payload both come back as `refusal`.
    func run(keyword: String, payload: Payload) throws(Refusal) -> [Effect] {
        // The payload travels as one `argv` element with no shell between here and there, so a
        // **Script** name or an **Input** containing quotes, spaces or a semicolon needs no escaping
        // and cannot be read as anything but data.
        let (reply, diagnostics, status) = try execute(
            ["run.mjs", "run", keyword, try encoded(payload)],
            called: "The Script \"\(keyword)\""
        )
        return try Effect.all(
            inReplyTo: keyword,
            reply: reply,
            diagnostics: diagnostics,
            exitStatus: status
        )
    }

    /// Every **Manifest**, which is the other verb `entry.gleam` answers and the only one that needs
    /// no **Keyword**.
    ///
    /// Nothing is run by asking this. `describe` reads the registry, so it answers for **Scripts**
    /// that would **Refuse** if they were reached for — which is what keeps a broken one listed (F2).
    func describe() throws(Refusal) -> [Manifest] {
        let (reply, diagnostics, status) = try execute(
            ["run.mjs", "describe"],
            called: "Listing your Scripts"
        )
        return try Manifest.all(reply: reply, diagnostics: diagnostics, exitStatus: status)
    }

    /// - Parameter called: how this invocation is named in a **Refusal** about it, already worded to
    ///   start a sentence — the deadline is the same clock either way, but the sentence a person
    ///   reads should say what did not finish.
    private func execute(
        _ arguments: [String],
        called what: String
    ) throws(Refusal) -> (reply: Data, diagnostics: String?, status: Int32) {
        let process = Process()
        process.executableURL = toolchain.bun
        // `run.mjs`, never `gleam run` — the reasoning is in the shim itself.
        process.arguments = arguments
        process.currentDirectoryURL = home

        // Kept apart, unlike C5's single pipe: stdout is the protocol and stderr is F12's channel,
        // and a warning bun printed on the way through must never be parsed as a reply.
        let reply = Pipe()
        let diagnostics = Pipe()
        process.standardOutput = reply
        process.standardError = diagnostics

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            throw Refusal(
                "The Toolchain is unusable: bun could not be started from \(toolchain.bun.path)."
            )
        }

        // Both pipes drained off this thread, and the deadline waited on separately. Reading to EOF
        // here instead would hand the deadline to the child: a **Script** that hangs never closes
        // its stdout, and a `readDataToEndOfFile` on the same thread as the timeout is a wait with
        // no clock on it. Draining concurrently also means neither stream can deadlock the other by
        // filling its 64 KB buffer while we read the wrong one.
        let collected = Collected()
        let drained = DispatchGroup()
        DispatchQueue.global().async(group: drained) {
            collected.reply = reply.fileHandleForReading.readDataToEndOfFile()
        }
        DispatchQueue.global().async(group: drained) {
            collected.diagnostics = diagnostics.fileHandleForReading.readDataToEndOfFile()
        }

        if exited.wait(timeout: .now() + Self.deadline) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            // The kill closes both write ends, so the drains finish on their own and whatever the
            // **Script** managed to say before it stopped is still worth showing.
            drained.wait()
            throw Refusal(
                "\(what) was killed after 5 seconds.",
                detail: collected.text(of: collected.diagnostics)
            )
        }
        drained.wait()

        return (
            collected.reply,
            collected.text(of: collected.diagnostics),
            process.terminationStatus
        )
    }

    /// Somewhere for two concurrent reads to land. Each queue writes only its own field and nothing
    /// is read until `drained.wait()` has returned, which is the ordering that makes a lock
    /// unnecessary rather than merely unlikely to be needed.
    private final class Collected {
        var reply = Data()
        var diagnostics = Data()

        /// bun ignores `NO_COLOR` (ADR 0003), so the escapes come out here or a stack trace reaches
        /// the menu bar wearing them. Empty becomes `nil`, because "there was nothing to say" and
        /// "here is an empty string" read differently at the other end.
        func text(of data: Data) -> String? {
            let text = String(decoding: data, as: UTF8.self)
                .withoutTerminalColour
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    /// The payload `entry.gleam` decodes, as the one `argv` element it travels in.
    ///
    /// What goes in it is C8's decision and was made before this was called (`ContextGatherer`);
    /// this only writes it down. Encoding cannot fail for a `Payload` — every field is a `String` or
    /// a list of them — so the **Refusal** below is a sentence nobody should ever read, kept because
    /// the alternative is a `try!` that would take the whole application with it if that ever
    /// stopped being true.
    private func encoded(_ payload: Payload) throws(Refusal) -> String {
        guard let json = try? JSONEncoder().encode(payload) else {
            throw Refusal("Starkit could not encode the payload it gathered.")
        }
        return String(decoding: json, as: UTF8.self)
    }
}
