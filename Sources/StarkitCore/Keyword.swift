import Foundation

public enum Keyword {
    /// Splits on the first run of whitespace; leading whitespace is dropped and the **Input** keeps
    /// its own spacing verbatim. A **Keyword** typed on its own yields an empty **Input** rather
    /// than none — `entry.gleam`'s decoder is written for exactly that.
    public static func split(_ typed: String) -> (keyword: String, input: String) {
        let text = typed.drop(while: \.isWhitespace)
        guard let space = text.firstIndex(where: \.isWhitespace) else {
            return (String(text), "")
        }
        return (String(text[..<space]), String(text[space...].drop(while: \.isWhitespace)))
    }

    /// The **Manifests** a typed prefix selects, case-insensitively, first one first. Nothing typed
    /// selects everything. An exact match is moved to the front so ↩ on a fully typed `link` cannot
    /// run `linkedin`; all other order is preserved.
    public static func matches(_ keyword: String, in catalogue: [Manifest]) -> [Manifest] {
        guard !keyword.isEmpty else { return catalogue }
        let typed = keyword.lowercased()

        let matching = catalogue.filter { $0.keyword.lowercased().hasPrefix(typed) }
        // Partitioned, not sorted: `sorted(by:)` is not documented to be stable.
        return matching.filter { $0.keyword.lowercased() == typed }
            + matching.filter { $0.keyword.lowercased() != typed }
    }
}
