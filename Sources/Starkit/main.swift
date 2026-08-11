import AppKit
import StarkitCore

// `Starkit run <keyword> [input] [--dry-run]`, the debugging path SPEC keeps permanently.
//
// Checked before any of the GUI exists. Given arguments Starkit is a command, and a command must not
// put an item in the menu bar, take an activation policy, or start a run loop it will never turn.
if CommandLine.arguments.count > 1 {
    exit(command(Array(CommandLine.arguments.dropFirst())))
}

let application = NSApplication.shared
// `NSApplication.delegate` is a weak reference, so the delegate has to be kept alive here.
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
// Menu-bar-only. Set here as well as via `LSUIElement` in Info.plist, because the executable
// is also run directly from a terminal during development, where no bundle is involved.
//
// `.accessory` is about the Dock icon and nothing more. It is *not* a promise that the Shelf never
// takes focus — T0.5 measured that it has to: macOS routes keys only to the active application's
// key window, so a panel in an inactive app cannot be typed into, and a bar that cannot be typed
// into is not a bar. The Shelf takes activation on Summon and Paste hands it back, at a measured
// 19.4 ms (DESIGN.md §4, F7).
application.setActivationPolicy(.accessory)
application.run()

/// One run, from a terminal. Exit code 1 for a **Refusal**, 2 for being asked the wrong thing.
private func command(_ arguments: [String]) -> Int32 {
    var dryRun = false
    var words: [String] = []
    for argument in arguments {
        if argument == "--dry-run" { dryRun = true } else { words.append(argument) }
    }

    guard words.count >= 2, words[0] == "run" else {
        report("usage: Starkit run <keyword> [input] [--dry-run]")
        return 2
    }
    let keyword = words[1]
    // Everything after the **Keyword** is the **Input**, rejoined with the spaces the shell ate. The
    // bar has one text field and splits the first token off the rest (C2), so putting it back
    // together here is what makes both paths hand a **Script** the same string.
    let input = words.dropFirst(2).joined(separator: " ")

    do {
        let home = Toolchain.home
        let toolchain = try Toolchain.resolve(home: home)
        let builder = Builder(toolchain: toolchain, home: home)
        try ensureCurrent(keyword, builder)

        let effects = try Runner(toolchain: toolchain, home: home).run(keyword: keyword, input: input)

        guard dryRun else {
            // C7 is T1.5. Printing the **Effects** and claiming to have performed them would be the
            // one failure mode `--dry-run` exists to rule out, so say so and stop.
            report("Starkit cannot perform Effects yet. Run with --dry-run to see them.")
            return 2
        }
        for effect in effects { print(effect) }
        return 0
    } catch {
        report(error.reason)
        if let detail = error.detail { report(detail) }
        return 1
    }
}

/// Bring the **Artefact** up to date, or **Refuse** — and **Refuse** only when it is *this*
/// **Script**'s problem.
///
/// The whole of [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md), and the
/// reason T1.6 is an executable reading of it rather than a task with code in it. All five
/// **Scripts** share one Gleam project, so a broken `youtube.gleam` fails the build that `work` also
/// needs; the mtime comparison is what turns that into one **Refusal** instead of five.
private func ensureCurrent(_ keyword: String, _ builder: Builder) throws(Refusal) {
    // The build's own **Refusal** is held rather than thrown. A project that does not compile is only
    // *this* **Script**'s problem if this **Script** changed since the project last compiled, and
    // that question has not been asked yet.
    var failed: Refusal?
    do {
        try builder.build()
        // Every **Artefact** on disk now matches the source beside it. Recorded here, while it is
        // true, because that is the only moment anything can vouch for it.
        builder.remember()
    } catch {
        failed = error
    }

    let why = switch try builder.staleness(of: keyword) {
    // Runs, even though the project as a whole may not compile. This line is the guarantee.
    case .current: nil as String?
    case .artefactMissing: "there is no Artefact for it"
    case .sourceChanged: "it has changed since it was last built"
    case .sharedModuleChanged(let module): "\(module) changed since it was last built"
    }
    guard let why else { return }

    throw Refusal(
        "Starkit cannot run \"\(keyword)\": \(why).",
        // The compile error verbatim when there was one — it is the only thing here that says what
        // to fix, and there is nothing Starkit could add to a Gleam diagnostic by rewording it. With
        // no compile error, the build succeeded and the **Artefact** is still not where Starkit
        // looks: that path is a layout Gleam never promised to keep (DESIGN.md §9), so name it rather
        // than report this as a missing **Script**.
        detail: failed?.detail ?? "Expected it at \(builder.artefact(of: keyword).path)."
    )
}

/// stderr, not stdout. stdout carries the **Effects** and nothing else, so a **Refusal** cannot be
/// mistaken for one by anything reading the output.
private func report(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}
