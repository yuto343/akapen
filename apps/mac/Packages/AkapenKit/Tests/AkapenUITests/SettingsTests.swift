import AppKit
import Testing
import AkapenCore
import AkapenAXID
@testable import AkapenUI

/// 設定のウィンドウ。各項目を変えると、その場で `settingsChanged` が送られること。
@Suite(.serialized)
@MainActor
struct SettingsTests {
    private let defaultHotkey = KeyboardShortcut()
    private let optionCommandK = KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.option, .command])

    private func makeController(
        _ sink: SettingsSink,
        canUseHotkey: @escaping @MainActor (KeyboardShortcut) -> Bool = { _ in true }
    ) -> SettingsController {
        _ = NSApplication.shared
        return SettingsController(
            settings: {
                sink.settings
            },
            send: sink.send,
            canUseHotkey: canUseHotkey,
            shortcutText: .ansi,
            activatesApp: false
        )
    }

    /// 人が入力欄に文字を打ったときと同じ経路（`NSTextView` の入力）で、定型文を書き換える。
    private func type(_ text: String, into editor: GrowingTextController) {
        editor.textView.selectAll(nil)
        editor.textView.insertText(text, replacementRange: editor.textView.selectedRange())
    }

    @Test
    func showOpensWindowAndShowingAgainKeepsOneWindow() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        #expect(!controller.isShown)
        controller.show()
        #expect(controller.isShown)
        #expect(controller.window.accessibilityIdentifier() == AXID.Settings.window)
        #expect(controller.window.title == "akapen Settings")
        let window = controller.window
        controller.show()
        #expect(controller.window === window)
        #expect(controller.isShown)
        #expect(sink.log.events.isEmpty)
        controller.close()
        #expect(!controller.isShown)
    }

    @Test
    func windowFitsThePaperSize() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        #expect(controller.window.frame.width == Tokens.Settings.width)
        // Paper の App 06 は 620×512（定型文が 3 行のとき）。「ボタン類の表示・非表示」の行（48pt）をなくしたので 464。
        #expect(abs(controller.window.frame.height - (512 - Tokens.Settings.rowHeight)) <= 1)
    }

    @Test
    func showLoadsTheLatestSettings() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        var changed = Settings()
        changed.language = .ja
        changed.imageRetentionDays = 30
        changed.hotkey = optionCommandK
        sink.settings = changed
        controller.show()
        #expect(controller.form.settings == changed)
        #expect(controller.form.retentionText == "30")
        #expect(controller.form.hotkey.shortcut == optionCommandK)
        #expect(controller.form.boilerplate.text == Boilerplate.japanese)
        #expect(controller.window.title == "akapen の設定")
    }

    @Test
    func languageChangeIsSentAndSwitchesTextAndBoilerplate() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        #expect(controller.form.boilerplate.text == Boilerplate.english)
        controller.form.setLanguage(.ja)
        #expect(sink.sentSettings.last?.language == .ja)
        #expect(controller.form.boilerplate.text == Boilerplate.japanese)
        #expect(controller.window.title == "akapen の設定")
        controller.form.setLanguage(.ja)
        #expect(sink.sentSettings.count == 1)
    }

    @Test
    func editedBoilerplateIsKeptPerLanguage() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        let editor = controller.form.boilerplate
        type("Please fix these.", into: editor)
        #expect(sink.settings.boilerplate(for: .en) == "Please fix these.")
        #expect(sink.settings.boilerplate(for: .ja) == Boilerplate.japanese)
        controller.form.setLanguage(.ja)
        #expect(editor.text == Boilerplate.japanese)
        type("直してください。", into: editor)
        #expect(sink.settings.boilerplate(for: .ja) == "直してください。")
        controller.form.setLanguage(.en)
        #expect(editor.text == "Please fix these.")
        #expect(sink.settings.boilerplate(for: .en) == "Please fix these.")
        #expect(sink.settings.boilerplate(for: .ja) == "直してください。")
        #expect(sink.settings.language == .en)
    }

    @Test
    func boilerplateIsNotSentWhileComposing() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        let textView = controller.form.boilerplate.textView
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.setMarkedText(
            "にほ",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(sink.sentSettings.isEmpty)
        textView.insertText("日本", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(sink.settings.boilerplate(for: .en) == Boilerplate.english + "日本")
    }

    @Test
    func returnInBoilerplateInsertsNewline() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        let editor = controller.form.boilerplate
        editor.setText("first")
        editor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        #expect(editor.text == "first\n")
        #expect(sink.settings.boilerplate(for: .en) == "first\n")
    }

    @Test
    func confirmKeyChangeIsSent() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        controller.form.setConfirmKey(.commandEnter)
        #expect(sink.sentSettings.map(\.confirmKey) == [.commandEnter])
        controller.form.setConfirmKey(.commandEnter)
        #expect(sink.sentSettings.count == 1)
    }

    @Test
    func recordedHotkeyIsSent() {
        let sink = SettingsSink()
        var asked: [KeyboardShortcut] = []
        let controller = makeController(sink, canUseHotkey: { candidate in
            asked.append(candidate)
            return true
        })
        defer { controller.close() }
        controller.show()
        controller.form.hotkey.beginRecording()
        controller.form.hotkey.handle(keyCode: TestKey.k, flags: [.command, .option])
        #expect(asked == [optionCommandK])
        #expect(sink.sentSettings.map(\.hotkey) == [optionCommandK])
    }

    @Test
    func unavailableHotkeyIsNotSentAndShowsMessage() {
        let sink = SettingsSink()
        let controller = makeController(sink, canUseHotkey: { _ in
            false
        })
        defer { controller.close() }
        controller.show()
        controller.form.hotkey.beginRecording()
        controller.form.hotkey.handle(keyCode: TestKey.k, flags: [.command, .option])
        #expect(sink.sentSettings.isEmpty)
        #expect(controller.form.hotkey.shortcut == defaultHotkey)
        #expect(controller.form.hotkey.problem == .unavailable)
        #expect(UIStrings(language: .en).recorderMessage(.unavailable) == "This shortcut is unavailable")
        #expect(UIStrings(language: .ja).recorderMessage(.unavailable) == "このショートカットは使えません")
    }

    @Test
    func recordingChangesAreReported() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        var recording: [Bool] = []
        controller.onRecordingChanged = { isRecording in
            recording.append(isRecording)
        }
        controller.show()
        controller.form.hotkey.beginRecording()
        #expect(controller.form.hotkey.isRecording)
        #expect(recording == [true])
        controller.form.hotkey.cancelRecording()
        #expect(recording == [true, false])
    }

    @Test
    func closingTheWindowEndsRecording() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        var recording: [Bool] = []
        controller.onRecordingChanged = { isRecording in
            recording.append(isRecording)
        }
        controller.show()
        controller.form.hotkey.beginRecording()
        controller.close()
        #expect(!controller.form.hotkey.isRecording)
        #expect(recording == [true, false])
    }

    @Test(arguments: [
        ("0", 1),
        ("1", 1),
        ("30", 30),
        ("365", 365),
        ("366", 365),
        ("99999999999999999999", 365),
    ])
    func retentionIsClampedToRange(input: String, expected: Int) {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        controller.form.setRetentionText(input)
        controller.form.commitRetention()
        #expect(sink.settings.imageRetentionDays == expected)
        #expect(controller.form.retentionText == String(expected))
    }

    @Test
    func retentionIgnoresNonDigitsAndRevertsWhenEmpty() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        controller.form.setRetentionText("1a4")
        #expect(controller.form.retentionText == "14")
        controller.form.setRetentionText("")
        controller.form.commitRetention()
        #expect(controller.form.retentionText == "7")
        #expect(sink.sentSettings.isEmpty)
        controller.form.setRetentionText("7")
        controller.form.commitRetention()
        #expect(sink.sentSettings.isEmpty)
    }

    @Test
    func closingTheWindowCommitsTheTypedDays() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        controller.show()
        controller.form.setRetentionText("400")
        controller.close()
        #expect(sink.settings.imageRetentionDays == 365)
    }

    @Test
    func changesKeepValuesChangedElsewhere() {
        let sink = SettingsSink()
        let controller = makeController(sink)
        defer { controller.close() }
        controller.show()
        // セットアップなど、ほかの画面がホットキーを変えたあとに言語を変えても、ホットキーを古い値に戻さない。
        sink.settings.hotkey = optionCommandK
        controller.form.setLanguage(.ja)
        #expect(sink.settings.hotkey == optionCommandK)
        #expect(sink.settings.language == .ja)
    }

    @Test
    func clampRetention() {
        #expect(SettingsForm.clampRetention(-5) == 1)
        #expect(SettingsForm.clampRetention(0) == 1)
        #expect(SettingsForm.clampRetention(7) == 7)
        #expect(SettingsForm.clampRetention(365) == 365)
        #expect(SettingsForm.clampRetention(1000) == 365)
    }
}
