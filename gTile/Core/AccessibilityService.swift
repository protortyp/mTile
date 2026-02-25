import AppKit
import ApplicationServices

/// Wraps the macOS Accessibility API (AXUIElement) for window management.
final class AccessibilityService {

    /// Returns true if the app has been granted accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for accessibility permissions if not yet granted.
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Returns the AXUIElement for the currently focused window, or nil.
    func focusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }

        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            return nil
        }

        return (focusedWindow as! AXUIElement)
    }

    /// Returns the frame rectangle of a window (in screen coordinates, top-left origin).
    func windowFrame(_ window: AXUIElement) -> Rectangle? {
        guard let position = getPosition(window),
              let size = getSize(window) else {
            return nil
        }

        return Rectangle(
            x: Double(position.x),
            y: Double(position.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }

    /// Moves and resizes a window to the specified frame.
    func setWindowFrame(_ window: AXUIElement, frame: Rectangle) {
        var position = CGPoint(x: frame.x, y: frame.y)
        var size = CGSize(width: frame.width, height: frame.height)

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }

        // Some apps need position set again after resize
        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
    }

    /// Moves a window to the specified position without resizing.
    func moveWindow(_ window: AXUIElement, to position: CGPoint) {
        var pos = position
        if let posValue = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
    }

    /// Returns the title of a window, or nil.
    func windowTitle(_ window: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    /// Returns the owning application's PID for a window.
    func windowPID(_ window: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        return pid
    }

    /// Returns all windows for a given application PID.
    func windowsForApp(_ pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }

    /// Enumerates all windows across all running applications.
    func allWindows() -> [(window: AXUIElement, pid: pid_t)] {
        var results: [(AXUIElement, pid_t)] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            let pid = app.processIdentifier
            for window in windowsForApp(pid) {
                // Skip windows without a title or with empty size
                if let frame = windowFrame(window), frame.width > 0 && frame.height > 0 {
                    results.append((window, pid))
                }
            }
        }

        return results
    }

    /// Returns the monitor index that a window is primarily on.
    func windowMonitorIndex(_ window: AXUIElement) -> Int {
        guard let frame = windowFrame(window) else { return 0 }
        let windowCenter = CGPoint(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)

        for (index, screen) in NSScreen.screens.enumerated() {
            let screenFrame = DisplayService.screenFrameInAXCoordinates(screen)
            if screenFrame.contains(windowCenter) {
                return index
            }
        }

        return 0
    }

    /// Returns true if a window is minimized.
    func isMinimized(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    // MARK: - Private Helpers

    private func getPosition(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    private func getSize(_ element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success else {
            return nil
        }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }
}
