import AppKit
import Carbon.HIToolbox
import StarkitCore

/// C3 — ⌃⌘K, the one way in from anywhere.
///
/// `RegisterEventHotKey` rather than the `CGEventTap` `cmd-tab` uses. A tap is the right tool for
/// *intercepting* a chord the system already means something by, and it costs an Accessibility
/// grant that macOS can revoke on its own — a permission a user never granted for this, silently
/// switched off, is F8's whole failure mode. Carbon asks for the chord instead of watching every
/// key, needs no permission, and cannot be turned off behind Starkit's back.
///
/// It also cannot swallow anything, though not for the reason T2.1 expected. Carbon does not
/// arbitrate between applications at all: two processes asking for ⌃⌘K both get `noErr` and neither
/// is told about the other, and a `CGEventTap` — which is how Script Kit listens — sees the key
/// before hotkey dispatch happens and can consume it outright. Measured both ways at T2.1. So
/// Starkit cannot take a chord away from anyone, and cannot be told when someone has taken it from
/// Starkit; what is left of "report failure to hold it" is the registration itself, which fails
/// only for reasons that are ours (`DESIGN.md` §4, F8).
@MainActor
final class HotKey {
    /// ⌃⌘K. Carbon counts keys by position, and `kVK_ANSI_K` is the key where a US layout prints K
    /// — the chord follows the physical key across layouts rather than following the letter.
    private static let key = UInt32(kVK_ANSI_K)
    private static let modifiers = UInt32(controlKey | cmdKey)

    /// `'STRK'`, four bytes as Carbon has wanted an `OSType` since 1984. It scopes the id below to
    /// us; nothing else reads it.
    private static let signature = OSType(0x5354_524B)

    private let onPress: () -> Void
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    /// Take the chord, or **Refuse**.
    func register() throws(Refusal) {
        var wanted = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // The callback is a C function pointer and can capture nothing, so `self` travels as the
        // user-data pointer. Unretained: the delegate owns this object for the life of the process,
        // and a retain here would be a cycle with no one left to break it.
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
        // `eventHotKeyExistsErr` is about us and not about the machine. Measured at T2.1: a second
        // process asking for the same chord is given it, so this fires only when Starkit registers
        // twice — a bug in the caller, worded as one rather than as a conflict with an application
        // that would be named in it if Carbon had a name to give.
        guard registered != eventHotKeyExistsErr else {
            throw Refusal("Starkit is already holding ⌃⌘K.")
        }
        guard registered == noErr else {
            throw Refusal("Starkit could not take ⌃⌘K (Carbon error \(registered)).")
        }
    }
}
