import ServiceManagement

/// C9 — start at login, via `SMAppService.mainApp`: the bundle registers itself, so there is no
/// helper bundle to sign alongside it and no login-items plist to keep in step.
///
/// **Nothing here is remembered.** The registration outlives the process and can be changed behind
/// its back — in System Settings, or by the bundle moving — so every read asks macOS again. That is
/// the whole of T7.2: a cached `Bool` would keep saying "on" long after the answer had changed.
enum LoginItem {
    /// What macOS reports, in the four shapes it can take.
    enum State {
        /// Registered and on: Starkit comes back at the next login.
        case on
        /// Never registered, or registered and then turned off from this menu.
        case off
        /// Registered, and waiting on the person — which is also what a switch turned off in
        /// System Settings looks like, since macOS keeps the registration and disables it.
        case awaitingApproval
        /// macOS cannot find the bundle the registration names.
        case lost

        var isOn: Bool { self == .on }

        /// What the state needs said about it beyond on and off, or `nil` when it needs nothing.
        /// One string, so the menu and the terminal cannot drift apart.
        var note: String? {
            switch self {
            case .on, .off: nil
            case .awaitingApproval: "waiting on approval in System Settings"
            case .lost: "macOS cannot find the bundle"
            }
        }

        var menuTitle: String {
            note.map { "Start at Login — \($0)" } ?? "Start at Login"
        }
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: .on
        case .notRegistered: .off
        case .requiresApproval: .awaitingApproval
        case .notFound: .lost
        // A status this build has never heard of is treated as the broken one, because `.lost`'s
        // repair — register again from where the bundle actually is — is the sane answer to not
        // knowing.
        @unknown default: .lost
        }
    }

    /// Ask for on or off. Returns nothing on purpose: what macOS did with the request is `state`,
    /// read again, and a return value here would be the cached assumption T7.2 forbids.
    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Not routed to the menu bar: the menu is rebuilt from `state` every time it opens, so
            // a request that failed shows as the switch not having moved — at the moment and in the
            // place the person asked for it.
            report(
                "Start at Login: could not turn it \(enabled ? "on" : "off") — "
                    + error.localizedDescription
            )
        }
    }

    /// The menu click. Three states ask to be flipped; the fourth is macOS waiting on a person, and
    /// registering again is not what it is waiting for.
    static func flip() {
        let state = state
        if state == .awaitingApproval {
            SMAppService.openSystemSettingsLoginItems()
        } else {
            set(!state.isOn)
        }
    }
}
