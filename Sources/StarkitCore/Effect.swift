import Foundation

/// One thing a **Script** asked the **Shelf** to do to the machine.
///
/// Must stay in sync with the **Effect** vocabulary `starkit.gleam` declares: there is no generator
/// between the two halves and no shared schema, which is why an unknown `kind` is a decode failure
/// naming the offending word rather than an **Effect** the **Effector** silently skips.
public enum Effect: Equatable, Sendable {
    /// Bring an application to the front, launching it if it is not running.
    case open(app: String)
    /// Hand a URL to whatever registered its scheme.
    case browse(url: String)
    /// Terminate an application without asking it first.
    case kill(app: String)
    /// Put text on the clipboard and stop there.
    case copy(text: String)
    /// Put text on the clipboard, restore focus, and synthesise the paste keystroke.
    case paste(text: String)
    case notify(message: String)
}

extension Effect {
    /// Reads what `entry.gleam` answered.
    ///
    /// - Parameters:
    ///   - diagnostics: the child's stderr with colour **already stripped** by the caller.
    ///   - exitStatus: reported, never judged. A non-zero exit with a good reply is normal —
    ///     `run.mjs` exits 1 on a **Refusal** it has already written out — so the reply is read
    ///     first and the status only ever appears in a message.
    public static func all(
        inReplyTo keyword: String,
        reply: Data,
        diagnostics: String?,
        exitStatus: Int32
    ) throws(Refusal) -> [Effect] {
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
            throw Refusal(
                "Starkit could not read what \"\(keyword)\" answered.",
                detail: "\(error)"
            )
        }

        if let refusal = keys.refusal { throw Refusal(refusal) }
        // A **Script** deciding on nothing at all is legitimate — the seeded `work.gleam` is exactly
        // that until you fill it in.
        return keys.effects ?? []
    }

    private struct Keys: Decodable {
        let effects: [Effect]?
        let refusal: String?
    }
}

extension Effect: Decodable {
    private enum Key: String, CodingKey {
        case kind, app, url, text, message
    }

    /// Each value arrives under the **Vocabulary**'s own name for it — `app`, `url`, `text`,
    /// `message`. `entry.gleam`'s `tagged` is the other end of exactly this.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "open": self = .open(app: try container.decode(String.self, forKey: .app))
        case "browse": self = .browse(url: try container.decode(String.self, forKey: .url))
        case "kill": self = .kill(app: try container.decode(String.self, forKey: .app))
        case "copy": self = .copy(text: try container.decode(String.self, forKey: .text))
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
    /// Printed as the **Script** author wrote it, not as it crossed the wire.
    public var description: String {
        switch self {
        case .open(let app): "Open(\(String(reflecting: app)))"
        case .browse(let url): "Browse(\(String(reflecting: url)))"
        case .kill(let app): "Kill(\(String(reflecting: app)))"
        case .copy(let text): "Copy(\(String(reflecting: text)))"
        case .paste(let text): "Paste(\(String(reflecting: text)))"
        case .notify(let message): "Notify(\(String(reflecting: message)))"
        }
    }
}
