import AppKit
import Testing
import AkapenCore
import AkapenAXID
@testable import AkapenUI

/// 初回のセットアップ。ページの行き来、許可の待ち受け、`Done` と閉じたときの違い、ホットキーの保存。
@Suite(.serialized)
@MainActor
struct SetupTests {
    private let optionCommandK = KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.option, .command])

    private func makeController(
        _ sink: SettingsSink,
        permission: FakePermission,
        canUseHotkey: @escaping @MainActor (KeyboardShortcut) -> Bool = { _ in true }
    ) -> SetupController {
        _ = NSApplication.shared
        return SetupController(
            settings: {
                sink.settings
            },
            send: sink.send,
            permission: permission,
            canUseHotkey: canUseHotkey,
            shortcutText: .ansi,
            pollInterval: .milliseconds(20),
            activatesApp: false
        )
    }

    @Test
    func startsOnTheHotkeyPageAndMovesBetweenPages() async throws {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission())
        defer { controller.close() }
        controller.show()
        #expect(controller.isShown)
        #expect(controller.window.accessibilityIdentifier() == AXID.Setup.window)
        #expect(controller.flow.page == .hotkey)
        #expect(controller.flow.primaryAction == .next)
        await settle()
        let firstFrame = controller.window.frame
        controller.flow.goNext()
        #expect(controller.flow.page == .permission)
        #expect(controller.flow.primaryAction == .openSystemSettings)
        await settle()
        // Paper の App 07 は 560×586、App 08 は 560×524。上端の位置は変えずに縮む。
        #expect(firstFrame.width == Tokens.Setup.width)
        #expect(abs(firstFrame.height - 586) <= 1)
        #expect(abs(controller.window.frame.height - 524) <= 1)
        #expect(controller.window.frame.maxY == firstFrame.maxY)
        controller.flow.goBack()
        #expect(controller.flow.page == .hotkey)
        #expect(controller.flow.primaryAction == .next)
        #expect(sink.log.events.isEmpty)
    }

    @Test
    func permissionIsPolledWhileOnTheSecondPage() async {
        let sink = SettingsSink()
        let permission = FakePermission(isGranted: false)
        let controller = makeController(sink, permission: permission)
        defer { controller.close() }
        controller.show()
        controller.flow.goNext()
        let strings = UIStrings(language: .en)
        #expect(strings[controller.flow.permissionStatus] == "Waiting…")
        #expect(controller.flow.primaryAction == .openSystemSettings)
        permission.isGranted = true
        #expect(await waitUntil {
            controller.flow.isGranted
        })
        #expect(strings[controller.flow.permissionStatus] == "Granted")
        #expect(controller.flow.primaryAction == .done)
        permission.isGranted = false
        #expect(await waitUntil {
            !controller.flow.isGranted
        })
        #expect(controller.flow.primaryAction == .openSystemSettings)
    }

    @Test
    func permissionIsNotPolledOnTheFirstPage() async {
        let sink = SettingsSink()
        let permission = FakePermission(isGranted: false)
        let controller = makeController(sink, permission: permission)
        defer { controller.close() }
        controller.show()
        permission.isGranted = true
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!controller.flow.isGranted)
        controller.flow.goNext()
        #expect(controller.flow.isGranted)
    }

    @Test
    func openSystemSettingsRequestsThenOpens() {
        let sink = SettingsSink()
        let permission = FakePermission(isGranted: false)
        let controller = makeController(sink, permission: permission)
        defer { controller.close() }
        controller.show()
        controller.flow.goNext()
        controller.flow.openSystemSettings()
        #expect(permission.calls == ["request", "openSystemSettings"])
        #expect(sink.log.events.isEmpty)
    }

    @Test
    func doneSendsSetupCompletedAndCloses() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission(isGranted: true))
        var completed = 0
        var dismissed = 0
        controller.onCompleted = {
            completed += 1
        }
        controller.onDismissed = {
            dismissed += 1
        }
        controller.show()
        controller.flow.goNext()
        #expect(controller.flow.isGranted)
        controller.flow.done()
        #expect(sink.log.names == ["setupCompleted"])
        #expect(sink.settings.setupCompleted)
        #expect(!controller.isShown)
        #expect(completed == 1)
        #expect(dismissed == 0)
    }

    @Test
    func doneDoesNothingWithoutPermission() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission(isGranted: false))
        defer { controller.close() }
        controller.show()
        controller.flow.goNext()
        controller.flow.done()
        #expect(sink.log.events.isEmpty)
        #expect(controller.isShown)
    }

    @Test
    func closingDoesNotCompleteSetup() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission(isGranted: true))
        var completed = 0
        var dismissed = 0
        controller.onCompleted = {
            completed += 1
        }
        controller.onDismissed = {
            dismissed += 1
        }
        controller.show()
        controller.flow.goNext()
        controller.window.performClose(nil)
        #expect(!controller.isShown)
        #expect(sink.log.events.isEmpty)
        #expect(!sink.settings.setupCompleted)
        #expect(completed == 0)
        #expect(dismissed == 1)
    }

    /// ページが変わるたびに知らせる（組み立ての側が `state.json` の `windows.setupPage` を書き直すため）。
    @Test
    func pageChangesAreReported() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission(isGranted: false))
        defer { controller.close() }
        var pages: [Bool] = []
        controller.onPageChanged = { [controller] in
            pages.append(controller.isShowingPermission)
        }
        controller.show()
        #expect(pages.isEmpty)
        controller.flow.goNext()
        #expect(pages == [true])
        controller.flow.goNext()
        #expect(pages == [true])
        controller.flow.goBack()
        #expect(pages == [true, false])
        controller.showPermission()
        #expect(pages == [true, false, true])
    }

    @Test
    func reopeningStartsFromTheFirstPage() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission(isGranted: false))
        defer { controller.close() }
        controller.show()
        controller.flow.goNext()
        controller.close()
        controller.show()
        #expect(controller.flow.page == .hotkey)
    }

    @Test
    func recordedHotkeyIsSavedRightAway() {
        var initial = Settings()
        initial.imageRetentionDays = 30
        let sink = SettingsSink(initial)
        var asked: [KeyboardShortcut] = []
        let controller = makeController(sink, permission: FakePermission(), canUseHotkey: { candidate in
            asked.append(candidate)
            return true
        })
        defer { controller.close() }
        controller.show()
        controller.flow.hotkey.beginRecording()
        controller.flow.hotkey.handle(keyCode: TestKey.k, flags: [.command, .option])
        #expect(asked == [optionCommandK])
        #expect(sink.sentSettings.map(\.hotkey) == [optionCommandK])
        #expect(sink.settings.imageRetentionDays == 30)
        #expect(!sink.settings.setupCompleted)
    }

    @Test
    func unavailableHotkeyIsNotSaved() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission(), canUseHotkey: { _ in
            false
        })
        defer { controller.close() }
        controller.show()
        controller.flow.hotkey.beginRecording()
        controller.flow.hotkey.handle(keyCode: TestKey.k, flags: [.command, .option])
        #expect(sink.log.events.isEmpty)
        #expect(controller.flow.hotkey.shortcut == KeyboardShortcut())
        #expect(controller.flow.hotkey.problem == .unavailable)
        #expect(UIStrings(language: .en).recorderMessage(.unavailable) == "This shortcut is unavailable")
    }

    @Test
    func recordingStateIsReported() {
        let sink = SettingsSink()
        let controller = makeController(sink, permission: FakePermission())
        defer { controller.close() }
        var recording: [Bool] = []
        controller.onRecordingChanged = { isRecording in
            recording.append(isRecording)
        }
        controller.show()
        controller.flow.hotkey.beginRecording()
        controller.flow.goNext()
        #expect(recording == [true, false])
    }

    @Test
    func textFollowsTheLanguageSetting() {
        var initial = Settings()
        initial.language = .ja
        let sink = SettingsSink(initial)
        let controller = makeController(sink, permission: FakePermission())
        defer { controller.close() }
        controller.show()
        controller.flow.goNext()
        #expect(controller.flow.language == .ja)
        #expect(controller.window.title == "akapen")
        #expect(UIStrings(language: controller.flow.language)[controller.flow.permissionStatus] == "待っています…")
    }
}
