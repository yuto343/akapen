import AppKit
import Testing
import AkapenCore
@testable import AkapenUI

/// どのパネルが出ているか。
private struct Shown: Equatable {
    var overlay = false
    /// 画面全体を覆う面がマウスを受けているか（下のアプリを操作できない）。
    var coversScreen = false
    /// 面が枠を描く入力を受けているか。
    var acceptsDrawing = false
    var toolbar = false
    var comment = false
    var list = false
    var copied = false
}

@MainActor
private func makeWindows(
    screens: FakeScreens = .single(),
    log: EventLog = EventLog(),
    fadeDuration: TimeInterval = 0
) -> SessionWindows {
    _ = NSApplication.shared
    return SessionWindows(
        send: { event in
            log.append(event)
        },
        screens: screens,
        fadeDuration: fadeDuration,
        timeZone: Fixtures.timeZone,
        thumbnails: StubThumbnails()
    )
}

@MainActor
private func shown(_ windows: SessionWindows) -> Shown {
    Shown(
        overlay: windows.overlayPanel.isVisible,
        coversScreen: windows.coversScreen,
        acceptsDrawing: windows.acceptsDrawing,
        toolbar: windows.toolbar.panel.isVisible,
        comment: windows.comment.panel.isVisible,
        list: windows.list.panel.isVisible,
        copied: windows.copied.panel.isVisible
    )
}

private let frame = ScreenRect(x: 910, y: 468, width: 204, height: 56)

