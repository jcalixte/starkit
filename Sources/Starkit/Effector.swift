import AppKit
import StarkitCore

/// C7 — do to the machine what a **Script** decided, in the order it decided it.
///
/// The only component that acts, which is what the closed **Effect** vocabulary buys: a **Script**
/// returns a decision and can touch nothing itself, so every permission the **Shelf** was granted
/// is exercised from here and nowhere else. **Open** is all of it for now — **Kill** arrives at
/// T4.3, **Paste** and **Notify** at T5.3 and T5.4 — and until then an **Effect** this cannot
/// perform is a **Refusal**, never a silent skip. Claiming to have done something is the one
/// failure a person cannot see.
struct Effector {
    /// Stops at the first **Effect** it cannot perform, leaving the ones before it done.
    ///
    /// The **Effects** after a failed one were decided on the assumption that it happened, so
    /// carrying on would be performing a decision nobody made.
    func perform(_ effects: [Effect]) throws(Refusal) {
        for effect in effects {
            switch effect {
            case .open(let app): try open(app)
            case .kill, .paste, .notify:
                throw Refusal("Starkit cannot perform \(effect) yet.")
            }
        }
    }

    /// Bring an application to the front, launching it if it is not running.
    ///
    /// `NSWorkspace.open` rather than `openApplication(at:configuration:)`, which is the same call
    /// with a completion handler and a queue to think about. Nothing here needs either: it returns
    /// what it did, and each **Open** is finished before the next one starts.
    ///
    /// Which application ends up frontmost after several **Opens** is not something this decides.
    /// `NSWorkspace` activates an application when its launch finishes rather than when it is
    /// asked, so a cold Slack can arrive after a warm terminal asked for later. Measured at T1.5
    /// and left alone: the **Effects** were all performed, in order, and the front is not worth
    /// serialising launches for.
    ///
    /// `fullPath(forApplication:)` is deprecated, and the replacement Apple names in the warning —
    /// `urlForApplication(withBundleIdentifier:)` — answers a different question. **Open** carries
    /// the name a person reads in the Finder (CONTEXT.md), and this is LaunchServices' own answer
    /// to it: it finds an application wherever it is installed, `/System/Applications` and
    /// `~/Applications` included, and it is case-insensitive. Enumerating the directories we think
    /// applications live in would be the mistake DESIGN.md §4 F15 records rejecting for `PATH` — a
    /// list that is right until someone keeps an app somewhere else, and whose failure reads as "no
    /// such application" when there plainly is one. When macOS removes it, the build breaks loudly,
    /// which is the failure worth having.
    private func open(_ app: String) throws(Refusal) {
        guard let path = NSWorkspace.shared.fullPath(forApplication: app) else {
            throw Refusal(
                "There is no application called \"\(app)\" on this machine.",
                detail: "Open takes the name you see in the Finder, not a path or a bundle id."
            )
        }
        guard NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
            throw Refusal("Starkit could not open \(app).", detail: "It is at \(path).")
        }
    }
}
