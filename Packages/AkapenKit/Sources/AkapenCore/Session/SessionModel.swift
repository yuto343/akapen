import Foundation
import Observation

/// 入力を直列に処理する唯一の状態機械。
///
/// 遷移の決まりは `.director/core/brief.md` と `ARCHITECTURE.md`「状態」のとおり。
/// 決まりに書いていない「状態と入力の組み合わせ」は何もしない。
@MainActor @Observable public final class SessionModel {
    public private(set) var phase: Phase = .hidden
    public private(set) var annotations: [Annotation] = []
    public private(set) var draft: Annotation?
    public private(set) var settings: Settings
    public private(set) var lastDrawnRect: ScreenRect?
    /// 直前にコピーした注釈の件数。
    public private(set) var lastCopiedCount: Int = 0
    /// 直前の操作の失敗。次に何かの入力が成功したら nil に戻る。
    public private(set) var lastFailure: SessionFailure?

    /// ボタン類を出すか。
    ///
    /// `hidden` と `copied` では常に false、`drawing` と `commenting` では常に true。
    /// `idle` と `listOpen` では、`toolbarToggled` で隠していなければ true。
    public var isToolbarVisible: Bool {
        switch phase {
        case .hidden, .copied:
            false
        case .drawing, .commenting:
            true
        case .idle, .listOpen:
            !isToolbarHidden
        }
    }

    /// 撮影する枠の幅と高さの下限（pt）。これより小さい枠は無視する。
    public static let minimumFrameSize = 4.0

    /// 画像を残す日数の範囲（`DECISIONS.md` 24・A10）。読み込んだ設定と `settingsChanged` の日数は、この範囲に丸める。
    public static let imageRetentionDaysRange = 1...365

    /// コピー完了の表示を出しておく時間。過ぎたら、まだ `copied` なら `hidden` に戻す。
    public static let copiedDisplayDuration = Duration.milliseconds(2500)

    private var isToolbarHidden = false

    /// 状態が変わったときだけ同期で通知する。App の表示更新・診断書き出し用。
    @ObservationIgnored public var onChange: (@MainActor () -> Void)?
    @ObservationIgnored private let settingsStore: any SettingsStore
    @ObservationIgnored private let capturing: (any WindowCapturing)?
    @ObservationIgnored private let pasteboard: (any PromptPasteboard)?
    @ObservationIgnored private let images: (any ImageStore)?
    @ObservationIgnored private let clock: (any Clock)?
    @ObservationIgnored private let timeZone: TimeZone
    /// いまの回の ID。時計がないときは nil。
    @ObservationIgnored private var sessionID: String?
    /// いまの回で次に保存する画像の番号（1 始まり）。
    @ObservationIgnored private var nextImageIndex = 1
    /// 処理中の非同期の入力。nil なら、次の入力はその場で処理できる。
    @ObservationIgnored private var tail: Task<Void, Never>?
    @ObservationIgnored private var tailGeneration = 0
    /// コピー完了の表示を消すタイマーの世代。古いタイマーが効かないように、張るたび・止めるたびに進める。
    @ObservationIgnored private var copiedTimerGeneration = 0
    /// コピー完了の表示を消すタイマー。テストから完了を待てるように internal にしている。
    @ObservationIgnored var copiedTimer: Task<Void, Never>?

    /// 回の ID（フォルダ名）は、この Mac のタイムゾーンで決める。
    ///
    /// 依存を省けるのは、撮影まで進まないテストのため。撮影（`capturing`）・画像の置き場（`images`）・時計（`clock`）の
    /// どれかがないときのドラッグ終了は `.captureFailed`、`pasteboard` がないときのコピーは `.pasteboardFailed` になる。
    public convenience init(
        settingsStore: any SettingsStore,
        capturing: (any WindowCapturing)? = nil,
        pasteboard: (any PromptPasteboard)? = nil,
        images: (any ImageStore)? = nil,
        clock: (any Clock)? = nil
    ) throws {
        try self.init(
            settingsStore: settingsStore,
            capturing: capturing,
            pasteboard: pasteboard,
            images: images,
            clock: clock,
            timeZone: .current
        )
    }

