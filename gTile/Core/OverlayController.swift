import AppKit
import Combine
import SwiftUI

/// Events emitted by the overlay system.
enum OverlayEvent {
    case selection(monitorIdx: Int, gridSize: GridSize, selection: GridSelection)
    case autotile(layout: AutoTileLayout)
    case visibility(visible: Bool)
}

/// Responsible for rendering the gTile overlay on each connected monitor.
///
/// Port of OverlayManager.ts.
final class OverlayController {
    private let windowManager: WindowManager
    private let preferences: UserPreferences
    private let previewWindow: PreviewWindow

    private var overlays: [OverlayWindowController] = []
    private var overlayStates: [OverlayState] = []
    private var interactionStates: [GridInteractionState] = []
    private var callbacks: [(OverlayEvent) -> Void] = []
    private var syncInProgress = false

    private(set) var activeMonitorIndex: Int?
    private(set) var presets: [GridSize]
    private(set) var gridSize: GridSize
    private var presetIndex: Int = 0

    /// The window that was focused before the overlay was shown.
    /// This is the actual target for window operations.
    private(set) var targetWindow: AXUIElement?
    /// PID of the target window's app, used for re-acquisition if AXUIElement becomes stale.
    private(set) var targetWindowPID: pid_t = 0

    struct OverlayState {
        var selection: GridSelection?
        var hoverTile: GridOffset?
        var monitorIndex: Int
    }

    init(windowManager: WindowManager, preferences: UserPreferences) {
        self.windowManager = windowManager
        self.preferences = preferences
        self.previewWindow = PreviewWindow()

        let gridSizeConf = preferences.gridSizes
        self.presets = GridSizeListParser(input: gridSizeConf).parse() ?? DefaultGridSizes
        self.gridSize = presets.first ?? DefaultGridSizes[0]

        renderOverlays()
    }

    /// Returns the target window, re-acquiring from the stored PID if the
    /// original AXUIElement reference has become stale.
    func validatedTargetWindow() -> AXUIElement? {
        if let tw = targetWindow,
           windowManager.accessibilityService.windowFrame(tw) != nil {
            return tw
        }

        // Re-acquire from the same app
        if targetWindowPID != 0 {
            let appElement = AXUIElementCreateApplication(targetWindowPID)
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
                let reacquired = focusedWindow as! AXUIElement
                targetWindow = reacquired
                return reacquired
            }
        }

