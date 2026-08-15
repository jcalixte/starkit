import AppKit
import Carbon.HIToolbox
import StarkitCore

/// C3 — ⌃⌘K, the one way in from anywhere.
///
/// `RegisterEventHotKey` rather than a `CGEventTap`: a tap costs an Accessibility grant that macOS
/// can revoke on its own, and a permission silently switched off is F8's whole failure mode.
///
/// Carbon does not arbitrate between applications: two processes asking for ⌃⌘K both get `noErr` and
/// neither is told about the other, so Starkit can neither take the chord from anyone nor detect
/// having lost it.
@MainActor
final class HotKey {
    /// Carbon counts keys by position, so the chord follows the physical key across layouts rather
    /// than the letter.
    private static let key = UInt32(kVK_ANSI_K)
    private static let modifiers = UInt32(controlKey | cmdKey)

    /// `'STRK'` as an `OSType`. Scopes the id below to us; nothing else reads it.
    private static let signature = OSType(0x5354_524B)

    private let onPress: () -> Void
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    func register() throws(Refusal) {
        var wanted = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // The callback is a C function pointer and can capture nothing, so `self` travels as the
        // user-data pointer — unretained, because the delegate owns this object for the life of the
        // process and a retain here would be a cycle with no one left to break it.
        let installed = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
                // Carbon dispatches this on the main run loop, which is where the assumption holds.
                MainActor.assumeIsolated { hotKey.onPress() }
                return noErr
            },
            1,
            &wanted,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard installed == noErr else {
            throw Refusal("Starkit could not listen for ⌃⌘K (Carbon error \(installed)).")
        }

        let registered = RegisterEventHotKey(
            Self.key,
            Self.modifiers,
            EventHotKeyID(signature: Self.signature, id: 1),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        // A second process asking for the same chord is given it, so this fires only when Starkit
        // registers twice — a bug in the caller, not a conflict with another app.
        guard registered != eventHotKeyExistsErr else {
            throw Refusal("Starkit is already holding ⌃⌘K.")
        }
        guard registered == noErr else {
            throw Refusal("Starkit could not take ⌃⌘K (Carbon error \(registered)).")
        }
    }
}
