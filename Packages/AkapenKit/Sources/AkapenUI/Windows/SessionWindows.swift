import AppKit
import SwiftUI
import AkapenCore

/// `phase` と `isToolbarVisible` に合わせて、画面の上に浮く部品のパネルを出し入れする。
///
/// どのパネルを出すかは `PanelPlan`（`SessionViewState` から作る純粋な値）で決め、ここは出し入れと置き場所の反映だけを行う。
/// 次の状態は判断しない。入力は `SessionEvent` にして送るだけ。
@MainActor public final class SessionWindows {
    private let model: SessionModel?
    private let send: (SessionEvent) -> Void
    private let screens: any ScreenProviding
    private let fadeDuration: TimeInterval
    private let timeZone: TimeZone
    private let thumbnails: any ThumbnailProviding

    /// 枠を描く面（画面全体を覆う）。`drawing` のときだけマウスを受け取る。
    let overlayPanel: FloatingPanel
    let surface: DrawingSurface
    private let overlayHost: PassthroughHostingView<OverlayView>
    let toolbar: PanelHost<ToolbarView>
    let comment: PanelHost<CommentView>
    let list: PanelHost<ListView>
    let copied: PanelHost<CopiedView>
    let commentEditor: GrowingTextController
    let listEditing: ListEditingController

    /// 最後に映した値。
    private(set) var state: SessionViewState?
    /// この回で部品を出している画面。`drawing` に入った時点（回の始まり）でカーソルがある画面に決め、回のあいだは変えない。
    private(set) var screen: ScreenInfo?
    /// 面の上の表示。
    private(set) var overlay: OverlayState?