@Suite(.serialized)
@MainActor
struct PanelTests {
    @Test
    func hiddenShowsNothing() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .hidden))
        #expect(shown(windows) == Shown())
    }

    @Test
    func drawingCoversScreenAndShowsToolbar() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        #expect(shown(windows) == Shown(overlay: true, coversScreen: true, acceptsDrawing: true, toolbar: true))
        #expect(windows.overlay?.showsHint == true)
        #expect(windows.overlayPanel.isKeyWindow || windows.overlayPanel.canBecomeKey)
        #expect(windows.overlayPanel.firstResponder === windows.surface)
    }

    @Test
    func commentingKeepsCoveringWithFrameAndShowsComment() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.render(SessionViewState(phase: .commenting, draftRect: frame))
        // 面は下のアプリを操作させないが、枠は描かない。
        #expect(shown(windows) == Shown(overlay: true, coversScreen: true, acceptsDrawing: false, toolbar: true, comment: true))
        #expect(windows.overlay?.frame == frame)
        #expect(windows.overlay?.showsHint == false)
        #expect(!windows.overlayPanel.canBecomeKey)
    }

    @Test
    func commentFieldHasFocusWhenShown() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .commenting, draftRect: frame))
        #expect(windows.comment.panel.firstResponder === windows.commentEditor.textView)
    }

    @Test
    func confirmingReturnsToEmptyDrawingSurface() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.surface.onDrag?(CGPoint(x: 100, y: 200), CGPoint(x: 300, y: 260))
        windows.render(SessionViewState(phase: .commenting, draftRect: frame))
        windows.render(SessionViewState(phase: .drawing, annotations: [Fixtures.twoAnnotations[0]]))
        // コメントを確定したら、枠とコメント欄は消え、すぐ次の枠を描ける。
        #expect(shown(windows) == Shown(overlay: true, coversScreen: true, acceptsDrawing: true, toolbar: true))
        #expect(windows.overlay?.frame == nil)
        #expect(windows.overlayViewState.frame == nil)
        #expect(windows.overlay?.showsHint == true)
        #expect(windows.overlayPanel.firstResponder === windows.surface)
    }

    @Test
    func listOpenCoversScreenWithoutDrawing() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        windows.render(SessionViewState(phase: .listOpen, annotations: Fixtures.twoAnnotations))
        #expect(shown(windows) == Shown(overlay: true, coversScreen: true, acceptsDrawing: false, toolbar: true, list: true))
        #expect(windows.overlay?.showsHint == false)
        // 面のクリックで一覧の入力欄からキーを奪わない。
        #expect(!windows.overlayPanel.canBecomeKey)
        #expect(windows.list.panel.canBecomeKey)
    }

    @Test
    func copiedShowsOnlyToast() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .copied, lastCopiedCount: 2))
        #expect(shown(windows) == Shown(copied: true))
        #expect(windows.copied.panel.ignoresMouseEvents)
    }

    @Test
    func followsPhaseChanges() {
        let windows = makeWindows()
        defer { windows.hide() }
        let states = [
            SessionViewState(phase: .drawing),
            SessionViewState(phase: .commenting, draftRect: frame),
            SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .listOpen, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .hidden, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .copied, lastCopiedCount: 2),
            SessionViewState(phase: .hidden),
        ]
        let expected = [
            Shown(overlay: true, coversScreen: true, acceptsDrawing: true, toolbar: true),
            Shown(overlay: true, coversScreen: true, toolbar: true, comment: true),
            Shown(overlay: true, coversScreen: true, acceptsDrawing: true, toolbar: true),
            Shown(overlay: true, coversScreen: true, toolbar: true, list: true),
            Shown(overlay: true, coversScreen: true, acceptsDrawing: true, toolbar: true),
            Shown(),
            Shown(overlay: true, coversScreen: true, acceptsDrawing: true, toolbar: true),
            Shown(copied: true),
            Shown(),
        ]
        for (state, want) in zip(states, expected) {
            windows.render(state)
            #expect(shown(windows) == want, "phase: \(state.phase)")
        }
    }

    @Test(arguments: [Phase.hidden, .copied])
    func nothingCoversScreenWithoutToolbar(phase: Phase) {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.render(SessionViewState(phase: phase, annotations: Fixtures.twoAnnotations, lastCopiedCount: 2))
        #expect(windows.overlayPanel.ignoresMouseEvents)
        #expect(!windows.coversScreen)
        #expect(!windows.acceptsDrawing)
        #expect(!windows.overlayPanel.canBecomeKey)
    }

    @Test(arguments: [Phase.commenting, .listOpen])
    func dragOutsideDrawingDoesNothing(phase: Phase) {
        let log = EventLog()
        let windows = makeWindows(log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        windows.render(SessionViewState(phase: phase, annotations: Fixtures.twoAnnotations, draftRect: phase == .commenting ? frame : nil))
        windows.surface.onDrag?(CGPoint(x: 10, y: 10), CGPoint(x: 200, y: 200))
        windows.surface.onDragEnded?(CGPoint(x: 10, y: 10), CGPoint(x: 200, y: 200))
        #expect(log.names.isEmpty)
        #expect(windows.overlay?.frame == (phase == .commenting ? frame : nil))
    }

    // MARK: - 前の中身が一瞬見えないこと

    @Test
    func hiddenOverlayIsClearedBeforeItIsShownAgain() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.render(SessionViewState(phase: .commenting, draftRect: frame))
        #expect(windows.overlayViewState.frame == frame)
        windows.render(SessionViewState(phase: .hidden, annotations: Fixtures.twoAnnotations))
        // 隠し終えた面は、赤枠も案内もない空の表示になっている。
        #expect(windows.overlayViewState.frame == nil)
        #expect(!windows.overlayViewState.showsHint)
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        #expect(windows.overlayViewState.frame == nil)
    }

    @Test
    func animatedPanelsStartEmptyWhenShownAgain() async {
        let windows = makeWindows(fadeDuration: Tokens.Motion.fade)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.render(SessionViewState(phase: .commenting, draftRect: frame))
        #expect(await waitUntil { windows.toolbar.isContentPresented && windows.comment.isContentPresented })
        windows.render(SessionViewState(phase: .drawing, annotations: [Fixtures.twoAnnotations[0]]))
        windows.render(SessionViewState(phase: .hidden, annotations: [Fixtures.twoAnnotations[0]]))
        #expect(await waitUntil { !windows.overlayPanel.isVisible && !windows.toolbar.panel.isVisible && !windows.comment.panel.isVisible })
        // 隠し終えたら、どのパネルの中身も見えない状態に戻っている。
        #expect(windows.overlayViewState.frame == nil)
        #expect(!windows.overlayViewState.showsHint)
        #expect(!windows.toolbar.isContentPresented)
        #expect(!windows.comment.isContentPresented)
        // 出し直した直後（動きの前）は、前の枠のない空の面と、見えない状態のボタン類から始まる。
        windows.render(SessionViewState(phase: .drawing, annotations: [Fixtures.twoAnnotations[0]]))
        #expect(windows.overlayPanel.isVisible)
        #expect(windows.overlayViewState.frame == nil)
        #expect(!windows.toolbar.isContentPresented)
        #expect(await waitUntil { windows.toolbar.isContentPresented && windows.overlayViewState.showsHint })
        #expect(windows.overlayViewState.frame == nil)
    }

    // MARK: - ショートカット

    @Test
    func commandShortcutsWhileToolbarIsShown() {
        let log = EventLog()
        let windows = makeWindows(log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        #expect(windows.overlayPanel.performKeyEquivalent(with: keyEvent(8, characters: "c", modifiers: .command)))
        #expect(windows.overlayPanel.performKeyEquivalent(with: keyEvent(37, characters: "l", modifiers: .command)))
        windows.render(SessionViewState(phase: .listOpen, annotations: Fixtures.twoAnnotations))
        #expect(windows.list.panel.performKeyEquivalent(with: keyEvent(37, characters: "l", modifiers: .command)))
        #expect(windows.list.panel.performKeyEquivalent(with: keyEvent(8, characters: "c", modifiers: .command)))
        #expect(log.names == ["copyPromptTapped", "listToggled", "listToggled", "copyPromptTapped"])
    }

    @Test
    func commandShortcutsAreIgnoredWhileWritingAComment() {
        let log = EventLog()
        let windows = makeWindows(log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .commenting, annotations: Fixtures.twoAnnotations, draftRect: frame))
        #expect(!windows.handleShortcut(keyEvent(8, characters: "c", modifiers: .command)))
        #expect(!windows.handleShortcut(keyEvent(37, characters: "l", modifiers: .command)))
        // 一覧でコメントを編集しているあいだは、入力欄のふつうの ⌘C に任せる。
        windows.render(SessionViewState(phase: .listOpen, annotations: Fixtures.twoAnnotations))
        windows.listEditing.begin(Fixtures.twoAnnotations[0], index: 0)
        #expect(!windows.handleShortcut(keyEvent(8, characters: "c", modifiers: .command)))
        #expect(!windows.handleShortcut(keyEvent(37, characters: "l", modifiers: .command)))
        windows.listEditing.end()
        // 修飾キーが違うもの・ほかのキーは受けない。
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        #expect(!windows.handleShortcut(keyEvent(8, characters: "c", modifiers: [.command, .shift])))
        #expect(!windows.handleShortcut(keyEvent(8, characters: "c")))
        #expect(!windows.handleShortcut(keyEvent(9, characters: "v", modifiers: .command)))
        #expect(log.names.isEmpty)
    }

    @Test
    func panelsDoNotActivateTheApp() {
        let windows = makeWindows()
        defer { windows.hide() }
        for panel in [windows.overlayPanel, windows.toolbar.panel, windows.comment.panel, windows.list.panel, windows.copied.panel] {
            #expect(panel.styleMask.contains(.nonactivatingPanel))
            #expect(!panel.canBecomeMain)
        }
        #expect(!windows.toolbar.panel.canBecomeKey)
        #expect(windows.comment.panel.canBecomeKey)
        // 面がキーになれるのは枠を描くときだけ。
        #expect(!windows.overlayPanel.canBecomeKey)
        windows.render(SessionViewState(phase: .drawing))
        #expect(windows.overlayPanel.canBecomeKey)
    }

    @Test
    func panelsUseLightAppearance() {
        let windows = makeWindows()
        defer { windows.hide() }
        for panel in [windows.overlayPanel, windows.toolbar.panel, windows.comment.panel, windows.list.panel, windows.copied.panel] {
            #expect(panel.appearance?.name == .aqua)
        }
    }

    @Test
    func toolbarSitsAboveVisibleBottomCentered() throws {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        let toolbar = try #require(windows.toolbar.contentFrame)
        #expect(toolbar.y + toolbar.height == 800 - 16)
        #expect(abs((toolbar.x + toolbar.width / 2) - 640) < 0.5)
        #expect(toolbar.height == 48)
    }

    @Test
    func commentSitsBelowFrameAlignedRight() throws {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .commenting, draftRect: frame))
        let comment = try #require(windows.comment.contentFrame)
        #expect(comment.x + comment.width == frame.x + frame.width)
        #expect(comment.y == frame.y + frame.height + 12)
        #expect(comment.width == 300)
        #expect(comment.height == 76)
    }

    @Test
    func listSitsAboveToolbar() throws {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .listOpen, annotations: Fixtures.twoAnnotations))
        let list = try #require(windows.list.contentFrame)
        let toolbar = try #require(windows.toolbar.contentFrame)
        #expect(list.y + list.height == toolbar.y - 12)
        #expect(abs((list.x + list.width / 2) - (toolbar.x + toolbar.width / 2)) < 0.5)
        #expect(list.width == 440)
    }

    @Test
    func choosesScreenUnderCursorWhenDrawingStartsAndKeepsItForTheSession() {
        let screens = FakeScreens.dual()
        screens.mouseLocation = CGPoint(x: -700, y: 300)
        let windows = makeWindows(screens: screens)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        #expect(windows.screen?.id == FakeScreens.secondary.id)
        let expected = ScreenCoordinates.nsRect(FakeScreens.secondary.frame, primaryTop: 800)
        #expect(windows.overlayPanel.frame == expected)
        screens.mouseLocation = CGPoint(x: 640, y: 400)
        windows.render(SessionViewState(phase: .listOpen, annotations: Fixtures.twoAnnotations))
        windows.render(SessionViewState(phase: .drawing, annotations: Fixtures.twoAnnotations))
        #expect(windows.screen?.id == FakeScreens.secondary.id)
        windows.render(SessionViewState(phase: .hidden))
        windows.render(SessionViewState(phase: .drawing))
        #expect(windows.screen?.id == FakeScreens.primary.id)
    }

    @Test
    func dragOnSecondaryScreenSendsGlobalRect() throws {
        let screens = FakeScreens.dual()
        screens.mouseLocation = CGPoint(x: -700, y: 300)
        let log = EventLog()
        let windows = makeWindows(screens: screens, log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.surface.onDrag?(CGPoint(x: 100, y: 200), CGPoint(x: 432, y: 288))
        #expect(windows.overlay?.frame == ScreenRect(x: -1340, y: 100, width: 332, height: 88))
        #expect(windows.overlay?.cursor == CGPoint(x: -1008, y: 188))
        windows.surface.onDragEnded?(CGPoint(x: 100, y: 200), CGPoint(x: 432, y: 288))
        let event = try #require(log.events.last)
        guard case let .dragEnded(rect, screen) = event else {
            Issue.record("dragEnded が送られていない: \(log.names)")
            return
        }
        #expect(rect == ScreenRect(x: -1340, y: 100, width: 332, height: 88))
        #expect(screen == FakeScreens.secondary.descriptor)
        #expect(windows.overlay?.cursor == nil)
    }

    @Test
    func emptyDragSendsNothing() {
        let log = EventLog()
        let windows = makeWindows(log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.surface.onDragEnded?(CGPoint(x: 100, y: 200), CGPoint(x: 100, y: 200))
        #expect(log.names.isEmpty)
    }

    @Test
    func escapeOnSurfaceSendsEscapePressed() {
        let log = EventLog()
        let windows = makeWindows(log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing))
        windows.surface.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(log.names == ["escapePressed"])
    }

    @Test
    func renderFromModelUsesModelState() throws {
        _ = NSApplication.shared
        let model = try SessionModel(settingsStore: MemoryStore())
        let windows = SessionWindows(model: model)
        defer { windows.hide() }
        windows.render()
        #expect(!windows.toolbar.panel.isVisible)
        #expect(windows.state == SessionViewState(model: model))
    }
}

