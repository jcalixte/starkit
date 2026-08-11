import Foundation

/// One thing a **Script** asked the **Shelf** to do to the machine.
///
/// The Swift half of the **Effect** vocabulary that `starkit.gleam` declares, and the only shape in
/// which a **Script**'s decision crosses into code that may act. There is no generator between the
/// two halves and no schema they are both checked against: the wire format is four tagged objects,
/// and a **Vocabulary** that grows by decision rather than by convenience (G6) is cheaper to spell
/// twice than to derive. What that costs is one **Refusal** when they drift, which is why the
/// unknown `kind` is a decode failure with the offending word in it rather than an **Effect** the
/// **Effector** would silently skip.
enum Effect: Equatable {
    /// Bring an application to the front, launching it if it is not running.
    case open(app: String)
    /// Terminate an application without asking it first.
    case kill(app: String)
    /// Put text on the clipboard, restore focus, and synthesise the paste keystroke.
    case paste(text: String)
    /// Show a message in the bar — the only way a **Script** reports anything.
    case notify(message: String)
}

extension Effect: Decodable {
    private enum Key: String, CodingKey {
        case kind, app, text, message
    }

    /// The field carrying the value is the **Vocabulary**'s own name for it — `app`, `text`,
    /// `message` — so `Paste(text:)` arrives under `"text"` and this reads back what the **Script**
    /// wrote. `entry.gleam`'s `tagged` is the other end of exactly this.
    init(from decoder: Decoder) throws {
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
    var description: String {
        switch self {
        case .open(let app): "Open(\(String(reflecting: app)))"
        case .kill(let app): "Kill(\(String(reflecting: app)))"
        case .paste(let text): "Paste(\(String(reflecting: text)))"
        case .notify(let message): "Notify(\(String(reflecting: message)))"
        }
    }
}