    /// `timeZone` は回の ID（フォルダ名）を決めるのに使う。
    /// テストは固定のタイムゾーンを渡し、手元の設定に結果が左右されないようにする。
    /// 読み込んだ設定の日数は `imageRetentionDaysRange` に丸める（範囲の外の値で、起動時の掃除がすべての回を消さないように）。
    public init(
        settingsStore: any SettingsStore,
        capturing: (any WindowCapturing)? = nil,
        pasteboard: (any PromptPasteboard)? = nil,
        images: (any ImageStore)? = nil,
        clock: (any Clock)? = nil,
        timeZone: TimeZone
    ) throws {
        self.settingsStore = settingsStore
        self.capturing = capturing
        self.pasteboard = pasteboard
        self.images = images
        self.clock = clock
        self.timeZone = timeZone
        settings = Self.clampingRetention(try settingsStore.load())
    }

    /// いまの回の ID（画像を置くフォルダの名前。`yyyyMMdd-HHmm`）。まだ回を始めていないか、時計がないときは nil。
    public var currentSessionID: String? {
        sessionID
    }

    /// 入力を送った順に 1 つずつ処理する。撮影のような非同期の処理の途中で、次の入力は割り込まない。
    ///
    /// 戻り値の Task は、その入力の処理が終わると完了する。呼び出し側は戻り値を捨ててよい。
    /// テストは `await model.send(...).value` で完了を待てる。
    /// 待っている入力がなく、処理が同期で済む入力は、この呼び出しの中で処理を終える。
    @discardableResult
    public func send(_ event: SessionEvent) -> Task<Void, Never> {
        enqueue { model in
            model.handle(event)
        }
    }

    /// 起動時の掃除。「いま − 設定の日数」より古い回のフォルダを消す。
    /// 画像の置き場か時計がつながっていなければ何もしない。
    public func performStartupCleanup() throws {
        guard let images, let clock else {
            return
        }
        let days = Swift.max(0, settings.imageRetentionDays)
        let cutoff = clock.now.addingTimeInterval(-TimeInterval(days) * 86_400)
        try images.removeSessions(before: cutoff)
    }
}

// MARK: - 入力の待ち行列

extension SessionModel {
    /// 入力の処理の結果。`lastFailure` の更新に使う。
    private enum Outcome {
        /// 何もしなかった。`lastFailure` は変えない。
        case ignored
        /// 成功した。`lastFailure` を nil に戻す。
        case succeeded
        /// 失敗した。状態は変えずに `lastFailure` を立てる。
        case failed(SessionFailure)
    }

    /// 1 つの入力の処理。同期で終わるか、続きを非同期で行うか。
    private enum Step {
        case done(Outcome)
        case async(@MainActor () async -> Outcome)
    }

    /// `onChange` を呼ぶかを決めるための、外から見える状態の写し。
    private struct Observed: Equatable {
        var phase: Phase
        var annotations: [Annotation]
        var draft: Annotation?
        var settings: Settings
        var lastDrawnRect: ScreenRect?
        var isToolbarHidden: Bool
        var lastCopiedCount: Int
        var lastFailure: SessionFailure?
    }

    private var observed: Observed {
        Observed(
            phase: phase,
            annotations: annotations,
            draft: draft,
            settings: settings,
            lastDrawnRect: lastDrawnRect,
            isToolbarHidden: isToolbarHidden,
            lastCopiedCount: lastCopiedCount,
            lastFailure: lastFailure
        )
    }

