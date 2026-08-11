import Foundation

/// C2's rule — what the person typed, read as a **Keyword** and the **Input** after it.
///
/// Pure, and tested, because it is the whole of how the bar decides what ↩ will run. There is no
/// index and no fuzzy matching: five **Scripts** and a prefix (F3). Anything cleverer would be a
/// ranking to explain when it guesses wrong, and a bar that guesses is worse than one that lists.
public enum Keyword {
    /// The first token is the **Keyword**; everything after it is the **Input**, verbatim.
    ///
    /// One text field, split on the first run of whitespace, which is a rule rather than a
    /// convenience: no **Keyword** contains a space (`CONTEXT.md`), so the first space is
    /// unambiguously the end of it. The **Input** keeps its own spacing — a URL cannot contain one,
    /// but a page title can, and normalising it here would be Starkit editing what was typed.
    ///
    /// Leading whitespace belongs to neither, and a **Keyword** on its own has an empty **Input**
    /// rather than no **Input**: a **Script** that declares one still runs when nothing was typed
    /// after it, and `entry.gleam`'s decoder is written for exactly that.
    public static func split(_ typed: String) -> (keyword: String, input: String) {
        let text = typed.drop(while: \.isWhitespace)
        guard let space = text.firstIndex(where: \.isWhitespace) else {
            return (String(text), "")
        }
        return (String(text[..<space]), String(text[space...].drop(while: \.isWhitespace)))
    }

    /// The **Manifests** a typed **Keyword** selects, the one that would run first.
    ///
    /// Prefix, case-insensitively, so `wo` reaches Work before it has been fully typed. Nothing
    /// typed selects everything, which is what makes the bar a list of what you have rather than an
    /// empty box you must already know the answer to fill.
    ///
    /// An exact match is moved to the front, and that is the only reordering here. It matters when
    /// one **Keyword** is a prefix of another — `link` beside `linkedin` — where the alternative is
    /// ↩ on a fully typed **Keyword** running a different **Script** that merely starts the same
    /// way. Everything else keeps the order it arrived in, which is the order `describe` reports
    /// and therefore stable between **Summons**.
    public static func matches(_ keyword: String, in catalogue: [Manifest]) -> [Manifest] {
        guard !keyword.isEmpty else { return catalogue }
        let typed = keyword.lowercased()

        let matching = catalogue.filter { $0.keyword.lowercased().hasPrefix(typed) }
        // Partitioned rather than sorted: `sorted(by:)` is not documented to be stable, and the
        // order of everything that is *not* an exact match is exactly what must not move.
        return matching.filter { $0.keyword.lowercased() == typed }
            + matching.filter { $0.keyword.lowercased() != typed }
    }
}
