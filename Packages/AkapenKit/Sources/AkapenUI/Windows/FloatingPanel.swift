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

    /// 前に出す直前（まだ画面に出ていないとき）。中身を、出しはじめの見た目にしておく。
    var onWillPresent: (() -> Void)?
    /// 前に出した直後（まだ画面に出ていなかったとき）。中身の出る動きを始める。
    var onDidPresent: (() -> Void)?
    /// 隠し終えたとき。前の中身が次に出したときに一瞬見えないように、中身を空にする。
    var onDidHide: (() -> Void)?
    /// `Command` つきのキー（`⌘C` など）が押されたとき。true を返すと、そのキーを使ったことにする。
    var onKeyEquivalent: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let onKeyEquivalent, onKeyEquivalent(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// 出す。`makeKey` ならキーウィンドウにする。
    ///
    /// まだ出ていなければ、中身を描き終えてから前に出す（前の中身が一瞬見えないように）。
    /// 窓の不透明度は 1 のまま出し、出る動きは中身（`PanelRoot`）が受け持つ。`duration` が 0 なら動かさない。
    func fadeIn(duration: TimeInterval, makeKey: Bool) {
        fadeGeneration += 1
        isFadingOut = false
        let wasVisible = isVisible
        if !wasVisible {
            onWillPresent?()
            contentView?.layoutSubtreeIfNeeded()
            contentView?.displayIfNeeded()
        }
        alphaValue = 1
        if makeKey && allowsKey {
            makeKeyAndOrderFront(nil)
        } else {
            orderFrontRegardless()
        }
        if !wasVisible {
            onDidPresent?()
        }
    }

    /// 隠す。`duration` が 0 ならすぐに隠す。消えるときは不透明度だけを速めに下げる。
    func fadeOut(duration: TimeInterval) {
        guard isVisible, !isFadingOut else {
            return
        }
        fadeGeneration += 1
        let generation = fadeGeneration
        guard duration > 0 else {
            finishHiding()
            return
        }
        isFadingOut = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                guard self.fadeGeneration == generation else {
                    return
                }
                self.finishHiding()
            }
        }
    }

    /// すぐに隠す。
    func hideNow() {
        fadeGeneration += 1
        finishHiding()
    }

    private func finishHiding() {
        isFadingOut = false
        orderOut(nil)
        alphaValue = 1
        onDidHide?()
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

/// パネルの出る動き。
enum PanelEntrance: Equatable {
    /// わずかに小さい大きさから、`anchor` を起点に等倍へ（コメント入力・一覧・ボタン類）。
    case scale(anchor: UnitPoint)
    /// 少し下から浮き上がる（コピー完了の表示）。
    case rise
}

/// パネルの中身が出ているか。`PanelHost` が切り替え、`PanelRoot` が見た目に映す。
@MainActor @Observable final class PanelPresentation {
    var isPresented = true
}

/// パネルの中身。影がはみ出す分の余白を足し、中身の大きさが変わったら知らせる。出る動きもここで付ける。
struct PanelRoot<Content: View>: View {
    let content: Content
    let margin: CGFloat
    let entrance: PanelEntrance
    let presentation: PanelPresentation
    let onSizeChange: (CGSize) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                onSizeChange(size)
            }
            .opacity(presentation.isPresented ? 1 : 0)
            .scaleEffect(scale, anchor: anchor)
            .offset(y: offset)
            .padding(margin)
            .lightAppearance()
    }

    private var scale: CGFloat {
        guard !presentation.isPresented, !reduceMotion, case .scale = entrance else {
            return 1
        }
        return Tokens.Motion.panelEntranceScale
    }

    private var anchor: UnitPoint {
        if case let .scale(anchor) = entrance {
            return anchor
        }
        return .center
    }

    private var offset: CGFloat {
        guard !presentation.isPresented, !reduceMotion, entrance == .rise else {
            return 0
        }
        return Tokens.Motion.toastRise
    }
}

/// SwiftUI の部品を 1 つ載せたパネル。部品の大きさから置き場所を決め、パネルの枠を合わせる。
@MainActor final class PanelHost<Content: View> {
    let panel: FloatingPanel
    private let hostingView: FirstMouseHostingView<PanelRoot<Content>>
    private let margin: CGFloat
    private let screens: any ScreenProviding
    private let entrance: PanelEntrance
    private let presentation = PanelPresentation()
    /// 出る動きを付けるか。false なら（テスト）すぐに出す。
    var animatesEntrance: Bool
    /// 部品の大きさから、部品の見た目の矩形（画面全体を通した左上原点）を決める。
    var placement: ((CGSize) -> ScreenRect)?
    /// 最後に置いた、部品の見た目の矩形。
    private(set) var contentFrame: ScreenRect?
    private var relayoutScheduled = false

    /// `shadows` は部品の影。はみ出す分だけパネルを広げる。
    init(
        content: Content,
        shadows: [ShadowToken],
        level: NSWindow.Level,
        allowsKey: Bool,
        screens: any ScreenProviding,
        entrance: PanelEntrance,
        animatesEntrance: Bool
    ) {
        panel = FloatingPanel(level: level)
        panel.allowsKey = allowsKey
        margin = (shadows.map(\.extent).max() ?? 0) + Tokens.Stroke.hairline
        self.screens = screens
        self.entrance = entrance
        self.animatesEntrance = animatesEntrance
        hostingView = FirstMouseHostingView(rootView: PanelRoot(
            content: content,
            margin: margin,
            entrance: entrance,
            presentation: presentation,
            onSizeChange: { _ in }
        ))
        hostingView.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hostingView
        setContent(content)
        connectPresentation()
    }

    /// 中身を入れ替える。大きさが変わったら、置き場所を決め直す。
    func setContent(_ content: Content) {
        hostingView.rootView = PanelRoot(content: content, margin: margin, entrance: entrance, presentation: presentation) { [weak self] _ in
            self?.scheduleRelayout()
        }
    }

    /// 中身が出ている見た目か（出る動きの途中を含む）。テスト用。
    var isContentPresented: Bool {
        presentation.isPresented
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

    /// 出しはじめは見えない状態で描き、前に出してから、ばねで出す。隠し終えたら、次に出すときのために見えない状態へ戻す。
    private func connectPresentation() {
        panel.onWillPresent = { [weak self] in
            guard let self, animatesEntrance else {
                return
            }
            setPresented(false, animation: nil)
        }
        panel.onDidPresent = { [weak self] in
            guard let self else {
                return
            }
            guard animatesEntrance else {
                setPresented(true, animation: nil)
                return
            }
            // 見えない状態が画面に出てから動かし始める。
            Task { @MainActor [weak self] in
                self?.setPresented(true, animation: Tokens.Motion.panelSpring)
            }
        }
        panel.onDidHide = { [weak self] in
            guard let self, animatesEntrance else {
                return
            }
            setPresented(false, animation: nil)
        }
    }

    private func setPresented(_ presented: Bool, animation: Animation?) {
        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = animation == nil
        withTransaction(transaction) {
            presentation.isPresented = presented
        }
        if animation == nil {
            hostingView.layoutSubtreeIfNeeded()
        }
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