    /// 処理を待ち行列に積む。前の非同期の処理が残っていなければ、同期の部分はその場で処理する。
    private func enqueue(_ start: @escaping @MainActor (SessionModel) -> Step) -> Task<Void, Never> {
        if let previous = tail {
            return chain { model in
                await previous.value
                if let rest = model.begin(start) {
                    await rest()
                }
            }
        }
        if let rest = begin(start) {
            return chain { _ in
                await rest()
            }
        }
        return Task {}
    }

    /// 同期の部分を処理する。続きがあれば、それを行う関数を返す。
    private func begin(_ start: @MainActor (SessionModel) -> Step) -> (@MainActor () async -> Void)? {
        let before = observed
        switch start(self) {
        case let .done(outcome):
            apply(outcome)
            notifyIfChanged(since: before)
            return nil
        case let .async(work):
            notifyIfChanged(since: before)
            return { [self] in
                let before = observed
                let outcome = await work()
                apply(outcome)
                notifyIfChanged(since: before)
            }
        }
    }

    /// 非同期の処理を待ち行列の末尾に置く。終わったときに自分が末尾なら、待ち行列を空にする。
    private func chain(_ body: @escaping @MainActor (SessionModel) async -> Void) -> Task<Void, Never> {
        tailGeneration += 1
        let generation = tailGeneration
        let task = Task { @MainActor [self] in
            await body(self)
            if tailGeneration == generation {
                tail = nil
            }
        }
        tail = task
        return task
    }

    private func apply(_ outcome: Outcome) {
        switch outcome {
        case .ignored:
            break
        case .succeeded:
            lastFailure = nil
        case let .failed(failure):
            lastFailure = failure
        }
    }

    private func notifyIfChanged(since before: Observed) {
        if observed != before {
            onChange?()
        }
    }
}

// MARK: - 遷移

extension SessionModel {
    private func handle(_ event: SessionEvent) -> Step {
        switch event {
        case .hotkeyPressed:
            .done(hotkeyPressed())
        case .addTapped:
            .done(addTapped())
        case .escapePressed:
            .done(escapePressed())
        case let .dragEnded(rect, _):
            dragEnded(rect)
        case let .commentConfirmed(text):
            .done(commentConfirmed(text))
        case .commentCancelled:
            .done(commentCancelled())
        case .listToggled:
            .done(listToggled())
        case let .annotationEdited(id, text):
            .done(annotationEdited(id: id, text: text))
        case let .annotationDeleted(id):
            .done(annotationDeleted(id: id))
        case .copyPromptTapped:
            .done(copyPromptTapped())
        case .copiedExpired:
            .done(copiedExpired())
        case .toolbarToggled:
            .done(toolbarToggled())
        case let .settingsChanged(newSettings):
            .done(settingsChanged(newSettings))
        case .setupCompleted:
            .done(setupCompleted())
        }
    }

    private func hotkeyPressed() -> Outcome {
        switch phase {
        case .hidden, .copied:
            startNewSession()
            phase = .drawing
            return .succeeded
        case .idle, .listOpen:
            isToolbarHidden = false
            phase = .drawing
            return .succeeded
        case .drawing, .commenting:
            return .ignored
        }
    }

    private func addTapped() -> Outcome {
        switch phase {
        case .idle, .listOpen:
            isToolbarHidden = false
            phase = .drawing
            return .succeeded
        case .hidden, .drawing, .commenting, .copied:
            return .ignored
        }
    }

    private func escapePressed() -> Outcome {
        switch phase {
        case .drawing:
            leaveEditing()
            return .succeeded
        case .commenting:
            discardDraft()
            leaveEditing()
            return .succeeded
        case .listOpen:
            phase = .idle
            return .succeeded
        case .hidden, .idle, .copied:
            return .ignored
        }
    }

    private func dragEnded(_ rect: ScreenRect) -> Step {
        guard phase == .drawing else {
            return .done(.ignored)
        }
        lastDrawnRect = rect
        guard rect.width >= Self.minimumFrameSize, rect.height >= Self.minimumFrameSize else {
            return .done(.ignored)
        }
        guard let capturing, let images, let clock else {
            // 撮影に要る依存がつながっていない。撮影できなかったのと同じに扱い、`drawing` のままにする。
            return .done(.failed(.captureFailed))
        }
        let sessionID = currentSessionID(clock: clock)
        return .async { [self] in
            await capture(
                rect,
                capturing: capturing,
                images: images,
                clock: clock,
                sessionID: sessionID
            )
        }
    }

