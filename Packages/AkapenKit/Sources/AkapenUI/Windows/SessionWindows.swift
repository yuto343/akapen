import AppKit
import AkapenCore
import AkapenAXID

private final class DrawingPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
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
        toolbar = NSPanel(
            contentRect: NSRect(origin: .zero, size: Tokens.toolbarSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        drawing = DrawingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        surface = DrawingSurface(model: model)
        drawing.contentView = surface
        drawing.isOpaque = false
        drawing.backgroundColor = Tokens.drawingBackground
        drawing.level = .floating
        toolbar.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        for panel in [toolbar, drawing] {
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = Tokens.spacing
        let buttons = [
            ("add", AXID.Toolbar.add, #selector(add)),
            ("list", AXID.Toolbar.list, #selector(list)),
            ("copyPrompt", AXID.Toolbar.copyPrompt, #selector(copyPrompt)),
        ]
        for (key, id, action) in buttons {
            let button = NSButton(title: UIStrings.text(key), target: self, action: action)
            button.setAccessibilityIdentifier(id)
            stack.addArrangedSubview(button)
        }
        toolbar.contentView = stack
    }

    /// 画面選択は表示開始時だけ行い、ドラッグ途中の画面を固定する。
    public func render() {
        guard model.phase != .hidden else {
            hide()
            return
        }
        if model.phase == .drawing && !drawing.isVisible {
            let underMouse = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            guard let screen = underMouse ?? NSScreen.screens.first else {
                return
            }
            let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            surface.screen = ScreenDescriptor(
                id: number?.uint32Value ?? 0,
                frame: ScreenCoordinates.rect(screen.frame, primaryTop: primaryTop)
            )
            surface.primaryTop = primaryTop
            surface.reset()
            drawing.setFrame(screen.frame, display: true)
            toolbar.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - Tokens.toolbarSize.width / 2,
                y: screen.visibleFrame.minY + Tokens.margin
            ))
            drawing.makeKeyAndOrderFront(nil)
            drawing.makeFirstResponder(surface)
        } else if model.phase != .drawing {
            drawing.orderOut(nil)
        }
        toolbar.orderFrontRegardless()
    }

    /// 終了処理とテストの後始末。
    public func hide() {
        drawing.orderOut(nil)
        toolbar.orderOut(nil)
    }

    @objc private func add() {
        model.send(.addTapped)
    }

    @objc private func list() {
        model.send(.listToggled)
    }

    @objc private func copyPrompt() {
        model.send(.copyPromptTapped)
    }
}
