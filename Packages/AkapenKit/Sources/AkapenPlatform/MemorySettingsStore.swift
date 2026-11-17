import Foundation
import AkapenCore

/// 設定をメモリにだけ保持する骨組み用の実装。
@MainActor public final class MemorySettingsStore: SettingsStore {
    private var value: Settings

    public init(_ value: Settings = Settings()) {
        self.value = value
    }

    public func load() throws -> Settings {
        value
    }

    public func save(_ settings: Settings) throws {
        value = settings
    }
}
