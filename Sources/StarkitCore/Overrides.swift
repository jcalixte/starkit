import Foundation

/// What `starkit.toml` is allowed to say instead of what the machine would have answered: where
/// `bun` and `gleam` are, and which application opens a **Script**.
///
/// Read without a TOML parser, and deliberately so: a known key on its own line, `key = "value"`,
/// with `#` starting a comment. Anything else is ignored rather than **Refused**, because this file
/// is optional and a line Starkit does not understand must not be the reason the **Toolchain** fails
/// to resolve.
public enum Overrides {
    /// The value of each of `keys` the text names. A key given twice keeps the last one, which is
    /// what a person editing the bottom of a file expects.
    ///
    /// An empty value is no override: `bun = ""` is a line someone half-wrote, and taking it would
    /// **Refuse** with a path that is not there rather than falling back to the login shell.
    public static func read(_ text: String, keys: [String]) -> [String: String] {
        var found: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            // Newlines as well as spaces: a file written on Windows ends every line in a carriage
            // return, and a path with one on the end is not a path to anything.
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            guard keys.contains(key) else { continue }
            // Only the *first* `=` separates, so a value may contain one.
            let value = trimmed[trimmed.index(after: equals)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !value.isEmpty { found[key] = value }
        }
        return found
    }
}
