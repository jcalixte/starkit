import AppKit

/// The four colours Starkit is drawn from — colorhunt.co/palette/fff2c6fff8deaac4f58ca9ff.
///
/// These never replace the system's text colours: `labelColor` and its relatives already answer
/// light and dark correctly, and overriding them would be a legibility bug on whichever appearance
/// was not being looked at while choosing.
enum Palette {
    static let fruit = NSColor(hex: 0xFFF2C6)

    /// Not a colour but an opacity: what the panel is made of, under everything else.
    ///
    /// `.behindWindow` blending lets the desktop set the bar's brightness while text colours answer
    /// the *appearance*. This neutral is weighted so the bar's own luminance wins: against a white
    /// desktop it leaves 5.7:1 behind `labelColor`, and against a dark one it barely shows.
    static let backing = NSColor(name: "starkit.backing") { appearance in
        appearance.isDark
            ? NSColor(white: 0, alpha: 0.55)
            : NSColor(white: 1, alpha: 0.5)
    }

    /// The **Keyword** at the end of a row, one step under the name beside it.
    ///
    /// Not `secondaryLabelColor`: the system picks that weight for secondary text on an *opaque*
    /// window, and over this bar's backing it measures 3.9:1 against a bright desktop at the
    /// **Keyword**'s 13pt. Half a step back up puts it near 5:1.
    static let aside = NSColor(name: "starkit.aside") { appearance in
        appearance.isDark
            ? NSColor(white: 1, alpha: 0.75)
            : NSColor(white: 0, alpha: 0.7)
    }

    /// A warm wash over the blur. Weighted per appearance because a fixed alpha cannot be right for
    /// both: cream heavy enough for near-black text in light mode lifts a dark panel until white
    /// text has nothing left.
    static let wash = NSColor(name: "starkit.wash") { appearance in
        NSColor(hex: 0xFFF8DE, alpha: appearance.isDark ? 0.07 : 0.55)
    }

    /// The panel's own edge. A blurred panel over a pale desktop otherwise has no outline at all and
    /// dissolves into whatever is behind it.
    static let edge = NSColor(name: "starkit.edge") { appearance in
        NSColor(hex: 0xAAC4F5, alpha: appearance.isDark ? 0.45 : 0.9)
    }

    static let accent = NSColor(hex: 0x8CA9FF)

    /// The accent behind the selected row, where it is the paper instead. The row's name stays
    /// `labelColor`, so the band must be strong enough to read as the selection and weak enough to
    /// leave near-black text readable in one appearance and white in the other.
    static let selection = NSColor(name: "starkit.selection") { appearance in
        NSColor(hex: 0x8CA9FF, alpha: appearance.isDark ? 0.30 : 0.45)
    }

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
    /// `0xRRGGBB`, in sRGB, so a colour reads the way its palette does rather than being
    /// reinterpreted into the display's own space.
    fileprivate convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
