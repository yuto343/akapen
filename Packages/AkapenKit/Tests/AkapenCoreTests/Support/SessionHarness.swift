import Foundation
@testable import AkapenCore

/// SessionModel と偽物一式。時計は 2026-11-18 14:32:10（東京）で止めてある。
@MainActor final class SessionHarness {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    /// 2026-11-18 05:32:10 UTC。
    static let start = Date(timeIntervalSince1970: 1_794_979_930)
    static let sessionID = "20261118-1432"

    let settingsStore: FakeSettingsStore
    let capturer: FakeCapturer
    let images = FakeImageStore()
    let pasteboard = FakePasteboard()
    let clock = ManualClock(now: SessionHarness.start)
    let model: SessionModel
    private(set) var changeCount = 0

    /// 枠を描く位置。`FakeCapturer.sampleWindow` の内側。
    static let frame = ScreenRect(x: 150, y: 100, width: 100, height: 50)

    static let screen = ScreenDescriptor(id: 1, frame: ScreenRect(x: 0, y: 0, width: 1440, height: 900))

    init(settings: Settings = Settings(), windows: [CaptureWindow] = [FakeCapturer.sampleWindow]) throws {
        settingsStore = FakeSettingsStore(settings)
        capturer = FakeCapturer(windows: windows)
        model = try SessionModel(
            settingsStore: settingsStore,
            capturing: capturer,
            pasteboard: pasteboard,
            images: images,
            clock: clock,
            timeZone: Self.timeZone
        )
        model.onChange = { [weak self] in
            self?.changeCount += 1
        }
    }

    func send(_ event: SessionEvent) async {
        await model.send(event).value
    }

    func drag(_ rect: ScreenRect = SessionHarness.frame) async {
        await send(.dragEnded(rect: rect, screen: Self.screen))
    }

    /// ホットキーから、枠を描いてコメントを確定するまで。
    func annotate(_ comment: String, rect: ScreenRect = SessionHarness.frame) async {
        if model.phase == .idle || model.phase == .listOpen {
            await send(.addTapped)
        } else {
            await send(.hotkeyPressed)
        }
        await drag(rect)
        await send(.commentConfirmed(text: comment))
    }

    /// コピー完了の表示を消すタイマーを、時計を進めて発火させ、処理が終わるまで待つ。
    func expireCopiedTimer(after duration: Duration = SessionModel.copiedDisplayDuration) async {
        await clock.waitForSleeper()
        let timer = model.copiedTimer
        clock.advance(by: duration)
        await timer?.value
    }
}
