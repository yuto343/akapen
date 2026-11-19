import Foundation
import AkapenCore

/// 設定全体を JSON にして、`UserDefaults` の 1 つのキーに保存する。
@MainActor public final class UserDefaultsSettingsStore: SettingsStore {
    /// 設定を置くキー。
    public static let key = "settings"

    private let defaults: UserDefaults

    /// 保存先の `UserDefaults` を渡す。本番では `.standard`、テストでは専用のスイート。
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 未保存なら既定値。データでない値や、設定として読めない JSON は `SettingsStoreError.corrupted`。
    public func load() throws -> Settings {
        guard let value = defaults.object(forKey: Self.key) else {
            return Settings()
        }
        guard let data = value as? Data else {
            throw SettingsStoreError.corrupted("値がデータではない: \(type(of: value))")
        }
        return try SettingsCoding.decode(data)
    }

    public func save(_ settings: Settings) throws {
        defaults.set(try SettingsCoding.encode(settings), forKey: Self.key)
    }
}
