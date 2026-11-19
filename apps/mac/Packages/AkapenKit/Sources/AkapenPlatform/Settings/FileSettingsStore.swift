import Foundation
import AkapenCore

/// 設定を JSON ファイル 1 つに保存する。E2E でテストごとの一時ディレクトリに置く。
@MainActor public final class FileSettingsStore: SettingsStore {
    /// 保存先のファイル。
    public let url: URL

    /// 保存先のファイルを渡す。親のフォルダは保存のときに作る。
    public init(url: URL) {
        self.url = url
    }

    /// ファイルがなければ既定値。設定として読めない内容は `SettingsStoreError.corrupted`。
    public func load() throws -> Settings {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            return Settings()
        }
        return try SettingsCoding.decode(data)
    }

    /// ファイル全体を原子的に置き換える。
    public func save(_ settings: Settings) throws {
        let data = try SettingsCoding.encode(settings)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
