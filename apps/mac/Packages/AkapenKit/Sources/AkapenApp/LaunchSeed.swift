import Foundation
import AkapenCore

/// E2E の起動時の前提（`AKAPEN_SEED`）。JSON をそのまま環境変数に入れる。
///
/// ```json
/// {
///   "settings": {"language": "ja", "imageRetentionDays": 3, "setupCompleted": true},
///   "screenRecording": "granted",
///   "windows": [{"frame": {"x": 140, "y": 64, "width": 1000, "height": 660}, "appName": "Sample App", "title": "Sample App"}],
///   "annotations": [{"comment": "ボタンの余白が左右で違う", "rect": {"x": 1000, "y": 420, "width": 120, "height": 50}}],
///   "open": "list"
/// }
/// ```
///
/// - どのキーも省ける。知らないキー・型の違う値・範囲の外の値（言語や確定キーの綴りなど）は起動エラーにする（書き間違いで前提が黙って変わらないように）。
/// - `settings`: 設定の一部。キーと値の形は保存する設定の JSON（`state.json` の `settings`）と同じ。保存済みの設定に、書いた項目だけを重ねる。
///   `boilerplates` は書いた言語（`en` / `ja`）だけを書き換える。
///   日数は `SessionModel` が 1〜365 に丸める。
/// - `screenRecording`: 画面収録の許可。`granted`（既定）か `denied`。偽の撮影（`AKAPEN_CAPTURE=fixture`）のときだけ効く。
/// - `windows`: 偽の撮影が返すウィンドウ（手前から順）。省くと `LaunchSeed.defaultWindows`（SampleTarget と同じ位置・大きさ）。
/// - `annotations`: 確定済みの注釈。起動時に、ホットキー → 枠 → コメントの確定を `SessionModel` に順に送って作る
///   （画像は本来と同じ経路で撮って、赤枠を描き込み、置き場に保存する）。作り終えたら `Esc` で隠すので、`open` を省くと
///   何も出ていない状態（注釈は残っている）になる。
/// - `open`: 起動後に出しておくもの。`toolbar` でボタン類が出ている状態（枠を描ける `drawing`。注釈が 0 件でも）、
///   `list` で一覧を開いた状態（`listOpen`）。省くと何も出ていない状態（`hidden`）。
///   どちらも `SessionModel` に入力（`hotkeyPressed` / `listToggled`）を送って作る。注釈があれば同じ回を続ける。
public struct LaunchSeed: Equatable, Sendable {
    /// 画面収録の許可の有無。
    public enum ScreenRecording: String, Codable, Equatable, Sendable {
        case granted
        case denied
    }

    /// 偽の撮影が返すウィンドウ。
    public struct Window: Codable, Equatable, Sendable {
        /// 画面全体を通した、左上が原点の矩形（pt）。
        public var frame: ScreenRect
        /// アプリ名（一覧のメタ情報に出る）。
        public var appName: String
        /// ウィンドウのタイトル。
        public var title: String?

        /// 値をそのまま持つ。
        public init(frame: ScreenRect, appName: String, title: String? = nil) {
            self.frame = frame
            self.appName = appName
            self.title = title
        }

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case frame
            case appName
            case title
        }

