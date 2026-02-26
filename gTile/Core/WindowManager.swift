import AppKit
import ApplicationServices

/// Axis for grid spec subdivision.
enum Axis: String {
    case x, y
}

/// Splits computed gridspec cell areas into non-dynamic and dynamic cells.
typealias GridSpecAreas = (dedicated: [Rectangle], dynamic: [Rectangle], dynamicAxes: [Axis])

/// Binary tree node used in the autogrow algorithm.
final class TreeNode<T> {
    let data: T
    var left: TreeNode<T>?
    var right: TreeNode<T>?

    init(data: T, left: TreeNode<T>? = nil, right: TreeNode<T>? = nil) {
        self.data = data
        self.left = left
        self.right = right
    }
}

/// Port of DesktopManager.ts - core window management logic.
///
/// Provides a unified interface for desktop-related actions and window
/// manipulation using the macOS Accessibility API.
final class WindowManager {
    let accessibilityService: AccessibilityService
    private let displayService: DisplayService
    private let preferences: UserPreferences

    init(
        accessibilityService: AccessibilityService,
        displayService: DisplayService,
        preferences: UserPreferences
    ) {
        self.accessibilityService = accessibilityService
        self.displayService = displayService
        self.preferences = preferences
    }

    // MARK: - Public Properties

    /// The window that is currently in focus.
    var focusedWindow: AXUIElement? {
        accessibilityService.focusedWindow()
    }

    /// The list of monitors that comprise the desktop.
    var monitors: [Screen] {
        displayService.monitors
    }

    /// The current pointer location.
    var pointer: CGPoint {
        displayService.pointerLocation
    }

    /// The monitor index that the pointer resides on.
    var pointerMonitorIndex: Int {
        displayService.pointerMonitorIndex
    }

    // MARK: - Window Operations

    /// Moves a window to another monitor, keeping the relative position.
    func moveToMonitor(_ target: AXUIElement, monitorIdx: Int? = nil) {
        let currentMonitor = accessibilityService.windowMonitorIndex(target)
        let targetMonitor = monitorIdx ?? ((currentMonitor + 1) % monitors.count)

        if targetMonitor == currentMonitor { return }

        // Center the window on the new monitor
        applySelection(
            target,
            monitorIdx: targetMonitor,
            gridSize: GridSize(cols: 5, rows: 10),
            selection: GridSelection(
                anchor: GridOffset(col: 1, row: 1),
                target: GridOffset(col: 3, row: 8)
            )
        )
    }

    /// Adjusts the window size and position to match the selection.
    func applySelection(
        _ target: AXUIElement,
        monitorIdx: Int,
        gridSize: GridSize,
        selection: GridSelection
    ) {
        let targetTitle = accessibilityService.windowTitle(target) ?? "<no title>"
        let currentFrame = accessibilityService.windowFrame(target)
        print("gTile: applySelection target='\(targetTitle)' grid=\(gridSize.cols)x\(gridSize.rows) sel=\(selection.anchor.col),\(selection.anchor.row)->\(selection.target.col),\(selection.target.row) monitor=\(monitorIdx) currentFrame=\(String(describing: currentFrame))")

        let gridArea = gridSize.cols * gridSize.rows
        let selectionArea =
            (abs(selection.target.col - selection.anchor.col) + 1) *
            (abs(selection.target.row - selection.anchor.row) + 1)

        if preferences.autoMaximize && gridArea == selectionArea {
            // Maximize: fill the work area
            let workArea = self.workArea(monitorIdx)
            fit(target, rect: workArea)
        } else {
            let projection = selectionToArea(selection, gridSize: gridSize, monitorIdx: monitorIdx)
            fit(target, rect: projection)
        }
    }

