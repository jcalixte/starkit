import Foundation

/// One of the **Shelf**-owned modules every **Script** is compiled against.
public struct SharedModule: Equatable, Sendable {
    public let name: String
    /// Hash of the file on disk.
    public let source: String
    /// Hash the last successful build recorded, or `nil` if it never compiled this file.
    public let asBuilt: String?

    public init(name: String, source: String, asBuilt: String?) {
        self.name = name
        self.source = source
        self.asBuilt = asBuilt
    }

    var changed: Bool { asBuilt != source }
}

/// Whether a **Script**'s **Artefact** was built from the source still on disk.
/// See [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md).
///
/// Compares content, never mtimes, because Gleam's incremental build compares content too:
/// `touch work.gleam && gleam build` recompiles nothing and leaves the **Artefact**'s mtime where it
/// was, so an mtime rule reads that as an edit and **Refuses** a **Script** no rebuild can make
/// **Current** again.
public enum Staleness: Equatable, Sendable {
    /// Built from the source on disk. Runs even while the project as a whole does not compile.
    case current
    /// Never built, or built and since removed.
    case artefactMissing
    case sourceChanged
    /// Carries the module name: "something shared changed" is not something a person can act on.
    case sharedModuleChanged(String)
}

extension Staleness {
    /// `artefactExists` is asked as a fact rather than derived from the hashes, because a matching
    /// hash and a missing file is a real state: `gleam clean`, or Gleam moving a build path it never
    /// promised to keep (DESIGN.md §9).
    public static func of(
        source: String,
        asBuilt: String?,
        artefactExists: Bool,
        shared: [SharedModule] = []
    ) -> Staleness {
        guard artefactExists else { return .artefactMissing }
        guard asBuilt == source else { return .sourceChanged }
        // First by the order given, so the same set of changes always names the same module.
        if let changed = shared.first(where: \.changed) {
            return .sharedModuleChanged(changed.name)
        }
        return .current
    }

    public var isStale: Bool { self != .current }
}
