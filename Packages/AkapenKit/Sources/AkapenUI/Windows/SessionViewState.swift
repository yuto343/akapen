import AkapenCore

/// 画面に映す値。`SessionModel` から作る。パネルの出し入れはこの値だけで決める。
///
/// テストは `SessionModel` に入力を送らずに、この値を直接作って `SessionWindows.render(_:)` に渡す。
public struct SessionViewState: Equatable, Sendable {
    public var phase: Phase
    /// ボタン類を出すか（`SessionModel.isToolbarVisible`）。
    public var isToolbarVisible: Bool
    /// 確定済みの注釈。
    public var annotations: [Annotation]
    /// コメントを書いている間に出しておく赤枠。
    public var draftRect: ScreenRect?
    /// 直前にコピーした注釈の件数。
    public var lastCopiedCount: Int
    public var language: Language
    public var confirmKey: ConfirmKey
    /// 画像を残す日数（一覧のフッター）。
    public var imageRetentionDays: Int
    /// 直前の操作の失敗（`SessionModel.lastFailure`）。案内の表示で知らせる。
    public var failure: SessionFailure?

    /// 値をそのまま持つ。設定の値の既定は `Settings()` と同じ。
    public init(
        phase: Phase,
        isToolbarVisible: Bool,
        annotations: [Annotation] = [],
        draftRect: ScreenRect? = nil,
        lastCopiedCount: Int = 0,
        language: Language = Settings().language,
        confirmKey: ConfirmKey = Settings().confirmKey,
        imageRetentionDays: Int = Settings().imageRetentionDays,
        failure: SessionFailure? = nil
    ) {
        self.phase = phase
        self.isToolbarVisible = isToolbarVisible
        self.annotations = annotations
        self.draftRect = draftRect
        self.lastCopiedCount = lastCopiedCount
        self.language = language
        self.confirmKey = confirmKey
        self.imageRetentionDays = imageRetentionDays
        self.failure = failure
    }

    /// `SessionModel` のいまの状態から作る。赤枠は書きかけの注釈の枠（なければ最後に描いた枠）。
    @MainActor public init(model: SessionModel) {
        self.init(
            phase: model.phase,
            isToolbarVisible: model.isToolbarVisible,
            annotations: model.annotations,
            draftRect: model.phase == .commenting ? (model.draft?.rect ?? model.lastDrawnRect) : nil,
            lastCopiedCount: model.lastCopiedCount,
            language: model.settings.language,
            confirmKey: model.settings.confirmKey,
            imageRetentionDays: model.settings.imageRetentionDays,
            failure: model.lastFailure
        )
    }
}

/// どのパネルを出すか。`SessionViewState` から作る純粋な値。
struct PanelPlan: Equatable {
    /// 枠を描く面がマウスを受け取るか（`drawing` のときだけ）。
    var acceptsDrawing: Bool
    /// コメントを書いている間に出しておく赤枠。面はマウスを受け取らない。
    var pinnedFrame: ScreenRect?
    var toolbar: Bool
    var comment: Bool
    var list: Bool
    var copied: Bool
    /// 案内の表示で知らせる失敗。`drawing` では撮影の失敗、`idle` と `listOpen` ではコピーと設定の保存の失敗。
    var notice: SessionFailure?

    /// 面（赤枠や案内を描く全画面のパネル）を出すか。
    var showsOverlay: Bool {
        acceptsDrawing || pinnedFrame != nil || notice != nil
    }

    /// 何も出さない。
    static let none = PanelPlan(
        acceptsDrawing: false,
        pinnedFrame: nil,
        toolbar: false,
        comment: false,
        list: false,
        copied: false,
        notice: nil
    )

    /// `phase` と `isToolbarVisible` から決める。次の状態は判断しない。
    init(_ state: SessionViewState) {
        self = .none
        toolbar = state.isToolbarVisible
        switch state.phase {
        case .hidden:
            toolbar = false
        case .drawing:
            acceptsDrawing = true
            notice = Self.drawingNotice(state.failure)
        case .commenting:
            pinnedFrame = state.draftRect
            comment = true
        case .idle:
            notice = Self.toolbarNotice(state.failure)
        case .listOpen:
            list = true
            notice = Self.toolbarNotice(state.failure)
        case .copied:
            copied = true
        }
    }

    private init(
        acceptsDrawing: Bool,
        pinnedFrame: ScreenRect?,
        toolbar: Bool,
        comment: Bool,
        list: Bool,
        copied: Bool,
        notice: SessionFailure?
    ) {
        self.acceptsDrawing = acceptsDrawing
        self.pinnedFrame = pinnedFrame
        self.toolbar = toolbar
        self.comment = comment
        self.list = list
        self.copied = copied
        self.notice = notice
    }

    /// 枠を描く状態で知らせる失敗（撮影まわり）。`DECISIONS.md` A9。
    private static func drawingNotice(_ failure: SessionFailure?) -> SessionFailure? {
        switch failure {
        case .noWindowUnderFrame, .captureFailed, .imageSaveFailed:
            failure
        case .pasteboardFailed, .settingsSaveFailed, nil:
            nil
        }
    }

    /// ボタン類だけが出ている状態と一覧で知らせる失敗（コピーと設定の保存）。
    private static func toolbarNotice(_ failure: SessionFailure?) -> SessionFailure? {
        switch failure {
        case .pasteboardFailed, .settingsSaveFailed:
            failure
        case .noWindowUnderFrame, .captureFailed, .imageSaveFailed, nil:
            nil
        }
    }
}
