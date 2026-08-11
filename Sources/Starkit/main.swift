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
        try Builder(toolchain: toolchain, home: home).ensureCurrent(keyword)

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
