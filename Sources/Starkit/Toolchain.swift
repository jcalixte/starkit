import Foundation
import StarkitCore

/// C12 — the `bun` and `gleam` that Starkit borrows from the machine rather than shipping.
///
/// Resolved at every launch, never cached to disk and never pinned, which is the whole of G7: an
/// upgrade to either is not an event because Starkit never recorded where they were. The cost is
/// one shell spawn per launch, against F9's 3 s budget.
///
/// The order is override, then the login shell. `starkit.toml` exists for the case where the shell
/// lies — a version manager that only initialises for interactive use, a tool installed somewhere
/// `PATH` never reaches — and not as the source of truth, so it is consulted first only to be
/// allowed to win, never to be required.
struct Toolchain {
    let bun: URL
    let gleam: URL
}

extension Toolchain {
    /// The names resolved, in the order they are reported when both are missing.
    private static let tools = ["bun", "gleam"]

    /// `~/.starkit`, or wherever `STARKIT_HOME` points.
    ///
    /// The same variable `install.sh` reads, and for the same reason: it is how either side gets
    /// exercised against a machine that has never had Starkit without disturbing the real one.
    static var home: URL {
        if let set = ProcessInfo.processInfo.environment["STARKIT_HOME"], !set.isEmpty {
            return URL(fileURLWithPath: set)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".starkit")
    }

    static func resolve(home: URL = Toolchain.home) throws(Refusal) -> Toolchain {
        let overridden = overrides(in: home)
        // Asked only about what is left. Overriding both is precisely the case where the shell's
        // answer is not wanted, so it should not also be waited for.
        let missing = tools.filter { overridden[$0] == nil }
        let reported = missing.isEmpty ? [:] : loginShellReport(for: missing)

        func locate(_ tool: String) throws(Refusal) -> URL {
            if let path = overridden[tool] {
                // Checked here rather than at first use, because DESIGN.md §8 rank 5 is explicit:
                // a wrong path in starkit.toml goes red at launch, not on the first Summon that
                // happens to need it.
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

    /// The two keys `starkit.toml` may carry, read without a TOML parser.
    ///
    /// `bun = "/path"` and `gleam = "/path"`, both optional. This is a deliberate two-key subset
    /// and not an implementation of TOML: the file exists for exactly one purpose, adding a
    /// dependency to read it would be absurd, and anything it does not understand it ignores — so
    /// a line that is valid TOML but not one of these two is silently not an override, which is
    /// the same outcome as not writing it.
    private static func overrides(in home: URL) -> [String: String] {
        let file = home.appendingPathComponent("starkit.toml")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [:] }

        var found: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            guard tools.contains(key) else { continue }
            let value = trimmed[trimmed.index(after: equals)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !value.isEmpty { found[key] = value }
        }
        return found
    }

    /// Ask the login shell where each tool is, in one spawn.
    ///
    /// `command -v` rather than searching `PATH` ourselves, because it is the shell's own answer —
    /// it follows shims, functions and aliases, and a version manager's shim is exactly the
    /// version-agnostic entry point worth resolving to rather than past.
    ///
    /// One spawn for both, and `|| true` so that a tool being absent still prints its name with an
    /// empty path: the caller needs to know *which* is missing to name it, and a shell that exits
    /// non-zero on the first failure would hide the second.
    ///
    /// `-ilc`, not `-lc`. A login shell that is not *interactive* never reads `~/.zshrc`, which is
    /// where people actually put their `PATH` — `~/.bun/bin` is added there, so `-lc` cannot see
    /// `bun` at all from a clean environment. Under `SMAppService` the app starts with exactly such
    /// an environment, so `-lc` would go red on every boot while looking correct from a terminal.
    /// The cost is measured in DESIGN.md §4, F9; `-ic` is no cheaper, so there is nothing to buy
    /// by giving up `.zprofile`.
    ///
    /// The login shell comes from the password database rather than being hardcoded. A
    /// login-launched app inherits a minimal environment, so `$SHELL` cannot be trusted to be
    /// there, and hardcoding `/bin/zsh` would be a pin of exactly the kind G7 rules out.
    private static func loginShellReport(for tools: [String]) -> [String: String] {
        // The names are compile-time constants from `tools`, never user input, so interpolating
        // them into a shell script is safe by construction rather than by escaping.
        let script = tools
            .map { #"printf '%s\t%s\n' \#($0) "$(command -v \#($0) || true)""# }
            .joined(separator: "; ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: loginShell)
        process.arguments = ["-ilc", script]
        let output = Pipe()
        process.standardOutput = output
        // A shell that complains on the way through — a noisy profile, a warning from a version
        // manager — must not reach our stderr, where it would read as Starkit's own message.
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            // The shell itself could not be started. Nothing was reported, so every tool comes back
            // missing and the Refusal names them — which is the right message: from the outside,
            // an unusable shell and an empty PATH are the same failure to answer.
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
