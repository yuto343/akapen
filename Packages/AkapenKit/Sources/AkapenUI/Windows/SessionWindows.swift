import AppKit
import AkapenCore
import AkapenAXID

private final class DrawingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
/// AppKit の左下原点と Core の共通左上原点の変換境界。
@MainActor public enum ScreenCoordinates {
    public static func rect(_ rect: NSRect, primaryTop: CGFloat) -> ScreenRect {
        ScreenRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }
}
/// phase に応じて描画面と非アクティブパネルを出し入れする。
@MainActor public final class SessionWindows {
    public let toolbar: NSPanel
    public let drawing: NSPanel
    private let model: SessionModel
    private let surface: DrawingSurface
    public init(model: SessionModel) {
        self.model = model
        toolbar = NSPanel(contentRect: NSRect(origin: .zero, size: Tokens.toolbarSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        drawing = DrawingPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        surface = DrawingSurface(model: model)
        drawing.contentView = surface; drawing.isOpaque = false; drawing.backgroundColor = Tokens.drawingBackground
        drawing.level = .floating; toolbar.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        for panel in [toolbar, drawing] {
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        let stack = NSStackView()
        stack.orientation = .horizontal; stack.spacing = Tokens.spacing
        for (key, id, action) in [("add", AXID.Toolbar.add, #selector(add)), ("list", AXID.Toolbar.list, #selector(list)), ("copyPrompt", AXID.Toolbar.copyPrompt, #selector(copyPrompt))] {
            let button = NSButton(title: UIStrings.text(key), target: self, action: action)
            button.setAccessibilityIdentifier(id); stack.addArrangedSubview(button)
        }
        toolbar.contentView = stack
    }
    /// 画面選択は表示開始時だけ行い、ドラッグ途中の画面を固定する。
    public func render() {
        guard model.phase != .hidden else { hide(); return }
        if model.phase == .drawing && !drawing.isVisible {
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.screens.first else { return }
            let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
            surface.screen = ScreenDescriptor(id: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0,
                frame: ScreenCoordinates.rect(screen.frame, primaryTop: primaryTop))
            surface.primaryTop = primaryTop; surface.reset()
            drawing.setFrame(screen.frame, display: true)
            toolbar.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - Tokens.toolbarSize.width / 2, y: screen.visibleFrame.minY + Tokens.margin))
            drawing.makeKeyAndOrderFront(nil); drawing.makeFirstResponder(surface)
        } else if model.phase != .drawing { drawing.orderOut(nil) }
        toolbar.orderFrontRegardless()
    }
    /// 終了処理とテストの後始末。
    public func hide() { drawing.orderOut(nil); toolbar.orderOut(nil) }
    @objc private func add() { model.send(.addTapped) }
    @objc private func list() { model.send(.listToggled) }
    @objc private func copyPrompt() { model.send(.copyPromptTapped) }
}
private final class DrawingSurface: NSView {
    let model: SessionModel
    var screen: ScreenDescriptor?
    var primaryTop: CGFloat = 0
    var start: NSPoint?
    var end: NSPoint?
    override var acceptsFirstResponder: Bool { true }
    init(model: SessionModel) {
        self.model = model; super.init(frame: .zero)
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityIdentifier(AXID.Draw.surface)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func reset() { start = nil; end = nil; needsDisplay = true }
    override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil); end = start }
    override func mouseDragged(with event: NSEvent) { end = convert(event.locationInWindow, from: nil); needsDisplay = true }
    private var selection: NSRect? {
        guard let start, let end else { return nil }
        return NSRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let selection else { return }
        Tokens.frameColor.setStroke(); let path = NSBezierPath(rect: selection); path.lineWidth = Tokens.frameWidth; path.stroke()
    }
    override func mouseUp(with event: NSEvent) {
        end = convert(event.locationInWindow, from: nil)
        guard let selection, let screen, let window, selection.width > 0, selection.height > 0 else { return }
        let global = window.convertToScreen(convert(selection, to: nil))
        model.send(.dragEnded(rect: ScreenCoordinates.rect(global, primaryTop: primaryTop), screen: screen))
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { model.send(.escapePressed) } else { super.keyDown(with: event) }
    }
}