    private func capture(
        _ rect: ScreenRect,
        capturing: any WindowCapturing,
        images: any ImageStore,
        clock: any Clock,
        sessionID: String
    ) async -> Outcome {
        let windows: [CaptureWindow]
        do {
            windows = try await capturing.windows()
        } catch {
            return .failed(.captureFailed)
        }
        guard let window = WindowPicker.pick(frame: rect, from: windows) else {
            return .failed(.noWindowUnderFrame)
        }
        let rendered: Data
        do {
            let png = try await capturing.capture(window: window)
            rendered = try await Self.renderInBackground(png: png, windowFrame: window.frame, frame: rect)
        } catch {
            return .failed(.captureFailed)
        }
        let url: URL
        do {
            url = try images.save(png: rendered, sessionID: sessionID, index: nextImageIndex)
        } catch {
            return .failed(.imageSaveFailed)
        }
        nextImageIndex += 1
        draft = Annotation(
            imagePath: url.path(percentEncoded: false),
            comment: "",
            rect: rect,
            sourceAppName: window.appName,
            createdAt: clock.now,
            windowFrame: window.frame
        )
        phase = .commenting
        return .succeeded
    }

    /// 赤枠の描き込みと縮小は重いので、メインアクターの外で行う。
    private static func renderInBackground(png: Data, windowFrame: ScreenRect, frame: ScreenRect) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try FrameRenderer.render(png: png, windowFrame: windowFrame, frame: frame)
        }.value
    }

    private func commentConfirmed(_ text: String) -> Outcome {
        guard phase == .commenting, var confirmed = draft else {
            return .ignored
        }
        let comment = text.trimmingWhitespaceAndNewlines()
        guard !comment.isEmpty else {
            return .ignored
        }
        confirmed.comment = comment
        annotations.append(confirmed)
        draft = nil
        phase = .idle
        return .succeeded
    }

    private func commentCancelled() -> Outcome {
        guard phase == .commenting else {
            return .ignored
        }
        discardDraft()
        leaveEditing()
        return .succeeded
    }

    private func listToggled() -> Outcome {
        switch phase {
        case .idle:
            isToolbarHidden = false
            phase = .listOpen
            return .succeeded
        case .listOpen:
            phase = .idle
            return .succeeded
        case .hidden, .drawing, .commenting, .copied:
            return .ignored
        }
    }

    private func annotationEdited(id: UUID, text: String) -> Outcome {
        guard phase == .listOpen, let index = annotations.firstIndex(where: { $0.id == id }) else {
            return .ignored
        }
        let comment = text.trimmingWhitespaceAndNewlines()
        guard !comment.isEmpty else {
            return .ignored
        }
        annotations[index].comment = comment
        return .succeeded
    }

    private func annotationDeleted(id: UUID) -> Outcome {
        guard phase == .listOpen, let index = annotations.firstIndex(where: { $0.id == id }) else {
            return .ignored
        }
        let removed = annotations.remove(at: index)
        removeImage(atPath: removed.imagePath)
        return .succeeded
    }

    private func copyPromptTapped() -> Outcome {
        guard phase == .idle || phase == .listOpen, !annotations.isEmpty else {
            return .ignored
        }
        guard let pasteboard else {
            return .failed(.pasteboardFailed)
        }
        let text = PromptBuilder.build(settings: settings, annotations: annotations)
        do {
            try pasteboard.write(text: text, imageURLs: [])
        } catch {
            return .failed(.pasteboardFailed)
        }
        lastCopiedCount = annotations.count
        annotations = []
        phase = .copied
        startCopiedTimer()
        return .succeeded
    }

    private func copiedExpired() -> Outcome {
        guard phase == .copied else {
            return .ignored
        }
        stopCopiedTimer()
        phase = .hidden
        return .succeeded
    }

    private func toolbarToggled() -> Outcome {
        switch phase {
        case .hidden:
            startNewSession()
            phase = .idle
            return .succeeded
        case .idle, .listOpen:
            isToolbarHidden.toggle()
            if isToolbarHidden {
                phase = .idle
            }
            return .succeeded
        case .drawing, .commenting, .copied:
            return .ignored
        }
    }

    private func settingsChanged(_ newSettings: Settings) -> Outcome {
        settings = Self.clampingRetention(newSettings)
        return saveSettings()
    }

    private func setupCompleted() -> Outcome {
        settings.setupCompleted = true
        return saveSettings()
    }
}

