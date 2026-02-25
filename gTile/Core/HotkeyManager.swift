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

/// A shortcut definition with modifiers and key code.
struct ShortcutDefinition {
    let name: String
    let action: HotkeyAction
    let group: KeyBindingGroup
    let defaultModifiers: NSEvent.ModifierFlags
    let defaultKeyCode: UInt16?
    let defaultKeyChar: String?
}

/// Manages global keyboard shortcuts for the application.
///
/// Uses Carbon event taps for global hotkeys (since KeyboardShortcuts
/// provides a nice settings UI but we need the core event monitoring).
final class HotkeyManager {
    private var callbacks: [(HotkeyAction) -> Void] = []
    private var activeGroups: KeyBindingGroup = .global
    private var monitors: [Any] = []
    private let preferences: UserPreferences

    // Registered shortcuts with their current state
    private var registeredShortcuts: [String: (action: HotkeyAction, group: KeyBindingGroup)] = [:]

    init(preferences: UserPreferences) {
        self.preferences = preferences
        registerAllShortcuts()
        setupEventMonitor()
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Subscribe to hotkey actions.
    func subscribe(_ callback: @escaping (HotkeyAction) -> Void) {
        callbacks.append(callback)
    }

    /// Sets which keybinding groups are actively listened for.
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
        // Global shortcuts
        register("showToggleTiling", action: .toggle, group: .global)

        // Overlay shortcuts
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

        // Autotile shortcuts
        register("autotileMain", action: .autotile(.main), group: .autotile)
        register("autotileMainInverted", action: .autotile(.mainInverted), group: .autotile)
        for i in 1...10 {
            register("autotile\(i)", action: .autotile(.cols(i)), group: .autotile)
        }

        // Action shortcuts (direct window manipulation)
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

        // Preset shortcuts
        for i in 1...30 {
            register("presetResize\(i)", action: .loopPreset(i), group: .preset)
        }
    }

    private func register(_ name: String, action: HotkeyAction, group: KeyBindingGroup) {
        registeredShortcuts[name] = (action, group)
    }

    private func setupEventMonitor() {
        // Monitor global key events
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        if let globalMonitor = globalMonitor {
            monitors.append(globalMonitor)
        }

        // Monitor local key events (when our window is key)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }
        if let localMonitor = localMonitor {
            monitors.append(localMonitor)
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Look up the shortcut by saved user preferences
        // For now, we use a simple modifier+key matching approach
        // The KeyboardShortcuts package will handle the settings UI

        for (name, shortcut) in registeredShortcuts {
            guard activeGroups.contains(shortcut.group) else { continue }

            // Check against saved shortcut for this name
            if let savedShortcut = loadShortcut(name: name) {
                if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == savedShortcut.modifiers &&
                   event.keyCode == savedShortcut.keyCode {
                    dispatch(shortcut.action)
                    return true
                }
            }
        }

        return false
    }

    /// Loads a saved shortcut from UserDefaults.
    private func loadShortcut(name: String) -> (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)? {
        let key = "shortcut-\(name)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            return defaultShortcut(name: name)
        }
        return (NSEvent.ModifierFlags(rawValue: UInt(decoded.modifiers)), decoded.keyCode)
    }

    /// Saves a shortcut to UserDefaults.
    func saveShortcut(name: String, modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        let saved = SavedShortcut(modifiers: Int(modifiers.rawValue), keyCode: keyCode)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: "shortcut-\(name)")
        }
    }

    /// Returns the default shortcut for a given name, or nil if no default.
    private func defaultShortcut(name: String) -> (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)? {
        // Default: Super+Enter to toggle tiling
        // Users will configure their own shortcuts through the settings UI
        switch name {
        case "showToggleTiling":
            // Cmd+Option+G (keyCode 5 = G)
            return (.init([.command, .option]), 5)
        default:
            return nil
        }
    }
}

/// Codable shortcut for UserDefaults persistence.
private struct SavedShortcut: Codable {
    let modifiers: Int
    let keyCode: UInt16
}
