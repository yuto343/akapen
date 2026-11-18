import AppKit
import SwiftUI
import AkapenCore

/// `phase` に合わせて、画面の上に浮く部品のパネルを出し入れする。
///
/// どのパネルを出すかは `PanelPlan`（`SessionViewState` から作る純粋な値）で決め、ここは出し入れと置き場所の反映だけを行う。
/// 次の状態は判断しない。入力は `SessionEvent` にして送るだけ。
///
/// ボタン類が出ているあいだは、画面全体を覆う面がマウスを受け、カーソルを十字にする（下のアプリは操作できない）。
/// `drawing` と `listOpen` のあいだは、`⌘C`（Copy prompt）と `⌘L`（一覧の開閉）を、キーになっているパネルで受ける。
@MainActor public final class SessionWindows {
    private let model: SessionModel?
    private let send: (SessionEvent) -> Void
    private let screens: any ScreenProviding
    private let fadeDuration: TimeInterval
    private let timeZone: TimeZone
    private let thumbnails: any ThumbnailProviding

    /// 画面全体を覆う面。ボタン類が出ているあいだマウスを受け、`drawing` のときだけ枠を描く。
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
    /// この回で部品を出している画面。部品を出し始めた時点でカーソルがある画面に決め、出しているあいだは変えない。
    private(set) var screen: ScreenInfo?
    /// 面の上の表示。
    private(set) var overlay: OverlayState?
    /// 面の上の案内を出しているか。面を出した直後は false にして、前に出してから動きを付けて出す。
    private var isHintPresented = true

    private static let overlayLevel = NSWindow.Level.floating
    private static let panelLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    /// 面を出したあとに、十字のカーソルを当て直す間隔（秒）。窓が画面に出る前に当てた分が効かないことがあるため。
    private static let crosshairRetryDelays: [TimeInterval] = [0.05, 0.15, 0.3]

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