        public init(from decoder: any Decoder) throws {
            try SeedKeys.reject(decoder, allowing: CodingKeys.allCases.map(\.rawValue))
            let container = try decoder.container(keyedBy: CodingKeys.self)
            frame = try container.decode(ScreenRect.self, forKey: .frame)
            appName = try container.decode(String.self, forKey: .appName)
            title = try container.decodeIfPresent(String.self, forKey: .title)
        }
    }

    /// 起動後に出しておくもの。
    public enum OpenView: String, Codable, Equatable, Sendable {
        /// ボタン類が出ていて、枠を描ける状態（`drawing`）。
        case toolbar
        /// 一覧を開いた状態（`listOpen`）。
        case list
    }

    /// 起動時に作る、確定済みの注釈。
    public struct Annotation: Codable, Equatable, Sendable {
        /// コメント。空白と改行だけのものは起動エラー。
        public var comment: String
        /// 描いた枠（画面全体を通した、左上が原点の矩形。pt）。撮る範囲は、枠内に見えている `windows` から決まる（なければ枠のまわり）。
        public var rect: ScreenRect

        /// 値をそのまま持つ。
        public init(comment: String, rect: ScreenRect) {
            self.comment = comment
            self.rect = rect
        }

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case comment
            case rect
        }

        public init(from decoder: any Decoder) throws {
            try SeedKeys.reject(decoder, allowing: CodingKeys.allCases.map(\.rawValue))
            let container = try decoder.container(keyedBy: CodingKeys.self)
            comment = try container.decode(String.self, forKey: .comment)
            rect = try container.decode(ScreenRect.self, forKey: .rect)
        }
    }

    /// 設定の一部。nil の項目は保存済みの値のまま。
    public struct SettingsPatch: Codable, Equatable, Sendable {
        public var language: Language?
        public var hotkey: KeyboardShortcut?
        public var confirmKey: ConfirmKey?
        /// 書き換える言語ごとの定型文。キーは `en` / `ja`。書いていない言語は保存済みの値のまま。
        public var boilerplates: [String: String]?
        public var imageRetentionDays: Int?
        public var setupCompleted: Bool?

        /// 何も変えない。
        public init() {}

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case language
            case hotkey
            case confirmKey
            case boilerplates
            case imageRetentionDays
            case setupCompleted
        }

        public init(from decoder: any Decoder) throws {
            try SeedKeys.reject(decoder, allowing: CodingKeys.allCases.map(\.rawValue))
            let container = try decoder.container(keyedBy: CodingKeys.self)
            language = try container.decodeIfPresent(Language.self, forKey: .language)
            hotkey = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .hotkey)
            confirmKey = try container.decodeIfPresent(ConfirmKey.self, forKey: .confirmKey)
            boilerplates = try container.decodeIfPresent([String: String].self, forKey: .boilerplates)
            if let boilerplates {
                let unknown = boilerplates.keys.filter { Language(rawValue: $0) == nil }.sorted()
                guard unknown.isEmpty else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .boilerplates,
                        in: container,
                        debugDescription: "知らない言語: \(unknown.joined(separator: ", "))"
                    )
                }
            }
            imageRetentionDays = try container.decodeIfPresent(Int.self, forKey: .imageRetentionDays)
            setupCompleted = try container.decodeIfPresent(Bool.self, forKey: .setupCompleted)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(language, forKey: .language)
            try container.encodeIfPresent(hotkey, forKey: .hotkey)
            try container.encodeIfPresent(confirmKey, forKey: .confirmKey)
            try container.encodeIfPresent(boilerplates, forKey: .boilerplates)
            try container.encodeIfPresent(imageRetentionDays, forKey: .imageRetentionDays)
            try container.encodeIfPresent(setupCompleted, forKey: .setupCompleted)
        }

        /// `settings` に、書いた項目だけを重ねた設定。
        public func applied(to settings: Settings) -> Settings {
            var result = settings
            if let language {
                result.language = language
            }
            if let hotkey {
                result.hotkey = hotkey
            }
            if let confirmKey {
                result.confirmKey = confirmKey
            }
            for (key, text) in boilerplates ?? [:] {
                if let language = Language(rawValue: key) {
                    result.setBoilerplate(text, for: language)
                }
            }
            if let imageRetentionDays {
                result.imageRetentionDays = imageRetentionDays
            }
            if let setupCompleted {
                result.setupCompleted = setupCompleted
            }
            return result
        }
    }

    /// 起動時の前提を読めなかったとき。
    public enum ParseError: Error, Equatable, Sendable {
        /// JSON として読めない、または形が違う。値は理由。
        case invalid(String)
    }

    /// `windows` を省いたときの、偽の撮影が返すウィンドウ。E2E の SampleTarget（`SAMPLE_FRAME` の既定）と同じ位置・大きさ。
    public static let defaultWindows = [
        Window(frame: ScreenRect(x: 140, y: 64, width: 1000, height: 660), appName: "Sample App", title: "Sample App"),
    ]

    /// 保存済みの設定に重ねる項目。nil なら設定には触らない。
    public var settings: SettingsPatch?
    /// 画面収録の許可。nil なら `granted`。
    public var screenRecording: ScreenRecording?
    /// 偽の撮影が返すウィンドウ。nil なら `defaultWindows`。
    public var windows: [Window]?
    /// 確定済みの注釈。
    public var annotations: [Annotation]
    /// 起動後に出しておくもの。nil なら、注釈の有無で決まる状態のまま。
    public var open: OpenView?

    /// 何も指定しない前提。
    public init(
        settings: SettingsPatch? = nil,
        screenRecording: ScreenRecording? = nil,
        windows: [Window]? = nil,
        annotations: [Annotation] = [],
        open: OpenView? = nil
    ) {
        self.settings = settings
        self.screenRecording = screenRecording
        self.windows = windows
        self.annotations = annotations
        self.open = open
    }

    /// 画面収録の許可があるか（省いたときは許可あり）。
    public var isScreenRecordingGranted: Bool {
        screenRecording != .denied
    }

    /// 偽の撮影が返すウィンドウ（省いたときは `defaultWindows`）。
    public var fixtureWindows: [CaptureWindow] {
        (windows ?? Self.defaultWindows).enumerated().map { index, window in
            CaptureWindow(id: UInt32(index + 1), frame: window.frame, appName: window.appName, title: window.title)
        }
    }

    /// `AKAPEN_SEED` の JSON を読む。形が違えば `ParseError.invalid`。
    public static func parse(_ json: String) throws -> LaunchSeed {
        do {
            return try JSONDecoder().decode(Document.self, from: Data(json.utf8)).seed
        } catch let error as DecodingError {
            throw ParseError.invalid(Self.describe(error))
        } catch {
            throw ParseError.invalid(String(describing: error))
        }
    }

    /// 環境変数に入れる JSON にする（テストとヘルパー用）。
    public func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(Document(self)), as: UTF8.self)
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case let .dataCorrupted(context):
            return "\(path(context.codingPath)): \(context.debugDescription)"
        case let .keyNotFound(key, context):
            return "\(path(context.codingPath + [key])): 必要なキーがない"
        case let .typeMismatch(_, context):
            return "\(path(context.codingPath)): \(context.debugDescription)"
        case let .valueNotFound(_, context):
            return "\(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return String(describing: error)
        }
    }

    private static func path(_ keys: [any CodingKey]) -> String {
        let parts = keys.map { key in
            key.intValue.map { "[\($0)]" } ?? key.stringValue
        }
        return parts.isEmpty ? "(先頭)" : parts.joined(separator: ".")
    }
}

