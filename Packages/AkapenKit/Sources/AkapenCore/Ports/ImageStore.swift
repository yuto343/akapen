import Foundation

/// PNG の保存と削除。before より古い回の画像を掃除する。
@MainActor public protocol ImageStore {
    /// 同じ回の index 番目（1 始まり）に保存し、絶対 URL を返す。
    func save(png: Data, sessionID: String, index: Int) throws -> URL

    /// 未確定注釈などの画像を削除する。
    func remove(at url: URL) throws

    /// 指定日時より古い回のフォルダを削除する。
    func removeSessions(before date: Date) throws
}
