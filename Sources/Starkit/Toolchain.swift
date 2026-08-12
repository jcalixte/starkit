import Foundation
import StarkitCore

/// C12 — the `bun` and `gleam` that Starkit borrows from the machine rather than shipping.
///
/// Resolved at every launch, never cached to disk and never pinned (G7), against F9's 3 s budget.
/// Order is override, then login shell: `starkit.toml` is consulted first only to be allowed to
/// win, never to be required.
struct Toolchain {
    let bun: URL
    let gleam: URL
}

extension Toolchain {
    /// The names resolved, in the order they are reported when both are missing.
    private static let tools = ["bun", "gleam"]

    /// `~/.starkit`, or wherever `STARKIT_HOME` points — the same variable `install.sh` reads.
    static var home: URL {
        if let set = ProcessInfo.processInfo.environment["STARKIT_HOME"], !set.isEmpty {
            return URL(fileURLWithPath: set)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".starkit")
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

    /// `bun = "/path"` and `gleam = "/path"`, both optional, read without a TOML parser.
    ///
    /// A deliberate two-key subset, not an implementation of TOML: anything else it ignores, so a
    /// line that is valid TOML but not one of these two is silently not an override.
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
    /// `command -v` rather than searching `PATH` ourselves: it follows shims, functions and aliases,
    /// and a version manager's shim is the version-agnostic entry point worth resolving *to*.
    /// `|| true` so an absent tool still prints its name with an empty path — a shell that exited
    /// non-zero on the first failure would hide the second.
    ///
    /// `-ilc`, **not** `-lc`. A login shell that is not *interactive* never reads `~/.zshrc`, which
    /// is where `~/.bun/bin` is added, so `-lc` cannot see `bun` at all from a clean environment.
    /// Under `SMAppService` the app starts with exactly such an environment, so `-lc` would go red
    /// on every boot while looking correct from a terminal (cost measured in DESIGN.md §4, F9).
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
            // Every tool then comes back missing and the Refusal names them: from the outside, an
            // unusable shell and an empty PATH are the same failure to answer.
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
