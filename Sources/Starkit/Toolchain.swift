import Foundation
import StarkitCore

struct Toolchain {
    let bun: URL
    let gleam: URL
}

extension Toolchain {
    private static let tools = ["bun", "gleam"]

    /// Every key `starkit.toml` may carry. `editor` is not a **Toolchain** path — nothing builds or
    /// runs with it — but it is read from the same file by the same rule, and a second file for one
    /// line would be a second thing to find.
    private static let keys = tools + ["editor"]

    static var home: URL {
        if let set = ProcessInfo.processInfo.environment["STARKIT_HOME"], !set.isEmpty {
            return URL(fileURLWithPath: set)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".starkit")
    }

    /// The home, but only when it is not the usual one — what C1 writes at the end of the bar, and
    /// `nil` on an ordinary machine.
    ///
    /// A scratch `STARKIT_HOME` is inherited rather than chosen: `install.sh` exports it and ends by
    /// `open`ing the bundle, and macOS hands an app the environment of whoever launched it.
    static var overriddenHome: URL? {
        let usual = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".starkit")
        // Compared as standardized paths rather than URLs, because `install.sh` exports
        // `STARKIT_HOME=$HOME/.starkit` on every ordinary run: that is the usual home written the
        // long way, and announcing it would make the tag mean "installed recently".
        return home.standardizedFileURL.path == usual.standardizedFileURL.path ? nil : home
    }

    static func resolve(home: URL = Toolchain.home) throws(Refusal) -> Toolchain {
        let overridden = overrides(in: home)
        // Asked only about what is left: overriding both is the case where the shell's answer is
        // not wanted, so it should not also be waited for.
        let missing = tools.filter { overridden[$0] == nil }
        let reported = missing.isEmpty ? [:] : loginShellReport(for: missing)

        func locate(_ tool: String) throws(Refusal) -> URL {
            if let path = overridden[tool] {
                // Checked here rather than at first use: DESIGN.md §8 rank 5 requires a wrong path
                // in starkit.toml to go red at launch, not on the first Summon that needs it.
                guard FileManager.default.isExecutableFile(atPath: path) else {
                    throw Refusal(
                        "The Toolchain is misconfigured: starkit.toml points \(tool) at \(path), "
                            + "which is not an executable. Correct the path, or delete the line to "
                            + "let your login shell answer."
                    )
                }
                return URL(fileURLWithPath: path)
            }
            guard let path = reported[tool], !path.isEmpty else {
                throw Refusal(
                    "The Toolchain is incomplete: your login shell cannot find \(tool). Install "
                        + "it, or name its path in \(home.appendingPathComponent("starkit.toml").path)."
                )
            }
            return URL(fileURLWithPath: path)
        }

        return Toolchain(bun: try locate("bun"), gleam: try locate("gleam"))
    }

    /// What `starkit.toml` says, or nothing at all: the file is optional and absent by default. The
    /// rule for reading it is `Overrides`, in **StarkitCore**, where it is tested.
    private static func overrides(in home: URL) -> [String: String] {
        let file = home.appendingPathComponent("starkit.toml")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [:] }
        return Overrides.read(text, keys: keys)
    }

    /// The application `starkit.toml` names for opening a **Script**, by the name the Finder shows —
    /// the same spelling the **Open** **Effect** takes, so there is one rule for naming an
    /// application and not two.
    ///
    /// Read at the moment it is needed rather than resolved at launch: nothing waits on it, and an
    /// editor installed after login should work without one.
    ///
    /// Takes the home rather than reading the usual one, so a scratch `$STARKIT_HOME` answers for its
    /// own `starkit.toml` exactly as it does for `bun` and `gleam`.
    static func editor(in home: URL) -> String? { overrides(in: home)["editor"] }

    /// Ask the login shell where each tool is, in one spawn.
    ///
    /// `command -v` rather than searching `PATH` ourselves: it follows shims, functions and aliases.
    /// `|| true` so an absent tool still prints its name with an empty path — a shell that exited
    /// non-zero on the first failure would hide the second.
    ///
    /// `-ilc`, not `-lc`. A login shell that is not *interactive* never reads `~/.zshrc`, which is
    /// where `~/.bun/bin` is added, so `-lc` cannot see `bun` at all from a clean environment — and
    /// under `SMAppService` the app starts with exactly such an environment.
    ///
    /// The shell comes from the password database, not `$SHELL`: a login-launched app inherits a
    /// minimal environment where that variable may be absent.
    private static func loginShellReport(for tools: [String]) -> [String: String] {
        // Safe by construction rather than by escaping: the names are compile-time constants from
        // `tools`, never user input.
        let script = tools
            .map { #"printf '%s\t%s\n' \#($0) "$(command -v \#($0) || true)""# }
            .joined(separator: "; ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: loginShell)
        process.arguments = ["-ilc", script]
        let output = Pipe()
        process.standardOutput = output
        // A noisy profile must not reach our stderr, where it would read as Starkit's own message.
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            // Every tool then comes back missing and the **Refusal** names them.
            return [:]
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        var report: [String: String] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            report[String(parts[0])] = String(parts[1]).trimmingCharacters(in: .whitespaces)
        }
        return report
    }

    private static var loginShell: String {
        guard let entry = getpwuid(getuid())?.pointee else { return "/bin/zsh" }
        let shell = String(cString: entry.pw_shell)
        return shell.isEmpty ? "/bin/zsh" : shell
    }
}
