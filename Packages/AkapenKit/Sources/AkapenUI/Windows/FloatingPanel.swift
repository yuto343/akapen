import AppKit
import SwiftUI
import AkapenCore

/// akapen の浮いている部品を載せる、アクティブ化しないパネル。
///
/// `allowsKey` が true のパネルは、キー入力を受け取れる（下のアプリを非アクティブにしないまま、キーウィンドウになる）。
/// 見た目はライトに固定する（`DECISIONS.md` 28）。
final class FloatingPanel: NSPanel {
    /// キーウィンドウになれるか。
    var allowsKey = false
    /// `Esc` が押されたとき（入力欄が受け取らなかった分）。
    var onCancel: (() -> Void)?
    /// `Return` が押されたとき（入力欄が受け取らなかった分）。nil なら下へ流す。
    var onReturn: (() -> Void)?
    /// フェードの世代。古いフェードの終わりで隠さないように、出し入れのたびに進める。
    private var fadeGeneration = 0
    /// 隠すフェードの途中か。
    private var isFadingOut = false

    override var canBecomeKey: Bool {
        allowsKey
    }

    override var canBecomeMain: Bool {
        false
    }

    init(level: NSWindow.Level) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        appearance = NSAppearance(named: .aqua)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape, let onCancel {
            onCancel()
            return
        }
        if event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.keypadEnter, let onReturn {
            onReturn()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// パネルが出ていて、隠す途中でもないか。
    var isShown: Bool {
        isVisible && !isFadingOut
    }

    /// 出す。`duration` が 0 ならすぐに出す。`makeKey` ならキーウィンドウにする。
    func fadeIn(duration: TimeInterval, makeKey: Bool) {
        fadeGeneration += 1
        isFadingOut = false
        let wasVisible = isVisible
        if !wasVisible {
            alphaValue = duration > 0 ? 0 : 1
        }
        if makeKey && allowsKey {
            makeKeyAndOrderFront(nil)
        } else {
            orderFrontRegardless()
        }
        guard duration > 0 else {
            alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 1
        }
    }

    /// 隠す。`duration` が 0 ならすぐに隠す。
    func fadeOut(duration: TimeInterval) {
        guard isVisible, !isFadingOut else {
            return
        }
        fadeGeneration += 1
        let generation = fadeGeneration
        guard duration > 0 else {
            orderOut(nil)
            return
        }
        isFadingOut = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                guard self.fadeGeneration == generation else {
                    return
                }
                self.isFadingOut = false
                self.orderOut(nil)
                self.alphaValue = 1
            }
        }
    }

    /// すぐに隠す。
    func hideNow() {
        fadeGeneration += 1
        isFadingOut = false
        orderOut(nil)
        alphaValue = 1
    }
}

/// 最初のクリックも受け取る `NSHostingView`。アクティブでないアプリのパネルで、ボタンを 1 回で押せるようにする。
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

/// マウスを受け取らない `NSHostingView`。枠を描く面の上の表示に使い、マウスは下の面に通す。
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// パネルの中身。影がはみ出す分の余白を足し、中身の大きさが変わったら知らせる。
struct PanelRoot<Content: View>: View {
    let content: Content
    let margin: CGFloat
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        content
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                onSizeChange(size)
            }
            .padding(margin)
            .lightAppearance()
    }
}

/// SwiftUI の部品を 1 つ載せたパネル。部品の大きさから置き場所を決め、パネルの枠を合わせる。
@MainActor final class PanelHost<Content: View> {
    let panel: FloatingPanel
    private let hostingView: FirstMouseHostingView<PanelRoot<Content>>
    private let margin: CGFloat
    private let screens: any ScreenProviding
    /// 部品の大きさから、部品の見た目の矩形（画面全体を通した左上原点）を決める。
    var placement: ((CGSize) -> ScreenRect)?
    /// 最後に置いた、部品の見た目の矩形。
    private(set) var contentFrame: ScreenRect?
    private var relayoutScheduled = false

    /// `shadows` は部品の影。はみ出す分だけパネルを広げる。
    init(content: Content, shadows: [ShadowToken], level: NSWindow.Level, allowsKey: Bool, screens: any ScreenProviding) {
        panel = FloatingPanel(level: level)
        panel.allowsKey = allowsKey
        margin = (shadows.map(\.extent).max() ?? 0) + Tokens.Stroke.hairline
        self.screens = screens
        hostingView = FirstMouseHostingView(rootView: PanelRoot(content: content, margin: margin, onSizeChange: { _ in }))
        hostingView.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hostingView
        setContent(content)
    }

    /// 中身を入れ替える。大きさが変わったら、置き場所を決め直す。
    func setContent(_ content: Content) {
        hostingView.rootView = PanelRoot(content: content, margin: margin) { [weak self] _ in
            self?.scheduleRelayout()
        }
    }

    /// 部品の大きさ（影の余白を含まない）。
    var contentSize: CGSize {
        let size = hostingView.intrinsicContentSize
        return CGSize(width: max(0, size.width - margin * 2), height: max(0, size.height - margin * 2))
    }

    /// 部品の大きさから置き場所を決め、パネルの枠を合わせる。
    func layout() {
        guard let placement else {
            return
        }
        let frame = placement(contentSize)
        contentFrame = frame
        let window = frame.expanded(by: margin)
        panel.setFrame(ScreenCoordinates.nsRect(window, primaryTop: screens.primaryTop), display: true)
    }

    private func scheduleRelayout() {
        guard !relayoutScheduled else {
            return
        }
        relayoutScheduled = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            relayoutScheduled = false
            if panel.isShown {
                layout()
            }
        }
    }
}
