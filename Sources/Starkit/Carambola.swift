import AppKit

/// The star fruit, drawn rather than loaded.
///
/// The shape is Tabler's `carambola` (MIT), whose outline is one closed path of quadratic curves.
/// `NSImage` cannot read an SVG unless it comes out of a compiled asset catalog, and this bundle is
/// assembled by hand in `build.sh` with no `actool` step — so the path is transcribed here instead.
/// That also keeps the menu bar's copy a template image, which is what lets AppKit tint it for a
/// light or dark menu bar without a second asset.
///
/// Two places draw it now, which is why it is here rather than inside either: C10 needs it in the
/// menu bar's own colour, C1 needs it in the palette's cream on a periwinkle chip.
enum Carambola {
    /// For the menu bar: one colour, tinted by AppKit to suit a light or dark bar.
    ///
    /// 18pt inside a 24pt bar. The outline fills about four fifths of its own box, so this puts the
    /// drawn glyph at roughly the height of the system symbols sitting next to it.
    static func template(accessibilityDescription: String) -> NSImage {
        let image = image(box: 18, colour: .black)
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    /// `NSImage(size:flipped:drawingHandler:)` rather than `lockFocus`, so the glyph is redrawn at
    /// whatever backing scale the screen it lands on has.
    static func image(box: CGFloat, colour: NSColor) -> NSImage {
        // Tabler strokes at 2 units in a 24-unit box. Thinned to 1.6, which matches the weight of
        // the menu bar's own glyphs — at 2 the fruit reads as bolder than everything around it.
        let pen = box * 1.6 / 24
        let glyph = centred(path(in: box, pen: pen), in: box)
        return NSImage(size: NSSize(width: box, height: box), flipped: false) { _ in
            colour.setStroke()
            glyph.stroke()
            return true
        }
    }

    /// Centre the outline on its own ink rather than on the box it was authored in.
    ///
    /// Tabler's fruit does not fill its 24-unit box evenly — it sits low and slightly left inside it
    /// — so a glyph drawn at the box's centre is visibly off centre in anything that centres the
    /// image, which is every place Starkit puts it. Corrected here, once, rather than by nudging
    /// each frame that holds it.
    private static func centred(_ path: NSBezierPath, in box: CGFloat) -> NSBezierPath {
        let ink = path.bounds
        path.transform(
            using: AffineTransform(
                translationByX: (box - ink.width) / 2 - ink.minX,
                byY: (box - ink.height) / 2 - ink.minY
            )
        )
        return path
    }

    /// Tabler's path data, verbatim in structure: one `move`, then its relative quadratic curves
    /// and two short horizontal joins, closed.
    ///
    /// `NSBezierPath` gained a quadratic curve only in macOS 14, so each is widened to the cubic it
    /// is equal to — control points at two thirds of the way from each end towards the quadratic's
    /// single control point. Exact, not an approximation.
    private static func path(in box: CGFloat, pen: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        var cursor = CGPoint(x: 17.286, y: 21.09)
        path.move(to: cursor)

        func curve(_ cx: CGFloat, _ cy: CGFloat, _ ex: CGFloat, _ ey: CGFloat) {
            let control = CGPoint(x: cursor.x + cx, y: cursor.y + cy)
            let end = CGPoint(x: cursor.x + ex, y: cursor.y + ey)
            path.curve(
                to: end,
                controlPoint1: CGPoint(
                    x: cursor.x + 2 / 3 * (control.x - cursor.x),
                    y: cursor.y + 2 / 3 * (control.y - cursor.y)
                ),
                controlPoint2: CGPoint(
                    x: end.x + 2 / 3 * (control.x - end.x),
                    y: end.y + 2 / 3 * (control.y - end.y)
                )
            )
            cursor = end
        }
        func across(_ dx: CGFloat) {
            cursor.x += dx
            path.line(to: cursor)
        }

        curve(-1.69, 0.001, -5.288, -2.615)
        curve(-3.596, 2.617, -5.288, 2.616)
        curve(-2.726, 0, -0.495, -6.8)
        curve(-9.389, -6.775, 2.135, -6.775)
        across(0.076)
        curve(1.785, -5.516, 3.574, -5.516)
        curve(1.785, 0, 3.574, 5.516)
        across(0.076)
        curve(11.525, 0, 2.133, 6.774)
        curve(2.23, 6.802, -0.497, 6.8)
        path.close()

        // SVG counts y downwards, AppKit upwards. Flip, then fit the 24-unit box into `box` with
        // half a pen width spare on each side — a stroke centred on the outline would otherwise
        // clip at the five points.
        var fit = AffineTransform(translationByX: pen / 2, byY: pen / 2)
        var flip = AffineTransform(scaleByX: (box - pen) / 24, byY: -(box - pen) / 24)
        flip.translate(x: 0, y: -24)
        fit.append(flip)
        path.transform(using: fit)

        path.lineWidth = pen
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        return path
    }
}