// MARK: - 遷移の下請け

extension SessionModel {
    /// 新しい回を始める。回の ID は時計から決める。
    /// 同じ分のうちに次の回を始めたときは、前の回の画像を上書きしないように番号を続ける。
    private func startNewSession() {
        stopCopiedTimer()
        draft = nil
        isToolbarHidden = false
        guard let clock else {
            sessionID = nil
            return
        }
        let id = CacheLayout.sessionID(for: clock.now, timeZone: timeZone)
        if id != sessionID {
            sessionID = id
            nextImageIndex = 1
        }
    }

    private func currentSessionID(clock: any Clock) -> String {
        if let sessionID {
            return sessionID
        }
        let id = CacheLayout.sessionID(for: clock.now, timeZone: timeZone)
        sessionID = id
        nextImageIndex = 1
        return id
    }

    /// 枠を描く・コメントを書く途中から抜ける。確定済みの注釈が 0 件なら hidden、あれば idle。
    private func leaveEditing() {
        if annotations.isEmpty {
            phase = .hidden
        } else {
            isToolbarHidden = false
            phase = .idle
        }
    }

    /// 書きかけの注釈と、その画像を捨てる。
    private func discardDraft() {
        if let draft {
            removeImage(atPath: draft.imagePath)
        }
        draft = nil
    }

    /// 画像を消す。消せなくても遷移は止めない（古い回の掃除で、いずれ消える）。
    private func removeImage(atPath path: String) {
        try? images?.remove(at: URL(filePath: path))
    }

    /// 画像を残す日数を `imageRetentionDaysRange` に丸めた設定。
    private static func clampingRetention(_ settings: Settings) -> Settings {
        var clamped = settings
        let range = imageRetentionDaysRange
        clamped.imageRetentionDays = Swift.min(Swift.max(settings.imageRetentionDays, range.lowerBound), range.upperBound)
        return clamped
    }

    private func saveSettings() -> Outcome {
        do {
            try settingsStore.save(settings)
            return .succeeded
        } catch {
            return .failed(.settingsSaveFailed)
        }
    }

    /// コピー完了の表示を消すタイマーを張る。時計がつながっていなければ張らない（`copiedExpired` を待つ）。
    private func startCopiedTimer() {
        stopCopiedTimer()
        guard let clock else {
            return
        }
        let generation = copiedTimerGeneration
        copiedTimer = Task { [weak self] in
            do {
                try await clock.sleep(for: Self.copiedDisplayDuration)
            } catch {
                return
            }
            guard let self else {
                return
            }
            await enqueue { model in
                .done(model.copiedTimerFired(generation: generation))
            }.value
        }
    }

    /// タイマーを止め、世代を進めて、すでに動き出したタイマーも効かないようにする。
    private func stopCopiedTimer() {
        copiedTimer?.cancel()
        copiedTimer = nil
        copiedTimerGeneration += 1
    }

    private func copiedTimerFired(generation: Int) -> Outcome {
        guard generation == copiedTimerGeneration else {
            return .ignored
        }
        return copiedExpired()
    }
}
