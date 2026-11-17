import Foundation
import AkapenCore

/// 画像をメモリに持つ偽物。パスは実在しない固定のフォルダの下に作る。
@MainActor final class FakeImageStore: ImageStore {
    static let root = "/akapen-test-cache"

    /// 保存された画像。キーは絶対パス。
    var files: [String: Data] = [:]
    var saveCalls: [(sessionID: String, index: Int)] = []
    var removedPaths: [String] = []
    var removedBefore: [Date] = []
    var saveError: TestError?
    var removeError: TestError?

    func save(png: Data, sessionID: String, index: Int) throws -> URL {
        saveCalls.append((sessionID, index))
        if let saveError {
            throw saveError
        }
        let path = "\(Self.root)/\(sessionID)/\(CacheLayout.fileName(index: index))"
        files[path] = png
        return URL(filePath: path)
    }

    func remove(at url: URL) throws {
        let path = url.path(percentEncoded: false)
        removedPaths.append(path)
        if let removeError {
            throw removeError
        }
        files[path] = nil
    }

    func removeSessions(before date: Date) throws {
        removedBefore.append(date)
    }
}
