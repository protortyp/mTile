import AppKit
import Combine
import SwiftUI

/// Events emitted by the overlay system.
enum OverlayEvent {
    /// A grid selection was completed by the user.
    case selection(monitorIdx: Int, gridSize: GridSize, selection: GridSelection)
    /// An autotile layout was requested from the overlay.
    case autotile(layout: AutoTileLayout)
    /// Overlay visibility changed.
    case visibility(visible: Bool)
}

/// Responsible for rendering the gTile overlay on each connected monitor.
///
/// Port of OverlayManager.ts. Keeps track of connected monitors and renders
/// one overlay per screen. Keeps UIs in sync and provides a unified interface
/// to manipulate overlay appearance.
final class OverlayController {
    private let windowManager: WindowManager
    private let preferences: UserPreferences
    private let previewWindow: PreviewWindow

    private var overlays: [OverlayWindowController] = []
    private var overlayStates: [OverlayState] = []
    private var callbacks: [(OverlayEvent) -> Void] = []
    private var syncInProgress = false

    private(set) var activeMonitorIndex: Int?
    private(set) var presets: [GridSize]
    private(set) var gridSize: GridSize
    private var presetIndex: Int = 0

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

    // MARK: - Public Interface

    func subscribe(_ callback: @escaping (OverlayEvent) -> Void) {
        callbacks.append(callback)
    }

    /// Toggles the visibility of the overlays.
    func toggleOverlays(hide: Bool? = nil) {
        let currentlyVisible = overlays.contains { $0.isVisible }
        let shouldHide = hide ?? currentlyVisible

        if shouldHide {
            syncInProgress = true
            overlays.forEach { $0.hide() }
            syncInProgress = false
            dispatch(.visibility(visible: false))
            return
        }

        // Check pre-conditions for showing overlay
        guard windowManager.focusedWindow != nil else { return }
        guard !overlays.isEmpty else { return }

        placeOverlays()

        syncInProgress = true
        overlays.forEach { $0.show() }
        syncInProgress = false
        dispatch(.visibility(visible: true))
    }

    /// Sets the tile selection on the overlay for the specified monitor.
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

    /// Returns the current tile selection for a monitor.
    func getSelection(_ monitorIdx: Int) -> GridSelection? {
        guard monitorIdx < overlayStates.count else { return nil }
        return overlayStates[monitorIdx].selection
    }

    /// Cycles through grid size presets.
    func iteratePreset() {
        presetIndex = (presetIndex + 1) % presets.count
        gridSize = presets[presetIndex]

        // Clear all selections and refresh
        for i in 0..<overlayStates.count {
            overlayStates[i].selection = nil
        }
        refreshAllOverlays()
    }

    /// Updates the list of grid size presets.
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
            let state = OverlayState(monitorIndex: index)
            overlayStates.append(state)

            let monitorIdx = index
            let controller = OverlayWindowController(
                content: makeOverlayView(for: monitorIdx),
                frame: NSRect(x: 0, y: 0, width: 300, height: 280)
            )
            overlays.append(controller)
        }
    }

    private func destroyOverlays() {
        let wasVisible = overlays.contains { $0.isVisible }
        overlays.forEach { $0.hide() }
        overlays.removeAll()
        overlayStates.removeAll()

        if wasVisible {
            dispatch(.visibility(visible: false))
        }
    }

    private func makeOverlayView(for monitorIdx: Int) -> OverlayView {
        // Create bindings that reference this controller's state
        let selectionBinding = Binding<GridSelection?>(
            get: { [weak self] in self?.overlayStates[safe: monitorIdx]?.selection },
            set: { [weak self] newValue in
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
            set: { [weak self] newValue in
                guard let self = self else { return }
                if monitorIdx < self.overlayStates.count {
                    self.overlayStates[monitorIdx].hoverTile = newValue
                }
                if let tile = newValue {
                    let hoverSelection = GridSelection(anchor: tile, target: tile)
                    let area = self.windowManager.selectionToArea(
                        hoverSelection, gridSize: self.gridSize, monitorIdx: monitorIdx, preview: true)
                    self.previewWindow.previewArea = area
                } else {
                    self.previewWindow.previewArea = nil
                }
            }
        )

        let gridSizeBinding = Binding<GridSize>(
            get: { [weak self] in self?.gridSize ?? DefaultGridSizes[0] },
            set: { [weak self] newValue in
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

            // Center on monitor
            let centerX = workArea.x + workArea.width / 2 - overlayWidth / 2
            let centerY = workArea.y + workArea.height / 2 - overlayHeight / 2
            overlay.placeAt(x: centerX, y: centerY)
        }
    }

    private func refreshOverlay(at index: Int) {
        guard index < overlays.count else { return }
        overlays[index].updateContent(makeOverlayView(for: index))
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
