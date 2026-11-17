import AppKit
import Testing
import AkapenCore
import AkapenAXID
@testable import AkapenUI

/// 終了の確認。`Return` / `Esc` / ボタンで正しい答えが返ること、2 つ重ならないこと、置き場所。
@Suite(.serialized)
@MainActor
struct QuitConfirmTests {
    private func makeController(language: Language = .en) -> (QuitConfirmController, ResultLog) {
        _ = NSApplication.shared
        let controller = QuitConfirmController(
            language: {
                language
            },
            screens: FakeScreens.single(),
            fadeDuration: 0
        )
        let log = ResultLog()
        controller.onResult = { result in
            log.results.append(result)
        }
        return (controller, log)
    }

    @Test
    func returnQuits() {
        let (controller, log) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 2)
        #expect(controller.isShown)
        controller.panel.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        #expect(log.results == [.quit])
        #expect(!controller.isShown)
    }

    @Test
    func keypadEnterQuits() {
        let (controller, log) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 2)
        controller.panel.keyDown(with: keyEvent(KeyCode.keypadEnter, characters: "\u{3}"))
        #expect(log.results == [.quit])
    }

    @Test
    func escapeCancels() {
        let (controller, log) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 2)
        controller.panel.keyDown(with: keyEvent(KeyCode.escape, characters: "\u{1b}"))
        #expect(log.results == [.cancel])
        #expect(!controller.isShown)
    }

    @Test
    func buttonsAnswer() {
        let (controller, log) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 1)
        controller.hostingView.rootView.onCancel()
        #expect(log.results == [.cancel])
        controller.show(annotationCount: 1)
        controller.hostingView.rootView.onQuit()
        #expect(log.results == [.cancel, .quit])
    }

    @Test
    func answersOnlyOncePerConfirmation() {
        let (controller, log) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 2)
        controller.panel.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        controller.panel.keyDown(with: keyEvent(KeyCode.returnKey, characters: "\r"))
        controller.hostingView.rootView.onCancel()
        #expect(log.results == [.quit])
    }

    @Test
    func showingAgainKeepsOnePanelAndUpdatesCount() {
        let (controller, log) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 1)
        let panel = controller.panel
        controller.show(annotationCount: 3)
        #expect(controller.panel === panel)
        #expect(controller.annotationCount == 3)
        #expect(controller.hostingView.rootView.annotationCount == 3)
        let panels = NSApp.windows.filter { window in
            window.accessibilityIdentifier() == AXID.QuitConfirm.panel && window.isVisible
        }
        #expect(panels.count == 1)
        #expect(log.results.isEmpty)
    }

    @Test
    func hideDoesNotAnswer() {
        let (controller, log) = makeController()
        controller.show(annotationCount: 2)
        controller.hide()
        #expect(!controller.isShown)
        #expect(log.results.isEmpty)
    }

    @Test
    func panelDimsBelowTheMenuBarAndTakesKeys() {
        let (controller, _) = makeController()
        defer { controller.hide() }
        controller.show(annotationCount: 2)
        let expected = ScreenCoordinates.nsRect(ScreenRect(x: 0, y: 28, width: 1280, height: 772), primaryTop: 800)
        #expect(controller.panel.frame == expected)
        #expect(controller.panel.canBecomeKey)
        #expect(controller.panel.level == .modalPanel)
    }

    @Test
    func messageShowsCountInTheSettingsLanguage() {
        let (english, _) = makeController(language: .en)
        defer { english.hide() }
        english.show(annotationCount: 2)
        let englishView = english.hostingView.rootView
        #expect(englishView.annotationCount == 2)
        #expect(englishView.strings.language == .en)
        let (japanese, _) = makeController(language: .ja)
        defer { japanese.hide() }
        japanese.show(annotationCount: 1)
        let japaneseView = japanese.hostingView.rootView
        #expect(japaneseView.annotationCount == 1)
        #expect(japaneseView.strings.language == .ja)
    }
}

@MainActor private final class ResultLog {
    var results: [QuitConfirmResult] = []
}

/// 終了確認の置き場所（Paper の App 09: 画面 1280×800、暗転は y=28 から、箱は 260×245 で x=510・y=250）。
@Suite
@MainActor
struct QuitConfirmPlacementTests {
    @Test
    func dimmedAreaIsBelowTheMenuBar() {
        #expect(PanelPlacement.dimmedArea(screen: FakeScreens.primary) == ScreenRect(x: 0, y: 28, width: 1280, height: 772))
        let secondary = PanelPlacement.dimmedArea(screen: FakeScreens.secondary)
        #expect(secondary == ScreenRect(x: -1440, y: -75, width: 1440, height: 875))
    }

    @Test
    func alertIsCenteredAndSlightlyAbove() {
        let rect = PanelPlacement.alert(size: CGSize(width: 260, height: 245), screen: FakeScreens.primary)
        #expect(rect.x == 510)
        #expect(abs(rect.y - 250) <= 0.5)
    }

    @Test
    func tallAlertStaysBelowTheMenuBar() {
        let rect = PanelPlacement.alert(size: CGSize(width: 260, height: 790), screen: FakeScreens.primary)
        #expect(rect.y == 28)
    }
}
