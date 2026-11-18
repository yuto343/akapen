import Foundation
import AkapenCore
import AkapenPlatform

/// アプリの依存一式。本物の起動・E2E・結合テストのどれも `make(_:)` で組み立てる。
///
/// どの実装を使うかは `LaunchConfiguration` だけで決める（`choose(_:)`）。
/// - 本番: `UserDefaults.standard` の設定、`~/Library/Caches/akapen/` の画像、一般のクリップボード、ScreenCaptureKit の撮影、
///   システムの時計、実際の画面収録の許可、実際のログイン時の起動。
/// - E2E（`AKAPEN_E2E=1`）: 設定・画像・`state.json` はすべて `AKAPEN_STATE_DIR` の下。クリップボードは `AKAPEN_PASTEBOARD` の名前つき。
///   時計は `AKAPEN_NOW` があれば固定。ログイン時の起動は何もしない実装。撮影と許可は `AKAPEN_CAPTURE` で、`fixture`（既定）なら偽物、`live` なら本物。
///   ユーザーの設定・キャッシュ・一般のクリップボード・ログイン項目に触る実装は、E2E では 1 つも作らない。
@MainActor public final class AppEnvironment {
    /// 選んだ実装。テストと診断のために、作った実装とは別に値で持つ。
    public struct Choice: Equatable, Sendable {
        /// 設定の置き場。
        public enum SettingsStorage: Equatable, Sendable {
            /// `UserDefaults.standard`（`UserDefaultsSettingsStore`）。
            case userDefaults
            /// JSON ファイル（`FileSettingsStore`）。
            case file(URL)
        }

        /// クリップボード。
        public enum Pasteboard: Equatable, Sendable {
            /// 一般のクリップボード。
            case general
            /// 名前つきのクリップボード。
            case named(String)
        }

        /// 撮影と、画面収録の許可。
        public enum Capture: Equatable, Sendable {
            /// `ScreenCaptureKitCapturer` と `SystemScreenRecordingPermission`。
            case screenCaptureKit
            /// `FixtureCapturer`（許可に従わせる包みつき）と `FixedScreenRecordingPermission`。
            case fixture
        }

        /// 時計。
        public enum ClockKind: Equatable, Sendable {
            /// `SystemClock`。
            case system
            /// `FixedClock`。
            case fixed(Date)
        }

        /// ログイン時の起動。
        public enum LoginItemKind: Equatable, Sendable {
            /// `SystemLoginItem`（`SMAppService.mainApp`）。
            case system
            /// `NoopLoginItem`（何もしない）。
            case noop
        }

        public var settings: SettingsStorage
        /// 画像の置き場の根。
        public var imagesDirectory: URL
        public var pasteboard: Pasteboard
        public var capture: Capture
        public var clock: ClockKind
        public var loginItem: LoginItemKind
        /// `state.json` の書き出し先。nil なら書き出さない（本番）。
        public var stateFile: URL?
        /// 起動に失敗したときに理由を書く先。nil なら書かない（本番）。
        public var startupErrorFile: URL?
    }

    /// 起動に失敗した理由（`LaunchConfiguration.Problem` のほか）。
    public enum StartupError: Error, Equatable {
        /// 環境変数が足りない・読めない。
        case invalidConfiguration([LaunchConfiguration.Problem])
        /// `AKAPEN_SEED` が読めない。
        case invalidSeed(String)
        /// `AKAPEN_SEED` の設定を保存できなかった。
        case seedSettingsNotSaved
        /// `AKAPEN_SEED` の注釈を作れなかった。番号（0 始まり）と理由。
        case seedAnnotationFailed(Int, String)
        /// `AKAPEN_SEED` の `open` の状態にできなかった。求めたものと、実際の `phase`。
        case seedOpenFailed(String, String)
    }

    /// 使った起動設定。
    public let configuration: LaunchConfiguration
    /// 選んだ実装。
    public let choice: Choice
    /// 状態機械。
    public let model: SessionModel
    public let settingsStore: any SettingsStore
    public let images: any ImageStore
    public let pasteboard: any PromptPasteboard
    public let capturer: any WindowCapturing
    public let clock: any Clock
    public let permission: any ScreenRecordingPermission
    public let loginItem: any LoginItem
    /// グローバルなホットキー。押されたら `model` に `hotkeyPressed` を送る。登録は `apply(_:)` を呼んでから。
    public let hotkeys: HotkeyCoordinator
    /// 起動時の掃除（古い回のフォルダの削除）の失敗。起動は止めない。
    public private(set) var startupCleanupError: String?
    /// 直前の `state.json` の書き出しの失敗。黙って成功扱いにしない。
    public private(set) var stateWriteError: String?
    /// `model` の状態が変わったとき（`state.json` を書き出す前）。画面の反映などに使う。
    public var onModelChange: (@MainActor () -> Void)?
    /// 出ている画面の様子（`state.json` に書く）。画面を組み立てる前は nil（どれも出ていない扱い）。
    public var windowStatus: (@MainActor () -> SessionSnapshot.Windows)?
    private let stateWriter: (any StateWriting)?
    private var isWritingState = false