    /// Projects a selection to an area on the monitor.
    ///
    /// - Parameters:
    ///   - selection: The selection to be mapped/projected.
    ///   - gridSize: The reference grid used to divide the monitor's work area.
    ///   - monitorIdx: The monitor for which the selection is being mapped.
    ///   - preview: When true, deducts the user-configured spacing ahead of time.
    /// - Returns: The mapped selection as a Rectangle.
    func selectionToArea(
        _ selection: GridSelection,
        gridSize: GridSize,
        monitorIdx: Int,
        preview: Bool = false
    ) -> Rectangle {
        let cols = Double(gridSize.cols)
        let rows = Double(gridSize.rows)
        let relX = Double(min(selection.anchor.col, selection.target.col)) / cols
        let relY = Double(min(selection.anchor.row, selection.target.row)) / rows
        let relW = Double(abs(selection.anchor.col - selection.target.col) + 1) / cols
        let relH = Double(abs(selection.anchor.row - selection.target.row) + 1) / rows
        let wa = workArea(monitorIdx)
        let spacing = preview ? Double(preferences.windowSpacing) : 0

        return Rectangle(
            x: wa.x + wa.width * relX + spacing,
            y: wa.y + wa.height * relY + spacing,
            width: wa.width * relW - spacing * 2,
            height: wa.height * relH - spacing * 2
        )
    }

    /// Maps the size and position of a window to the most fitting selection
    /// that aligns with the provided grid size.
    func windowToSelection(
        _ window: AXUIElement,
        gridSize: GridSize,
        snap: SnapStrategy = .closest
    ) -> GridSelection {
        let frame = frameRect(window)
        let monitorIdx = accessibilityService.windowMonitorIndex(window)
        let wa = workArea(monitorIdx)
        let relativeRect = Rectangle(
            x: (frame.x - wa.x) / wa.width,
            y: (frame.y - wa.y) / wa.height,
            width: frame.width / wa.width,
            height: frame.height / wa.height
        )

        return rectToSelection(relativeRect, gridSize: gridSize, snap: snap)
    }

    /// Snap strategy for mapping window positions to grid selections.
    enum SnapStrategy {
        case closest, shrink, grow
    }

    /// Expands the target window to maximize its area without overlapping
    /// any new windows.
    ///
    /// Uses an O(2^n) binary tree expansion algorithm where n is the number
    /// of windows that need to be avoided. In practice n remains small (2-3).
    func autogrow(_ target: AXUIElement) {
        let monitorIdx = accessibilityService.windowMonitorIndex(target)
        let wa = workArea(monitorIdx)

        guard var frame = accessibilityService.windowFrame(target) else { return }

        // Intersect frame with work area
        if let clipped = frame.intersection(wa) {
            frame = clipped
        }

        // Get collision windows
        let allWindows = accessibilityService.allWindows()
        var collisionWindows: [Rectangle] = []

        for (win, _) in allWindows {
            // Skip the target window itself
            guard let winFrame = accessibilityService.windowFrame(win) else { continue }
            if accessibilityService.isMinimized(win) { continue }
            if winFrame == frame { continue } // Same position = same window
            let winMonitor = accessibilityService.windowMonitorIndex(win)
            if winMonitor != monitorIdx { continue }
            if frame.contains(winFrame) { continue }
            if frame.intersects(winFrame) { continue }

            collisionWindows.append(winFrame)
        }

        // Step 1: Calculate maximum possible boundary
        let doShareXAxis = { (r: Rectangle, o: Rectangle) -> Bool in
            r.x < (o.x + o.width) && o.x < (r.x + r.width)
        }
        let doShareYAxis = { (r: Rectangle, o: Rectangle) -> Bool in
            r.y < (o.y + o.height) && o.y < (r.y + r.height)
        }

        let maxWestBound = collisionWindows
            .filter { isWestOf($0, frame) && doShareYAxis($0, frame) }
            .map { $0.x + $0.width }
            .max() ?? -.infinity

        let maxNorthBound = collisionWindows
            .filter { isNorthOf($0, frame) && doShareXAxis($0, frame) }
            .map { $0.y + $0.height }
            .max() ?? -.infinity

        let maxEastBound = collisionWindows
            .filter { isEastOf($0, frame) && doShareYAxis($0, frame) }
            .map { $0.x }
            .min() ?? .infinity

        let maxSouthBound = collisionWindows
            .filter { isSouthOf($0, frame) && doShareXAxis($0, frame) }
            .map { $0.y }
            .min() ?? .infinity

        let x = max(maxWestBound, wa.x)
        let y = max(maxNorthBound, wa.y)
        let optimalFrame = Rectangle(
            x: x, y: y,
            width: min(maxEastBound, wa.x + wa.width) - x,
            height: min(maxSouthBound, wa.y + wa.height) - y
        )

        // Step 2: Build tree and find optimal expansion
        let remainingColliders = collisionWindows.filter { win in
            optimalFrame.intersects(win) || optimalFrame.contains(win)
        }
        let root = buildTree(frame: frame, bounds: optimalFrame, collisionObjects: remainingColliders)
        let best = findBest(root)

        fit(target, rect: best)
    }

