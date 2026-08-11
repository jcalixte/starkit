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

    // Spelled out rather than inferred: everything in here throws a **Refusal** and nothing else, and
    // saying so is what lets the `catch` read `reason` and `detail` off it.
    do throws(Refusal) {
        let home = Toolchain.home
        let toolchain = try Toolchain.resolve(home: home)
        let builder = Builder(toolchain: toolchain, home: home)
        try ensureCurrent(keyword, builder)

        let effects = try Runner(toolchain: toolchain, home: home).run(keyword: keyword, input: input)

        // `--dry-run` prints the decision and performs none of it. The two are exclusive on
        // purpose: the flag exists to answer "what did this **Script** decide" without the machine
        // changing underneath the answer.
        if dryRun {
            for effect in effects { print(effect) }
        } else {
            try Effector().perform(effects)
        }
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
/// All five **Scripts** share one Gleam project, so a broken `youtube.gleam` fails the build that
/// `work` also needs. `Staleness` is what turns that into one **Refusal** instead of five — see
/// [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md).
private func ensureCurrent(_ keyword: String, _ builder: Builder) throws(Refusal) {
    // The build's own **Refusal** is held rather than thrown. A project that does not compile is only
    // *this* **Script**'s problem if this **Script** changed since the project last compiled, and
    // that question has not been asked yet.
    var failed: Refusal?
    do {
        try builder.build()
        builder.remember()
    } catch {
        failed = error
    }

    let why = switch try builder.staleness(of: keyword) {
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
