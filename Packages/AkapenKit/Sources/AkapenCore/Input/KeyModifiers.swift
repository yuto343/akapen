/// プラットフォーム非依存の修飾キー集合。
public struct KeyModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt32

    /// 保存済みビット集合から復元する。
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = Self(rawValue: 1)
    public static let shift = Self(rawValue: 2)
    public static let option = Self(rawValue: 4)
    public static let control = Self(rawValue: 8)
}
