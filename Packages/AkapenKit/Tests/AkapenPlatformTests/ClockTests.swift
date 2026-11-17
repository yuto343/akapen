import Foundation
import Testing
import AkapenPlatform

@MainActor
struct ClockTests {
    @Test
    func fixedClockReturnsSameTime() async throws {
        let fixed = Date(timeIntervalSince1970: 1_795_000_000)
        let clock = FixedClock(now: fixed)
        #expect(clock.now == fixed)
        try await clock.sleep(for: .milliseconds(10))
        #expect(clock.now == fixed)
    }

    @Test
    func fixedClockSleepsInRealTime() async throws {
        let clock = FixedClock(now: Date(timeIntervalSince1970: 0))
        let started = ContinuousClock.now
        try await clock.sleep(for: .milliseconds(100))
        #expect(ContinuousClock.now - started >= .milliseconds(100))
    }

    @Test
    func fixedClockSleepIsCancellable() async throws {
        let clock = FixedClock(now: Date(timeIntervalSince1970: 0))
        let task = Task { @MainActor in
            try await clock.sleep(for: .seconds(60))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test
    func systemClockFollowsRealTime() {
        let clock = SystemClock()
        let before = Date()
        let now = clock.now
        let after = Date()
        #expect(before <= now)
        #expect(now <= after)
    }
}