    /// Applies a GridSpec to the targeted monitor.
    func autotile(_ spec: GridSpec, monitorIdx: Int) {
        let (dedicated, dynamic, dynamicAxis) = gridSpecToAreas(spec)
        let wa = workArea(monitorIdx)

        // Get windows on this monitor
        var windows: [(window: AXUIElement, hasFocus: Bool)] = []
        let focused = focusedWindow

        for (win, _) in accessibilityService.allWindows() {
            if accessibilityService.isMinimized(win) { continue }
            let winMonitor = accessibilityService.windowMonitorIndex(win)
            if winMonitor != monitorIdx { continue }

            let isFocused = focused.map { CFEqual($0, win) } ?? false
            windows.append((win, isFocused))
        }

        // Sort: focused window first
        windows.sort { w1, w2 in
            if w1.hasFocus { return true }
            if w2.hasFocus { return false }
            return false
        }

        let project = { (rect: Rectangle, canvas: Rectangle) -> Rectangle in
            Rectangle(
                x: canvas.x + canvas.width * rect.x,
                y: canvas.y + canvas.height * rect.y,
                width: canvas.width * rect.width,
                height: canvas.height * rect.height
            )
        }

        var mutableDedicated = dedicated
        var windowList = windows

        // Place focused window in the largest dedicated area
        let focusedIdx = windowList.firstIndex { $0.hasFocus }
        if let focusedIdx = focusedIdx, !mutableDedicated.isEmpty {
            var largestIdx = 0
            var largestArea = 0.0
            for (idx, rect) in mutableDedicated.enumerated() {
                let area = rect.width * rect.height
                if area > largestArea {
                    largestIdx = idx
                    largestArea = area
                }
            }

            let projectedArea = project(mutableDedicated[largestIdx], wa)
            fit(windowList[focusedIdx].window, rect: projectedArea)

            windowList.remove(at: focusedIdx)
            mutableDedicated.remove(at: largestIdx)
        }

        // Place windows in regular cells
        let regularCount = min(mutableDedicated.count, windowList.count)
        for i in 0..<regularCount {
            fit(windowList[i].window, rect: project(mutableDedicated[i], wa))
        }

        // Fit remaining windows in dynamic cells
        let remaining = Array(windowList.dropFirst(mutableDedicated.count))
        for i in 0..<dynamic.count {
            let mustFitAtLeastN = remaining.count / dynamic.count
            let mustTakeOverflow = i < (remaining.count % dynamic.count)
            let n = mustFitAtLeastN + (mustTakeOverflow ? 1 : 0)

            var j = i
            for area in splitN(dynamic[i], n: n, axis: dynamicAxis[i]) {
                if j < remaining.count {
                    fit(remaining[j].window, rect: project(area, wa))
                }
                j += dynamic.count
            }
        }
    }

