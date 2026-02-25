import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions
        let trusted = AccessibilityService.isTrusted
        if !trusted {
            AccessibilityService.requestPermission()
            print("gTile: Accessibility permission not yet granted. Please grant access in System Settings.")
        }

        // Create the app coordinator
        coordinator = AppCoordinator()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator = nil
        AppCoordinator.shared = nil
    }
}