    private static let overlayLevel = NSWindow.Level.floating
    private static let panelLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)

    /// `model` の状態を映す。押された操作は `model` に送る。
    public convenience init(model: SessionModel) {
        self.init(
            model: model,
            send: { [weak model] event in
                model?.send(event)
            },
            screens: SystemScreens(),
            fadeDuration: Tokens.Motion.fade,
            timeZone: .current,
            thumbnails: FileThumbnailProvider()
        )
    }

    /// テスト用。画面・フェードの長さ・時刻のタイムゾーン・サムネイルを差し替えられる。`fadeDuration` が 0 ならフェードしない。
    init(
        model: SessionModel? = nil,
        send: @escaping (SessionEvent) -> Void,
        screens: any ScreenProviding,
        fadeDuration: TimeInterval,
        timeZone: TimeZone,
        thumbnails: any ThumbnailProviding
    ) {
        self.model = model
        self.send = send
        self.screens = screens
        self.fadeDuration = fadeDuration
        self.timeZone = timeZone
        self.thumbnails = thumbnails
        let strings = UIStrings(language: .en)
        let placeholderScreen = ScreenInfo(
            id: 0,
            frame: ScreenRect(x: 0, y: 0, width: 0, height: 0),
            visibleFrame: ScreenRect(x: 0, y: 0, width: 0, height: 0)
        )
        overlayPanel = FloatingPanel(level: Self.overlayLevel)
        overlayPanel.allowsKey = true
        overlayPanel.backgroundColor = Tokens.Surface.background.nsColor
        overlayPanel.ignoresMouseEvents = true
        surface = DrawingSurface(frame: .zero)
        overlayHost = PassthroughHostingView(rootView: OverlayView(
            state: OverlayState(screen: placeholderScreen, showsHint: false),
            strings: strings,
            animated: fadeDuration > 0
        ))
        overlayHost.sizingOptions = []
        overlayHost.autoresizingMask = [.width, .height]
        surface.addSubview(overlayHost)
        overlayPanel.contentView = surface
        commentEditor = CommentView.makeEditor()
        listEditing = ListEditingController()
        toolbar = PanelHost(
            content: ToolbarView(state: ToolbarState(annotationCount: 0, isListOpen: false), strings: strings, onAdd: {}, onList: {}, onCopy: {}),
            shadows: Tokens.Toolbar.shadows,
            level: Self.panelLevel,
            allowsKey: false,
            screens: screens
        )
        comment = PanelHost(
            content: CommentView(editor: commentEditor, confirmKey: .enter, strings: strings),
            shadows: Tokens.Comment.shadows,
            level: Self.panelLevel,
            allowsKey: true,
            screens: screens
        )
        list = PanelHost(
            content: ListView(
                annotations: [],
                retentionDays: 0,
                confirmKey: .enter,
                strings: strings,
                timeZone: timeZone,
                editing: listEditing,
                thumbnails: thumbnails,
                onDelete: { _ in }
            ),
            shadows: Tokens.List.shadows,
            level: Self.panelLevel,
            allowsKey: true,
            screens: screens
        )
        copied = PanelHost(
            content: CopiedView(count: 0, strings: strings),
            shadows: Tokens.Toast.shadows,
            level: Self.panelLevel,
            allowsKey: false,
            screens: screens
        )
        copied.panel.ignoresMouseEvents = true
        connectInputs()
    }

    /// いまの `SessionModel` の状態を映す。
    public func render() {
        guard let model else {
            return
        }
        render(SessionViewState(model: model))
    }

    /// 値を映す。同じ値で何度呼んでもよい。
    public func render(_ state: SessionViewState) {
        let previous = self.state
        self.state = state
        guard state.phase != .hidden else {
            hideAll(duration: fadeDuration)
            return
        }
        chooseScreen(for: state, previous: previous)
        guard let screen else {
            return
        }
        thumbnails.retain(state.annotations)
        let plan = PanelPlan(state)
        let strings = UIStrings(language: state.language)
        let entering = { (phase: Phase) in
            state.phase == phase && previous?.phase != phase
        }
        renderOverlay(plan, screen: screen, strings: strings, entering: entering(.drawing))
        let toolbarFrame = renderToolbar(plan, state: state, screen: screen, strings: strings)
        renderCopied(plan, state: state, screen: screen, strings: strings)
        renderList(plan, state: state, screen: screen, strings: strings, toolbarFrame: toolbarFrame, entering: entering(.listOpen))
        renderComment(plan, state: state, screen: screen, strings: strings, entering: entering(.commenting))
    }

    /// すべてのパネルをすぐに外す。終了処理とテストの後始末。
    public func hide() {
        for panel in panels {
            panel.hideNow()
        }
        overlayPanel.ignoresMouseEvents = true
        listEditing.end()
        surface.reset()
        overlay = nil
        screen = nil
        state = nil
    }

    /// 枠を描く面がマウスを受け取っているか。
    var acceptsDrawing: Bool {
        overlayPanel.isShown && !overlayPanel.ignoresMouseEvents
    }

    private var panels: [FloatingPanel] {
        [overlayPanel, toolbar.panel, comment.panel, list.panel, copied.panel]
    }

    // MARK: - 入力

    private func connectInputs() {
        surface.onDrag = { [weak self] start, current in
            self?.dragChanged(from: start, to: current)
        }
        surface.onDragEnded = { [weak self] start, end in
            self?.dragEnded(from: start, to: end)
        }
        surface.onEscape = { [weak self] in
            self?.send(.escapePressed)
        }
        overlayPanel.onCancel = { [weak self] in
            self?.send(.escapePressed)
        }
        commentEditor.textView.onConfirm = { [weak self] text in
            self?.send(.commentConfirmed(text: text))
        }
        commentEditor.textView.onCancel = { [weak self] in
            self?.send(.commentCancelled)
        }
        comment.panel.onCancel = { [weak self] in
            self?.send(.commentCancelled)
        }
        list.panel.onCancel = { [weak self] in
            self?.send(.escapePressed)
        }
        listEditing.onSave = { [weak self] id, text in
            self?.send(.annotationEdited(id: id, text: text))
        }
    }

    private func dragChanged(from start: CGPoint, to current: CGPoint) {
        guard state?.phase == .drawing, var overlay else {
            return
        }
        // 描き始めたら、前の失敗の知らせは元の案内に戻す（`DECISIONS.md` A9）。
        overlay.notice = nil
        overlay.frame = globalRect(from: start, to: current, on: overlay.screen)
        overlay.cursor = globalPoint(current, on: overlay.screen)
        self.overlay = overlay
        updateOverlayView()
    }

    private func dragEnded(from start: CGPoint, to end: CGPoint) {
        guard state?.phase == .drawing, var overlay else {
            return
        }
        let rect = globalRect(from: start, to: end, on: overlay.screen)
        overlay.frame = rect
        overlay.cursor = nil
        self.overlay = overlay
        updateOverlayView()
        guard rect.width > 0, rect.height > 0 else {
            return
        }
        send(.dragEnded(rect: rect, screen: overlay.screen.descriptor))
    }

    /// 面の中の座標（面の左上が原点）を、画面全体を通した座標にする。
    private func globalPoint(_ point: CGPoint, on screen: ScreenInfo) -> CGPoint {
        CGPoint(x: screen.frame.x + point.x, y: screen.frame.y + point.y)
    }

    private func globalRect(from start: CGPoint, to end: CGPoint, on screen: ScreenInfo) -> ScreenRect {
        let first = globalPoint(start, on: screen)
        let second = globalPoint(end, on: screen)
        return ScreenRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(second.x - first.x),
            height: abs(second.y - first.y)
        )
    }

    // MARK: - 画面

    private func chooseScreen(for state: SessionViewState, previous: SessionViewState?) {
        let available = screens.screens
        let previousPhase = previous?.phase ?? .hidden
        let startsSession = previousPhase == .hidden || (state.phase == .drawing && previousPhase == .copied)
        if startsSession || screen == nil {
            screen = ScreenInfo.containing(screens.mouseLocation, in: available)
            return
        }
        if let current = screen {
            screen = available.first { $0.id == current.id } ?? ScreenInfo.containing(screens.mouseLocation, in: available)
        }
    }

    // MARK: - パネルごとの反映

    private func renderOverlay(_ plan: PanelPlan, screen: ScreenInfo, strings: UIStrings, entering: Bool) {
        if plan.acceptsDrawing {
            if entering || overlay == nil {
                surface.reset()
                overlay = OverlayState(screen: screen, showsHint: true)
            }
            overlay?.showsHint = true
            overlay?.showsCancel = true
            overlay?.notice = plan.notice
            showOverlay(on: screen, strings: strings, acceptsMouse: true, makeKey: entering)
        } else if let frame = plan.pinnedFrame {
            overlay = OverlayState(screen: screen, showsHint: false, frame: frame)
            showOverlay(on: screen, strings: strings, acceptsMouse: false, makeKey: false)
        } else if let notice = plan.notice {
            // ボタン類だけが出ている状態での失敗は、マウスを受け取らない面の上端の案内で知らせる。
            overlay = OverlayState(screen: screen, showsHint: true, notice: notice, showsCancel: false)
            showOverlay(on: screen, strings: strings, acceptsMouse: false, makeKey: false)
        } else {
            overlayPanel.ignoresMouseEvents = true
            overlayPanel.fadeOut(duration: fadeDuration)
        }
    }

    private func showOverlay(on screen: ScreenInfo, strings: UIStrings, acceptsMouse: Bool, makeKey: Bool) {
        overlayPanel.ignoresMouseEvents = !acceptsMouse
        overlayPanel.setFrame(ScreenCoordinates.nsRect(screen.frame, primaryTop: screens.primaryTop), display: false)
        surface.frame = NSRect(origin: .zero, size: overlayPanel.frame.size)
        updateOverlayView(strings: strings)
        if makeKey || !overlayPanel.isShown {
            overlayPanel.fadeIn(duration: fadeDuration, makeKey: acceptsMouse)
        }
        if acceptsMouse && makeKey {
            overlayPanel.makeFirstResponder(surface)
            NSCursor.crosshair.set()
        }
    }

    private func updateOverlayView(strings: UIStrings? = nil) {
        guard let overlay else {
            return
        }
        overlayHost.rootView = OverlayView(
            state: overlay,
            strings: strings ?? UIStrings(language: state?.language ?? .en),
            animated: fadeDuration > 0
        )
    }

    private func renderToolbar(_ plan: PanelPlan, state: SessionViewState, screen: ScreenInfo, strings: UIStrings) -> ScreenRect {
        toolbar.setContent(ToolbarView(
            state: ToolbarState(annotationCount: state.annotations.count, isListOpen: state.phase == .listOpen),
            strings: strings,
            onAdd: { [weak self] in
                self?.send(.addTapped)
            },
            onList: { [weak self] in
                self?.send(.listToggled)
            },
            onCopy: { [weak self] in
                self?.send(.copyPromptTapped)
            }
        ))
        let visibleFrame = screen.visibleFrame
        toolbar.placement = { size in
            PanelPlacement.bottomCenter(size: size, visibleFrame: visibleFrame)
        }
        let frame = PanelPlacement.bottomCenter(size: toolbar.contentSize, visibleFrame: visibleFrame)
        if plan.toolbar {
            toolbar.layout()
            toolbar.panel.fadeIn(duration: fadeDuration, makeKey: false)
        } else {
            toolbar.panel.fadeOut(duration: fadeDuration)
        }
        return frame
    }

    private func renderComment(_ plan: PanelPlan, state: SessionViewState, screen: ScreenInfo, strings: UIStrings, entering: Bool) {
        guard plan.comment else {
            comment.panel.fadeOut(duration: fadeDuration)
            return
        }
        if entering {
            commentEditor.setText("")
        }
        commentEditor.setConfirmKey(state.confirmKey)
        commentEditor.setPlaceholder(strings[.commentPlaceholder])
        comment.setContent(CommentView(editor: commentEditor, confirmKey: state.confirmKey, strings: strings))
        let visibleFrame = screen.visibleFrame
        let anchor = plan.pinnedFrame ?? ScreenRect(x: visibleFrame.centerX, y: visibleFrame.centerY, width: 0, height: 0)
        comment.placement = { size in
            PanelPlacement.comment(size: size, frame: anchor, visibleFrame: visibleFrame)
        }
        comment.layout()
        if entering || !comment.panel.isShown {
            comment.panel.fadeIn(duration: fadeDuration, makeKey: true)
            commentEditor.focus()
        }
    }

    private func renderList(
        _ plan: PanelPlan,
        state: SessionViewState,
        screen: ScreenInfo,
        strings: UIStrings,
        toolbarFrame: ScreenRect,
        entering: Bool
    ) {
        guard plan.list else {
            listEditing.end()
            list.panel.fadeOut(duration: fadeDuration)
            return
        }
        if entering {
            listEditing.end()
        }
        if let editing = listEditing.editingID, !state.annotations.contains(where: { $0.id == editing }) {
            listEditing.end()
        }
        listEditing.editor.setConfirmKey(state.confirmKey)
        list.setContent(ListView(
            annotations: state.annotations,
            retentionDays: state.imageRetentionDays,
            confirmKey: state.confirmKey,
            strings: strings,
            timeZone: timeZone,
            editing: listEditing,
            thumbnails: thumbnails,
            onDelete: { [weak self] id in
                self?.send(.annotationDeleted(id: id))
            }
        ))
        let visibleFrame = screen.visibleFrame
        list.placement = { size in
            PanelPlacement.list(size: size, toolbar: toolbarFrame, visibleFrame: visibleFrame)
        }
        list.layout()
        if entering || !list.panel.isShown {
            list.panel.fadeIn(duration: fadeDuration, makeKey: true)
        }
    }

    private func renderCopied(_ plan: PanelPlan, state: SessionViewState, screen: ScreenInfo, strings: UIStrings) {
        guard plan.copied else {
            copied.panel.fadeOut(duration: fadeDuration)
            return
        }
        copied.setContent(CopiedView(count: state.lastCopiedCount, strings: strings))
        let visibleFrame = screen.visibleFrame
        copied.placement = { size in
            PanelPlacement.bottomCenter(size: size, visibleFrame: visibleFrame)
        }
        copied.layout()
        copied.panel.fadeIn(duration: fadeDuration, makeKey: false)
    }

    private func hideAll(duration: TimeInterval) {
        overlayPanel.ignoresMouseEvents = true
        for panel in panels {
            panel.fadeOut(duration: duration)
        }
        listEditing.end()
        surface.reset()
        overlay = nil
        screen = nil
    }
}
