import Foundation
import AkapenCore

/// 時刻が止まった時計。`advance(by:)` を呼んだときだけ進み、期限が来た `sleep` を起こす。
@MainActor final class ManualClock: Clock {
    private(set) var now: Date
    private var sleepers: [Sleeper] = []
    private var nextID = 0
    private var sleepWaiters: [CheckedContinuation<Void, Never>] = []

    private struct Sleeper {
        let id: Int
        let deadline: Date
        let continuation: CheckedContinuation<Void, any Error>
    }

    init(now: Date) {
        self.now = now
    }

    /// 眠っている `sleep` の数。
    var pendingSleepCount: Int {
        sleepers.count
    }

    func sleep(for duration: Duration) async throws {
        nextID += 1
        let id = nextID
        let deadline = now.addingTimeInterval(Self.seconds(duration))
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                let waiters = sleepWaiters
                sleepWaiters = []
                for waiter in waiters {
                    waiter.resume()
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelSleeper(id)
            }
        }
    }

    /// 時刻を進め、期限が来た `sleep` を起こす。
    func advance(by duration: Duration) {
        now = now.addingTimeInterval(Self.seconds(duration))
        let due = sleepers.filter { $0.deadline <= now }
        sleepers.removeAll { $0.deadline <= now }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// `sleep` が 1 つ以上眠るまで待つ。すでに眠っていればすぐに戻る。
    func waitForSleeper() async {
        if !sleepers.isEmpty {
            return
        }
        await withCheckedContinuation { continuation in
            sleepWaiters.append(continuation)
        }
    }

    private func cancelSleeper(_ id: Int) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else {
            return
        }
        let sleeper = sleepers.remove(at: index)
        sleeper.continuation.resume(throwing: CancellationError())
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}
