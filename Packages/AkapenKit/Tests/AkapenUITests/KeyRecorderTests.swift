import AppKit
import Testing
import AkapenCore
@testable import AkapenUI

/// キーの記録欄（設定とセットアップで共通）。記録、修飾キーなしを受け付けないこと、`Esc`、`Delete`、判定が false のときに戻すこと。
@Suite
@MainActor
struct KeyRecorderTests {
    private let commandSemicolon = KeyboardShortcut(keyCode: UInt32(TestKey.semicolon), modifiers: .command)
    private let optionCommandK = KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.option, .command])

    /// 値の変化（`onCommit`）を記録する。
    private func recorder(
        _ shortcut: KeyboardShortcut?,
        allowsNone: Bool = false
    ) -> (KeyRecorderModel, CommitLog) {
        let model = KeyRecorderModel(shortcut: shortcut, allowsNone: allowsNone)
        let log = CommitLog()
        model.onCommit = { value in
            log.values.append(value)
        }
        model.onRecordingChange = { isRecording in
            log.recording.append(isRecording)
        }
        return (model, log)
    }

    @Test
    func recordsKeyWithModifiers() {
        let (model, log) = recorder(commandSemicolon)
        model.toggleRecording()
        #expect(model.isRecording)
        #expect(model.handle(keyCode: TestKey.k, flags: [.command, .option]))
        #expect(model.shortcut == optionCommandK)
        #expect(!model.isRecording)
        #expect(log.values == [optionCommandK])
        #expect(log.recording == [true, false])
    }

    @Test
    func keysWithoutModifiersAreNotRecorded() {
        let (model, log) = recorder(commandSemicolon)
        model.beginRecording()
        #expect(model.handle(keyCode: TestKey.k, flags: []))
        #expect(model.isRecording)
        // ⇧ だけでは足りない（大文字を打てなくなるため）。
        #expect(model.handle(keyCode: TestKey.k, flags: [.shift]))
        #expect(model.isRecording)
        // Caps Lock やテンキーの印は修飾キーに数えない。
        #expect(model.handle(keyCode: TestKey.k, flags: [.capsLock, .numericPad]))
        #expect(model.isRecording)
        #expect(model.shortcut == commandSemicolon)
        #expect(log.values.isEmpty)
        model.handle(keyCode: TestKey.k, flags: [.control, .shift])
        #expect(model.shortcut == KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.control, .shift]))
    }

    @Test
    func escapeCancelsAndKeepsValue() {
        let (model, log) = recorder(commandSemicolon)
        model.beginRecording()
        #expect(model.handle(keyCode: KeyCode.escape, flags: []))
        #expect(!model.isRecording)
        #expect(model.shortcut == commandSemicolon)
        #expect(log.values.isEmpty)
        #expect(log.recording == [true, false])
    }

    @Test
    func clickingAgainCancels() {
        let (model, log) = recorder(commandSemicolon)
        model.toggleRecording()
        model.toggleRecording()
        #expect(!model.isRecording)
        #expect(log.values.isEmpty)
    }

    @Test(arguments: [KeyCode.delete, KeyCode.forwardDelete])
    func deleteUnassignsWhenAllowed(keyCode: UInt16) {
        let (model, log) = recorder(optionCommandK, allowsNone: true)
        model.beginRecording()
        #expect(model.handle(keyCode: keyCode, flags: []))
        #expect(model.shortcut == nil)
        #expect(!model.isRecording)
        #expect(log.values == [nil])
    }

    @Test
    func deleteIsIgnoredWhenUnassignedIsNotAllowed() {
        let (model, log) = recorder(commandSemicolon, allowsNone: false)
        model.beginRecording()
        #expect(model.handle(keyCode: KeyCode.delete, flags: []))
        #expect(model.isRecording)
        #expect(model.shortcut == commandSemicolon)
        #expect(log.values.isEmpty)
    }

    @Test
    func unavailableKeyRevertsAndShowsMessage() {
        let (model, log) = recorder(commandSemicolon)
        var asked: [KeyboardShortcut] = []
        model.isAvailable = { candidate in
            asked.append(candidate)
            return false
        }
        model.beginRecording()
        model.handle(keyCode: TestKey.k, flags: [.command, .option])
        #expect(asked == [optionCommandK])
        #expect(model.shortcut == commandSemicolon)
        #expect(model.problem == .unavailable)
        #expect(!model.isRecording)
        #expect(log.values.isEmpty)
        model.beginRecording()
        #expect(model.problem == nil)
    }

    @Test
    func keyTakenByTheOtherFieldIsRejectedWithoutAsking() {
        let (model, log) = recorder(nil, allowsNone: true)
        var asked = 0
        model.isAvailable = { _ in
            asked += 1
            return true
        }
        model.isTaken = { [commandSemicolon] candidate in
            candidate == commandSemicolon
        }
        model.beginRecording()
        model.handle(keyCode: TestKey.semicolon, flags: [.command])
        #expect(model.shortcut == nil)
        #expect(model.problem == .inUse)
        #expect(asked == 0)
        #expect(log.values.isEmpty)
    }

    @Test
    func recordingTheSameKeyEndsWithoutAsking() {
        let (model, log) = recorder(commandSemicolon)
        var asked = 0
        model.isAvailable = { _ in
            asked += 1
            return false
        }
        model.beginRecording()
        model.handle(keyCode: TestKey.semicolon, flags: [.command])
        #expect(!model.isRecording)
        #expect(model.problem == nil)
        #expect(asked == 0)
        #expect(log.values.isEmpty)
    }

    @Test
    func keysAreIgnoredWhenNotRecording() {
        let (model, log) = recorder(commandSemicolon)
        #expect(!model.handle(keyCode: TestKey.k, flags: [.command]))
        #expect(log.values.isEmpty)
    }

    @Test
    func loadReplacesValueAndClearsState() {
        let (model, log) = recorder(commandSemicolon)
        model.isAvailable = { _ in
            false
        }
        model.beginRecording()
        model.handle(keyCode: TestKey.k, flags: [.command])
        #expect(model.problem == .unavailable)
        model.beginRecording()
        model.load(optionCommandK)
        #expect(model.shortcut == optionCommandK)
        #expect(model.problem == nil)
        #expect(!model.isRecording)
        #expect(log.values.isEmpty)
    }
}

