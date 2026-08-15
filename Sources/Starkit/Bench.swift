import Foundation
import StarkitCore

/// `Starkit run <keyword> --bench[=N]` — the actuals behind [DESIGN.md](../../DESIGN.md) §8,
/// measured on the machine in front of you rather than asserted in CI.
///
/// Performs no **Effects**: twenty iterations of `work` would otherwise open eighty applications.
func bench(keyword: String, input: String, samples: Int) -> Int32 {
    let home = Toolchain.home
    print("\(samples) samples, \"\(keyword)\" against \(home.path). No Effects are performed.")

    // Capped where a sample costs a login-shell spawn that reads the whole profile: five is enough
    // for a median, and twenty would take ten seconds to answer about something per-launch.
    let launchSamples = min(samples, 5)

    var resolving = Clock("C12 resolve", "in F9's 3 s")
    var building = Clock("F4 build", "≤ 40 ms")
    var ensuring = Clock("F4 + staleness", "what ↩ pays")
    var describing = Clock("C2 describe", "in F9's 3 s")
    var gathering = Clock("F6 gather Context", "≤ 5 ms")
    var executing = Clock("F5 execute", "≤ 20 ms")

    var refusals = 0
    var lastRefusal: Refusal?

    do throws(Refusal) {
        // The first outside the loop rather than an optional inside it: one sample is always taken.
        var start = CFAbsoluteTimeGetCurrent()
        var toolchain = try Toolchain.resolve(home: home)
        resolving.sample(since: start)
        for _ in 1..<launchSamples {
            start = CFAbsoluteTimeGetCurrent()
            toolchain = try Toolchain.resolve(home: home)
            resolving.sample(since: start)
        }

        let builder = Builder(toolchain: toolchain, home: home)
        let runner = Runner(toolchain: toolchain, home: home)

        // Both clocks per iteration, so the two builds are the same age. `build` is the row §8 names;
        // `ensureCurrent` is that plus `remember` and the SHA-256 of every shared module.
        for _ in 0..<samples {
            start = CFAbsoluteTimeGetCurrent()
            try builder.build()
            building.sample(since: start)

            start = CFAbsoluteTimeGetCurrent()
            try builder.ensureCurrent(keyword)
            ensuring.sample(since: start)
        }

        for _ in 0..<launchSamples {
            start = CFAbsoluteTimeGetCurrent()
            _ = try runner.describe()
            describing.sample(since: start)
        }

        // Read once outside the clock: this is the declaration, not the gathering.
        let needs = try Catalogue(home: home).manifest(for: keyword, using: runner)?.needs ?? []
        if needs.isEmpty {
            print(
                "\"\(keyword)\" declares no Needs, so F6's row below is an empty Payload rather "
                    + "than a gather. Bench a Script that declares one for that number."
            )
        }

        for _ in 0..<samples {
            start = CFAbsoluteTimeGetCurrent()
            let payload = try ContextGatherer()
                .payload(input: input, keyword: keyword, needs: needs)
            gathering.sample(since: start)

            // A **Refusal** is timed like anything else and the loop goes on: for a **Script** that
            // hangs the **Refusal** *is* F14's measurement.
            start = CFAbsoluteTimeGetCurrent()
            do throws(Refusal) {
                _ = try runner.run(keyword: keyword, payload: payload)
            } catch {
                refusals += 1
                lastRefusal = error
            }
            executing.sample(since: start)
        }
    } catch {
        report(error.reason)
        if let detail = error.detail { report(detail) }
        return 1
    }

    print("")
    print(Clock.heading)
    for clock in [resolving, building, ensuring, describing, gathering, executing] {
        print(clock.row)
    }

    let path = [ensuring, gathering, executing].compactMap(\.median).reduce(0, +)
    print("")
    print("↩ path (F4 + staleness, F6, F5): \(Clock.milliseconds(path))")

    // On stdout with the table, not through `report`: on stderr it would arrive out of order, since
    // that stream is not buffered and this one is.
    if let lastRefusal {
        print("")
        print("\(refusals) of \(samples) runs Refused, the last of them:")
        print(lastRefusal.reason)
        if let detail = lastRefusal.detail { print(detail) }
    }
    return 0
}

/// One row of §8 and the samples taken for it.
///
/// The first sample is kept apart rather than averaged in: cold and warm are different numbers
/// everywhere in this system, and a median that hides the first sample would report neither.
private struct Clock {
    let function: String
    let budget: String
    private var cold: Double?
    private var warm: [Double] = []

    init(_ function: String, _ budget: String) {
        self.function = function
        self.budget = budget
    }

    /// Called after the work whether it returned or **Refused**: a run killed at its deadline took
    /// the time it took.
    mutating func sample(since start: CFAbsoluteTime) {
        let milliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1000
        if cold == nil { cold = milliseconds } else { warm.append(milliseconds) }
    }

    /// `nil` only when a single sample was asked for, where the cold one is all there is.
    var median: Double? {
        let sorted = warm.sorted()
        guard !sorted.isEmpty else { return cold }
        return sorted[(sorted.count - 1) / 2]
    }

    /// Nearest-rank, so the figure is always one that was actually measured rather than interpolated
    /// between two that were.
    private var p90: Double? {
        let sorted = warm.sorted()
        guard !sorted.isEmpty else { return nil }
        return sorted[min(sorted.count - 1, Int(ceil(0.9 * Double(sorted.count))) - 1)]
    }

    static let heading = "function            budget            cold    median       min       p90"

    var row: String {
        let cells = [Self.milliseconds(cold), Self.milliseconds(median)]
            + [Self.milliseconds(warm.min()), Self.milliseconds(p90)]
        return function.padding(toLength: 20, withPad: " ", startingAt: 0)
            + budget.padding(toLength: 14, withPad: " ", startingAt: 0)
            + cells.map { $0.leftPadded(to: 10) }.joined()
    }

    /// Three decimals under a millisecond, because F6's warm number is 0.006–0.016 ms and one decimal
    /// would print it as nothing at all.
    static func milliseconds(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: value < 1 ? "%.3f" : "%.1f", value)
    }
}

extension String {
    fileprivate func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