@MainActor private final class MemoryStore: SettingsStore {
    func load() throws -> Settings {
        Settings()
    }

    func save(_ settings: Settings) throws {}
}

@Suite
struct PanelPlanTests {
    @Test
    func planFollowsPhase() {
        let rect = ScreenRect(x: 1, y: 2, width: 3, height: 4)
        let drawing = PanelPlan(SessionViewState(phase: .drawing))
        #expect(drawing.coversScreen && drawing.acceptsDrawing && drawing.toolbar && !drawing.comment && !drawing.list)
        let commenting = PanelPlan(SessionViewState(phase: .commenting, draftRect: rect))
        #expect(commenting.coversScreen && !commenting.acceptsDrawing && commenting.pinnedFrame == rect && commenting.comment)
        #expect(commenting.toolbar && commenting.showsOverlay)
        let list = PanelPlan(SessionViewState(phase: .listOpen))
        #expect(list.coversScreen && !list.acceptsDrawing && list.list && list.toolbar && list.showsOverlay)
        let copied = PanelPlan(SessionViewState(phase: .copied))
        #expect(copied.copied && !copied.toolbar && !copied.coversScreen)
        let hidden = PanelPlan(SessionViewState(phase: .hidden, annotations: Fixtures.twoAnnotations))
        #expect(hidden == PanelPlan.none)
    }

