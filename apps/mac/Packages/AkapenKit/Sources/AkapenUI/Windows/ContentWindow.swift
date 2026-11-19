import AppKit
import SwiftUI

/// 設定とセットアップの、通常のウィンドウ（タイトルバーつき）。
///
/// タイトルバーは透明にし、中身（SwiftUI）がウィンドウの上端から描く。信号ボタンはシステムが描く。
/// 見た目はライトに固定する（`DECISIONS.md` 28）。
final class ContentWindow: NSWindow {
    /// 閉じられたとき（閉じるボタン・`⌘W`・`close()` のどれでも）。
    var onClose: (() -> Void)?
    /// キーウィンドウでなくなったとき。
    var onResignKey: (() -> Void)?

    /// - Parameters:
    ///   - toolbarStyle: タイトルバーの高さと信号ボタンの位置を決める（空のツールバーを付ける）。
    ///   - miniaturizable: 最小化のボタンを使えるようにするか。
    init(toolbarStyle: NSWindow.ToolbarStyle, miniaturizable: Bool) {
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        if miniaturizable {
            styleMask.insert(.miniaturizable)
        }
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        titlebarSeparatorStyle = .none
        toolbar = NSToolbar()
        self.toolbarStyle = toolbarStyle
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .documentWindow
        collectionBehavior = [.moveToActiveSpace]
        appearance = NSAppearance(named: .aqua)
        backgroundColor = Tokens.Window.background.nsColor
    }

    override func close() {
        let wasVisible = isVisible
        super.close()
        if wasVisible {
            onClose?()
        }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    /// メインメニューのないアプリなので、`⌘W` で閉じられるようにする。
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) {
            return true
        }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return true
        }
        return false
    }
}

/// ウィンドウの中身。中身の大きさが変わったら知らせる。
struct ContentWindowRoot<Content: View>: View {
    let content: Content
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        content
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                onSizeChange(size)
            }
            .lightAppearance()
    }
}

/// SwiftUI の中身を載せた `ContentWindow`。中身の大きさに合わせて、上端の位置を保ったままウィンドウの大きさを変える。
@MainActor final class ContentWindowHost<Content: View> {
    let window: ContentWindow
    private let hostingView: NSHostingView<ContentWindowRoot<Content>>
    /// アプリを前面に出してからウィンドウを出すか。テストでは false にして、手元の作業の邪魔をしない。
    private let activatesApp: Bool

    init(content: Content, toolbarStyle: NSWindow.ToolbarStyle, miniaturizable: Bool, activatesApp: Bool) {
        window = ContentWindow(toolbarStyle: toolbarStyle, miniaturizable: miniaturizable)
        self.activatesApp = activatesApp
        hostingView = NSHostingView(rootView: ContentWindowRoot(content: content, onSizeChange: { _ in }))
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []
        window.contentView = hostingView
        hostingView.rootView = ContentWindowRoot(content: content) { [weak self] size in
            self?.resize(to: size)
        }
        resize(to: hostingView.fittingSize)
    }

    /// 中身の大きさ。
    var contentSize: CGSize {
        hostingView.fittingSize
    }

    /// 出ているか。
    var isShown: Bool {
        window.isVisible
    }

    /// 前面に出してキー入力を受け取れるようにする。`center` なら画面の中央に置き直す。
    func show(center: Bool) {
        resize(to: hostingView.fittingSize)
        if center {
            window.center()
        }
        if activatesApp {
            NSApp.activate()
        }
        window.makeKeyAndOrderFront(nil)
        if activatesApp {
            // ほかのアプリが使われている最中（起動した直後など）は、アプリを前面に出す求めが断られることがある。
            // そのときもウィンドウは手前に出す（初回のセットアップが、ほかのウィンドウの後ろに隠れないように）。
            window.orderFrontRegardless()
        }
    }

    /// 上端の位置を保ったまま、ウィンドウの大きさを中身に合わせる。
    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            return
        }
        let frame = window.frame
        guard frame.size != size else {
            return
        }
        let origin = NSPoint(x: frame.minX, y: frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
