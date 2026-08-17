import Foundation
import StarkitCore

/// C4 — run one **Artefact** and collect what it decided.
///
/// A fresh `bun` per run, nothing kept between runs. The cold spawn guarantees a fresh module cache,
/// so an edited **Script** is always the one that runs.
struct Runner {
    /// F14. Enforced with `SIGKILL`, never `terminate()`: that is `SIGTERM`, which is a request, and
    /// a request is not a guarantee.
    static let deadline: DispatchTimeInterval = .seconds(5)

    let toolchain: Toolchain
    let home: URL

    func run(keyword: String, payload: Payload) throws(Refusal) -> [Effect] {
        // One `argv` element with no shell in between, so an **Input** containing quotes, spaces or
        // a semicolon needs no escaping and cannot be read as anything but data.
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

    /// Runs no **Script**: `describe` reads the registry, so it still answers for **Scripts** that
    /// would **Refuse** if they were reached for — which is what keeps a broken one listed (F2).
    func describe() throws(Refusal) -> [Manifest] {
        let (reply, diagnostics, status) = try execute(
            ["run.mjs", "describe"],
            called: "Listing your Scripts"
        )
        return try Manifest.all(reply: reply, diagnostics: diagnostics, exitStatus: status)
    }

    /// - Parameter called: how this invocation is named in a **Refusal** about it, already worded to
    ///   start a sentence.
    private func execute(
        _ arguments: [String],
        called what: String
    ) throws(Refusal) -> (reply: Data, diagnostics: String?, status: Int32) {
        let process = Process()
        process.executableURL = toolchain.bun
        // `run.mjs`, never `gleam run` — the reasoning is in the shim itself.
        process.arguments = arguments
        process.currentDirectoryURL = home

        // Kept apart: stdout is the protocol, so a warning bun printed on the way through must never
        // be parsed as a reply.
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

        // Both pipes drain off this thread, with the deadline waited on separately — see `Drain`.
        let answered = Drain()
        let said = Drain()
        let drained = DispatchGroup()
        answered.drain(reply, in: drained)
        said.drain(diagnostics, in: drained)

        if exited.wait(timeout: .now() + Self.deadline) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            // The kill closes both write ends, so the drains finish on their own.
            drained.wait()
            throw Refusal("\(what) was killed after 5 seconds.", detail: said.text)
        }
        drained.wait()

        return (answered.data, said.text, process.terminationStatus)
    }

    /// Encoding cannot fail for a `Payload` — every field is a `String` or a list of them — so the
    /// **Refusal** below is unreachable, kept only because the alternative is a `try!` that would
    /// take the whole application with it if that stopped being true.
    private func encoded(_ payload: Payload) throws(Refusal) -> String {
        guard let json = try? JSONEncoder().encode(payload) else {
            throw Refusal("Starkit could not encode the payload it gathered.")
        }
        return String(decoding: json, as: UTF8.self)
    }
}
