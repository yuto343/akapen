import Foundation
import AkapenCore

/// 時刻だけを固定した時計。E2E で回の ID と古い回の判定を決まった値にする。
///
/// `sleep` は実時間で待つ。時刻を固定しても、コピー完了の表示は決まった時間で消える。
@MainActor public final class FixedClock: Clock {
    /// 常に返す時刻。
    public let now: Date

    /// 返す時刻を固定して作る。
    public init(now: Date) {
        self.now = now
    }

    /// 実時間で待つ。キャンセルされたら `CancellationError` を投げる。
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
