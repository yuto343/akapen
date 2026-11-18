import AkapenCore

/// 画面に映す値。`SessionModel` から作る。パネルの出し入れはこの値だけで決める。
///
/// テストは `SessionModel` に入力を送らずに、この値を直接作って `SessionWindows.render(_:)` に渡す。
public struct SessionViewState: Equatable, Sendable {
    public var phase: Phase
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
        annotations: [Annotation] = [],
        draftRect: ScreenRect? = nil,
        lastCopiedCount: Int = 0,
        language: Language = Settings().language,
        confirmKey: ConfirmKey = Settings().confirmKey,
        imageRetentionDays: Int = Settings().imageRetentionDays,
        failure: SessionFailure? = nil
    ) {
        self.phase = phase
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
///
/// ボタン類が出ているあいだ（`drawing`・`commenting`・`listOpen`）は、画面全体を覆う面も出してマウスを受ける。
/// 面が枠を描くのは `drawing` のときだけで、`commenting` と `listOpen` では面のクリックは何もしない。
struct PanelPlan: Equatable {
    /// 画面全体を覆う面を出して、マウスを受けるか（下のアプリを操作させない）。
    var coversScreen: Bool
    /// 面が枠を描くか（`drawing` のときだけ）。
    var acceptsDrawing: Bool
    /// コメントを書いている間に出しておく赤枠。
    var pinnedFrame: ScreenRect?
    var toolbar: Bool
    var comment: Bool
    var list: Bool
    var copied: Bool
    /// 案内の表示で知らせる失敗。`drawing` ではすべて、`listOpen` ではコピーと設定の保存の失敗。
    var notice: SessionFailure?

    /// 面（赤枠や案内を描く全画面のパネル）を出すか。
    var showsOverlay: Bool {
        coversScreen
    }

    /// 何も出さない。
    static let none = PanelPlan(
        coversScreen: false,
        acceptsDrawing: false,
        pinnedFrame: nil,
        toolbar: false,
        comment: false,
        list: false,
        copied: false,
        notice: nil
    )

    /// `phase` から決める。次の状態は判断しない。
    init(_ state: SessionViewState) {
        self = .none
        switch state.phase {
        case .hidden:
            break
        case .drawing:
            coversScreen = true
            acceptsDrawing = true
            toolbar = true
            notice = state.failure
        case .commenting:
            coversScreen = true
            toolbar = true
            pinnedFrame = state.draftRect
            comment = true
        case .listOpen:
            coversScreen = true
            toolbar = true
            list = true
            notice = Self.listNotice(state.failure)
        case .copied:
            copied = true
        }
    }

    private init(
        coversScreen: Bool,
        acceptsDrawing: Bool,
        pinnedFrame: ScreenRect?,
        toolbar: Bool,
        comment: Bool,
        list: Bool,
        copied: Bool,
        notice: SessionFailure?
    ) {
        self.coversScreen = coversScreen
        self.acceptsDrawing = acceptsDrawing
        self.pinnedFrame = pinnedFrame
        self.toolbar = toolbar
        self.comment = comment
        self.list = list
        self.copied = copied
        self.notice = notice
    }

    /// 一覧で知らせる失敗（コピーと設定の保存）。撮影の失敗は一覧を開く前の話なので出さない。
    private static func listNotice(_ failure: SessionFailure?) -> SessionFailure? {
        switch failure {
        case .pasteboardFailed, .settingsSaveFailed:
            failure
        case .noWindowUnderFrame, .captureFailed, .imageSaveFailed, nil:
            nil
        }
    }
}