    private init(
        configuration: LaunchConfiguration,
        choice: Choice,
        model: SessionModel,
        dependencies: Dependencies
    ) {
        self.configuration = configuration
        self.choice = choice
        self.model = model
        settingsStore = dependencies.settingsStore
        images = dependencies.images
        pasteboard = dependencies.pasteboard
        capturer = dependencies.capturer
        clock = dependencies.clock
        permission = dependencies.permission
        loginItem = dependencies.loginItem
        stateWriter = choice.stateFile.map { AtomicStateWriter(url: $0) }
        hotkeys = HotkeyCoordinator(
            draw: CarbonHotkey(),
            probe: CarbonHotkey(),
            onDraw: { [weak model] in
                model?.send(.hotkeyPressed)
            }
        )
        model.onChange = { [weak self] in
            self?.modelChanged()
        }
    }

    // MARK: - 選び分け

    /// 起動設定から、使う実装を選ぶ。OS には触らない。E2E で環境変数が足りなければ起動エラー。
    public static func choose(_ configuration: LaunchConfiguration) throws -> Choice {
        guard configuration.isE2E else {
            return Choice(
                settings: .userDefaults,
                imagesDirectory: FileImageStore.defaultRoot(),
                pasteboard: .general,
                capture: .screenCaptureKit,
                clock: .system,
                loginItem: .system,
                stateFile: nil,
                startupErrorFile: nil
            )
        }
        guard configuration.problems.isEmpty,
              let directory = configuration.stateDirectory,
              let pasteboardName = configuration.pasteboardName else {
            throw StartupError.invalidConfiguration(configuration.problems)
        }
        return Choice(
            settings: .file(directory.appending(path: "settings.json", directoryHint: .notDirectory)),
            imagesDirectory: directory.appending(path: "images", directoryHint: .isDirectory),
            pasteboard: .named(pasteboardName),
            capture: configuration.capture == .live ? .screenCaptureKit : .fixture,
            clock: configuration.now.map(Choice.ClockKind.fixed) ?? .system,
            loginItem: .noop,
            stateFile: directory.appending(path: "state.json", directoryHint: .notDirectory),
            startupErrorFile: directory.appending(path: "startup-error.txt", directoryHint: .notDirectory)
        )
    }

    // MARK: - 組み立て

    /// 依存一式を組み立て、起動時の処理（`AKAPEN_SEED` の設定、古い回の掃除、`AKAPEN_SEED` の注釈と `open`）まで済ませる。
    ///
    /// `state.json` はまだ書き出さない（画面を組み立て終えたら `startWritingState()` を呼ぶ）。
    /// 書き出しを始めた時点で、起動の前提が揃っていることになる。
    public static func make(_ configuration: LaunchConfiguration) async throws -> AppEnvironment {
        let choice = try choose(configuration)
        let seed: LaunchSeed?
        do {
            seed = try configuration.isE2E ? configuration.seedJSON.map(LaunchSeed.parse) : nil
        } catch let LaunchSeed.ParseError.invalid(reason) {
            throw StartupError.invalidSeed(reason)
        }
        let dependencies = Dependencies(choice: choice, seed: seed ?? LaunchSeed())
        let model = try SessionModel(
            settingsStore: dependencies.settingsStore,
            capturing: dependencies.capturer,
            pasteboard: dependencies.pasteboard,
            images: dependencies.images,
            clock: dependencies.clock
        )
        let environment = AppEnvironment(
            configuration: configuration,
            choice: choice,
            model: model,
            dependencies: dependencies
        )
        if let patch = seed?.settings {
            await model.send(.settingsChanged(patch.applied(to: model.settings))).value
            guard model.lastFailure != .settingsSaveFailed else {
                throw StartupError.seedSettingsNotSaved
            }
        }
        do {
            try model.performStartupCleanup()
        } catch {
            environment.startupCleanupError = String(describing: error)
        }
        try await seedAnnotations(seed?.annotations ?? [], into: model)
        if let open = seed?.open {
            try await seedOpenView(open, into: model)
        }
        return environment
    }

    /// 起動に失敗した理由を、E2E なら `startup-error.txt` に書く（テストが待ち続けずに理由を出せるように）。
    public static func reportStartupFailure(_ error: any Error, configuration: LaunchConfiguration) {
        guard configuration.isE2E, let directory = configuration.stateDirectory else {
            return
        }
        let url = directory.appending(path: "startup-error.txt", directoryHint: .notDirectory)
        try? AtomicStateWriter(url: url).write(Data(String(describing: error).utf8))
    }

