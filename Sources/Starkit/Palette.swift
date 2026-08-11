import AppKit

/// The four colours Starkit is drawn from — colorhunt.co/palette/fff2c6fff8deaac4f58ca9ff.
///
/// Named by the job each one does rather than by its hue, because that is what a call site needs to
/// know, and the hex is kept in the comment so the set can be checked against the palette it came
/// from. Two creams and two blues is deliberately few: nothing here is a theme, and a fifth colour
/// would mean the bar had grown something to distinguish that the first four could not.
///
/// None of them replace the system's text colours. `labelColor` and its relatives already answer
/// light and dark correctly, and a palette that overrode them would be a legibility bug on whichever
/// appearance was not being looked at while choosing.
enum Palette {
    /// `#FFF2C6` — the fruit itself, on the periwinkle chip at the head of the bar.
    static let fruit = NSColor(hex: 0xFFF2C6)

    /// `#FFF8DE` — a warm wash over the blur, so the bar is Starkit's rather than the system's.
    ///
    /// Weighted per appearance, because a fixed alpha cannot be right for both: cream heavy enough
    /// to give near-black text something to sit on in light mode would lift a dark panel until white
    /// text had nothing left. Chosen for the contrast rather than for the colour.
    static let wash = NSColor(name: "starkit.wash") { appearance in
        NSColor(hex: 0xFFF8DE, alpha: appearance.isDark ? 0.07 : 0.55)
    }

    /// `#AAC4F5` — the panel's own edge. A blurred panel over a pale desktop otherwise has no
    /// outline at all, and dissolves into whatever is behind it.
    static let edge = NSColor(name: "starkit.edge") { appearance in
        NSColor(hex: 0xAAC4F5, alpha: appearance.isDark ? 0.45 : 0.9)
    }

    /// `#8CA9FF` — the chip and the caret, where the accent is the ink.
    static let accent = NSColor(hex: 0x8CA9FF)

    /// The accent behind the selected row, where it is the paper instead.
    ///
    /// Weighted per appearance for the same reason `wash` is, and against the same constraint: the
    /// row's name stays `labelColor`, so the band has to be strong enough to be the selection and
    /// weak enough to leave near-black text readable on it in one appearance and white in the other.
    static let selection = NSColor(name: "starkit.selection") { appearance in
        NSColor(hex: 0x8CA9FF, alpha: appearance.isDark ? 0.30 : 0.45)
    }

    /// The accent, taken far enough towards the background it sits on to be read as placeholder text
    /// rather than as something typed. Periwinkle at full strength on cream is a colour, not a word.
    static let placeholder = NSColor(name: "starkit.placeholder") { appearance in
        appearance.isDark
            ? NSColor(hex: 0x8CA9FF, alpha: 0.75)
            : NSColor(hex: 0x8CA9FF).blended(withFraction: 0.35, of: .black) ?? NSColor(hex: 0x8CA9FF)
    }
}

extension NSAppearance {
    fileprivate var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

extension NSColor {
    /// `0xRRGGBB`, in sRGB, so a colour reads the way its palette does rather than being reinterpreted
    /// into the display's own space.
    fileprivate convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
