import AppKit
import AkapenAXID

/// 枠をドラッグで描く面。画面全体を覆うパネルの中身。
///
/// 座標は面の左上を原点にした値で知らせる（`isFlipped`）。画面全体を通した座標への直しは `SessionWindows` が行う。
final class DrawingSurface: NSView {
    /// ドラッグの始点と、いまのカーソルの位置。
    var onDrag: ((CGPoint, CGPoint) -> Void)?
    /// ドラッグの始点と終点。
    var onDragEnded: ((CGPoint, CGPoint) -> Void)?
    /// `Esc` が押されたとき。
    var onEscape: (() -> Void)?
    private var start: CGPoint?

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier(AXID.Draw.surface)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unsupported")
    }

    /// ドラッグの途中の値を捨てる。
    func reset() {
        start = nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        start = point
        NSCursor.crosshair.set()
        onDrag?(point, point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else {
            return
        }
        onDrag?(start, convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard let start else {
            return
        }
        self.start = nil
        onDragEnded?(start, convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    // MARK: 十字カーソル（`DECISIONS.md` 17）

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
}