@MainActor private final class CommitLog {
    var values: [KeyboardShortcut?] = []
    var recording: [Bool] = []
}

/// 記録欄の後ろに置く NSView が、キー入力を記録欄に渡すこと。`⌘` 付きのキーは `performKeyEquivalent` で受け取る。
@Suite(.serialized)
@MainActor
struct KeyCaptureViewTests {
    private func makeView(_ model: KeyRecorderModel) -> (KeyCaptureView, NSWindow) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = KeyCaptureView(frame: NSRect(x: 0, y: 0, width: 100, height: 26))
        view.recorder = model
        window.contentView?.addSubview(view)
        return (view, window)
    }

    @Test
    func takesFocusWhileRecordingAndRecordsCommandKeys() {
        let model = KeyRecorderModel(shortcut: KeyboardShortcut(), allowsNone: false)
        let (view, window) = makeView(model)
        defer { window.close() }
        #expect(!view.acceptsFirstResponder)
        model.beginRecording()
        view.syncFocus()
        #expect(window.firstResponder === view)
        let handled = view.performKeyEquivalent(with: keyEvent(TestKey.k, characters: "k", modifiers: [.command, .option]))
        #expect(handled)
        #expect(model.shortcut == KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.option, .command]))
        view.syncFocus()
        #expect(window.firstResponder !== view)
    }

    @Test
    func keyDownAndLosingFocusEndRecording() {
        let model = KeyRecorderModel(shortcut: KeyboardShortcut(), allowsNone: true)
        let (view, window) = makeView(model)
        defer { window.close() }
        model.beginRecording()
        view.syncFocus()
        view.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(!model.isRecording)
        model.beginRecording()
        view.syncFocus()
        window.makeFirstResponder(nil)
        #expect(!model.isRecording)
    }

    @Test
    func recreatedViewTakesOverWithoutEndingRecording() {
        let model = KeyRecorderModel(shortcut: KeyboardShortcut(), allowsNone: false)
        let (old, window) = makeView(model)
        defer { window.close() }
        model.beginRecording()
        old.syncFocus()
        // 記録欄の中身が変わって、SwiftUI が NSView を作り直したとき。
        let new = KeyCaptureView(frame: NSRect(x: 0, y: 0, width: 100, height: 26))
        new.recorder = model
        window.contentView?.addSubview(new)
        new.syncFocus()
        #expect(window.firstResponder === new)
        #expect(model.isRecording)
        old.removeFromSuperview()
        #expect(model.isRecording)
        new.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(!model.isRecording)
    }

    @Test
    func anotherRecorderTakingFocusEndsRecording() {
        let first = KeyRecorderModel(shortcut: KeyboardShortcut(), allowsNone: false)
        let (firstView, window) = makeView(first)
        defer { window.close() }
        let second = KeyRecorderModel(shortcut: nil, allowsNone: true)
        let secondView = KeyCaptureView(frame: NSRect(x: 0, y: 30, width: 100, height: 26))
        secondView.recorder = second
        window.contentView?.addSubview(secondView)
        first.beginRecording()
        firstView.syncFocus()
        second.beginRecording()
        secondView.syncFocus()
        #expect(!first.isRecording)
        #expect(second.isRecording)
    }

    @Test
    func performKeyEquivalentIsIgnoredWhenNotFocused() {
        let model = KeyRecorderModel(shortcut: KeyboardShortcut(), allowsNone: false)
        let (view, window) = makeView(model)
        defer { window.close() }
        model.beginRecording()
        // フォーカスを取る前（ほかの欄の記録など）は、⌘ 付きのキーを横取りしない。
        #expect(!view.performKeyEquivalent(with: keyEvent(TestKey.k, characters: "k", modifiers: [.command])))
        #expect(model.isRecording)
    }
}

