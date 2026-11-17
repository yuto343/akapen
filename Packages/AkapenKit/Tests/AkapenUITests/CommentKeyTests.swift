import AppKit
import Testing
import AkapenCore
@testable import AkapenUI

/// `ConfirmKeyPolicy` に渡した値の記録。判定の結果は偽物が返す（判定そのものは `AkapenCoreTests` で見る）。
@MainActor private final class DecisionRecorder {
    var answer: ConfirmKeyDecision = .passThrough
    private(set) var calls: [(modifiers: KeyModifiers, isComposing: Bool, confirmKey: ConfirmKey)] = []

    var decide: (KeyModifiers, Bool, ConfirmKey) -> ConfirmKeyDecision {
        { [self] modifiers, isComposing, confirmKey in
            MainActor.assumeIsolated {
                calls.append((modifiers, isComposing, confirmKey))
                return answer
            }
        }
    }
}

/// `Return` の判定の結果を正しく行動に移すこと、修飾キーと変換中かどうかを正しく渡すこと。
@Suite
@MainActor
struct CommentKeyRouterTests {
    @Test(arguments: [
        (ConfirmKeyDecision.confirm, CommentKeyAction.confirm),
        (.insertNewline, .insertNewline),
        (.passThrough, .passThrough),
    ])
    func returnFollowsDecision(decision: ConfirmKeyDecision, action: CommentKeyAction) {
        let recorder = DecisionRecorder()
        recorder.answer = decision
        let router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        #expect(router.action(keyCode: KeyCode.returnKey, modifierFlags: [], isComposing: false) == action)
        #expect(router.action(keyCode: KeyCode.keypadEnter, modifierFlags: [], isComposing: false) == action)
    }

    @Test
    func passesModifiersComposingAndConfirmKey() throws {
        let recorder = DecisionRecorder()
        let router = CommentKeyRouter(confirmKey: .commandEnter, decide: recorder.decide)
        _ = router.action(keyCode: KeyCode.returnKey, modifierFlags: [.shift], isComposing: false)
        _ = router.action(keyCode: KeyCode.returnKey, modifierFlags: [.command, .capsLock], isComposing: true)
        _ = router.action(keyCode: KeyCode.keypadEnter, modifierFlags: [.numericPad, .function], isComposing: false)
        _ = router.action(keyCode: KeyCode.returnKey, modifierFlags: [.option, .control], isComposing: false)
        try #require(recorder.calls.count == 4)
        #expect(recorder.calls[0].modifiers == .shift)
        #expect(recorder.calls[0].isComposing == false)
        #expect(recorder.calls[1].modifiers == .command)
        #expect(recorder.calls[1].isComposing == true)
        #expect(recorder.calls[2].modifiers == [])
        #expect(recorder.calls[3].modifiers == [.option, .control])
        #expect(recorder.calls.allSatisfy { $0.confirmKey == .commandEnter })
    }

    @Test
    func escapeCancelsUnlessComposing() {
        let recorder = DecisionRecorder()
        let router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        #expect(router.action(keyCode: KeyCode.escape, modifierFlags: [], isComposing: false) == .cancel)
        #expect(router.action(keyCode: KeyCode.escape, modifierFlags: [], isComposing: true) == .passThrough)
        #expect(recorder.calls.isEmpty)
    }

    @Test
    func otherKeysPassThroughWithoutAsking() {
        let recorder = DecisionRecorder()
        let router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        #expect(router.action(keyCode: 0, modifierFlags: [], isComposing: false) == .passThrough)
        #expect(recorder.calls.isEmpty)
    }
}

