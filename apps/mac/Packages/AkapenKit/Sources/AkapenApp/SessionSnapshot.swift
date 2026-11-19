import Foundation
import AkapenCore

/// `state.json`（v3）の中身。E2E のときだけ、状態が変わるたびに書き出す。形は `docs/FOUNDATION.md`「state.json v3」。
///
/// 矩形は画面全体を通した、左上が原点の pt。日付は ISO 8601 の文字列。値がないものは `null` として書く（キーを省かない）。
public struct SessionSnapshot: Encodable, Equatable {
    /// 形の版。キーを足したり意味を変えたりしたら上げる。
    public static let schemaVersion = 3

    /// 設定の写し。定型文は、書き換えていない言語も既定文を入れて、すべての言語を書く。
    public struct SettingsValues: Encodable, Equatable {
        public var language: Language
        public var hotkey: KeyboardShortcut
        public var confirmKey: ConfirmKey
        public var boilerplates: [String: String]
        public var imageRetentionDays: Int
        public var setupCompleted: Bool

        /// 設定から作る。
        public init(_ settings: Settings) {
            language = settings.language
            hotkey = settings.hotkey
            confirmKey = settings.confirmKey
            boilerplates = Dictionary(uniqueKeysWithValues: [Language.en, Language.ja].map { language in
                (language.rawValue, settings.boilerplate(for: language))
            })
            imageRetentionDays = settings.imageRetentionDays
            setupCompleted = settings.setupCompleted
        }

        private enum CodingKeys: String, CodingKey {
            case language
            case hotkey
            case confirmKey
            case boilerplates
            case imageRetentionDays
            case setupCompleted
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(language, forKey: .language)
            try container.encode(hotkey, forKey: .hotkey)
            try container.encode(confirmKey, forKey: .confirmKey)
            try container.encode(boilerplates, forKey: .boilerplates)
            try container.encode(imageRetentionDays, forKey: .imageRetentionDays)
            try container.encode(setupCompleted, forKey: .setupCompleted)
        }
    }

    /// いまの回と画像の置き場。
    public struct Storage: Encodable, Equatable {
        /// 画像の置き場の根（絶対パス）。
        public var imagesDirectory: String
        /// いまの回の ID（`yyyyMMdd-HHmm`）。まだ回を始めていなければ null。
        public var sessionID: String?
        /// いまの回のフォルダ（絶対パス）。まだ回を始めていなければ null。
        public var sessionDirectory: String?

        /// 置き場の根と回の ID から作る。
        public init(imagesDirectory: URL, sessionID: String?) {
            self.imagesDirectory = imagesDirectory.path(percentEncoded: false)
            self.sessionID = sessionID
            sessionDirectory = sessionID.map { id in
                imagesDirectory.appending(path: id, directoryHint: .isDirectory).path(percentEncoded: false)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case imagesDirectory
            case sessionID
            case sessionDirectory
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(imagesDirectory, forKey: .imagesDirectory)
            try container.encode(sessionID, forKey: .sessionID)
            try container.encode(sessionDirectory, forKey: .sessionDirectory)
        }
    }

    /// 出ている画面（設定・セットアップ・終了の確認）。
    public struct Windows: Encodable, Equatable, Sendable {
        /// セットアップのページ。
        public enum SetupPage: String, Encodable, Sendable {
            /// 1 ページ目（ホットキー）。
            case hotkey
            /// 2 ページ目（画面収録の許可）。
            case permission
        }

        public var settings: Bool
        public var setup: Bool
        /// セットアップの出ているページ。出ていなければ null。
        public var setupPage: SetupPage?
        public var quitConfirm: Bool

        /// どれも出ていない。
        public static let none = Windows(settings: false, setup: false, setupPage: nil, quitConfirm: false)

