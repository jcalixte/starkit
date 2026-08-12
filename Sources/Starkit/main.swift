import AppKit
import StarkitCore

// Must stay ahead of every line below: given arguments Starkit is a command, and a command must not
// put an item in the menu bar, take an activation policy, or start a run loop it will never turn.
if CommandLine.arguments.count > 1 {
    exit(command(Array(CommandLine.arguments.dropFirst())))
}

let application = NSApplication.shared
// `NSApplication.delegate` is a weak reference, so the delegate has to be kept alive here.
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
// Set here as well as via `LSUIElement` in Info.plist, because the executable is also run directly
// from a terminal during development, where no bundle is involved. `.accessory` governs the Dock
// icon only — the Shelf still takes activation on **Summon**, since macOS routes keys only to the
// active application's key window.
application.setActivationPolicy(.accessory)
application.run()

/// One run, from a terminal. Exit code 1 for a **Refusal**, 2 for being asked the wrong thing.
private func command(_ arguments: [String]) -> Int32 {
    var dryRun = false
    var samples: Int?
    var words: [String] = []
    for argument in arguments {
        switch argument {
        case "--dry-run": dryRun = true
        case "--bench": samples = 20
        case let flag where flag.hasPrefix("--bench="):
            guard let count = Int(flag.dropFirst("--bench=".count)), count > 0 else {
                report("--bench takes a count of samples, at least 1.")
                return 2
            }
            samples = count
        default: words.append(argument)
        }
    }

    if words.first == "login" { return login(Array(words.dropFirst())) }

    guard words.count >= 2, words[0] == "run" else {
        report("usage: Starkit run <keyword> [input] [--dry-run] [--bench[=N]]")
        report("       Starkit login [on|off]")
        return 2
    }
    let keyword = words[1]
    // Rejoined with the spaces the shell ate, so this path and the bar (C2) hand a **Script** the
    // same string.
    let input = words.dropFirst(2).joined(separator: " ")

    // Before everything below, and not a variation on it: `--bench` resolves and builds on its own
    // clock, and it must reach neither the `--dry-run` print nor the **Effector**.
    if let samples { return bench(keyword: keyword, input: input, samples: samples) }

    do throws(Refusal) {
        let home = Toolchain.home
        let toolchain = try Toolchain.resolve(home: home)
        try Builder(toolchain: toolchain, home: home).ensureCurrent(keyword)

        let runner = Runner(toolchain: toolchain, home: home)
        // A **Keyword** no **Manifest** answers to declares nothing and the run goes ahead —
        // the sentence saying it does not exist is `entry.gleam`'s to write.
        let needs = try Catalogue(home: home).manifest(for: keyword, using: runner)?.needs ?? []
        let gathered = CFAbsoluteTimeGetCurrent()
        let payload = try ContextGatherer().payload(input: input, keyword: keyword, needs: needs)
        let gathering = (CFAbsoluteTimeGetCurrent() - gathered) * 1000

        let effects = try runner.run(keyword: keyword, payload: payload)

        // Printing and performing are exclusive on purpose: the flag answers "what did this
        // **Script** decide" without the machine changing underneath the answer.
        if dryRun {
            // The gather clock prints here because it is the only place F6's 5 ms budget can be read
            // without putting an instrument on the ↩ path.
            print(payload, terminator: "")
            print(String(format: " in %.2f ms", gathering))
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

/// `Starkit login [on|off]` — C9 from a terminal, since the registration belongs to the *bundle*
/// this executable sits in and not to the running instance.
///
/// It exists for two callers. `install.sh`, because an install is the moment the whole promise was
/// asked for, boot included; and T7.2, which has to read the state after moving that bundle around
/// and would otherwise be a person opening a menu and squinting at a tick.
///
/// Always prints the state macOS reports *after* the request, never what was requested. Exit 1 when
/// those differ, so a caller can tell without parsing the sentence.
private func login(_ words: [String]) -> Int32 {
    var wanted: Bool?
    switch words.first {
    case nil: break
    case "on": wanted = true
    case "off": wanted = false
    default:
        report("usage: Starkit login [on|off]")
        return 2
    }

    if let wanted { LoginItem.set(wanted) }

    let state = LoginItem.state
    let note = state.note.map { " (\($0))" } ?? ""
    print("Start at Login: \(state.isOn ? "on" : "off")\(note)")
    return wanted == nil || wanted == state.isOn ? 0 : 1
}
