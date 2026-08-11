import AppKit

let application = NSApplication.shared
// `NSApplication.delegate` is a weak reference, so the delegate has to be kept alive here.
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
// Menu-bar-only. Set here as well as via `LSUIElement` in Info.plist, because the executable
// is also run directly from a terminal during development, where no bundle is involved.
//
// `.accessory` matters beyond the missing Dock icon: the Shelf must never take focus away from
// the app you were in, because Paste has to give it back. An app that never became active has
// nothing to give back.
application.setActivationPolicy(.accessory)
application.run()
