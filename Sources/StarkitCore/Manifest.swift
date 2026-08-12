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

    /// The further **Keywords** this **Script** answers to — `["yt"]` for `youtube`. Not file names:
    /// only the canonical `keyword` is, because a **Script** is a Gleam module.
    public let otherKeywords: [String]

    public init(
        keyword: String,
        name: String,
        needs: [String] = [],
        asks: String? = nil,
        otherKeywords: [String] = []
    ) {
        self.keyword = keyword
        self.name = name
        self.needs = needs
        self.asks = asks
        self.otherKeywords = otherKeywords
    }

    /// `other_keywords` on the wire, because `entry.gleam` writes the **Vocabulary**'s own snake_case
    /// and the two halves of one field must not be spelled differently in the same system.
    enum CodingKeys: String, CodingKey {
        case keyword, name, needs, asks
        case otherKeywords = "other_keywords"
    }

    /// Written out rather than synthesised, because Swift's generated decoder cannot default a field
    /// that is not optional — and every field added here has to arrive absent from a `manifests.json`
    /// some older Starkit wrote. `keyword` and `name` are the two that may not: a **Script** with
    /// neither is not a **Script**, and a cache missing them is corrupt rather than old.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        keyword = try fields.decode(String.self, forKey: .keyword)
        name = try fields.decode(String.self, forKey: .name)
        needs = try fields.decodeIfPresent([String].self, forKey: .needs) ?? []
        asks = try fields.decodeIfPresent(String.self, forKey: .asks)
        otherKeywords = try fields.decodeIfPresent([String].self, forKey: .otherKeywords) ?? []
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
