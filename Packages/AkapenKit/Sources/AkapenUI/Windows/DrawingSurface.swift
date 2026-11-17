import AppKit
import AkapenCore
import AkapenAXID

/// 枠をドラッグで描く透明な面。
final class DrawingSurface: NSView {
    let model: SessionModel
    var screen: ScreenDescriptor?
    var primaryTop: CGFloat = 0
    var start: NSPoint?
    var end: NSPoint?

    override var acceptsFirstResponder: Bool {
        true
    }

    init(model: SessionModel) {
        self.model = model
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier(AXID.Draw.surface)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unsupported")
    }

    func reset() {
        start = nil
        end = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        end = start
    }

    override func mouseDragged(with event: NSEvent) {
        end = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    private var selection: NSRect? {
        guard let start, let end else {
            return nil
        }
        return NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let selection else {
            return
        }
        Tokens.frameColor.setStroke()
        let path = NSBezierPath(rect: selection)
        path.lineWidth = Tokens.frameWidth
        path.stroke()
    }

    override func mouseUp(with event: NSEvent) {
        end = convert(event.locationInWindow, from: nil)
        guard let selection, let screen, let window, selection.width > 0, selection.height > 0 else {
            return
        }
        let global = window.convertToScreen(convert(selection, to: nil))
        model.send(.dragEnded(rect: ScreenCoordinates.rect(global, primaryTop: primaryTop), screen: screen))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            model.send(.escapePressed)
        } else {
            super.keyDown(with: event)
        }
    }
}
