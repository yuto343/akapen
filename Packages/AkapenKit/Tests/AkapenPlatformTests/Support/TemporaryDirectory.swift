import Foundation

/// テストごとの一時ディレクトリ。`remove()` で中身ごと消す。
struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "akapen-platform-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    func child(_ path: String) -> URL {
        url.appending(path: path)
    }
}
