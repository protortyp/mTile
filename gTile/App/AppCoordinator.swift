import AppKit

/// Type alias for the preset cycling index.
typealias PresetIndex = (index: Int, subindex: Int)

/// Top-level orchestrator for the gTile macOS app.
///
/// Port of App.ts. Routes HotkeyAction events to WindowManager and
/// OverlayController, manages preset cycling, autotile layout resolution.
final class AppCoordinator {
    static var shared: AppCoordinator?

    private let preferences: UserPreferences
    private let accessibilityService: AccessibilityService
    private let displayService: DisplayService
    private let windowManager: WindowManager
    private let overlayController: OverlayController
    private let hotkeyManager: HotkeyManager
    private let lastPresetIndex: VolatileStorage<PresetIndex>

    // Autotile layout cache
    private var gridSpecs: AutoTileLayoutCache

    /// Global keybinding groups that are always active.
    private var globalKeyBindingGroups: KeyBindingGroup

    init() {
        self.preferences = UserPreferences()
        self.accessibilityService = AccessibilityService()
        self.displayService = DisplayService()
        self.windowManager = WindowManager(
            accessibilityService: accessibilityService,
            displayService: displayService,
            preferences: preferences
        )
        self.overlayController = OverlayController(
            windowManager: windowManager,
            preferences: preferences
        )
        self.hotkeyManager = HotkeyManager(preferences: preferences)
        self.lastPresetIndex = VolatileStorage<PresetIndex>(lifetime: 2.0)
        self.gridSpecs = AutoTileLayoutCache(preferences: preferences)

        // Determine global keybinding groups from preferences
        var groups: KeyBindingGroup = .global
        if preferences.globalAutoTiling { groups.insert(.autotile) }
        if preferences.globalPresets { groups.insert(.preset) }
        if preferences.moveResizeEnabled { groups.insert(.action) }
        self.globalKeyBindingGroups = groups

        // Wire up event handlers
        overlayController.subscribe { [weak self] event in
            self?.onOverlayEvent(event)
        }
        hotkeyManager.subscribe { [weak self] action in
            self?.onUserAction(action)
        }
        hotkeyManager.setListeningGroups(globalKeyBindingGroups)

        // Monitor workspace notifications for focus changes
        setupWorkspaceObservers()

        AppCoordinator.shared = self
    }

    // MARK: - Preset Resolution

    private func getResizePreset(_ index: Int) -> Preset? {
        let config = preferences.resizePreset(index)
        guard let presets = ResizePresetListParser(input: config).parse(),
              !presets.isEmpty else {
            return nil
        }

        let (lastIndex, lastSubindex) = lastPresetIndex.store ?? (-1, -1)
        if lastIndex != index {
            lastPresetIndex.store = (index, 0)
            return presets[0]
        }

        let nextSubindex = (lastSubindex + 1) % presets.count
        lastPresetIndex.store = (index, nextSubindex)
        return presets[nextSubindex]
    }

    private func getAutotilePreset(_ layout: AutoTileLayout) -> GridSpec? {
        let specs = gridSpecs.specs(for: layout)
        guard !specs.isEmpty else { return nil }

        let index: Int
        switch layout {
        case .main: index = 100
        case .mainInverted: index = 101
        case .cols(let n): index = 102 + n
        }

        let (lastIndex, lastSubindex) = lastPresetIndex.store ?? (-1, -1)
        if lastIndex != index {
            lastPresetIndex.store = (index, 0)
            return specs[0]
        }

        let nextSubindex = (lastSubindex + 1) % specs.count
        lastPresetIndex.store = (index, nextSubindex)
        return specs[nextSubindex]
    }

    // MARK: - Event Handlers

    private func onOverlayEvent(_ event: OverlayEvent) {
        switch event {
        case .selection:
            onUserAction(.confirm)
        case .autotile(let layout):
            onUserAction(.autotile(layout))
        case .visibility(let visible):
            hotkeyManager.setListeningGroups(
                visible
                    ? globalKeyBindingGroups.union(.overlayDefaults)
                    : globalKeyBindingGroups
            )
        }
    }

    /// Public entry point for triggering actions (used by MenuBarView).
    func onAction(_ action: HotkeyAction) {
        onUserAction(action)
    }

