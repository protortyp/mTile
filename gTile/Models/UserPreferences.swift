import Foundation
import SwiftUI

/// Observable settings model backed by UserDefaults.
@Observable
final class UserPreferences {
    // MARK: - Boolean Settings

    var autoClose: Bool {
        didSet { UserDefaults.standard.set(autoClose, forKey: "autoClose") }
    }

    var autoMaximize: Bool {
        didSet { UserDefaults.standard.set(autoMaximize, forKey: "autoMaximize") }
    }

    var followCursor: Bool {
        didSet { UserDefaults.standard.set(followCursor, forKey: "followCursor") }
    }

    var globalAutoTiling: Bool {
        didSet { UserDefaults.standard.set(globalAutoTiling, forKey: "globalAutoTiling") }
    }

    var globalPresets: Bool {
        didSet { UserDefaults.standard.set(globalPresets, forKey: "globalPresets") }
    }

    var moveResizeEnabled: Bool {
        didSet { UserDefaults.standard.set(moveResizeEnabled, forKey: "moveResizeEnabled") }
    }

    var showGridLines: Bool {
        didSet { UserDefaults.standard.set(showGridLines, forKey: "showGridLines") }
    }

    var targetPresetsToMonitorOfMouse: Bool {
        didSet { UserDefaults.standard.set(targetPresetsToMonitorOfMouse, forKey: "targetPresetsToMonitorOfMouse") }
    }

    // MARK: - Numeric Settings

    var insetsPrimaryTop: Int {
        didSet { UserDefaults.standard.set(insetsPrimaryTop, forKey: "insetsPrimaryTop") }
    }

    var insetsPrimaryRight: Int {
        didSet { UserDefaults.standard.set(insetsPrimaryRight, forKey: "insetsPrimaryRight") }
    }

    var insetsPrimaryBottom: Int {
        didSet { UserDefaults.standard.set(insetsPrimaryBottom, forKey: "insetsPrimaryBottom") }
    }

    var insetsPrimaryLeft: Int {
        didSet { UserDefaults.standard.set(insetsPrimaryLeft, forKey: "insetsPrimaryLeft") }
    }

    var insetsSecondaryTop: Int {
        didSet { UserDefaults.standard.set(insetsSecondaryTop, forKey: "insetsSecondaryTop") }
    }

    var insetsSecondaryRight: Int {
        didSet { UserDefaults.standard.set(insetsSecondaryRight, forKey: "insetsSecondaryRight") }
    }

    var insetsSecondaryBottom: Int {
        didSet { UserDefaults.standard.set(insetsSecondaryBottom, forKey: "insetsSecondaryBottom") }
    }

    var insetsSecondaryLeft: Int {
        didSet { UserDefaults.standard.set(insetsSecondaryLeft, forKey: "insetsSecondaryLeft") }
    }

    var windowSpacing: Int {
        didSet { UserDefaults.standard.set(windowSpacing, forKey: "windowSpacing") }
    }

    var selectionTimeout: Int {
        didSet { UserDefaults.standard.set(selectionTimeout, forKey: "selectionTimeout") }
    }

    // MARK: - String Settings

    var gridSizes: String {
        didSet { UserDefaults.standard.set(gridSizes, forKey: "gridSizes") }
    }

    var autotileMainWindowRatios: String {
        didSet { UserDefaults.standard.set(autotileMainWindowRatios, forKey: "autotileMainWindowRatios") }
    }

    // MARK: - Resize Presets (1-30)

    private(set) var resizePresets: [String]

    func resizePreset(_ index: Int) -> String {
        guard index >= 1 && index <= 30 else { return "" }
        return resizePresets[index - 1]
    }

    func setResizePreset(_ index: Int, value: String) {
        guard index >= 1 && index <= 30 else { return }
        resizePresets[index - 1] = value
        UserDefaults.standard.set(value, forKey: "resize\(index)")
    }

    // MARK: - Autotile GridSpecs (1-10)

    private(set) var autotileGridSpecs: [String]

    func autotileGridSpec(_ index: Int) -> String {
        guard index >= 1 && index <= 10 else { return "" }
        return autotileGridSpecs[index - 1]
    }

    func setAutotileGridSpec(_ index: Int, value: String) {
        guard index >= 1 && index <= 10 else { return }
        autotileGridSpecs[index - 1] = value
        UserDefaults.standard.set(value, forKey: "autotileGridSpec\(index)")
    }

    // MARK: - Computed Properties

    func getInset(isPrimary: Bool) -> Inset {
        if isPrimary {
            return Inset(
                top: insetsPrimaryTop,
                right: insetsPrimaryRight,
                bottom: insetsPrimaryBottom,
                left: insetsPrimaryLeft
            )
        } else {
            return Inset(
                top: insetsSecondaryTop,
                right: insetsSecondaryRight,
                bottom: insetsSecondaryBottom,
                left: insetsSecondaryLeft
            )
        }
    }

