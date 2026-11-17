import Foundation
import Observation

/// 入力を直列に処理する唯一の状態機械。未実装の入力は状態を変更しない。
@MainActor @Observable public final class SessionModel {
    public private(set) var phase: Phase = .hidden
    public private(set) var annotations: [Annotation] = []
    public private(set) var draft: Annotation?
    public private(set) var settings: Settings
    public private(set) var lastDrawnRect: ScreenRect?
    /// 直前にコピーした注釈の件数。
    public private(set) var lastCopiedCount: Int = 0
    /// 直前の操作の失敗。成功したら nil に戻る。
    public private(set) var lastFailure: SessionFailure?

    /// ボタン類を出すか。phase が hidden のときは常に false。
    public var isToolbarVisible: Bool {
        phase != .hidden && !isToolbarHidden
    }

    private var isToolbarHidden = false

    /// 状態の更新後に同期で通知する。App の表示更新・診断書き出し用。
    @ObservationIgnored public var onChange: (@MainActor () -> Void)?
    @ObservationIgnored private let settingsStore: any SettingsStore
    @ObservationIgnored private let capturing: (any WindowCapturing)?
    @ObservationIgnored private let pasteboard: (any PromptPasteboard)?
    @ObservationIgnored private let images: (any ImageStore)?
    @ObservationIgnored private let clock: (any Clock)?

    /// 未接続の依存は nil。撮影以降の担当が具体実装を注入する。
    public init(
        settingsStore: any SettingsStore,
        capturing: (any WindowCapturing)? = nil,
        pasteboard: (any PromptPasteboard)? = nil,
        images: (any ImageStore)? = nil,
        clock: (any Clock)? = nil
    ) throws {
        self.settingsStore = settingsStore
        self.capturing = capturing
        self.pasteboard = pasteboard
        self.images = images
        self.clock = clock
        settings = try settingsStore.load()
    }

    /// 入力を送った順に 1 つずつ処理する。戻り値の Task は、その入力の処理が終わると完了する。
    /// 呼び出し側は戻り値を捨ててよい。テストは `await model.send(...).value` で完了を待てる。
    @discardableResult
    public func send(_ event: SessionEvent) -> Task<Void, Never> {
        // TODO(core): 撮影・保存などの非同期処理が入ったら、入力の待ち行列に積む形へ変える。
        handle(event)
        return Task {}
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .hotkeyPressed, .addTapped:
            phase = .drawing
        case .escapePressed where phase == .drawing:
            phase = annotations.isEmpty ? .hidden : .idle
        case let .dragEnded(rect, _) where phase == .drawing:
            lastDrawnRect = rect
            // TODO(core): 撮影と draft の生成後 commenting へ。骨組みでは idle に進む。
            phase = .idle
        default:
            // TODO(core): コメント・一覧・コピー・設定・表示切替の遷移と副作用。
            break
        }
        onChange?()
    }
}