    /// Moves a window such that its NW edge aligns with the next grid line.
    func moveWindow(_ target: AXUIElement, gridSize: GridSize, dir: CardinalDirection) {
        let strategy: SnapStrategy = (dir == .west || dir == .north) ? .shrink : .grow
        let frameFit = windowToSelection(target, gridSize: gridSize, snap: strategy)
        let targetSelection = pan(frameFit, bounds: gridSize, dir: dir)
        let nwTile = GridOffset(
            col: min(targetSelection.anchor.col, targetSelection.target.col),
            row: min(targetSelection.anchor.row, targetSelection.target.row)
        )
        let asSelection = GridSelection(anchor: nwTile, target: nwTile)
        let monitorIdx = accessibilityService.windowMonitorIndex(target)
        let targetArea = selectionToArea(asSelection, gridSize: gridSize, monitorIdx: monitorIdx)
        let frame = frameRect(target)
        let newX = (dir == .north || dir == .south) ? frame.x : targetArea.x
        let newY = (dir == .east || dir == .west) ? frame.y : targetArea.y

        moveResize(target, x: newX, y: newY)
    }

    /// Resizes a window by shrinking or extending an edge towards a specified direction.
    func resizeWindow(
        _ target: AXUIElement,
        gridSize: GridSize,
        dir: CardinalDirection,
        mode: AdjustMode
    ) {
        let strategy: SnapStrategy = mode == .extend ? .shrink : .grow
        let frameFit = windowToSelection(target, gridSize: gridSize, snap: strategy)
        let targetSelection = adjust(frameFit, bounds: gridSize, dir: dir, mode: mode)
        let monitorIdx = accessibilityService.windowMonitorIndex(target)
        let targetArea = selectionToArea(targetSelection, gridSize: gridSize, monitorIdx: monitorIdx)
        let frame = frameRect(target)

        let rect: Rectangle
        switch dir {
        case .north:
            let height = frame.y + frame.height - targetArea.y
            rect = Rectangle(x: frame.x, y: targetArea.y, width: frame.width, height: height)
        case .south:
            let height = targetArea.y + targetArea.height - frame.y
            rect = Rectangle(x: frame.x, y: frame.y, width: frame.width, height: height)
        case .east:
            let width = targetArea.x + targetArea.width - frame.x
            rect = Rectangle(x: frame.x, y: frame.y, width: width, height: frame.height)
        case .west:
            let width = frame.x + frame.width - targetArea.x
            rect = Rectangle(x: targetArea.x, y: frame.y, width: width, height: frame.height)
        }

        fit(target, rect: rect)
    }

    // MARK: - Private Methods

    private func moveResize(_ target: AXUIElement, x: Double, y: Double, size: CGSize? = nil) {
        let spacing = Double(preferences.windowSpacing)
        let adjustedX = x + spacing
        let adjustedY = y + spacing

        if let size = size {
            let adjustedWidth = size.width - CGFloat(spacing * 2)
            let adjustedHeight = size.height - CGFloat(spacing * 2)
            accessibilityService.setWindowFrame(target, frame: Rectangle(
                x: adjustedX, y: adjustedY,
                width: Double(adjustedWidth), height: Double(adjustedHeight)
            ))
        } else {
            accessibilityService.moveWindow(target, to: CGPoint(x: adjustedX, y: adjustedY))
        }
    }

    private func fit(_ target: AXUIElement, rect: Rectangle) {
        moveResize(target, x: rect.x, y: rect.y,
                   size: CGSize(width: rect.width, height: rect.height))
    }

    private func frameRect(_ target: AXUIElement) -> Rectangle {
        guard let frame = accessibilityService.windowFrame(target) else {
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }
        let spacing = Double(preferences.windowSpacing)
        return Rectangle(
            x: frame.x - spacing,
            y: frame.y - spacing,
            width: frame.width + spacing * 2,
            height: frame.height + spacing * 2
        )
    }