    // MARK: - Initialization

    init() {
        let defaults = UserDefaults.standard

        // Register defaults
        let defaultValues: [String: Any] = [
            "autoClose": true,
            "autoMaximize": false,
            "followCursor": false,
            "globalAutoTiling": false,
            "globalPresets": true,
            "moveResizeEnabled": true,
            "showGridLines": false,
            "targetPresetsToMonitorOfMouse": false,
            "insetsPrimaryTop": 0,
            "insetsPrimaryRight": 0,
            "insetsPrimaryBottom": 0,
            "insetsPrimaryLeft": 0,
            "insetsSecondaryTop": 0,
            "insetsSecondaryRight": 0,
            "insetsSecondaryBottom": 0,
            "insetsSecondaryLeft": 0,
            "windowSpacing": 0,
            "selectionTimeout": 600,
            "gridSizes": "8x6, 6x4, 4x4",
            "autotileMainWindowRatios": "0.5,0.6,0.65,0.7",
        ]

        // Default resize presets matching gTile defaults
        let defaultResizePresets = [
            "4x4 1:3 2:4, 1:2 3:4, 1:1 4:4, 1:4 1:4",     // 1
            "4x4 1:3 4:4,1:2 4:4,1:1 4:4,1:4 4:4",         // 2
            "4x4 3:3 4:4,2:2 4:4,1:1 4:4,4:4 4:4",         // 3
            "4x4 1:1 2:4,1:1 3:4,1:1 4:4,1:1 1:4",         // 4
            "8x8 3:3 6:6, 2:2 7:7,1:1 8:8,16x16 6:6 10:10", // 5
            "4x4 3:1 4:4,2:1 4:4,1:1 4:4,4:1 4:4",         // 6
            "4x4 1:1 2:2,1:1 3:3,1:1 4:4,1:1 1:1",         // 7
            "4x4 1:1 4:2,1:1 4:3,1:1 4:4,1:1 4:1",         // 8
            "4x4 3:1 4:2,2:1 4:3,1:1 4:4,4:1 4:1",         // 9
        ]

        var mutableDefaults = defaultValues
        for i in 1...30 {
            let key = "resize\(i)"
            mutableDefaults[key] = i <= defaultResizePresets.count ? defaultResizePresets[i - 1] : ""
        }
        for i in 1...10 {
            mutableDefaults["autotileGridSpec\(i)"] = ""
        }

        defaults.register(defaults: mutableDefaults)

        // Load values
        self.autoClose = defaults.bool(forKey: "autoClose")
        self.autoMaximize = defaults.bool(forKey: "autoMaximize")
        self.followCursor = defaults.bool(forKey: "followCursor")
        self.globalAutoTiling = defaults.bool(forKey: "globalAutoTiling")
        self.globalPresets = defaults.bool(forKey: "globalPresets")
        self.moveResizeEnabled = defaults.bool(forKey: "moveResizeEnabled")
        self.showGridLines = defaults.bool(forKey: "showGridLines")
        self.targetPresetsToMonitorOfMouse = defaults.bool(forKey: "targetPresetsToMonitorOfMouse")

        self.insetsPrimaryTop = defaults.integer(forKey: "insetsPrimaryTop")
        self.insetsPrimaryRight = defaults.integer(forKey: "insetsPrimaryRight")
        self.insetsPrimaryBottom = defaults.integer(forKey: "insetsPrimaryBottom")
        self.insetsPrimaryLeft = defaults.integer(forKey: "insetsPrimaryLeft")
        self.insetsSecondaryTop = defaults.integer(forKey: "insetsSecondaryTop")
        self.insetsSecondaryRight = defaults.integer(forKey: "insetsSecondaryRight")
        self.insetsSecondaryBottom = defaults.integer(forKey: "insetsSecondaryBottom")
        self.insetsSecondaryLeft = defaults.integer(forKey: "insetsSecondaryLeft")
        self.windowSpacing = defaults.integer(forKey: "windowSpacing")
        self.selectionTimeout = defaults.integer(forKey: "selectionTimeout")

        self.gridSizes = defaults.string(forKey: "gridSizes") ?? "8x6, 6x4, 4x4"
        self.autotileMainWindowRatios = defaults.string(forKey: "autotileMainWindowRatios") ?? "0.5,0.6,0.65,0.7"

        self.resizePresets = (1...30).map { defaults.string(forKey: "resize\($0)") ?? "" }
        self.autotileGridSpecs = (1...10).map { defaults.string(forKey: "autotileGridSpec\($0)") ?? "" }
    }
}