    @Test
    func noticesFollowPhase() {
        // 枠を描く状態では、撮影の失敗もコピーの失敗も知らせる。一覧ではコピーと設定の保存の失敗だけ。
        #expect(PanelPlan(SessionViewState(phase: .drawing, failure: .captureFailed)).notice == .captureFailed)
        #expect(PanelPlan(SessionViewState(phase: .drawing, failure: .pasteboardFailed)).notice == .pasteboardFailed)
        #expect(PanelPlan(SessionViewState(phase: .listOpen, failure: .pasteboardFailed)).notice == .pasteboardFailed)
        #expect(PanelPlan(SessionViewState(phase: .listOpen, failure: .captureFailed)).notice == nil)
        #expect(PanelPlan(SessionViewState(phase: .commenting, failure: .pasteboardFailed)).notice == nil)
    }
}

@Test
@MainActor
func coordinateConversion() {
    let converted = ScreenCoordinates.rect(NSRect(x: -100, y: 50, width: 20, height: 40), primaryTop: 900)
    #expect(converted == ScreenRect(x: -100, y: 810, width: 20, height: 40))
    #expect(ScreenCoordinates.nsRect(converted, primaryTop: 900) == NSRect(x: -100, y: 50, width: 20, height: 40))
    #expect(ScreenCoordinates.point(NSPoint(x: 10, y: 900), primaryTop: 900) == CGPoint(x: 10, y: 0))
}
