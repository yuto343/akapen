import Foundation
import AkapenCore

/// 設定を保存する JSON の形。保存先が違っても同じ形にする。
enum SettingsCoding {
    static func encode(_ settings: Settings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    static func decode(_ data: Data) throws -> Settings {
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            throw SettingsStoreError.corrupted(String(describing: error))
        }
    }
}

/// 保存された設定を読めないときのエラー。
public enum SettingsStoreError: Error, Equatable {
    /// 保存内容が設定の JSON として読めない。値は読めなかった理由。
    case corrupted(String)
}
