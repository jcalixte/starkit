import AppKit
import StarkitCore

/// C8 — read the slices of the machine a **Script** declared, and none of the ones it did not.
/// Nothing here may spawn a process: the F6 budget is ≤ 5 ms (`DESIGN.md` §4).
struct ContextGatherer {
    func payload(input: String, keyword: String, needs: [String]) throws(Refusal) -> Payload {
        let needed = try Need.all(needs, for: keyword)
        return Payload(
            input: input,
            runningApps: needed.contains(.runningApps) ? Self.runningApps() : nil
        )
    }

    /// Pay for the workspace connection at launch, so that no run pays for it.
    ///
    /// Measured: the *first* read of `runningApplications` in a process costs 2.8–7.8 ms, every read
    /// after it 0.006–0.016 ms. Without this the first Clean of a session misses F6's 5 ms budget.
    static func warm() {
        _ = runningApps()
    }

    /// Every application with a Dock icon, under the name macOS shows.
    ///
    /// `.regular` also drops Starkit itself, which is `.accessory`, so a **Kill** list can never
    /// contain the process performing it.
    private static func runningApps() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.localizedName)
    }
}
