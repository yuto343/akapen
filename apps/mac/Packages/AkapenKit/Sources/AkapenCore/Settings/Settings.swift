/// 永続化する設定。既定は英語、Enter 確定、7 日保存。
public struct Settings: Codable, Equatable, Sendable {
    public var language: Language = .en
    public var hotkey = KeyboardShortcut()
    public var confirmKey: ConfirmKey = .enter
    /// 書き換えた定型文。nil なら表示言語の既定文を使う。
    public var customBoilerplate: String?
    public var imageRetentionDays: Int = 7
    /// 初回のセットアップを終えたか。
    public var setupCompleted: Bool = false

    /// DESIGN.md に定めた既定値で初期化する。
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case language
        case hotkey
        case confirmKey
        case boilerplates
        case customBoilerplate
        case imageRetentionDays
        case setupCompleted
    }

    /// 欠けているキーは既定値で補い、知らないキー（古い版の `toolbarShortcut` など）は無視する。古い保存内容でも読める。
    public init(from decoder: any Decoder) throws {
        let defaults = Settings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(Language.self, forKey: .language) ?? defaults.language
        hotkey = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .hotkey) ?? defaults.hotkey
        confirmKey = try container.decodeIfPresent(ConfirmKey.self, forKey: .confirmKey) ?? defaults.confirmKey
        if container.contains(.customBoilerplate) {
            customBoilerplate = try container.decodeIfPresent(String.self, forKey: .customBoilerplate)
        } else if let legacy = try container.decodeIfPresent([String: String].self, forKey: .boilerplates),
                  let text = legacy[language.rawValue] {
            setBoilerplate(text, for: language)
        }
        imageRetentionDays = try container.decodeIfPresent(Int.self, forKey: .imageRetentionDays) ?? defaults.imageRetentionDays
        setupCompleted = try container.decodeIfPresent(Bool.self, forKey: .setupCompleted) ?? defaults.setupCompleted
    }

    /// 現行の設定形式で保存する。
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(confirmKey, forKey: .confirmKey)
        try container.encode(customBoilerplate, forKey: .customBoilerplate)
        try container.encode(imageRetentionDays, forKey: .imageRetentionDays)
        try container.encode(setupCompleted, forKey: .setupCompleted)
    }

    /// 現在の言語で実際に使う定型文。
    public var effectiveBoilerplate: String {
        boilerplate(for: language)
    }

    /// 指定した言語で実際に使う定型文。カスタム文は全言語で共通。
    public func boilerplate(for language: Language) -> String {
        customBoilerplate ?? Boilerplate.defaultText(for: language)
    }

    /// 共通の定型文を書き換える。空または現在の既定文なら言語追従へ戻す。
    public mutating func setBoilerplate(_ text: String, for language: Language) {
        customBoilerplate = text.isEmpty || text == Boilerplate.defaultText(for: language) ? nil : text
    }
}
