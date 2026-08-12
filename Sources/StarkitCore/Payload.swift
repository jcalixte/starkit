import Foundation

/// A slice of machine state a **Script** declared. Raw values are `entry.gleam`'s own spelling —
/// every **Need** arrives in the payload under the key it is named by, so no second mapping table
/// exists anywhere.
public enum Need: String, Sendable, CaseIterable {
    case runningApps = "running_apps"
}

extension Need {
    /// An unknown word **Refuses** rather than being filtered out: a **Script** handed nothing for a
    /// **Need** it declared still runs, and cannot tell an ungathered slice from an empty machine.
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

/// What the **Shelf** hands a **Script**. `entry.gleam`'s `payload_decoder` is the other end.
///
/// Slices a **Script** did not declare must stay *absent* rather than empty — a `nil` optional
/// writes no key at all, and the Gleam side's `decode.optional_field` supplies the empty value. Both
/// halves agree on that rule without either carrying a list of what the other might omit.
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
    /// What was gathered, for `--dry-run`. Spelled as `starkit.gleam` spells it, not as the wire
    /// does, because the person reading it is looking at Gleam.
    public var description: String {
        guard let runningApps else { return "Context()" }
        return "Context(running_apps: \(runningApps.count) — \(runningApps.joined(separator: ", ")))"
    }
}
