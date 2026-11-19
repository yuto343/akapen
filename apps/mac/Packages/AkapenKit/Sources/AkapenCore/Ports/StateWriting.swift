import Foundation

/// 状態などの診断データの原子的な保存。実ファイル操作は Platform が担う。
@MainActor public protocol StateWriting {
    /// 読者から途中の内容が見えないように全体を原子的に置き換える。
    func write(_ data: Data) throws
}
