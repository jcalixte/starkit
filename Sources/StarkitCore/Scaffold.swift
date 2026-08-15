import Foundation

/// What a new **Script** says before anyone has written it.
///
/// The text has to compile the moment it lands on disk, because C6 will build it within 200 ms of it
/// appearing and a template that does not compile turns the menu bar red as its own welcome.
public enum Scaffold {
    /// A **Keyword** is a Gleam module name — the file becomes `import scripts/<keyword>` — so what is
    /// allowed here is what Gleam allows there: lowercase, digits and underscores, starting with a
    /// letter. Anything else is not offered rather than sanitised, because a **Keyword** silently
    /// different from what was typed is a **Keyword** nobody can find again.
    public static func isValid(_ keyword: String) -> Bool {
        guard let first = keyword.first, first.isLowercaseASCIILetter else { return false }
        return keyword.allSatisfy { $0.isLowercaseASCIILetter || $0.isASCIIDigit || $0 == "_" }
    }

    public static func name(for keyword: String) -> String {
        let words = keyword.split(separator: "_").joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// A **Script** that compiles, does nothing, and shows where to start.
    public static func source(for keyword: String) -> String {
        """
        //// \(name(for: keyword)) — created by Starkit. Say what it does here.

        import starkit.{type Script, Decides, Script}

        pub fn script() -> Script {
          Script(
            keyword: "\(keyword)",
            name: "\(name(for: keyword))",
            other_keywords: [],
            needs: [],
            asks: Decides,
            run: fn(_input, _context) {
              // The Effects you want performed, in order. For example:
              //
              //   [starkit.Notify("it works")]
              //
              // Declare needs: [starkit.RunningApps] to be handed the machine's state, and
              // asks: Asks(for: "a question") to be given a line of Input first.
              []
            },
          )
        }

        """
    }
}

extension Character {
    fileprivate var isLowercaseASCIILetter: Bool { self >= "a" && self <= "z" }
    fileprivate var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}
