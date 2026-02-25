import AppKit

/// Abstraction that represents monitor settings, analogous to gTile's Screen type.
struct Screen {
    let index: Int
    let scale: CGFloat
    let resolution: Rectangle
    let workArea: Rectangle
}

/// Multi-monitor abstraction wrapping NSScreen.
///
/// macOS uses a bottom-left origin coordinate system for NSScreen,
/// but the Accessibility API uses top-left origin. This service handles
/// the conversion.
final class DisplayService {

    /// Returns the list of connected monitors with their work areas.
    /// Work areas are returned in Accessibility API coordinates (top-left origin).
    var monitors: [Screen] {
        NSScreen.screens.enumerated().map { (index, screen) in
            let resolution = screenFrameInAXCoordinates(screen)
            let workArea = visibleFrameInAXCoordinates(screen)

            return Screen(
                index: index,
                scale: screen.backingScaleFactor,
                resolution: resolution,
                workArea: workArea
            )
        }
    }

    /// Returns the primary monitor's index (always 0 for NSScreen).
    var primaryMonitorIndex: Int { 0 }

    /// The current mouse pointer location in AX coordinates.
    var pointerLocation: CGPoint {
        let nsPoint = NSEvent.mouseLocation
        return nsPointToAXPoint(nsPoint)
    }

    /// The monitor index that the pointer resides on.
    var pointerMonitorIndex: Int {
        let point = pointerLocation
        for (index, screen) in NSScreen.screens.enumerated() {
            let frame = DisplayService.screenFrameInAXCoordinates(screen)
            if point.x >= frame.x && point.x <= frame.x + frame.width &&
               point.y >= frame.y && point.y <= frame.y + frame.height {
                return index
            }
        }
        return 0
    }

    /// Converts an NSScreen frame to AX coordinates (top-left origin).
    static func screenFrameInAXCoordinates(_ screen: NSScreen) -> Rectangle {
        let frame = screen.frame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height

        return Rectangle(
            x: Double(frame.origin.x),
            y: Double(primaryHeight - frame.origin.y - frame.height),
            width: Double(frame.width),
            height: Double(frame.height)
        )
    }

    /// Converts an NSScreen's visible frame to AX coordinates (top-left origin).
    private func visibleFrameInAXCoordinates(_ screen: NSScreen) -> Rectangle {
        let visible = screen.visibleFrame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        return Rectangle(
            x: Double(visible.origin.x),
            y: Double(primaryHeight - visible.origin.y - visible.height),
            width: Double(visible.width),
            height: Double(visible.height)
        )
    }

    /// Converts an NSPoint (bottom-left origin) to AX coordinates (top-left origin).
    private func nsPointToAXPoint(_ point: NSPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