/// キーの表示。修飾キーは ⌃ ⌥ ⇧ ⌘ の順、文字のキーは大文字、名前の決まったキーは記号。
@Suite
@MainActor
struct ShortcutTextTests {
    @Test
    func defaultHotkeyIsCommandSemicolon() {
        let text = ShortcutText.ansi
        #expect(text.parts(KeyboardShortcut()) == ["⌘", ";"])
        #expect(text.string(KeyboardShortcut()) == "⌘ ;")
    }

    @Test
    func modifiersFollowMenuOrder() {
        let text = ShortcutText.ansi
        let all = KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.command, .shift, .option, .control])
        #expect(text.parts(all) == ["⌃", "⌥", "⇧", "⌘", "K"])
        #expect(text.string(all) == "⌃ ⌥ ⇧ ⌘ K")
    }

    @Test
    func namedKeys() {
        let text = ShortcutText.ansi
        #expect(text.keyName(UInt32(TestKey.space)) == "Space")
        #expect(text.keyName(UInt32(TestKey.f5)) == "F5")
        #expect(text.keyName(UInt32(KeyCode.returnKey)) == "↵")
        #expect(text.keyName(UInt32(KeyCode.delete)) == "⌫")
    }

    @Test
    func layoutDecidesTheCharacter() {
        let jis = ShortcutText(keyNames: StubKeyNames(names: [41: ";", 39: ":"]))
        #expect(jis.keyName(39) == ":")
        let unknown = ShortcutText(keyNames: StubKeyNames(names: [:]))
        #expect(unknown.keyName(41) == "#41")
    }
}

/// 決まった表を返すキーの名前の偽物。
private struct StubKeyNames: KeyNameProviding {
    let names: [UInt32: String]

    func character(forKeyCode keyCode: UInt32) -> String? {
        names[keyCode]
    }
}
