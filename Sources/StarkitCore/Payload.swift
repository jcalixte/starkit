import Foundation

/// A slice of machine state a **Script** declared, under the name it crosses the wire by.
///
/// The Swift half of `starkit.gleam`'s `Need`, and the raw values are `entry.gleam`'s own spelling:
/// every **Need** arrives in the payload under the key it is named by, so nothing anywhere holds a
/// second table mapping one to the other.
///
/// One case, and a closed enum for it. The **Vocabulary** grows deliberately (G6), and this is the
/// side that has to refuse a word rather than shrug at it — see `all(_:for:)`.
public enum Need: String, Sendable, CaseIterable {
    /// The applications currently running, as their names.
    case runningApps = "running_apps"
}

extension Need {
    /// The **Needs** a **Manifest** declared, or a **Refusal** naming the word this Starkit cannot
    /// gather.
    ///
    /// Loud rather than skipped, and for the same reason `Effect` is loud about a word it does not
    /// know: a **Script** that declared a **Need** and is handed nothing still runs, and it decides
    /// from an empty **Context** with no way to tell that apart from an empty machine. Clean is the
    /// **Script** that makes the cost of that concrete — but the answer would be the same for one
    /// where the mistake is quiet instead of destructive, which is why it lives here rather than in
    /// a filter.
    ///
    /// A `Set`, so a **Manifest** that names the same slice twice is gathered once.
    public static func all(_ declared: [String], for keyword: String) throws(Refusal) -> Set<Need> {
        var needs: Set<Need> = []
        for word in declared {
            guard let need = Need(rawValue: word) else {
                throw Refusal(
                    "The Script \"\(keyword)\" needs \"\(word)\", which this Starkit cannot gather.",
                    detail: "The vendored Vocabulary in ~/.starkit is ahead of the app; reinstall."
                )
            }
            needs.insert(need)
        }
        return needs
    }
}

/// What the **Shelf** hands a **Script**: the **Input**, and one key per **Context** slice gathered.
///
/// A mechanism, not a word from `CONTEXT.md` — the glossary has a **Context** and an **Input** and
/// deliberately no name for the thing that carries both, in the same way it leaves the reply
/// unnamed. This is that thing, and `entry.gleam`'s `payload_decoder` is the other end of it.
///
/// Slices a **Script** did not declare are *absent* rather than empty, which the synthesised
/// encoding gives for free: an optional that is `nil` writes no key at all. Both halves of the wire
/// were built to that rule — `decode.optional_field` on the Gleam side supplies the empty value —
/// so the two of them agree without either one carrying a list of what the other might omit.
public struct Payload: Equatable, Sendable, Codable {
    public let input: String
    public let runningApps: [String]?

    private enum CodingKeys: String, CodingKey {
        case input
        case runningApps = "running_apps"
    }

    public init(input: String, runningApps: [String]? = nil) {
        self.input = input
        self.runningApps = runningApps
    }
}

extension Payload: CustomStringConvertible {
    /// What was gathered, for `--dry-run` to print above the **Effects** it produced.
    ///
    /// The **Context** in `starkit.gleam`'s spelling rather than the wire's, because the person
    /// reading it is looking at Gleam — the same choice `Effect.description` makes. The **Input** is
    /// not in here: it is what you typed, and it is never the surprising half.
    public var description: String {
        guard let runningApps else { return "Context()" }
        return "Context(running_apps: \(runningApps.count) — \(runningApps.joined(separator: ", ")))"
    }
}
