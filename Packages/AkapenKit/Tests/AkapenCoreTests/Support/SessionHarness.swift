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

    /// 枠を描き終え、撮影と保存が終わって書きかけに反映されるまで待つ。
    func drag(_ rect: ScreenRect = SessionHarness.frame) async {
        await send(.dragEnded(rect: rect, screen: Self.screen))
        await finishCapture()
    }

    /// 枠を描き終えた入力の処理だけを待つ（撮影の完了は待たない）。
    func dragWithoutWaitingForCapture(_ rect: ScreenRect = SessionHarness.frame) async {
        await send(.dragEnded(rect: rect, screen: Self.screen))
    }

    /// 撮影中の書きかけがあれば、その撮影の完了が状態に反映されるまで待つ。
    func finishCapture() async {
        await model.captureCompletion?.value
    }

    /// 先読みしているウィンドウの一覧の取得が終わるまで待つ。
    func finishListing() async {
        _ = await model.windowListing?.value
    }

    /// 枠を描ける状態にして（何も出ていなければホットキー、一覧が開いていれば閉じる）、枠を描いてコメントを確定するまで。
    /// 確定すると `drawing` に戻る。
    func annotate(_ comment: String, rect: ScreenRect = SessionHarness.frame) async {
        switch model.phase {
        case .hidden, .copied:
            await send(.hotkeyPressed)
        case .listOpen:
            await send(.listToggled)
        case .drawing, .commenting:
            break
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
