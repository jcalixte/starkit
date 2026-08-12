import AppKit
import StarkitCore

/// Starkit's icon in Finder, drawn rather than stored.
///
/// The same two colours on the same path as the bar's mark — cream fruit on a periwinkle plate — so
/// what /Applications shows and what sits at the head of the bar are one object and not two drawings
/// that have to be kept in step by hand. `build.sh` renders it on every build for that reason: a
/// checked-in `.icns` is a copy of `Carambola` that nothing recompiles.
///
/// Written as an `.iconset` of PNGs because `iconutil` is the only thing that writes `.icns`, and it
/// reads a directory of PNGs named its way.
enum AppIcon {
    /// Apple's icon grid: an 824-wide plate inside a 1024 canvas, cornered at 185.4. The margin is
    /// not spare room — it is where macOS expects the icon's shadow to go, so an icon drawn edge to
    /// edge reads a tenth larger than everything beside it.
    private static let plate: CGFloat = 824 / 1024
    private static let corner: CGFloat = 185.4 / 824

    /// The fruit on the plate, filled rather than outlined and a little larger than the 20-on-30 the
    /// bar's mark uses.
    ///
    /// The smallest size decides both. Finder's list view asks for 16 pixels: at the mark's
    /// proportions the fruit lands on 9 of them behind a stroke half a pixel wide, which renders as a
    /// bruise on a blue square, while solid ink at this size is still recognisably a star. The mark
    /// keeps the outline because it sits among 13pt text and system symbols drawn the same way.
    private static let fruit: CGFloat = 0.74

    /// What `iconutil` demands, under the names it demands them under.
    ///
    /// An `@2x` is the same drawing at twice the pixels, which for a stroked path is just a bigger
    /// render — so this is a list of pixel counts and nothing more. Two pairs come out identical
    /// (`16x16@2x` and `32x32`, `256x256@2x` and `512x512`); both files are written, because
    /// `iconutil` fails on an incomplete set rather than inferring the one it was not given.
    private static let sizes: [(name: String, pixels: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    /// Write the `.iconset` directory, and say where it went.
    static func iconset(at directory: URL) throws(Refusal) -> URL {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw Refusal("Starkit could not make \(directory.path).", detail: "\(error)")
        }

        for (name, pixels) in sizes {
            guard let png = png(pixels: pixels) else {
                throw Refusal("Starkit could not draw its icon at \(pixels)px.")
            }
            do {
                try png.write(to: directory.appending(path: name), options: .atomic)
            } catch {
                throw Refusal("Starkit could not write \(name).", detail: "\(error)")
            }
        }
        return directory
    }

    /// One PNG, `pixels` on a side.
    ///
    /// sRGB is named rather than left to the device, for the reason `Palette` gives its hexes in
    /// sRGB: a bitmap tagged with whatever space the drawing Mac's display uses would put a
    /// different periwinkle in the file depending on which Mac ran the build.
    private static func png(pixels: Int) -> Data? {
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: pixels,
                height: pixels,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw(box: CGFloat(pixels))
        NSGraphicsContext.restoreGraphicsState()

        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// The plate, then the fruit on it, into whichever context is current.
    ///
    /// A circular corner, not the continuous one the bar's chip has: AppKit exposes that curve on
    /// `CALayer` only, and reaching for a layer to render one rounded rectangle would trade a
    /// documented shape for an undocumented one.
    private static func draw(box: CGFloat) {
        let side = box * plate
        let radius = side * corner
        Palette.accent.setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: (box - side) / 2,
                y: (box - side) / 2,
                width: side,
                height: side
            ),
            xRadius: radius,
            yRadius: radius
        ).fill()

        let glyph = side * fruit
        Carambola.fill(box: glyph, colour: Palette.fruit)
            .draw(
                in: NSRect(
                    x: (box - glyph) / 2,
                    y: (box - glyph) / 2,
                    width: glyph,
                    height: glyph
                )
            )
    }
}
