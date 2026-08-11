import Foundation

/// One thing a **Script** asked the **Shelf** to do to the machine.
///
/// The Swift half of the **Effect** vocabulary that `starkit.gleam` declares, and the only shape in
/// which a **Script**'s decision crosses into code that may act. There is no generator between the
/// two halves and no schema they are both checked against, so drift is possible — which is why an
/// unknown `kind` is a decode failure with the offending word in it rather than an **Effect** the
/// **Effector** would silently skip.
public enum Effect: Equatable, Sendable {
    /// Bring an application to the front, launching it if it is not running.
    case open(app: String)
    /// Terminate an application without asking it first.
    case kill(app: String)
    /// Put text on the clipboard, restore focus, and synthesise the paste keystroke.
    case paste(text: String)
    /// Show a message in the bar — the only way a **Script** reports anything.
    case notify(message: String)
}

extension Effect {
    /// Read what `entry.gleam` answered: the **Effects** a **Script** decided on, or the **Refusal**
    /// that came back instead of them.
    ///
    /// Pure, and in `StarkitCore` for that reason: C4 owns the process and none of that is testable
    /// without a machine, while deciding what a reply *means* is separable from obtaining one.
    ///
    /// - Parameters:
    ///   - reply: everything the child wrote to stdout.
    ///   - keyword: named in every **Refusal**, because a person ran one **Script** and should be
    ///     told about that one.
    ///   - diagnostics: everything it wrote to stderr, colour already stripped, `nil` when it said
    ///     nothing. This is F12's only channel.
    ///   - exitStatus: reported rather than judged. A non-zero exit with a good reply is normal —
    ///     `run.mjs` exits 1 on a **Refusal** it has already written out — so the reply is read
    ///     first and the status only ever appears in a message.
    public static func all(
        inReplyTo keyword: String,
        reply: Data,
        diagnostics: String?,
        exitStatus: Int32
    ) throws(Refusal) -> [Effect] {
        // Nothing on stdout is F12's case: the **Script** threw, or `run.mjs` could not import the
        // **Artefact** at all. Either way the child's own words are the only useful thing to say, and
        // there is nothing Starkit could add to a stack trace by paraphrasing it.
        guard !reply.isEmpty else {
            throw Refusal(
                "The Script \"\(keyword)\" failed while it was running.",
                detail: diagnostics ?? "bun exited \(exitStatus) without writing an answer."
            )
        }

        let keys: Keys
        do {
            keys = try JSONDecoder().decode(Keys.self, from: reply)
        } catch {
            // A reply that cannot be read means the two halves of the **Vocabulary** have drifted,
            // which is a different problem from a **Script** failing and has a different fix.
            throw Refusal(
                "Starkit could not read what \"\(keyword)\" answered.",
                detail: "\(error)"
            )
        }

        if let refusal = keys.refusal { throw Refusal(refusal) }
        // Absent rather than empty is not a case `entry.gleam` produces — every reply carries one key
        // or the other — but a **Script** deciding on nothing at all is legitimate, and the seeded
        // `work.gleam` is exactly that until you fill it in.
        return keys.effects ?? []
    }

    /// The two keys `entry.gleam` writes — a decoding mechanism, not a name for the reply, which
    /// CONTEXT.md deliberately leaves unnamed.
    private struct Keys: Decodable {
        let effects: [Effect]?
        let refusal: String?
    }
}

extension Effect: Decodable {
    private enum Key: String, CodingKey {
        case kind, app, text, message
    }

    /// The field carrying the value is the **Vocabulary**'s own name for it — `app`, `text`,
    /// `message` — so `Paste(text:)` arrives under `"text"` and this reads back what the **Script**
    /// wrote. `entry.gleam`'s `tagged` is the other end of exactly this.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "open": self = .open(app: try container.decode(String.self, forKey: .app))
        case "kill": self = .kill(app: try container.decode(String.self, forKey: .app))
        case "paste": self = .paste(text: try container.decode(String.self, forKey: .text))
        case "notify": self = .notify(message: try container.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription:
                    "\"\(kind)\" is not an Effect this Starkit knows. The vendored Vocabulary in "
                    + "~/.starkit is ahead of the app; reinstall."
            )
        }
    }
}

extension Effect: CustomStringConvertible {
    /// Printed as the **Script** author wrote it, not as it crossed the wire. `--dry-run` exists to
    /// answer "what did this **Script** decide", and the person asking is reading Gleam.
    public var description: String {
        switch self {
        case .open(let app): "Open(\(String(reflecting: app)))"
        case .kill(let app): "Kill(\(String(reflecting: app)))"
        case .paste(let text): "Paste(\(String(reflecting: text)))"
        case .notify(let message): "Notify(\(String(reflecting: message)))"
        }
    }
}
