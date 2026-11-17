import Foundation
import AkapenCore

/// 設定をメモリにだけ保持する骨組み用の実装。
@MainActor public final class MemorySettingsStore: SettingsStore {
    private var value: Settings
    public init(_ value: Settings = Settings()) { self.value = value }
    public func load() throws -> Settings { value }
    public func save(_ settings: Settings) throws { value = settings }
}
/// 指定ファイルへ JSON 等の診断データを原子的に保存する。
@MainActor public final class AtomicStateWriter: StateWriting {
    private let url: URL
    public init(url: URL) { self.url = url }
    public func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