    /// 注釈を、ホットキー → 枠 → コメントの確定の順に送って作る。画像は本来の撮影の経路で保存される。
    ///
    /// 確定すると枠を描ける状態に戻るので、2 件目からはそのまま枠を送る。作り終えたら `Esc` で隠す（注釈は残る）。
    private static func seedAnnotations(_ annotations: [LaunchSeed.Annotation], into model: SessionModel) async throws {
        for (index, annotation) in annotations.enumerated() {
            if model.phase == .hidden {
                await model.send(.hotkeyPressed).value
            }
            guard model.phase == .drawing else {
                throw StartupError.seedAnnotationFailed(index, "枠を描く状態に入れない（\(model.phase.rawValue)）")
            }
            let screen = ScreenDescriptor(id: 0, frame: annotation.rect)
            await model.send(.dragEnded(rect: annotation.rect, screen: screen)).value
            guard model.phase == .commenting else {
                let reason = model.lastFailure.map(SessionSnapshot.name) ?? "枠が小さすぎる"
                throw StartupError.seedAnnotationFailed(index, reason)
            }
            await model.send(.commentConfirmed(text: annotation.comment)).value
            guard model.phase == .drawing else {
                throw StartupError.seedAnnotationFailed(index, "コメントが空")
            }
        }
        if model.phase == .drawing {
            await model.send(.escapePressed).value
        }
    }

    /// 起動後に出しておくものを、`hotkeyPressed`（ボタン類を出す。注釈があれば同じ回を続ける）と `listToggled` を送って作る。
    private static func seedOpenView(_ open: LaunchSeed.OpenView, into model: SessionModel) async throws {
        if model.phase == .hidden {
            await model.send(.hotkeyPressed).value
        }
        if open == .list, model.phase == .drawing {
            await model.send(.listToggled).value
        }
        let expected: Phase = open == .list ? .listOpen : .drawing
        guard model.phase == expected, model.isToolbarVisible else {
            throw StartupError.seedOpenFailed(open.rawValue, model.phase.rawValue)
        }
    }

    // MARK: - state.json

    /// `state.json` の書き出しを始め、いまの状態を書き出す。E2E でなければ何もしない。
    public func startWritingState() {
        isWritingState = true
        writeState()
    }

    /// いまの状態を書き出す。書き出しを始める前と、E2E でないときは何もしない。失敗は `stateWriteError` に残す。
    public func writeState() {
        guard isWritingState, let stateWriter else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try stateWriter.write(encoder.encode(snapshot()))
            stateWriteError = nil
        } catch {
            stateWriteError = String(describing: error)
        }
    }

    /// いまの状態の写し。
    public func snapshot() -> SessionSnapshot {
        SessionSnapshot(
            model: model,
            imagesDirectory: choice.imagesDirectory,
            windows: windowStatus?() ?? .none,
            hotkeys: hotkeys.status
        )
    }

    private func modelChanged() {
        onModelChange?()
        writeState()
    }
}

/// 選んだ実装を実際に作ったもの。
@MainActor private struct Dependencies {
    let settingsStore: any SettingsStore
    let images: any ImageStore
    let pasteboard: any PromptPasteboard
    let capturer: any WindowCapturing
    let clock: any Clock
    let permission: any ScreenRecordingPermission
    let loginItem: any LoginItem

    init(choice: AppEnvironment.Choice, seed: LaunchSeed) {
        switch choice.settings {
        case .userDefaults:
            settingsStore = UserDefaultsSettingsStore(defaults: .standard)
        case let .file(url):
            settingsStore = FileSettingsStore(url: url)
        }
        images = FileImageStore(root: choice.imagesDirectory, timeZone: .current)
        switch choice.pasteboard {
        case .general:
            pasteboard = SystemPromptPasteboard(name: nil)
        case let .named(name):
            pasteboard = SystemPromptPasteboard(name: name)
        }
        switch choice.capture {
        case .screenCaptureKit:
            permission = SystemScreenRecordingPermission()
            capturer = ScreenCaptureKitCapturer()
        case .fixture:
            let fixed = FixedScreenRecordingPermission(isGranted: seed.isScreenRecordingGranted)
            permission = fixed
            capturer = PermissionCheckedCapturer(base: FixtureCapturer(windows: seed.fixtureWindows), permission: fixed)
        }
        switch choice.clock {
        case .system:
            clock = SystemClock()
        case let .fixed(date):
            clock = FixedClock(now: date)
        }
        switch choice.loginItem {
        case .system:
            loginItem = SystemLoginItem()
        case .noop:
            loginItem = NoopLoginItem()
        }
    }
}