/// 入力欄（`NSTextView`）でのキー入力。
@Suite(.serialized)
@MainActor
struct CommentTextViewTests {
    private func makeEditor() -> (GrowingTextController, NSWindow) {
        _ = NSApplication.shared
        let editor = CommentView.makeEditor()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 120), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = editor.scrollView
        window.makeFirstResponder(editor.textView)
        return (editor, window)
    }

    @Test
    func confirmSendsCurrentText() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        let recorder = DecisionRecorder()
        recorder.answer = .confirm
        editor.textView.router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        var confirmed: [String] = []
        editor.textView.onConfirm = { text in
            confirmed.append(text)
        }
        editor.setText("Padding differs left and right")
        editor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        #expect(confirmed == ["Padding differs left and right"])
        #expect(editor.text == "Padding differs left and right")
    }

    @Test
    func insertNewlineAddsLineAndGrows() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        let recorder = DecisionRecorder()
        recorder.answer = .insertNewline
        editor.textView.router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        var confirmed = 0
        editor.textView.onConfirm = { _ in
            confirmed += 1
        }
        editor.setText("first")
        let oneLine = editor.height
        editor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r", modifiers: [.shift]))
        #expect(editor.text == "first\n")
        #expect(confirmed == 0)
        #expect(editor.height == oneLine * 2)
        #expect(recorder.calls.first?.modifiers == .shift)
    }

    @Test
    func heightStopsAtFiveLines() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        editor.setText("1\n2\n3\n4\n5\n6\n7")
        #expect(editor.height == Tokens.Typography.commentInput.lineHeight * 5)
        editor.setText("")
        #expect(editor.height == Tokens.Typography.commentInput.lineHeight)
    }

    @Test
    func returnWhileComposingIsPassedAsComposing() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        let recorder = DecisionRecorder()
        recorder.answer = .passThrough
        editor.textView.router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        var confirmed = 0
        editor.textView.onConfirm = { _ in
            confirmed += 1
        }
        editor.textView.setMarkedText(
            "にほんご",
            selectedRange: NSRange(location: 4, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(editor.textView.hasMarkedText())
        editor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        #expect(recorder.calls.first?.isComposing == true)
        #expect(confirmed == 0)
    }

    @Test
    func returnAfterCompositionIsNotComposing() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        let recorder = DecisionRecorder()
        recorder.answer = .confirm
        editor.textView.router = CommentKeyRouter(confirmKey: .enter, decide: recorder.decide)
        editor.textView.setMarkedText(
            "にほんご",
            selectedRange: NSRange(location: 4, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        editor.textView.unmarkText()
        var confirmed: [String] = []
        editor.textView.onConfirm = { text in
            confirmed.append(text)
        }
        editor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        #expect(recorder.calls.first?.isComposing == false)
        #expect(confirmed == ["にほんご"])
    }

    @Test
    func escapeCancels() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        var cancelled = 0
        editor.textView.onCancel = {
            cancelled += 1
        }
        editor.textView.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(cancelled == 1)
    }

    @Test
    func escapeWhileComposingDoesNotCancel() {
        let (editor, window) = makeEditor()
        defer { window.close() }
        var cancelled = 0
        editor.textView.onCancel = {
            cancelled += 1
        }
        editor.textView.setMarkedText(
            "か",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        editor.textView.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(cancelled == 0)
    }
}

/// コメント入力のパネルで、確定・取り消しが `SessionEvent` になること。確定キーの設定が判定に渡ること。
@Suite(.serialized)
@MainActor
struct CommentPanelEventTests {
    private func render(confirmKey: ConfirmKey, log: EventLog) -> SessionWindows {
        _ = NSApplication.shared
        let windows = SessionWindows(
            send: { event in
                log.append(event)
            },
            screens: FakeScreens.single(),
            fadeDuration: 0,
            timeZone: Fixtures.timeZone,
            thumbnails: StubThumbnails()
        )
        windows.render(SessionViewState(
            phase: .commenting,
            isToolbarVisible: true,
            draftRect: ScreenRect(x: 910, y: 468, width: 204, height: 56),
            confirmKey: confirmKey
        ))
        return windows
    }

    @Test
    func confirmSendsCommentConfirmed() throws {
        let log = EventLog()
        let windows = render(confirmKey: .commandEnter, log: log)
        defer { windows.hide() }
        let recorder = DecisionRecorder()
        recorder.answer = .confirm
        windows.commentEditor.textView.router.decide = recorder.decide
        windows.commentEditor.setText("Change this label")
        windows.commentEditor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r", modifiers: [.command]))
        #expect(recorder.calls.first?.confirmKey == .commandEnter)
        #expect(recorder.calls.first?.modifiers == .command)
        let event = try #require(log.events.last)
        guard case let .commentConfirmed(text) = event else {
            Issue.record("commentConfirmed が送られていない: \(log.names)")
            return
        }
        #expect(text == "Change this label")
    }

    @Test
    func escapeSendsCommentCancelled() {
        let log = EventLog()
        let windows = render(confirmKey: .enter, log: log)
        defer { windows.hide() }
        windows.commentEditor.textView.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(log.names == ["commentCancelled"])
    }

    @Test
    func enteringCommentingClearsPreviousText() {
        let log = EventLog()
        let windows = render(confirmKey: .enter, log: log)
        defer { windows.hide() }
        windows.commentEditor.setText("left over")
        windows.render(SessionViewState(phase: .idle, isToolbarVisible: true))
        windows.render(SessionViewState(
            phase: .commenting,
            isToolbarVisible: true,
            draftRect: ScreenRect(x: 10, y: 40, width: 20, height: 20)
        ))
        #expect(windows.commentEditor.text.isEmpty)
    }
}
