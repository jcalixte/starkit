import AppKit

let application = NSApplication.shared
// `NSApplication.delegate` is a weak reference, so the delegate has to be kept alive here.
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
// Menu-bar-only. Set here as well as via `LSUIElement` in Info.plist, because the executable
// is also run directly from a terminal during development, where no bundle is involved.
//
// `.accessory` is about the Dock icon and nothing more. It is *not* a promise that the Shelf never
// takes focus — T0.5 measured that it has to: macOS routes keys only to the active application's
// key window, so a panel in an inactive app cannot be typed into, and a bar that cannot be typed
// into is not a bar. The Shelf takes activation on Summon and Paste hands it back, at a measured
// 19.4 ms (DESIGN.md §4, F7).
application.setActivationPolicy(.accessory)
application.run()
