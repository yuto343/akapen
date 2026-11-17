import Foundation
import AkapenCore

/// 実際の時刻と、実時間の待機。
@MainActor public final class SystemClock: Clock {
    public init() {}

    public var now: Date {
        Date()
    }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
