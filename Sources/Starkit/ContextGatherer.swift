import AppKit
import StarkitCore

/// C8 — read the slices of the machine a **Script** declared, and none of the ones it did not.
///
/// The whole component is one `NSWorkspace` property and a filter, which is the point: `CONTEXT.md`
/// records the alternative it replaces, and it was `osascript` asking System Events for the same
/// list at 463 ms and an Automation grant (`DESIGN.md` §4, F6). Nothing here spawns anything, and
/// the F6 budget is ≤ 5 ms.
///
/// Declaring is what makes the cost opt-in: a **Script** that needs nothing pays nothing, so the
/// gather is not on the path of every run — only of the runs that asked. Today that is Clean and
/// nothing else.
struct ContextGatherer {
    /// The payload for one run: the **Input** as typed, plus what the **Manifest** declared.
    ///
    /// Takes the declared words rather than a **Manifest** so the CLI can pass what it found and the
    /// bar can pass what the panel is holding, and neither has to invent a **Manifest** it does not
    /// have. An unknown word is a **Refusal** before anything is gathered — `Need.all` explains why
    /// it is not merely skipped.
    func payload(input: String, keyword: String, needs: [String]) throws(Refusal) -> Payload {
        let needed = try Need.all(needs, for: keyword)
        return Payload(
            input: input,
            runningApps: needed.contains(.runningApps) ? Self.runningApps() : nil
        )
    }

    /// Pay for the workspace connection at launch, so that no run pays for it.
    ///
    /// Measured: the *first* read of `runningApplications` in a process costs 2.8–7.8 ms and every
    /// read after it costs 0.006–0.016 ms. What is expensive is connecting to the workspace, not
    /// asking it anything — so without this, the first Clean of a session would be the one gather
    /// that misses F6's 5 ms budget, on the main thread, and every one after it would be three
    /// orders of magnitude inside it.
    ///
    /// The same trade C1 makes by building its window at launch (T2.2): the cheapest place to pay
    /// for something once is the place where nobody is waiting for it. Here that place is already
    /// spending 510 ms resolving the **Toolchain**.
    static func warm() {
        _ = runningApps()
    }

    /// Every application with a Dock icon, named as the person sees it named.
    ///
    /// `.regular` is what "application" means here — it drops the agents, the extensions and the
    /// helpers that make up most of `runningApplications`, none of which anyone thinks of as
    /// something on their screen. It also drops Starkit, which is `.accessory` (`main.swift`), so
    /// the **Kill** list cannot contain the process performing it. `clean.gleam` refuses that name
    /// again on its own side, and the two locks are deliberate: this one is not tested and that one
    /// is.
    ///
    /// `localizedName` because it is the name macOS shows and therefore the name someone writes in
    /// a keep list. The nil case is an application that stopped existing between the property read
    /// and this line, which is a **Kill** with nothing to aim at.
    private static func runningApps() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.localizedName)
    }
}
