import SwiftUI
import AppKit

/// Observable state for the grid, shared between GridView and OverlayController.
/// Using a class avoids @State being reset when the view is recreated.
final class GridInteractionState: ObservableObject {
    @Published var anchor: GridOffset?
    @Published var hoverTile: GridOffset?
    /// Keyboard-driven cursor position. Takes priority over hoverTile for highlighting.
    @Published var keyboardCursor: GridOffset?

    /// The active cursor: keyboard takes priority over mouse hover.
    var activeCursor: GridOffset? {
        keyboardCursor ?? hoverTile
    }
}

/// SwiftUI view that renders an interactive 2D tile grid.
struct GridView: View {
    let gridSize: GridSize
    @Binding var selection: GridSelection?
    var onHoverChanged: ((GridOffset?) -> Void)?
    let onSelectionComplete: ((GridSelection) -> Void)?
    @ObservedObject var interactionState: GridInteractionState

    private let tileSpacing: CGFloat = 2
    private let tileCornerRadius: CGFloat = 3

    var body: some View {
        GridTrackingView(
            gridSize: gridSize,
            interactionState: interactionState,
            onHoverChanged: onHoverChanged,
            onTap: { handleTap($0) }
        )
        .overlay(gridOverlay)
        .clipped()
    }

    /// Pure rendering layer — no gesture handlers, drawn on top of the tracking view.
    private var gridOverlay: some View {
        GeometryReader { geometry in
            let tileWidth = (geometry.size.width - tileSpacing * CGFloat(gridSize.cols - 1)) / CGFloat(gridSize.cols)
            let tileHeight = (geometry.size.height - tileSpacing * CGFloat(gridSize.rows - 1)) / CGFloat(gridSize.rows)

            Canvas { context, _ in
                for row in 0..<gridSize.rows {
                    for col in 0..<gridSize.cols {
                        let offset = GridOffset(col: col, row: row)
                        let state = tileState(offset)
                        let x = CGFloat(col) * (tileWidth + tileSpacing)
                        let y = CGFloat(row) * (tileHeight + tileSpacing)
                        let rect = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
                        let path = Path(roundedRect: rect, cornerRadius: tileCornerRadius)
                        context.fill(path, with: .color(colorForState(state)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private enum TileState {
        case selected, previewed, hovered, normal
    }

    private func tileState(_ offset: GridOffset) -> TileState {
        if let selection = selection, isInRange(offset, from: selection.anchor, to: selection.target) {
            return .selected
        }
        let cursor = interactionState.activeCursor
        if let anchor = interactionState.anchor, let cur = cursor {
            if isInRange(offset, from: anchor, to: cur) {
                return .previewed
            }
        }
        if interactionState.anchor == nil && cursor == offset {
            return .hovered
        }
        return .normal
    }

    private func isInRange(_ offset: GridOffset, from a: GridOffset, to b: GridOffset) -> Bool {
        let minCol = min(a.col, b.col), maxCol = max(a.col, b.col)
        let minRow = min(a.row, b.row), maxRow = max(a.row, b.row)
        return offset.col >= minCol && offset.col <= maxCol &&
               offset.row >= minRow && offset.row <= maxRow
    }

    private func colorForState(_ state: TileState) -> Color {
        switch state {
        case .selected:  return Color.accentColor.opacity(0.8)
        case .previewed: return Color.accentColor.opacity(0.45)
        case .hovered:   return Color.accentColor.opacity(0.3)
        case .normal:    return Color.white.opacity(0.08)
        }
    }

    private func handleTap(_ offset: GridOffset) {
        if let currentAnchor = interactionState.anchor {
            let newSelection = GridSelection(anchor: currentAnchor, target: offset)
            selection = newSelection
            interactionState.anchor = nil
            onSelectionComplete?(newSelection)
        } else {
            interactionState.anchor = offset
            selection = GridSelection(anchor: offset, target: offset)
        }
    }
}

// MARK: - AppKit tracking view (single NSTrackingArea, no SwiftUI per-tile overhead)

/// NSView that handles mouse tracking and clicks via a single NSTrackingArea,
/// then forwards hit-tested grid offsets to SwiftUI.
final class GridTrackingNSView: NSView {
    var gridSize: GridSize = GridSize(cols: 1, rows: 1)
    var onHover: ((GridOffset?) -> Void)?
    var onTap: ((GridOffset) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onHover?(gridHitTest(point))
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(nil)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let offset = gridHitTest(point) {
            onTap?(offset)
        }
    }

    private func gridHitTest(_ point: CGPoint) -> GridOffset? {
        // Flip Y: NSView uses bottom-left origin
        let flippedY = bounds.height - point.y
        let tileSpacing: CGFloat = 2
        let tileWidth = (bounds.width - tileSpacing * CGFloat(gridSize.cols - 1)) / CGFloat(gridSize.cols)
        let tileHeight = (bounds.height - tileSpacing * CGFloat(gridSize.rows - 1)) / CGFloat(gridSize.rows)
        let col = Int(point.x / (tileWidth + tileSpacing))
        let row = Int(flippedY / (tileHeight + tileSpacing))
        guard col >= 0, col < gridSize.cols, row >= 0, row < gridSize.rows else { return nil }
        return GridOffset(col: col, row: row)
    }
}

/// SwiftUI wrapper for GridTrackingNSView.
struct GridTrackingView: NSViewRepresentable {
    let gridSize: GridSize
    let interactionState: GridInteractionState
    var onHoverChanged: ((GridOffset?) -> Void)?
    var onTap: ((GridOffset) -> Void)?

    func makeNSView(context: Context) -> GridTrackingNSView {
        let view = GridTrackingNSView()
        view.gridSize = gridSize
        view.onHover = { [weak interactionState] offset in
            DispatchQueue.main.async {
                guard let state = interactionState else { return }
                if state.hoverTile != offset {
                    state.hoverTile = offset
                    onHoverChanged?(offset)
                }
            }
        }
        view.onTap = onTap
        return view
    }

    func updateNSView(_ nsView: GridTrackingNSView, context: Context) {
        nsView.gridSize = gridSize
        nsView.onTap = onTap
        nsView.onHover = { [weak interactionState] offset in
            DispatchQueue.main.async {
                guard let state = interactionState else { return }
                if state.hoverTile != offset {
                    state.hoverTile = offset
                    onHoverChanged?(offset)
                }
            }
        }
    }
}
