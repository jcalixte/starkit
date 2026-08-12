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

        // Partitioned, not sorted: `sorted(by:)` is not documented to be stable, and inside a band the
        // order is the catalogue's own.
        let ranked = catalogue.compactMap { manifest in
            band(of: manifest, matching: typed).map { (manifest, $0) }
        }
        return (0...3).flatMap { band in ranked.filter { $0.1 == band }.map(\.0) }
    }

    /// Which band a **Manifest** falls in for an already-lowercased `typed`. Lower is better; `nil`
    /// does not match at all. A **Script** is ranked once however many of its **Keywords** match, so a
    /// second name can never put the same row on screen twice.
    ///
    /// One function and two callers, for the reason T9.1 moved the registry rule into Swift: the bar
    /// and a terminal disagreeing about which **Script** a word means is a bug nobody would see until
    /// the wrong one ran.
    static func band(of manifest: Manifest, matching typed: String) -> Int? {
        let keyword = manifest.keyword.lowercased()
        let others = manifest.otherKeywords.map { $0.lowercased() }
        if keyword == typed { return 0 }
        if others.contains(typed) { return 1 }
        if keyword.hasPrefix(typed) { return 2 }
        if others.contains(where: { $0.hasPrefix(typed) }) { return 3 }
        return nil
    }

    /// What a word typed at a terminal means.
    public enum Resolution: Equatable, Sendable {
        /// The canonical **Keyword** to build and run — the module name, whichever of a **Script**'s
        /// names was typed.
        case one(String)

        /// No **Script** in the **Catalogue** answers to it. The caller carries on with what was
        /// typed rather than refusing here: a **Catalogue** is a cache, and an empty or stale one must
        /// not be the thing that decides a **Script** does not exist.
        case unknown

        /// More than one **Script** answers to it, by the same band. Named rather than picked.
        case several([String])
    }

    /// The canonical **Keyword** behind a word typed at a terminal, so `Starkit run theodo` reaches
    /// the **Script** whose module is `work.gleam` — everything downstream is addressed by the
    /// canonical one, since C5 finds a source at `src/scripts/<keyword>.gleam` and `entry.gleam`
    /// matches on the name a **Script** declares.
    ///
    /// **Exact only, where the bar also takes prefixes.** The bar can afford band 2 and band 3 because
    /// it shows you the row it selected before ↩ reaches it; between a typed word and the **Effects**
    /// a terminal shows nothing, and `Starkit run c` meaning Clean is every application on the machine
    /// force-quit by an abbreviation. So the two exact bands resolve and the two prefix bands do not.
    ///
    /// Ambiguity is reported *within* a band, never across: a `yt.gleam` and a `youtube` declaring
    /// `yt` is not a tie, because band 0 beating band 1 is the rule the bar already follows.
    public static func resolve(_ typed: String, in catalogue: [Manifest]) -> Resolution {
        guard !typed.isEmpty else { return .unknown }
        let typed = typed.lowercased()

        let exact = catalogue.compactMap { manifest -> (String, Int)? in
            guard let band = band(of: manifest, matching: typed), band <= 1 else { return nil }
            return (manifest.keyword, band)
        }
        guard let best = exact.map(\.1).min() else { return .unknown }

        let winners = exact.filter { $0.1 == best }.map(\.0)
        return winners.count == 1 ? .one(winners[0]) : .several(winners)
    }
}
