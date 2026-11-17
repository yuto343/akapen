import AppKit
import AkapenCore
@testable import AkapenUI

/// 画面収録の許可の偽物。`isGranted` を書き換えて、許可が取れた・外れたを作る。
@MainActor final class FakePermission: ScreenRecordingPermission {
    var isGranted: Bool
    /// 呼ばれた順（`request` / `openSystemSettings`）。
    private(set) var calls: [String] = []

    init(isGranted: Bool = false) {
        self.isGranted = isGranted
    }

    func request() -> Bool {
        calls.append("request")
        return isGranted
    }

    func openSystemSettings() {
        calls.append("openSystemSettings")
    }
}

/// `SessionModel` の代わりに設定を持ち、送られた入力を記録する。`settingsChanged` と `setupCompleted` は設定に当てる。
@MainActor final class SettingsSink {
    var settings: Settings
    let log = EventLog()

    init(_ settings: Settings = Settings()) {
        self.settings = settings
    }

    var send: @MainActor (SessionEvent) -> Void {
        { [self] event in
            log.append(event)
            switch event {
            case let .settingsChanged(newSettings):
                settings = newSettings
            case .setupCompleted:
                settings.setupCompleted = true
            default:
                break
            }
        }
    }

    /// 送られた `settingsChanged` の設定（送った順）。
    var sentSettings: [Settings] {
        log.events.compactMap { event in
            if case let .settingsChanged(settings) = event {
                return settings
            }
            return nil
        }
    }
}

/// テストで使う仮想キーコード（US 配列）。
enum TestKey {
    static let j: UInt16 = 38
    static let k: UInt16 = 40
    static let semicolon: UInt16 = 41
    static let space: UInt16 = 49
    static let f5: UInt16 = 96
}

extension ShortcutText {
    /// 手元のキーボード配列に左右されない表示（US 配列の表）。
    @MainActor static var ansi: ShortcutText {
        ShortcutText(keyNames: ANSIKeyNames())
    }
}

/// 条件が満たされるまで、少しずつ待つ。`timeout` を過ぎたら false。
@MainActor func waitUntil(timeout: Duration = .seconds(3), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// SwiftUI の描画と、`Task` に回した処理が進むのを少し待つ。
@MainActor func settle() async {
    for _ in 0..<5 {
        await Task.yield()
    }
    try? await Task.sleep(for: .milliseconds(50))
}