    func workArea(_ monitorIdx: Int) -> Rectangle {
        guard monitorIdx < monitors.count else {
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        let isPrimary = monitorIdx == displayService.primaryMonitorIndex
        let inset = preferences.getInset(isPrimary: isPrimary)
        var wa = monitors[monitorIdx].workArea
        let spacing = Double(preferences.windowSpacing)

        let top = Double(clamp(inset.top, min: 0, max: Int(wa.height) / 2))
        let bottom = Double(clamp(inset.bottom, min: 0, max: Int(wa.height) / 2))
        let left = Double(clamp(inset.left, min: 0, max: Int(wa.width) / 2))
        let right = Double(clamp(inset.right, min: 0, max: Int(wa.width) / 2))

        wa.x += left - spacing
        wa.y += top - spacing
        wa.width -= left + right - spacing * 2
        wa.height -= top + bottom - spacing * 2

        return wa
    }

    // MARK: - Grid-to-Selection Mapping

    private func rectToSelection(
        _ rect: Rectangle,
        gridSize: GridSize,
        snap: SnapStrategy,
        epsilon: Double = 0.01
    ) -> GridSelection {
        let cols = Double(gridSize.cols)
        let rows = Double(gridSize.rows)

        let roundNear = { (n: Double, eps: Double) -> Double in
            abs(n - n.rounded()) <= eps ? n.rounded() : n
        }

        let exactNwX = clamp(roundNear(cols * rect.x, epsilon), min: 0, max: cols - 1)
        let exactNwY = clamp(roundNear(rows * rect.y, epsilon), min: 0, max: rows - 1)
        let exactSeX = clamp(roundNear(cols * (rect.x + rect.width), epsilon), min: 1, max: cols)
        let exactSeY = clamp(roundNear(rows * (rect.y + rect.height), epsilon), min: 1, max: rows)

        let discretize: (Double) -> Double
        switch snap {
        case .shrink: discretize = { Foundation.floor($0) }
        case .grow: discretize = { Foundation.ceil($0) }
        case .closest: discretize = { $0.rounded() }
        }

        let transformNW: (Double) -> Double = { n in
            n * (snap == .closest ? 1 : -1)
        }

        var alignedNwX = transformNW(discretize(transformNW(exactNwX)))
        var alignedNwY = transformNW(discretize(transformNW(exactNwY)))
        var alignedSeX = discretize(exactSeX)
        var alignedSeY = discretize(exactSeY)

        // Resolve collapsed corners
        if alignedNwX == alignedSeX {
            let nwXAlt = transformNW(Foundation.ceil(transformNW(exactNwX)))
            let seXAlt = Foundation.ceil(exactSeX)

            if nwXAlt == seXAlt {
                alignedSeX += 1
            } else if abs(nwXAlt - exactNwX) < abs(seXAlt - exactSeX) {
                alignedNwX = nwXAlt
            } else {
                alignedSeX = seXAlt
            }
        }

        if alignedNwY == alignedSeY {
            let nwYAlt = transformNW(Foundation.ceil(transformNW(exactNwY)))
            let seYAlt = Foundation.ceil(exactSeY)

            if nwYAlt == seYAlt {
                alignedSeY += 1
            } else if abs(nwYAlt - exactNwY) < abs(seYAlt - exactSeY) {
                alignedNwY = nwYAlt
            } else {
                alignedSeY = seYAlt
            }
        }

        return GridSelection(
            anchor: GridOffset(col: Int(alignedNwX), row: Int(alignedNwY)),
            target: GridOffset(col: Int(alignedSeX) - 1, row: Int(alignedSeY) - 1)
        )
    }

    // MARK: - GridSpec Processing

    func gridSpecToAreas(
        _ spec: GridSpec,
        x: Double = 0, y: Double = 0,
        w: Double = 1, h: Double = 1
    ) -> GridSpecAreas {
        var regularCells: [Rectangle] = []
        var dynamicCells: [Rectangle] = []
        var dynamicAxes: [Axis] = []
        let totalWeight = spec.cells.reduce(0) { $0 + $1.weight }

        var cx = x, cy = y
        for cell in spec.cells {
            let ratio = Double(cell.weight) / Double(totalWeight)
            let width = spec.mode == .cols ? w * ratio : w
            let height = spec.mode == .rows ? h * ratio : h
            let axis: Axis = spec.mode == .cols ? .x : .y

            if let child = cell.child {
                let (dedicated, dynamic, childAxes) = gridSpecToAreas(child, x: cx, y: cy, w: width, h: height)
                regularCells.append(contentsOf: dedicated)
                dynamicCells.append(contentsOf: dynamic)
                dynamicAxes.append(contentsOf: childAxes)
            } else if cell.dynamic {
                dynamicCells.append(Rectangle(x: cx, y: cy, width: width, height: height))
                dynamicAxes.append(axis)
            } else {
                regularCells.append(Rectangle(x: cx, y: cy, width: width, height: height))
            }

            if spec.mode == .cols { cx += width }
            if spec.mode == .rows { cy += height }
        }

        return (regularCells, dynamicCells, dynamicAxes)
    }

    func splitN(_ rect: Rectangle, n: Int, axis: Axis) -> [Rectangle] {
        guard n > 0 else { return [] }
        var result: [Rectangle] = []
        var cx = rect.x, cy = rect.y
        var i = n

        while i > 0 {
            result.append(Rectangle(
                x: cx, y: cy,
                width: axis == .x ? rect.width / Double(n) : rect.width,
                height: axis == .y ? rect.height / Double(n) : rect.height
            ))

            if axis == .x { cx += rect.width / Double(n) }
            if axis == .y { cy += rect.height / Double(n) }
            i -= 1
        }

        return result
    }

    // MARK: - Autogrow Tree Algorithm

    private func buildTree(
        frame: Rectangle,
        bounds: Rectangle,
        collisionObjects: [Rectangle]
    ) -> TreeNode<Rectangle> {
        let node = TreeNode(data: bounds)
        guard !collisionObjects.isEmpty else { return node }

        var remaining = collisionObjects
        let win = remaining.removeFirst()

        let we: CardinalDirection = isWestOf(win, frame) ? .west : .east
        let optimalFrameX = noCollide(bounds: bounds, collider: win, dir: we)
        node.left = buildTree(
            frame: frame,
            bounds: optimalFrameX,
            collisionObjects: remaining.filter {
                optimalFrameX.intersects($0) || optimalFrameX.contains($0)
            }
        )

        let ns: CardinalDirection = isNorthOf(win, frame) ? .north : .south
        let optimalFrameY = noCollide(bounds: bounds, collider: win, dir: ns)
        node.right = buildTree(
            frame: frame,
            bounds: optimalFrameY,
            collisionObjects: remaining.filter {
                optimalFrameY.intersects($0) || optimalFrameY.contains($0)
            }
        )

        return node
    }

    private func findBest(_ tree: TreeNode<Rectangle>) -> Rectangle {
        let left = tree.left.map { findBest($0) }
        let right = tree.right.map { findBest($0) }

        switch (left, right) {
        case (nil, nil): return tree.data
        case (nil, let r?): return r
        case (let l?, nil): return l
        case (let l?, let r?): return l.area > r.area ? l : r
        }
    }

    // MARK: - Geometry Helpers

    private func isWestOf(_ r: Rectangle, _ o: Rectangle) -> Bool {
        o.x >= (r.x + r.width)
    }

    private func isEastOf(_ r: Rectangle, _ o: Rectangle) -> Bool {
        isWestOf(o, r)
    }

    private func isNorthOf(_ r: Rectangle, _ o: Rectangle) -> Bool {
        o.y >= (r.y + r.height)
    }

    private func isSouthOf(_ r: Rectangle, _ o: Rectangle) -> Bool {
        isNorthOf(o, r)
    }

    private func noCollide(bounds: Rectangle, collider: Rectangle, dir: CardinalDirection) -> Rectangle {
        var newBounds = bounds

        switch dir {
        case .east:
            newBounds.width = collider.x - newBounds.x
        case .west:
            let oldX = newBounds.x
            newBounds.x = collider.x + collider.width
            newBounds.width -= newBounds.x - oldX
        case .north:
            let oldY = newBounds.y
            newBounds.y = collider.y + collider.height
            newBounds.height -= newBounds.y - oldY
        case .south:
            newBounds.height = collider.y - newBounds.y
        }

        return newBounds
    }
}
