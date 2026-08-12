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

    if words.first == "start-at-login" { return startAtLogin(Array(words.dropFirst())) }
    if words.first == "registry" { return registry() }
    if words.first == "create" { return create(Array(words.dropFirst())) }
    if words.first == "delete" { return delete(Array(words.dropFirst())) }

    guard words.count >= 2, words[0] == "run" else {
        report("usage: Starkit run <keyword> [input] [--dry-run] [--bench[=N]]")
        report("       Starkit start-at-login [on|off]")
        report("       Starkit registry")
        report("       Starkit create <keyword>")
        report("       Starkit delete <keyword>")
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

/// `Starkit create <keyword>` — C11 from a terminal.
///
/// **This verb exists because its absence shipped a crash.** Every other component is reachable from
/// this CLI, and C11 was reachable only by pressing ↩ on a row in the bar — so the one line that
/// mattered, the write itself, was never executed until someone did that, and it trapped on the first
/// try (`Scaffolder`). A path that cannot be run without a keystroke is a path that does not get run.
///
/// It writes and opens exactly as the bar does, and performs no build: C6 does that, or `registry`
/// does it by hand when nothing is watching.
private func create(_ words: [String]) -> Int32 {
    guard let keyword = words.first, words.count == 1 else {
        report("usage: Starkit create <keyword>")
        return 2
    }
    // Checked here as well as in the bar, because the bar's check is about what to *offer* and this
    // one is about what a person typed. Both ask `Scaffold`, so they cannot disagree.
    guard Scaffold.isValid(keyword) else {
        report(
            "\"\(keyword)\" cannot be a Keyword: a Script is a Gleam module, so it needs lowercase "
                + "letters, digits and underscores, starting with a letter."
        )
        return 2
    }

    do throws(Refusal) {
        let file = try Scaffolder(home: Toolchain.home).create(keyword)
        print("→ \(file.path)")
        return 0
    } catch {
        report(error.reason)
        if let detail = error.detail { report(detail) }
        return 1
    }
}

/// `Starkit delete <keyword>` — move a **Script** to the Trash, the same way ⌃D twice in the bar does.
///
/// Here for the reason `create` is: this is the one path in Starkit that destroys something a person
/// wrote, so it is the last one that should first execute because somebody pressed a key twice. It
/// takes no confirmation of its own — a terminal has already made typing the name the confirmation,
/// and the file goes to the Trash either way.
private func delete(_ words: [String]) -> Int32 {
    guard let keyword = words.first, words.count == 1 else {
        report("usage: Starkit delete <keyword>")
        return 2
    }

    do throws(Refusal) {
        let trashed = try Scaffolder(home: Toolchain.home).trash(keyword)
        for file in trashed { print("→ Trash: \(file.path)") }
        return 0
    } catch {
        report(error.reason)
        if let detail = error.detail { report(detail) }
        return 1
    }
}

/// `Starkit registry` — write `src/registry.gleam` from the **Scripts** on disk, once.
///
/// C6 does this on every save, so this verb exists for the two moments no Watcher is running:
/// `install.sh`, which has to produce a registry *before* its first `gleam build` because a fresh
/// `~/.starkit` has none, and a person who wants the file back after deleting it. It is the same code
/// path either way — one rule, one implementation, which is what retired `gen-registry.sh`.
private func registry() -> Int32 {
    let home = Toolchain.home
    do throws(Refusal) {
        let changed = try Watcher.regenerate(home: home)
        // Says which of the two happened, because "unchanged" is the interesting answer: it means
        // every **Artefact** is still valid, and a rewrite would have marked them all **Stale**.
        print("\(changed ? "→" : "=") \(Watcher.registry(in: home).path)\(changed ? "" : " unchanged")")
        return 0
    } catch {
        report(error.reason)
        if let detail = error.detail { report(detail) }
        return 1
    }
}

/// `Starkit start-at-login [on|off]` — C9 from a terminal, since the registration belongs to the *bundle*
/// this executable sits in and not to the running instance.
///
/// Named for the words already on the menu item rather than for what it does to `SMAppService`. The
/// verb was `login` until it was read aloud: `Starkit login on` is a sentence about an account, and
/// Starkit has no account and never will. One thing, one name — the menu says **Start at Login**.
///
/// It exists for two callers. `install.sh`, because an install is the moment the whole promise was
/// asked for, boot included; and T7.2, which has to read the state after moving that bundle around
/// and would otherwise be a person opening a menu and squinting at a tick.
///
/// Always prints the state macOS reports *after* the request, never what was requested. Exit 1 when
/// those differ, so a caller can tell without parsing the sentence.
private func startAtLogin(_ words: [String]) -> Int32 {
    var wanted: Bool?
    switch words.first {
    case nil: break
    case "on": wanted = true
    case "off": wanted = false
    default:
        report("usage: Starkit start-at-login [on|off]")
        return 2
    }

    if let wanted { LoginItem.set(wanted) }

    let state = LoginItem.state
    let note = state.note.map { " (\($0))" } ?? ""
    print("Start at Login: \(state.isOn ? "on" : "off")\(note)")
    return wanted == nil || wanted == state.isOn ? 0 : 1
}
