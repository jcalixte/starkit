import Foundation

/// The Swift half of `starkit.gleam`'s `Script` minus the deciding — everything needed to *list* a
/// **Script**, and nothing that needs building or running one.
public struct Manifest: Equatable, Sendable, Codable {
    public let keyword: String
    public let name: String

    /// Deliberately not decoded into `Need` here: a `manifests.json` naming a slice this binary has
    /// never heard of would fail the *listing* and empty the bar of every **Script** in it. The word
    /// is carried as written and refused later by `Need.all`, which can name the **Script**.
    public let needs: [String]

    /// The question this **Script** asks, or `nil` if it decides on its own.
    ///
    /// Must stay decoding-optional: a `manifests.json` cached before this field existed has no
    /// `asks` key, and a cache that fails to decode is an empty bar on the launch after an upgrade.
    public let asks: String?

    public init(keyword: String, name: String, needs: [String] = [], asks: String? = nil) {
        self.keyword = keyword
        self.name = name
        self.needs = needs
        self.asks = asks
    }
}

extension Manifest {
    /// Reads what `describe` answered. A bare array, unlike `run`'s reply: listing cannot **Refuse**
    /// from inside, so there is no second shape for this to arrive in.
    public static func all(
        reply: Data,
        diagnostics: String?,
        exitStatus: Int32
    ) throws(Refusal) -> [Manifest] {
        guard !reply.isEmpty else {
            throw Refusal(
                "Starkit could not list your Scripts.",
                detail: diagnostics ?? "bun exited \(exitStatus) without writing an answer."
            )
        }
        do {
            return try JSONDecoder().decode([Manifest].self, from: reply)
        } catch {
            throw Refusal(
                "Starkit could not read the list of your Scripts.",
                detail: "\(error)"
            )
        }
    }
}
