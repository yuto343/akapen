/// 永続化する設定。既定は英語、Enter 確定、7 日保存。
public struct Settings: Codable, Equatable, Sendable {
    public var language: Language = .en
    public var hotkey = KeyboardShortcut()
    public var toolbarShortcut: KeyboardShortcut?
    public var confirmKey: ConfirmKey = .enter
    public var boilerplates: [String: String] = [
        "en": "I annotated the screen. Please address the comments below.\nOpen every image and check the area marked with the red frame before you start.",
        "ja": "画面に注釈を付けました。以下のコメントに対応してください。\n作業前にすべての画像を開き、赤枠の箇所を確認してください。",
    ]
    public var imageRetentionDays: Int = 7
    /// 初回のセットアップを終えたか。
    public var setupCompleted: Bool = false

    /// DESIGN.md に定めた既定値で初期化する。
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case language
        case hotkey
        case toolbarShortcut
        case confirmKey
        case boilerplates
        case imageRetentionDays
        case setupCompleted
    }

    /// 欠けているキーは既定値で補う。古い保存内容でも読める。
    public init(from decoder: any Decoder) throws {
        let defaults = Settings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(Language.self, forKey: .language) ?? defaults.language
        hotkey = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .hotkey) ?? defaults.hotkey
        toolbarShortcut = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .toolbarShortcut)
        confirmKey = try container.decodeIfPresent(ConfirmKey.self, forKey: .confirmKey) ?? defaults.confirmKey
        boilerplates = try container.decodeIfPresent([String: String].self, forKey: .boilerplates) ?? defaults.boilerplates
        imageRetentionDays = try container.decodeIfPresent(Int.self, forKey: .imageRetentionDays) ?? defaults.imageRetentionDays
        setupCompleted = try container.decodeIfPresent(Bool.self, forKey: .setupCompleted) ?? defaults.setupCompleted
    }
}
