import AkapenCore

/// メモリに設定を持つ偽物。保存の失敗を起こせる。
@MainActor final class FakeSettingsStore: SettingsStore {
    var stored: Settings
    var saved: [Settings] = []
    var saveError: TestError?

    init(_ settings: Settings = Settings()) {
        stored = settings
    }

    func load() throws -> Settings {
        stored
    }

    func save(_ settings: Settings) throws {
        if let saveError {
            throw saveError
        }
        stored = settings
        saved.append(settings)
    }
}
