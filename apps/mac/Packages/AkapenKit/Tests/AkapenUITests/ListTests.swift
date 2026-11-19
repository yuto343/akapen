import AppKit
import Testing
import AkapenCore
@testable import AkapenUI

/// 一覧の編集中の行と、一覧のパネルでのキー入力が `SessionEvent` になること。
@Suite(.serialized)
@MainActor
struct ListTests {
    private func render(_ log: EventLog, confirmKey: ConfirmKey = .enter) -> SessionWindows {
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
            phase: .listOpen,
            annotations: Fixtures.twoAnnotations,
            confirmKey: confirmKey
        ))
        return windows
    }

    @Test
    func confirmingEditSendsAnnotationEdited() throws {
        let log = EventLog()
        let windows = render(log, confirmKey: .commandEnter)
        defer { windows.hide() }
        let target = Fixtures.twoAnnotations[1]
        windows.listEditing.begin(target, index: 1)
        #expect(windows.listEditing.editingID == target.id)
        #expect(windows.listEditing.editor.text == target.comment)
        var asked: [ConfirmKey] = []
        windows.listEditing.editor.textView.router.decide = { _, _, confirmKey in
            asked.append(confirmKey)
            return .confirm
        }
        windows.listEditing.editor.setText("Rename to Save")
        windows.listEditing.editor.textView.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r", modifiers: [.command]))
        #expect(asked == [.commandEnter])
        let event = try #require(log.events.last)
        guard case let .annotationEdited(id, text) = event else {
            Issue.record("annotationEdited が送られていない: \(log.names)")
            return
        }
        #expect(id == target.id)
        #expect(text == "Rename to Save")
        #expect(windows.listEditing.editingID == nil)
    }

    @Test
    func escapeWhileEditingOnlyEndsEditing() {
        let log = EventLog()
        let windows = render(log)
        defer { windows.hide() }
        windows.listEditing.begin(Fixtures.twoAnnotations[0], index: 0)
        windows.listEditing.editor.textView.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(windows.listEditing.editingID == nil)
        #expect(log.names.isEmpty)
    }

    @Test
    func escapeOnListPanelClosesList() {
        let log = EventLog()
        let windows = render(log)
        defer { windows.hide() }
        windows.list.panel.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(log.names == ["escapePressed"])
    }

    @Test
    func editingEndsWhenListCloses() {
        let log = EventLog()
        let windows = render(log)
        defer { windows.hide() }
        windows.listEditing.begin(Fixtures.twoAnnotations[0], index: 0)
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        #expect(windows.listEditing.editingID == nil)
    }

    @Test
    func editingEndsWhenEditedAnnotationIsGone() {
        let log = EventLog()
        let windows = render(log)
        defer { windows.hide() }
        windows.listEditing.begin(Fixtures.twoAnnotations[0], index: 0)
        windows.render(SessionViewState(
            phase: .listOpen,
            annotations: [Fixtures.twoAnnotations[1]]
        ))
        #expect(windows.listEditing.editingID == nil)
    }
}
