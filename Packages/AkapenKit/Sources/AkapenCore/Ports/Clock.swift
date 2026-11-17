import Foundation

/// 時刻と待機。テストでは固定時刻と制御可能な待機を差す。
@MainActor public protocol Clock {
    var now: Date { get }

    /// キャンセル可能な待機。固定時計の実装ではテスト側が進行を制御する。
    func sleep(for duration: Duration) async throws
}
