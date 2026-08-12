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

    /// The **Manifests** a typed prefix selects, case-insensitively, best first. Nothing typed selects
    /// everything.
    ///
    /// Four bands, in this order: the canonical **Keyword** exactly, one of the others exactly, the
    /// canonical **Keyword** by prefix, one of the others by prefix. The first band is why ↩ on a fully
    /// typed `link` cannot run `linkedin`; the second is why a two-letter shorthand cannot be shadowed
    /// by a **Script** that merely starts with those letters. A **Keyword** typed in full always wins,
    /// and the canonical one wins over the rest.
    public static func matches(_ keyword: String, in catalogue: [Manifest]) -> [Manifest] {
        guard !keyword.isEmpty else { return catalogue }
        let typed = keyword.lowercased()

        /// Lower is better; `nil` does not match at all. A **Script** is ranked once however many of
        /// its **Keywords** match, so a second name can never put the same row on screen twice.
        func band(_ manifest: Manifest) -> Int? {
            let keyword = manifest.keyword.lowercased()
            let others = manifest.otherKeywords.map { $0.lowercased() }
            if keyword == typed { return 0 }
            if others.contains(typed) { return 1 }
            if keyword.hasPrefix(typed) { return 2 }
            if others.contains(where: { $0.hasPrefix(typed) }) { return 3 }
            return nil
        }

        // Partitioned, not sorted: `sorted(by:)` is not documented to be stable, and inside a band the
        // order is the catalogue's own.
        let ranked = catalogue.compactMap { manifest in band(manifest).map { (manifest, $0) } }
        return (0...3).flatMap { band in ranked.filter { $0.1 == band }.map(\.0) }
    }
}
