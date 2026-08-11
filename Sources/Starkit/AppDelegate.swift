import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
    }
}