        return nil
    }

    // MARK: - Public Interface

    func subscribe(_ callback: @escaping (OverlayEvent) -> Void) {
        callbacks.append(callback)
    }

    func toggleOverlays(hide: Bool? = nil) {
        let currentlyVisible = overlays.contains { $0.isVisible }
        let shouldHide = hide ?? currentlyVisible

        if shouldHide {
            syncInProgress = true
            overlays.forEach { $0.hide() }
            previewWindow.previewArea = nil
            syncInProgress = false
            // Clear selections and anchors
            for i in 0..<overlayStates.count {
                overlayStates[i].selection = nil
                overlayStates[i].hoverTile = nil
            }
            for state in interactionStates {
                state.anchor = nil
            }
            targetWindow = nil
            targetWindowPID = 0
            dispatch(.visibility(visible: false))
            return
        }

        guard !overlays.isEmpty else { return }

        // Capture the focused window BEFORE showing overlay (which steals focus).
        // Use focusedWindowExcludingSelf to avoid capturing our own overlay panel.
        targetWindow = windowManager.accessibilityService.focusedWindowExcludingSelf()
        if let tw = targetWindow {
            targetWindowPID = windowManager.accessibilityService.windowPID(tw)
        } else {
            targetWindowPID = 0
        }

        placeOverlays()

        syncInProgress = true
        overlays.forEach { $0.show() }
        // Make the first overlay key so it receives keyboard events
        overlays.first?.window.makeKey()
        syncInProgress = false
        dispatch(.visibility(visible: true))
    }

    func setSelection(_ selection: GridSelection?, monitorIdx: Int) {
        guard monitorIdx < overlayStates.count else { return }
        overlayStates[monitorIdx].selection = selection

        if let selection = selection {
            activeMonitorIndex = monitorIdx
            let area = windowManager.selectionToArea(
                selection, gridSize: gridSize, monitorIdx: monitorIdx, preview: true)
            previewWindow.previewArea = area
        } else {
            activeMonitorIndex = nil
            previewWindow.previewArea = nil
        }

        refreshOverlay(at: monitorIdx)
    }

    func getSelection(_ monitorIdx: Int) -> GridSelection? {
        guard monitorIdx < overlayStates.count else { return nil }
        return overlayStates[monitorIdx].selection
    }

    func iteratePreset() {
        presetIndex = (presetIndex + 1) % presets.count
        gridSize = presets[presetIndex]

        for i in 0..<overlayStates.count {
            overlayStates[i].selection = nil
        }
        for state in interactionStates {
            state.anchor = nil
        }
        refreshAllOverlays()
    }

    func updatePresets(_ newPresets: [GridSize]) {
        presets = newPresets
        presetIndex = 0
        if let first = presets.first {
            gridSize = first
        }
        refreshAllOverlays()
    }

    // MARK: - Private Methods

    private func dispatch(_ event: OverlayEvent) {
        for callback in callbacks {
            callback(event)
        }
    }

    private func renderOverlays() {
        destroyOverlays()

        let monitors = windowManager.monitors
        for (index, _) in monitors.enumerated() {
            overlayStates.append(OverlayState(monitorIndex: index))
            let interactionState = GridInteractionState()
            interactionStates.append(interactionState)

            let controller = OverlayWindowController(
                content: makeOverlayView(for: index, interactionState: interactionState),
                frame: NSRect(x: 0, y: 0, width: 300, height: 280)
            )

            // Wire Escape key
            controller.window.onEscape = { [weak self] in
                self?.toggleOverlays(hide: true)
            }

            overlays.append(controller)
        }
    }

    private func destroyOverlays() {
        let wasVisible = overlays.contains { $0.isVisible }
        overlays.forEach { $0.hide() }
        overlays.removeAll()
        overlayStates.removeAll()
        interactionStates.removeAll()

        if wasVisible {
            dispatch(.visibility(visible: false))
        }
    }

    private func makeOverlayView(for monitorIdx: Int, interactionState: GridInteractionState) -> OverlayView {
        let selectionBinding = Binding<GridSelection?>(
            get: { [weak self] in self?.overlayStates[safe: monitorIdx]?.selection },
            set: { [weak self] (newValue: GridSelection?) in
                guard let self = self else { return }
                if monitorIdx < self.overlayStates.count {
                    self.overlayStates[monitorIdx].selection = newValue
                }
                if let selection = newValue {
                    self.activeMonitorIndex = monitorIdx
                    let area = self.windowManager.selectionToArea(
                        selection, gridSize: self.gridSize, monitorIdx: monitorIdx, preview: true)
                    self.previewWindow.previewArea = area
                }
            }
        )

        let hoverBinding = Binding<GridOffset?>(
            get: { [weak self] in self?.overlayStates[safe: monitorIdx]?.hoverTile },
            set: { [weak self] (newValue: GridOffset?) in
                guard let self = self else { return }
                if monitorIdx < self.overlayStates.count {
                    self.overlayStates[monitorIdx].hoverTile = newValue
                }
                if let tile = newValue {
                    // If we have an anchor, show the range preview
                    let previewAnchor = interactionState.anchor ?? tile
                    let previewSel = GridSelection(anchor: previewAnchor, target: tile)
                    let area = self.windowManager.selectionToArea(
                        previewSel, gridSize: self.gridSize, monitorIdx: monitorIdx, preview: true)
                    self.previewWindow.previewArea = area
                } else if interactionState.anchor == nil {
                    self.previewWindow.previewArea = nil
                }
            }
        )

        let gridSizeBinding = Binding<GridSize>(
            get: { [weak self] in self?.gridSize ?? DefaultGridSizes[0] },
            set: { [weak self] (newValue: GridSize) in
                self?.gridSize = newValue
                self?.refreshAllOverlays()
            }
        )

        let focusedTitle = windowManager.focusedWindow.flatMap {
            windowManager.accessibilityService.windowTitle($0)
        } ?? "gTile"

        return OverlayView(
            title: focusedTitle,
            presets: presets,
            gridSize: gridSizeBinding,
            selection: selectionBinding,
            hoverTile: hoverBinding,
            interactionState: interactionState,
            onSelectionComplete: { [weak self] selection in
                guard let self = self else { return }
                self.dispatch(.selection(
                    monitorIdx: monitorIdx,
                    gridSize: self.gridSize,
                    selection: selection
                ))
            },
            onAutotile: { [weak self] layout in
                self?.dispatch(.autotile(layout: layout))
            },
            onClose: { [weak self] in
                self?.toggleOverlays(hide: true)
            },
            onToggleAutoClose: { [weak self] in
                self?.preferences.autoClose.toggle()
            },
            onToggleFollowCursor: { [weak self] in
                self?.preferences.followCursor.toggle()
            }
        )
    }

    private func placeOverlays() {
        let monitors = windowManager.monitors
        let focused = windowManager.focusedWindow

        for (index, monitor) in monitors.enumerated() {
            guard index < overlays.count else { break }

            let overlay = overlays[index]
            let workArea = monitor.workArea
            let overlayWidth = 300.0
            let overlayHeight = 280.0

            if let focused = focused {
                let focusedMonitor = windowManager.accessibilityService.windowMonitorIndex(focused)
                if focusedMonitor == index, let frame = windowManager.accessibilityService.windowFrame(focused) {
                    let anchorX = clamp(
                        frame.x + frame.width / 2 - overlayWidth / 2,
                        min: workArea.x,
                        max: workArea.x + workArea.width - overlayWidth
                    )
                    let anchorY = clamp(
                        frame.y + frame.height / 2 - overlayHeight / 2,
                        min: workArea.y,
                        max: workArea.y + workArea.height - overlayHeight
                    )
                    overlay.placeAt(x: anchorX, y: anchorY)
                    continue
                }
            }

            let centerX = workArea.x + workArea.width / 2 - overlayWidth / 2
            let centerY = workArea.y + workArea.height / 2 - overlayHeight / 2
            overlay.placeAt(x: centerX, y: centerY)
        }
    }

    private func refreshOverlay(at index: Int) {
        guard index < overlays.count, index < interactionStates.count else { return }
        overlays[index].updateContent(makeOverlayView(for: index, interactionState: interactionStates[index]))
    }

    private func refreshAllOverlays() {
        for i in 0..<overlays.count {
            refreshOverlay(at: i)
        }
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
