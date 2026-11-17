import AppKit
import Testing
import AkapenCore
@testable import AkapenUI

/// どのパネルが出ているか。
private struct Shown: Equatable {
    var overlay = false
    var acceptsDrawing = false
    var toolbar = false
    var comment = false
    var list = false
    var copied = false
}

@MainActor
private func makeWindows(screens: FakeScreens = .single(), log: EventLog = EventLog()) -> SessionWindows {
    _ = NSApplication.shared
    return SessionWindows(
        send: { event in
            log.append(event)
        },
        screens: screens,
        fadeDuration: 0,
        timeZone: Fixtures.timeZone,
        thumbnails: StubThumbnails()
    )
}

@MainActor
private func shown(_ windows: SessionWindows) -> Shown {
    Shown(
        overlay: windows.overlayPanel.isVisible,
        acceptsDrawing: windows.overlayPanel.isVisible && !windows.overlayPanel.ignoresMouseEvents,
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
        windows.render(SessionViewState(phase: .hidden, isToolbarVisible: false))
        #expect(shown(windows) == Shown())
    }

    @Test
    func drawingShowsSurfaceAndToolbar() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
        #expect(shown(windows) == Shown(overlay: true, acceptsDrawing: true, toolbar: true))
        #expect(windows.overlay?.showsHint == true)
    }

    @Test
    func commentingKeepsFrameWithoutMouseAndShowsComment() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
        windows.render(SessionViewState(phase: .commenting, isToolbarVisible: true, draftRect: frame))
        #expect(shown(windows) == Shown(overlay: true, acceptsDrawing: false, toolbar: true, comment: true))
        #expect(windows.overlayPanel.ignoresMouseEvents)
        #expect(windows.overlay?.frame == frame)
        #expect(windows.overlay?.showsHint == false)
    }

    @Test
    func commentFieldHasFocusWhenShown() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .commenting, isToolbarVisible: true, draftRect: frame))
        #expect(windows.comment.panel.firstResponder === windows.commentEditor.textView)
    }

    @Test
    func idleShowsOnlyToolbar() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .idle, isToolbarVisible: true, annotations: Fixtures.twoAnnotations))
        #expect(shown(windows) == Shown(toolbar: true))
    }

    @Test
    func idleWithHiddenToolbarShowsNothing() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .idle, isToolbarVisible: false, annotations: Fixtures.twoAnnotations))
        #expect(shown(windows) == Shown())
    }

    @Test
    func listOpenShowsToolbarAndList() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .listOpen, isToolbarVisible: true, annotations: Fixtures.twoAnnotations))
        #expect(shown(windows) == Shown(toolbar: true, list: true))
    }

    @Test
    func copiedShowsOnlyToast() {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .copied, isToolbarVisible: false, lastCopiedCount: 2))
        #expect(shown(windows) == Shown(copied: true))
        #expect(windows.copied.panel.ignoresMouseEvents)
    }

    @Test
    func followsPhaseChanges() {
        let windows = makeWindows()
        defer { windows.hide() }
        let states = [
            SessionViewState(phase: .drawing, isToolbarVisible: true),
            SessionViewState(phase: .commenting, isToolbarVisible: true, draftRect: frame),
            SessionViewState(phase: .idle, isToolbarVisible: true, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .listOpen, isToolbarVisible: true, annotations: Fixtures.twoAnnotations),
            SessionViewState(phase: .copied, isToolbarVisible: false, lastCopiedCount: 2),
            SessionViewState(phase: .hidden, isToolbarVisible: false),
        ]
        let expected = [
            Shown(overlay: true, acceptsDrawing: true, toolbar: true),
            Shown(overlay: true, toolbar: true, comment: true),
            Shown(toolbar: true),
            Shown(toolbar: true, list: true),
            Shown(copied: true),
            Shown(),
        ]
        for (state, want) in zip(states, expected) {
            windows.render(state)
            #expect(shown(windows) == want, "phase: \(state.phase)")
        }
    }

    @Test(arguments: [Phase.hidden, .commenting, .idle, .listOpen, .copied])
    func surfaceIgnoresMouseOutsideDrawing(phase: Phase) {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
        windows.render(SessionViewState(
            phase: phase,
            isToolbarVisible: phase != .hidden && phase != .copied,
            annotations: Fixtures.twoAnnotations,
            draftRect: phase == .commenting ? frame : nil,
            lastCopiedCount: 2
        ))
        #expect(windows.overlayPanel.ignoresMouseEvents)
        #expect(!windows.acceptsDrawing)
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
        windows.render(SessionViewState(phase: .idle, isToolbarVisible: true, annotations: Fixtures.twoAnnotations))
        let toolbar = try #require(windows.toolbar.contentFrame)
        #expect(toolbar.y + toolbar.height == 800 - 16)
        #expect(abs((toolbar.x + toolbar.width / 2) - 640) < 0.5)
        #expect(toolbar.height == 48)
    }

    @Test
    func commentSitsBelowFrameAlignedRight() throws {
        let windows = makeWindows()
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .commenting, isToolbarVisible: true, draftRect: frame))
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
        windows.render(SessionViewState(phase: .listOpen, isToolbarVisible: true, annotations: Fixtures.twoAnnotations))
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
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
        #expect(windows.screen?.id == FakeScreens.secondary.id)
        let expected = ScreenCoordinates.nsRect(FakeScreens.secondary.frame, primaryTop: 800)
        #expect(windows.overlayPanel.frame == expected)
        screens.mouseLocation = CGPoint(x: 640, y: 400)
        windows.render(SessionViewState(phase: .idle, isToolbarVisible: true, annotations: Fixtures.twoAnnotations))
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true, annotations: Fixtures.twoAnnotations))
        #expect(windows.screen?.id == FakeScreens.secondary.id)
        windows.render(SessionViewState(phase: .hidden, isToolbarVisible: false))
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
        #expect(windows.screen?.id == FakeScreens.primary.id)
    }

    @Test
    func dragOnSecondaryScreenSendsGlobalRect() throws {
        let screens = FakeScreens.dual()
        screens.mouseLocation = CGPoint(x: -700, y: 300)
        let log = EventLog()
        let windows = makeWindows(screens: screens, log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
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
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
        windows.surface.onDragEnded?(CGPoint(x: 100, y: 200), CGPoint(x: 100, y: 200))
        #expect(log.names.isEmpty)
    }

    @Test
    func escapeOnSurfaceSendsEscapePressed() {
        let log = EventLog()
        let windows = makeWindows(log: log)
        defer { windows.hide() }
        windows.render(SessionViewState(phase: .drawing, isToolbarVisible: true))
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
        let drawing = PanelPlan(SessionViewState(phase: .drawing, isToolbarVisible: true))
        #expect(drawing.acceptsDrawing && drawing.toolbar && !drawing.comment)
        let commenting = PanelPlan(SessionViewState(phase: .commenting, isToolbarVisible: true, draftRect: rect))
        #expect(!commenting.acceptsDrawing && commenting.pinnedFrame == rect && commenting.comment && commenting.showsOverlay)
        let idle = PanelPlan(SessionViewState(phase: .idle, isToolbarVisible: false))
        #expect(idle == PanelPlan.none)
        let list = PanelPlan(SessionViewState(phase: .listOpen, isToolbarVisible: true))
        #expect(list.list && list.toolbar && !list.showsOverlay)
        let copied = PanelPlan(SessionViewState(phase: .copied, isToolbarVisible: false))
        #expect(copied.copied && !copied.toolbar)
        let hidden = PanelPlan(SessionViewState(phase: .hidden, isToolbarVisible: true))
        #expect(hidden == PanelPlan.none)
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
