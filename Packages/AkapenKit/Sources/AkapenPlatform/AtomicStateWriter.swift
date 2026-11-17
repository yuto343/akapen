import Foundation
import AkapenCore

/// 指定ファイルへ JSON 等の診断データを原子的に保存する。
@MainActor public final class AtomicStateWriter: StateWriting {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
