import Darwin
import Foundation
import AkapenCore

/// 画像を `<root>/<回の ID>/<番号>.png` に保存し、古い回を掃除する。
///
/// 置き場の決め方は `CacheLayout` に従う。`root` の外のファイルには触らない。
@MainActor public final class FileImageStore: ImageStore {
    /// 保存と削除で起きるエラー。
    public enum StoreError: Error, Equatable {
        /// 回の ID が `CacheLayout` の形をしていない。
        case invalidSessionID(String)
        /// 番号が 1 より小さい。
        case invalidIndex(Int)
        /// 空いている番号が見つからなかった。
        case noAvailableIndex
        /// 指定された URL が `root` の下を指していない。
        case outsideRoot(URL)
        /// 指定された URL がファイルではない（フォルダなど）。
        case notAFile(URL)
    }

    /// 番号を探す上限。これより先は `noAvailableIndex` にする。
    private static let maximumIndexAttempts = 10_000

    /// 画像の置き場の根。
    public let root: URL

    private let timeZone: TimeZone

    /// 置き場の根と、回の ID を日時に戻すときのタイムゾーンを渡す。
    public init(root: URL, timeZone: TimeZone) {
        self.root = root
        self.timeZone = timeZone
    }

    /// 本番の置き場 `~/Library/Caches/akapen/`。
    public static func defaultRoot() -> URL {
        URL.cachesDirectory.appending(path: "akapen", directoryHint: .isDirectory)
    }

    /// 原子的に書く。既にあるファイルは上書きせず、空いている次の番号で保存して、実際に書いた URL を返す。
    public func save(png: Data, sessionID: String, index: Int) throws -> URL {
        guard CacheLayout.date(fromSessionID: sessionID, timeZone: timeZone) != nil else {
            throw StoreError.invalidSessionID(sessionID)
        }
        guard index >= 1 else {
            throw StoreError.invalidIndex(index)
        }
        let directory = root.appending(path: sessionID, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appending(path: ".\(UUID().uuidString).tmp", directoryHint: .notDirectory)
        try png.write(to: temporary, options: .withoutOverwriting)
        defer {
            try? FileManager.default.removeItem(at: temporary)
        }
        for candidate in index..<(index + Self.maximumIndexAttempts) {
            let destination = directory.appending(
                path: CacheLayout.fileName(index: candidate),
                directoryHint: .notDirectory
            )
            if try Self.moveWithoutOverwriting(from: temporary, to: destination) {
                return destination
            }
        }
        throw StoreError.noAvailableIndex
    }

    /// `root` の下のファイルを 1 つ消す。`root` の外を指す URL（`..` やシンボリックリンクで外に出るものを含む）はエラーにする。
    /// ファイルがなければ、ファイル操作のエラーをそのまま投げる。
    public func remove(at url: URL) throws {
        guard url.isFileURL else {
            throw StoreError.outsideRoot(url)
        }
        let standardized = url.standardizedFileURL
        let name = standardized.lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", name != "/" else {
            throw StoreError.outsideRoot(url)
        }
        guard let rootPath = Self.canonicalPath(root.path(percentEncoded: false)),
              let parentPath = Self.canonicalPath(standardized.deletingLastPathComponent().path(percentEncoded: false)),
              Self.isSameOrDescendant(parentPath, of: rootPath) else {
            throw StoreError.outsideRoot(url)
        }
        let target = URL(filePath: parentPath, directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .notDirectory)
        var status = stat()
        if lstat(target.path(percentEncoded: false), &status) == 0, (status.st_mode & S_IFMT) == S_IFDIR {
            throw StoreError.notAFile(url)
        }
        try FileManager.default.removeItem(at: target)
    }

    /// `CacheLayout` で「`date` より前に始まった回」と判定されたフォルダだけを消す。
    /// 回の ID の形をしていない名前や、フォルダでないもの（シンボリックリンクを含む）には触らない。
    /// 消せなかったフォルダがあっても残りを続け、最後に最初のエラーを投げる。
    public func removeSessions(before date: Date) throws {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false))
        } catch CocoaError.fileReadNoSuchFile {
            return
        }
        var firstError: (any Error)?
        for sessionID in CacheLayout.sessionIDs(names, olderThan: date, timeZone: timeZone) {
            let directory = root.appending(path: sessionID, directoryHint: .isDirectory)
            var status = stat()
            guard lstat(directory.path(percentEncoded: false), &status) == 0,
                  (status.st_mode & S_IFMT) == S_IFDIR else {
                continue
            }
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError {
            throw firstError
        }
    }

    /// 移動先が空いていれば原子的に移して true。既にあれば何もせず false。
    private static func moveWithoutOverwriting(from source: URL, to destination: URL) throws -> Bool {
        let result = renamex_np(
            source.path(percentEncoded: false),
            destination.path(percentEncoded: false),
            UInt32(RENAME_EXCL)
        )
        if result == 0 {
            return true
        }
        let code = errno
        if code == EEXIST {
            return false
        }
        throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }

    /// シンボリックリンクと `..` を解いた絶対パス。存在しなければ nil。
    private static func canonicalPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else {
            return nil
        }
        defer {
            free(resolved)
        }
        return String(cString: resolved)
    }

    private static func isSameOrDescendant(_ path: String, of ancestor: String) -> Bool {
        if path == ancestor {
            return true
        }
        let prefix = ancestor.hasSuffix("/") ? ancestor : ancestor + "/"
        return path.hasPrefix(prefix)
    }
}
