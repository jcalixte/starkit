import Foundation
import StarkitCore

/// C4 — run one **Artefact** and collect what it decided.
///
/// A fresh `bun` per run, and nothing kept between runs. T3 proposed the opposite — spawn on
/// **Summon** so the process is warm by the time ↩ is pressed — and it was dropped here, at the task
/// DESIGN.md §9 nominated for deciding it. Measured on this machine, through `Process`, against the
/// installed `~/.starkit`: a cold run is 19.8 ms min / 22.7 median / 24.2 p90, of which about 5 ms
/// is `Process`'s own fork and exec. That is 3 ms over F5's 20 ms target and under two frames at
/// 60 Hz, on a threshold whose entire purpose is imperceptibility — and the **Effects** themselves
/// are orders of magnitude slower, since `Open` launches applications.
///
/// What the 16 ms would have cost is the part worth recording. A process spawned before a
/// **Keyword** is known cannot be handed one on `argv`, so feeding it a run means replacing
/// `run.mjs`'s argument reading with a stdin protocol — framing and a read loop, in a **Shelf**-owned
/// file vendored into everyone's `~/.starkit` — on top of the lifecycle itself: dismissal mid-run, a
/// second **Summon**, a child that died while waiting, a build that landed underneath it. §7 already
/// named C4 the riskiest component. This is the version with no lifecycle in it at all.
///
/// A cold spawn also keeps two properties T3 had to argue for: a fresh module cache every run, so an
/// edited **Script** is always the one that runs, and 0 MB held while idle (G4).
struct Runner {
    /// F14. A **Script** may not hold the bar longer than this, and SPEC lists outliving it among
    /// the things Starkit never does — so the deadline is enforced with `SIGKILL` rather than by
    /// asking. `terminate()` is `SIGTERM`, which is a request, and a request is not a guarantee.
    static let deadline: DispatchTimeInterval = .seconds(5)

    let toolchain: Toolchain
    let home: URL

    /// The **Effects** this **Script** decided on, or a **Refusal** naming what happened instead.
    ///
    /// Every failure here is a **Refusal** rather than a **Notify**, including a **Script** that
    /// crashed or hung: a **Notify** is a **Script** reporting what it *decided*, and a run that
    /// died decided nothing. `entry.gleam` already takes the same view — an unknown **Keyword** and
    /// an undecodable payload come back as `refusal` from inside the child.
    func run(keyword: String, input: String = "") throws(Refusal) -> [Effect] {
        let (answer, diagnostics, status) = try execute(keyword: keyword, input: input)

        // Nothing on stdout is F12's case: the **Script** threw, or `run.mjs` could not import the
        // **Artefact** at all. Either way the child's own words are the only useful thing to say,
        // and there is nothing Starkit could add to a stack trace by paraphrasing it.
        guard !answer.isEmpty else {
            throw Refusal(
                "The Script \"\(keyword)\" failed while it was running.",
                detail: diagnostics.isEmpty
                    ? "bun exited \(status) without writing an answer." : diagnostics
            )
        }

        let decoded: Answer
        do {
            decoded = try JSONDecoder().decode(Answer.self, from: answer)
        } catch {
            // An answer that cannot be read means the two halves of the **Vocabulary** have drifted,
            // which is a different problem from a **Script** failing and has a different fix.
            throw Refusal(
                "Starkit could not read what \"\(keyword)\" answered.",
                detail: "\(error)"
            )
        }

        if let refusal = decoded.refusal { throw Refusal(refusal) }
        // Absent rather than empty is not a case `entry.gleam` produces — every answer carries one
        // key or the other — but a **Script** deciding on nothing at all is legitimate, and the
        // seeded `work.gleam` is exactly that until you fill it in.
        return decoded.effects ?? []
    }

    /// What `entry.gleam` answers with: **Effects**, or a **Refusal**, never both and never a bare
    /// array. One object is what keeps this decode total.
    private struct Answer: Decodable {
        let effects: [Effect]?
        let refusal: String?
    }

    private func execute(
        keyword: String,
        input: String
    ) throws(Refusal) -> (answer: Data, diagnostics: String, status: Int32) {
        let process = Process()
        process.executableURL = toolchain.bun
        // `run.mjs`, never `gleam run` — the reasoning is in the shim itself. The payload travels as
        // one `argv` element with no shell between here and there, so a **Script** name or an
        // **Input** containing quotes, spaces or a semicolon needs no escaping and cannot be read as
        // anything but data.
        process.arguments = ["run.mjs", "run", keyword, try payload(input: input)]
        process.currentDirectoryURL = home

        // Kept apart, unlike C5's single pipe: stdout is the protocol and stderr is F12's channel,
        // and a warning bun printed on the way through must never be parsed as an answer.
        let answer = Pipe()
        let diagnostics = Pipe()
        process.standardOutput = answer
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
            collected.answer = answer.fileHandleForReading.readDataToEndOfFile()
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
                "The Script \"\(keyword)\" was killed after 5 seconds.",
                detail: collected.text(of: collected.diagnostics)
            )
        }
        drained.wait()

        return (
            collected.answer,
            collected.text(of: collected.diagnostics) ?? "",
            process.terminationStatus
        )
    }

    /// Somewhere for two concurrent reads to land. Each queue writes only its own field and nothing
    /// is read until `drained.wait()` has returned, which is the ordering that makes a lock
    /// unnecessary rather than merely unlikely to be needed.
    private final class Collected {
        var answer = Data()
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

    /// The payload `entry.gleam` decodes: the **Input** typed after the **Keyword**, and later a key
    /// per **Context** slice once C8 gathers them. Slices a **Script** did not declare stay absent
    /// rather than arriving empty — `payload_decoder` is written for exactly that, and it is why the
    /// Clean **Kill** list is worth testing.
    private func payload(input: String) throws(Refusal) -> String {
        guard let encoded = try? JSONEncoder().encode(["input": input]) else {
            throw Refusal("Starkit could not encode the Input it was given.")
        }
        return String(decoding: encoded, as: UTF8.self)
    }
}