    /// テスト用。画面・フェードの長さ・時刻のタイムゾーン・サムネイルを差し替えられる。
    /// `fadeDuration` が 0 なら、出し入れに動きを付けない（すぐに出し、すぐに隠す）。
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
        let animated = fadeDuration > 0
        overlayPanel = FloatingPanel(level: Self.overlayLevel)
        overlayPanel.allowsKey = false
        overlayPanel.backgroundColor = Tokens.Surface.background.nsColor
        overlayPanel.ignoresMouseEvents = true
        surface = DrawingSurface(frame: .zero)
        overlayHost = PassthroughHostingView(rootView: OverlayView(
            state: OverlayState(screen: Self.placeholderScreen, showsHint: false),
            strings: strings,
            animated: animated
        ))
        overlayHost.sizingOptions = []
        overlayHost.autoresizingMask = [.width, .height]
        surface.addSubview(overlayHost)
        overlayPanel.contentView = surface
        commentEditor = CommentView.makeEditor()
        listEditing = ListEditingController()
        toolbar = PanelHost(
            content: ToolbarView(state: ToolbarState(annotationCount: 0, isListOpen: false), strings: strings, onList: {}, onCopy: {}),
            shadows: Tokens.Toolbar.shadows,
            level: Self.panelLevel,
            allowsKey: false,
            screens: screens,
            entrance: .scale(anchor: .bottom),
            animatesEntrance: animated
        )
        comment = PanelHost(
            content: CommentView(editor: commentEditor, confirmKey: .enter, strings: strings),
            shadows: Tokens.Comment.shadows,
            level: Self.panelLevel,
            allowsKey: true,
            screens: screens,
            entrance: .scale(anchor: .top),
            animatesEntrance: animated
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
            screens: screens,
            entrance: .scale(anchor: .bottom),
            animatesEntrance: animated
        )
        copied = PanelHost(
            content: CopiedView(count: 0, strings: strings),
            shadows: Tokens.Toast.shadows,
            level: Self.panelLevel,
            allowsKey: false,
            screens: screens,
            entrance: .content,
            animatesEntrance: animated
        )
        copied.panel.ignoresMouseEvents = true
        connectInputs()
        connectOverlayPresentation()
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
            let wasCovering = previous.map { PanelPlan($0).coversScreen } ?? false
            hideAll(duration: fadeDuration)
            if wasCovering {
                // 面を外したら、カーソルを普通の矢印に戻す。
                NSCursor.arrow.set()
            }
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
        renderOverlay(plan, screen: screen, strings: strings, enteringDrawing: entering(.drawing))
        let toolbarFrame = renderToolbar(plan, state: state, screen: screen, strings: strings)
        renderCopied(plan, state: state, screen: screen, strings: strings)
        renderList(plan, state: state, screen: screen, strings: strings, toolbarFrame: toolbarFrame, entering: entering(.listOpen))
        renderComment(plan, state: state, screen: screen, strings: strings, entering: entering(.commenting))
        if plan.acceptsDrawing && entering(.drawing) {
            showCrosshair()
        }
    }

    /// すべてのパネルをすぐに外す。終了処理とテストの後始末。
    public func hide() {
        for panel in panels {
            panel.hideNow()
        }
        overlayPanel.ignoresMouseEvents = true
        overlayPanel.allowsKey = false
        listEditing.end()
        surface.reset()
        overlay = nil
        screen = nil
        state = nil
    }

    /// キー入力を、いまの状態で受け取るべきパネルに戻す（終了の確認など、ほかのパネルがキーを取ったあと）。
    /// `drawing` なら覆う面（`Esc`・`⌘C`・`⌘L`）、`commenting` ならコメントの入力欄、`listOpen` なら一覧。
    public func restoreFocus() {
        switch state?.phase {
        case .drawing:
            guard overlayPanel.isShown else {
                return
            }
            overlayPanel.makeKeyAndOrderFront(nil)
            overlayPanel.makeFirstResponder(surface)
        case .commenting:
            guard comment.panel.isShown else {
                return
            }
            comment.panel.makeKeyAndOrderFront(nil)
            commentEditor.focus()
        case .listOpen:
            guard list.panel.isShown else {
                return
            }
            list.panel.makeKeyAndOrderFront(nil)
        case .hidden, .copied, nil:
            break
        }
    }

    /// 枠を描く面が、枠を描く入力を受け取っているか。
    var acceptsDrawing: Bool {
        overlayPanel.isShown && !overlayPanel.ignoresMouseEvents && state?.phase == .drawing
    }

    /// 画面全体を覆う面が出ていて、マウスを受けているか（下のアプリを操作できない）。
    var coversScreen: Bool {
        overlayPanel.isShown && !overlayPanel.ignoresMouseEvents
    }

    /// 面に描いている表示（テスト用）。面を隠し終えたら、赤枠も案内もない空の表示に戻る。
    var overlayViewState: OverlayState {
        overlayHost.rootView.state
    }

    private var panels: [FloatingPanel] {
        [overlayPanel, toolbar.panel, comment.panel, list.panel, copied.panel]
    }

    private static let placeholderScreen = ScreenInfo(
        id: 0,
        frame: ScreenRect(x: 0, y: 0, width: 0, height: 0),
        visibleFrame: ScreenRect(x: 0, y: 0, width: 0, height: 0)
    )

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
        overlayPanel.onKeyEquivalent = { [weak self] event in
            self?.handleShortcut(event) ?? false
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
        list.panel.onKeyEquivalent = { [weak self] event in
            self?.handleShortcut(event) ?? false
        }
        listEditing.onSave = { [weak self] id, text in
            self?.send(.annotationEdited(id: id, text: text))
        }
    }

    /// ボタン類のショートカット（`⌘C` で Copy prompt、`⌘L` で一覧の開閉）。
    ///
    /// ボタン類が出ていて、コメントを書いていないとき（`drawing` と、一覧で編集していない `listOpen`）だけ受ける。
    /// 一覧でコメントを編集しているあいだは、入力欄のふつうの `⌘C`（文字のコピー）に任せる。
    func handleShortcut(_ event: NSEvent) -> Bool {
        guard let phase = state?.phase else {
            return false
        }
        switch phase {
        case .drawing:
            break
        case .listOpen:
            guard listEditing.editingID == nil else {
                return false
            }
        case .hidden, .commenting, .copied:
            return false
        }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else {
            return false
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c":
            send(.copyPromptTapped)
            return true
        case "l":
            send(.listToggled)
            return true
        default:
            return false
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

    // MARK: - カーソル

    /// 十字のカーソルにする。窓が画面に出る前に当てた分が効かないことがあるので、少しあとにも当て直す。
    ///
    /// アクティブでないアプリのカーソルを効かせる許可（`AkapenPlatform` の `BackgroundCursor`）は、組み立ての側で取る。
    /// 許可がなくても、マウスを動かせば面の追跡領域が十字にする。
    private func showCrosshair() {
        setCrosshairIfOverSurface()
        for delay in Self.crosshairRetryDelays {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                self?.setCrosshairIfOverSurface()
            }
        }
    }

    /// カーソルが面の上（ボタン類などのパネルの上でない所）にあれば、十字にする。
    private func setCrosshairIfOverSurface() {
        guard coversScreen else {
            return
        }
        let location = NSEvent.mouseLocation
        let number = NSWindow.windowNumber(at: location, belowWindowWithWindowNumber: 0)
        guard number == overlayPanel.windowNumber else {
            return
        }
        NSCursor.crosshair.set()
    }

    // MARK: - 画面

    private func chooseScreen(for state: SessionViewState, previous: SessionViewState?) {
        let available = screens.screens
        let previousPhase = previous?.phase ?? .hidden
        let startsShowing = previousPhase == .hidden || (state.phase == .drawing && previousPhase == .copied)
        if startsShowing || screen == nil {
            screen = ScreenInfo.containing(screens.mouseLocation, in: available)
            return
        }
        if let current = screen {
            screen = available.first { $0.id == current.id } ?? ScreenInfo.containing(screens.mouseLocation, in: available)
        }
    }

    // MARK: - パネルごとの反映

    private func renderOverlay(_ plan: PanelPlan, screen: ScreenInfo, strings: UIStrings, enteringDrawing: Bool) {
        guard plan.coversScreen else {
            overlayPanel.ignoresMouseEvents = true
            overlayPanel.allowsKey = false
            overlayPanel.fadeOut(duration: fadeDuration)
            return
        }
        if enteringDrawing || overlay == nil || overlay?.screen != screen {
            // 枠を描く状態に入るたびに、前の枠を消した空の面から始める。
            surface.reset()
            overlay = OverlayState(screen: screen, showsHint: false)
        }
        if !plan.acceptsDrawing {
            overlay?.frame = plan.pinnedFrame
            overlay?.cursor = nil
        }
        overlay?.showsHint = plan.acceptsDrawing || plan.notice != nil
        overlay?.showsCancel = plan.acceptsDrawing
        overlay?.notice = plan.notice
        overlayPanel.allowsKey = plan.acceptsDrawing
        overlayPanel.ignoresMouseEvents = false
        overlayPanel.setFrame(ScreenCoordinates.nsRect(screen.frame, primaryTop: screens.primaryTop), display: false)
        surface.frame = NSRect(origin: .zero, size: overlayPanel.frame.size)
        updateOverlayView(strings: strings)
        let makeKey = plan.acceptsDrawing && enteringDrawing
        if makeKey || !overlayPanel.isShown {
            overlayPanel.fadeIn(duration: fadeDuration, makeKey: plan.acceptsDrawing)
        }
        if makeKey {
            overlayPanel.makeFirstResponder(surface)
        }
    }

    /// 面を出す直前に案内を隠しておき、前に出してから動きを付けて出す。隠し終えたら、空の表示に戻す。
    private func connectOverlayPresentation() {
        overlayPanel.onWillPresent = { [weak self] in
            guard let self, fadeDuration > 0 else {
                return
            }
            isHintPresented = false
            updateOverlayView()
        }
        overlayPanel.onDidPresent = { [weak self] in
            guard let self, !isHintPresented else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                isHintPresented = true
                updateOverlayView()
            }
        }
        overlayPanel.onDidHide = { [weak self] in
            self?.clearOverlayView()
        }
    }

    private func updateOverlayView(strings: UIStrings? = nil) {
        guard var shown = overlay else {
            return
        }
        shown.showsHint = shown.showsHint && isHintPresented
        overlayHost.rootView = OverlayView(
            state: shown,
            strings: strings ?? UIStrings(language: state?.language ?? .en),
            animated: fadeDuration > 0
        )
    }

    /// 面の表示を、赤枠も案内もない空の表示にする（動きは付けない）。次に面を出したとき、前の枠が一瞬見えないように。
    private func clearOverlayView() {
        let screen = overlayHost.rootView.state.screen
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            overlayHost.rootView = OverlayView(
                state: OverlayState(screen: screen, showsHint: false),
                strings: UIStrings(language: state?.language ?? .en),
                animated: false
            )
        }
        overlayHost.layoutSubtreeIfNeeded()
    }

    private func renderToolbar(_ plan: PanelPlan, state: SessionViewState, screen: ScreenInfo, strings: UIStrings) -> ScreenRect {
        toolbar.setContent(ToolbarView(
            state: ToolbarState(annotationCount: state.annotations.count, isListOpen: state.phase == .listOpen),
            strings: strings,
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
        overlayPanel.allowsKey = false
        for panel in panels {
            panel.fadeOut(duration: duration)
        }
        listEditing.end()
        surface.reset()
        overlay = nil
        screen = nil
    }
}
