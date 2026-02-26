import AppKit
import Carbon

/// Identifies groups of related keyboard shortcuts that can be (de)activated
/// together. Members act as bitflags.
struct KeyBindingGroup: OptionSet {
    let rawValue: Int

    static let global   = KeyBindingGroup(rawValue: 1 << 0)
    static let overlay  = KeyBindingGroup(rawValue: 1 << 1)
    static let autotile = KeyBindingGroup(rawValue: 1 << 2)
    static let action   = KeyBindingGroup(rawValue: 1 << 3)
    static let preset   = KeyBindingGroup(rawValue: 1 << 4)

    /// Default groups active when the overlay is shown.
    static let overlayDefaults: KeyBindingGroup = [.overlay, .autotile, .preset]
}

/// Maps preference keys to their keybinding groups for "always active" toggles.
let settingKeyToKeyBindingGroup: [(key: String, group: KeyBindingGroup)] = [
    ("globalAutoTiling", .autotile),
    ("globalPresets", .preset),
    ("moveResizeEnabled", .action),
]

/// Manages global keyboard shortcuts for the application.
///
/// Uses a combination of Carbon hot keys (for true global shortcuts that work
/// even when the app is not focused) and NSEvent monitors.
final class HotkeyManager {
    private var callbacks: [(HotkeyAction) -> Void] = []
    private var activeGroups: KeyBindingGroup = .global
    private var monitors: [Any] = []
    private let preferences: UserPreferences

    private var registeredShortcuts: [String: (action: HotkeyAction, group: KeyBindingGroup)] = [:]

    // Carbon hot key for the global toggle (works even when app is not focused)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(preferences: UserPreferences) {
        self.preferences = preferences
        registerAllShortcuts()
        installCarbonHotKey()
        setupEventMonitor()
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        uninstallCarbonHotKey()
    }

    func subscribe(_ callback: @escaping (HotkeyAction) -> Void) {
        callbacks.append(callback)
    }

    func setListeningGroups(_ groups: KeyBindingGroup) {
        activeGroups = groups.union(.global)
    }

    // MARK: - Private

    private func dispatch(_ action: HotkeyAction) {
        for callback in callbacks {
            callback(action)
        }
    }

    private func registerAllShortcuts() {
        // Global
        register("showToggleTiling", action: .toggle, group: .global)

        // Overlay
        register("cancelTiling", action: .cancel, group: .overlay)
        register("changeGridSize", action: .loopGridSize, group: .overlay)
        register("moveUp", action: .pan(.north), group: .overlay)
        register("moveRight", action: .pan(.east), group: .overlay)
        register("moveDown", action: .pan(.south), group: .overlay)
        register("moveLeft", action: .pan(.west), group: .overlay)
        register("moveNextMonitor", action: .relocate, group: .overlay)
        register("contractLeft", action: .adjust(mode: .shrink, dir: .west), group: .overlay)
        register("contractRight", action: .adjust(mode: .shrink, dir: .east), group: .overlay)
        register("contractUp", action: .adjust(mode: .shrink, dir: .north), group: .overlay)
        register("contractDown", action: .adjust(mode: .shrink, dir: .south), group: .overlay)
        register("expandLeft", action: .adjust(mode: .extend, dir: .west), group: .overlay)
        register("expandRight", action: .adjust(mode: .extend, dir: .east), group: .overlay)
        register("expandUp", action: .adjust(mode: .extend, dir: .north), group: .overlay)
        register("expandDown", action: .adjust(mode: .extend, dir: .south), group: .overlay)
        register("setTiling", action: .confirm, group: .overlay)
        register("snapToNeighbors", action: .grow, group: .overlay)

        // Autotile
        register("autotileMain", action: .autotile(.main), group: .autotile)
        register("autotileMainInverted", action: .autotile(.mainInverted), group: .autotile)
        for i in 1...10 {
            register("autotile\(i)", action: .autotile(.cols(i)), group: .autotile)
        }

        // Action
        register("actionAutotileMain", action: .autotile(.main), group: .action)
        register("actionAutotileMainInverted", action: .autotile(.mainInverted), group: .action)
        register("actionChangeTiling", action: .loopGridSize, group: .action)
        register("actionContractTop", action: .resize(mode: .shrink, dir: .north), group: .action)
        register("actionContractRight", action: .resize(mode: .shrink, dir: .east), group: .action)
        register("actionContractBottom", action: .resize(mode: .shrink, dir: .south), group: .action)
        register("actionContractLeft", action: .resize(mode: .shrink, dir: .west), group: .action)
        register("actionExpandTop", action: .resize(mode: .extend, dir: .north), group: .action)
        register("actionExpandRight", action: .resize(mode: .extend, dir: .east), group: .action)
        register("actionExpandBottom", action: .resize(mode: .extend, dir: .south), group: .action)
        register("actionExpandLeft", action: .resize(mode: .extend, dir: .west), group: .action)
        register("actionMoveUp", action: .move(.north), group: .action)
        register("actionMoveRight", action: .move(.east), group: .action)
        register("actionMoveDown", action: .move(.south), group: .action)
        register("actionMoveLeft", action: .move(.west), group: .action)
        register("actionMoveNextMonitor", action: .relocate, group: .action)

        // Preset
        for i in 1...30 {
            register("presetResize\(i)", action: .loopPreset(i), group: .preset)
        }
    }

    private func register(_ name: String, action: HotkeyAction, group: KeyBindingGroup) {
        registeredShortcuts[name] = (action, group)
    }

    // MARK: - Carbon Hot Key (truly global, works when app is not focused)

    private func installCarbonHotKey() {
        // Register Cmd+Option+G as the global toggle shortcut
        // keyCode 5 = G on US keyboard
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = 5 // G

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x6754696C) // "gTil"
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Install handler - use a C function pointer via closure context
        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.dispatch(.toggle)
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func uninstallCarbonHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    // MARK: - NSEvent Monitor (for local events when overlay is showing)

    private func setupEventMonitor() {
        // Global monitor for when other apps have focus
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        if let globalMonitor = globalMonitor {
            monitors.append(globalMonitor)
        }

        // Local monitor for when our panel has focus
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
        if let localMonitor = localMonitor {
            monitors.append(localMonitor)
        }
    }

    /// The modifier flags we care about (ignore caps lock, fn, etc.)
    private static let significantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let eventMods = event.modifierFlags.intersection(Self.significantModifiers)

        for (name, shortcut) in registeredShortcuts {
            // Skip the global toggle - handled by Carbon hot key
            if name == "showToggleTiling" { continue }

            guard activeGroups.contains(shortcut.group) else { continue }

            if let saved = loadShortcut(name: name) {
                let savedMods = saved.modifiers.intersection(Self.significantModifiers)
                if eventMods == savedMods && event.keyCode == saved.keyCode {
                    dispatch(shortcut.action)
                    return true
                }
            }
        }

        return false
    }

    private func loadShortcut(name: String) -> (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)? {
        let key = "shortcut-\(name)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            return defaultShortcut(name: name)
        }
        return (NSEvent.ModifierFlags(rawValue: UInt(decoded.modifiers)), decoded.keyCode)
    }

    func saveShortcut(name: String, modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        let saved = SavedShortcut(modifiers: Int(modifiers.rawValue), keyCode: keyCode)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: "shortcut-\(name)")
        }
    }

    private func defaultShortcut(name: String) -> (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)? {
        // Only the toggle shortcut has a default - others are configured via settings
        // The toggle is handled by Carbon hot key, so no NSEvent default needed
        nil
    }
}

private struct SavedShortcut: Codable {
    let modifiers: Int
    let keyCode: UInt16
}
