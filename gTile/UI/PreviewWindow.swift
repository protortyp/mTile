import AppKit

/// Semi-transparent NSPanel that shows a preview of where the window will be placed.
///
/// This is the macOS equivalent of gTile's Preview UI component.
final class PreviewWindow: NSPanel {
    private let previewView: NSView

    init() {
        let initialFrame = NSRect(x: 0, y: 0, width: 100, height: 100)
        self.previewView = NSView(frame: initialFrame)

        super.init(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Configure preview appearance
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        previewView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        previewView.layer?.borderWidth = 2
        previewView.layer?.cornerRadius = 8

        contentView = previewView
    }

    /// Sets the preview area in AX coordinates (top-left origin).
    /// Pass nil to hide the preview.
    var previewArea: Rectangle? {
        didSet {
            if let area = previewArea {
                let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                let nsY = primaryHeight - area.y - area.height

                let frame = NSRect(
                    x: area.x, y: nsY,
                    width: area.width, height: area.height
                )

                setFrame(frame, display: true, animate: true)
                orderFrontRegardless()
            } else {
                orderOut(nil)
            }
        }
    }
}