/// JSON の一番外側。知らないキーを断るために、`LaunchSeed` とは別の型で読み書きする。
private struct Document: Codable {
    var seed: LaunchSeed

    init(_ seed: LaunchSeed) {
        self.seed = seed
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case settings
        case screenRecording
        case windows
        case annotations
        case open
    }

    init(from decoder: any Decoder) throws {
        try SeedKeys.reject(decoder, allowing: CodingKeys.allCases.map(\.rawValue))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seed = LaunchSeed(
            settings: try container.decodeIfPresent(LaunchSeed.SettingsPatch.self, forKey: .settings),
            screenRecording: try container.decodeIfPresent(LaunchSeed.ScreenRecording.self, forKey: .screenRecording),
            windows: try container.decodeIfPresent([LaunchSeed.Window].self, forKey: .windows),
            annotations: try container.decodeIfPresent([LaunchSeed.Annotation].self, forKey: .annotations) ?? [],
            open: try container.decodeIfPresent(LaunchSeed.OpenView.self, forKey: .open)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(seed.settings, forKey: .settings)
        try container.encodeIfPresent(seed.screenRecording, forKey: .screenRecording)
        try container.encodeIfPresent(seed.windows, forKey: .windows)
        if !seed.annotations.isEmpty {
            try container.encode(seed.annotations, forKey: .annotations)
        }
        try container.encodeIfPresent(seed.open, forKey: .open)
    }
}

/// 知らないキーを断る。
private enum SeedKeys {
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    static func reject(_ decoder: any Decoder, allowing known: [String]) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        let unknown = container.allKeys.map(\.stringValue).filter { !known.contains($0) }.sorted()
        guard unknown.isEmpty else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "知らないキー: \(unknown.joined(separator: ", "))"
            ))
        }
    }
}