        /// 値をそのまま持つ。
        public init(settings: Bool, setup: Bool, setupPage: SetupPage?, quitConfirm: Bool) {
            self.settings = settings
            self.setup = setup
            self.setupPage = setupPage
            self.quitConfirm = quitConfirm
        }

        private enum CodingKeys: String, CodingKey {
            case settings
            case setup
            case setupPage
            case quitConfirm
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(settings, forKey: .settings)
            try container.encode(setup, forKey: .setup)
            try container.encode(setupPage, forKey: .setupPage)
            try container.encode(quitConfirm, forKey: .quitConfirm)
        }
    }

    /// 実際に登録しているグローバルなホットキー。
    public struct Hotkeys: Encodable, Equatable {
        public var draw: KeyboardShortcut?
        /// キーの記録欄のために、登録を外しているか。
        public var suspended: Bool
        /// 直前の登録に失敗した役（`draw`）。
        public var failed: [String]

        /// 登録の様子から作る。
        public init(_ status: HotkeyCoordinator.Status) {
            draw = status.draw
            suspended = status.isSuspended
            failed = status.failed.map(\.rawValue)
        }

        private enum CodingKeys: String, CodingKey {
            case draw
            case suspended
            case failed
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(draw, forKey: .draw)
            try container.encode(suspended, forKey: .suspended)
            try container.encode(failed, forKey: .failed)
        }
    }

    public let phase: Phase
    public let isToolbarVisible: Bool
    /// 確定済みの注釈（確定した順）。
    public let annotations: [Annotation]
    /// 書きかけの注釈（コメントが未確定のもの）。撮影と保存が終わるまで、画像のパス・アプリ名・ウィンドウの矩形は nil。
    public let draft: DraftAnnotation?
    public let lastDrawnRect: ScreenRect?
    public let lastCopiedCount: Int
    /// 直前の操作の失敗（`SessionFailure` の名前）。
    public let lastFailure: String?
    public let settings: SettingsValues
    public let storage: Storage
    public let windows: Windows
    public let hotkeys: Hotkeys

    /// いまの状態から作る。
    @MainActor public init(
        model: SessionModel,
        imagesDirectory: URL,
        windows: Windows,
        hotkeys: HotkeyCoordinator.Status
    ) {
        phase = model.phase
        isToolbarVisible = model.isToolbarVisible
        annotations = model.annotations
        draft = model.draft
        lastDrawnRect = model.lastDrawnRect
        lastCopiedCount = model.lastCopiedCount
        lastFailure = model.lastFailure.map(Self.name)
        settings = SettingsValues(model.settings)
        storage = Storage(imagesDirectory: imagesDirectory, sessionID: model.currentSessionID)
        self.windows = windows
        self.hotkeys = Hotkeys(hotkeys)
    }

    /// 失敗の名前（`state.json` に書く値）。
    static func name(_ failure: SessionFailure) -> String {
        switch failure {
        case .captureFailed:
            "captureFailed"
        case .imageSaveFailed:
            "imageSaveFailed"
        case .pasteboardFailed:
            "pasteboardFailed"
        case .settingsSaveFailed:
            "settingsSaveFailed"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case phase
        case isToolbarVisible
        case annotations
        case draft
        case lastDrawnRect
        case lastCopiedCount
        case lastFailure
        case settings
        case storage
        case windows
        case hotkeys
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(phase, forKey: .phase)
        try container.encode(isToolbarVisible, forKey: .isToolbarVisible)
        try container.encode(annotations, forKey: .annotations)
        try container.encode(draft, forKey: .draft)
        try container.encode(lastDrawnRect, forKey: .lastDrawnRect)
        try container.encode(lastCopiedCount, forKey: .lastCopiedCount)
        try container.encode(lastFailure, forKey: .lastFailure)
        try container.encode(settings, forKey: .settings)
        try container.encode(storage, forKey: .storage)
        try container.encode(windows, forKey: .windows)
        try container.encode(hotkeys, forKey: .hotkeys)
    }
}