    private func onUserAction(_ action: HotkeyAction) {
        // Trivial delegation events
        switch action {
        case .toggle:
            overlayController.toggleOverlays()
            return
        case .cancel:
            overlayController.toggleOverlays(hide: true)
            return
        case .loopGridSize:
            overlayController.iteratePreset()
            return
        default:
            break
        }

        let om = overlayController
        let wm = windowManager

        // Use the target window captured before overlay was shown,
        // falling back to the current focused window.
        let validated = om.validatedTargetWindow()
        let fallback = wm.accessibilityService.focusedWindowExcludingSelf()
        guard let window = validated ?? fallback else {
            print("gTile: no target window available for action \(action)")
            return
        }

        // Final safety check: never manipulate our own process windows
        let windowPID = wm.accessibilityService.windowPID(window)
        guard windowPID != ProcessInfo.processInfo.processIdentifier else {
            print("gTile: BUG - target is own process, blocking action")
            return
        }

        let windowTitle = wm.accessibilityService.windowTitle(window) ?? "<no title>"
        print("gTile: action=\(action) target='\(windowTitle)' PID=\(windowPID) (validated=\(validated != nil), fallback=\(fallback != nil))")

        let monitorIdx = om.activeMonitorIndex ?? accessibilityService.windowMonitorIndex(window)
        let selection = om.getSelection(monitorIdx)

        switch action {
        case .confirm:
            if let selection = selection {
                wm.applySelection(window, monitorIdx: monitorIdx, gridSize: om.gridSize, selection: selection)
                om.setSelection(nil, monitorIdx: monitorIdx)
                om.toggleOverlays(hide: true)
            }

        case .pan(let dir):
            let curSel = selection ?? wm.windowToSelection(window, gridSize: om.gridSize)
            let newSel = pan(curSel, bounds: om.gridSize, dir: dir)
            om.setSelection(newSel, monitorIdx: monitorIdx)

        case .adjust(let mode, let dir):
            let curSel = selection ?? wm.windowToSelection(window, gridSize: om.gridSize)
            let newSel = adjust(curSel, bounds: om.gridSize, dir: dir, mode: mode)
            om.setSelection(newSel, monitorIdx: monitorIdx)

        case .move(let dir):
            wm.moveWindow(window, gridSize: om.gridSize, dir: dir)

        case .resize(let mode, let dir):
            wm.resizeWindow(window, gridSize: om.gridSize, dir: dir, mode: mode)

        case .grow:
            wm.autogrow(window)

        case .loopPreset(let preset):
            if let p = getResizePreset(preset) {
                let targetMonitor = preferences.targetPresetsToMonitorOfMouse
                    ? wm.pointerMonitorIndex
                    : monitorIdx
                wm.applySelection(window, monitorIdx: targetMonitor, gridSize: p.gridSize, selection: p.selection)
            }

        case .relocate:
            wm.moveToMonitor(window)

        case .autotile(let layout):
            if let spec = getAutotilePreset(layout) {
                wm.autotile(spec, monitorIdx: monitorIdx)
            }

        default:
            break
        }
    }

    // MARK: - Workspace Observers

    private func setupWorkspaceObservers() {
        // Monitor for active application changes (focus changes)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // When focus changes and overlay is visible, reposition overlays
            _ = self
        }

        // Monitor for screen configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Rebuild overlays when monitor config changes
            self?.overlayController.toggleOverlays(hide: true)
        }
    }
}

// MARK: - Autotile Layout Cache

/// Caches autotile layout specs, analogous to AutoTileLayouts() in grid.ts.
final class AutoTileLayoutCache {
    private let preferences: UserPreferences

    init(preferences: UserPreferences) {
        self.preferences = preferences
    }

    func specs(for layout: AutoTileLayout) -> [GridSpec] {
        switch layout {
        case .main:
            return mainSpecs(inverted: false)
        case .mainInverted:
            return mainSpecs(inverted: true)
        case .cols(let n):
            let config = preferences.autotileGridSpec(n)
            guard !config.isEmpty,
                  let spec = GridSpecParser(input: config).parse() else {
                return []
            }
            return [spec]
        }
    }

    private func mainSpecs(inverted: Bool) -> [GridSpec] {
        let fractionScaleFactor = 1024
        let ratios = preferences.autotileMainWindowRatios
            .split(separator: ",")
            .compactMap { Double(String($0).trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isNaN }
            .map { Int(clamp($0, min: 0, max: 1) * Double(fractionScaleFactor)) }
            .map { ($0, fractionScaleFactor - $0) }

        return ratios.compactMap { (main, minor) in
            let spec: String
            if inverted {
                spec = "cols(\(minor):rows(1d), \(main))"
            } else {
                spec = "cols(\(main), \(minor):rows(1d))"
            }
            return GridSpecParser(input: spec).parse()
        }
    }
}
