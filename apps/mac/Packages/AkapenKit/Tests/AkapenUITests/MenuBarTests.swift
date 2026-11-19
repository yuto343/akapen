import AppKit
import Testing
import AkapenCore
import AkapenAXID
@testable import AkapenUI

/// メニューバーのメニュー。中身、件数ごとの見出し、開くたびの読み直し、項目を選んだときのコールバック。
///
/// メニューバーに実際のアイコンは置かない（`installsStatusItem: false`）。
@Suite(.serialized)
@MainActor
struct MenuBarTests {
    private final class StatusBox {
        var status = MenuBarStatus(annotationCount: 2, language: .en)
    }

    /// 呼ばれた回数を数える、偽の更新の確認。
    private final class FakeUpdater: UpdateChecking {
        var checkCount = 0

        func checkForUpdates() {
            checkCount += 1
        }
    }

    private func makeController(_ box: StatusBox) -> MenuBarController {
        MenuBarController(
            status: {
                box.status
            },
            installsStatusItem: false
        )
    }

    @Test
    func menuHasHeaderSettingsUpdatesAndQuit() throws {
        let controller = makeController(StatusBox())
        let items = controller.menu.items
        try #require(items.count == 6)
        #expect(items[0].view === controller.headerView)
        #expect(items[1].isSeparatorItem)
        #expect(items[2] === controller.settingsItem)
        #expect(items[2].title == "Settings…")
        #expect(items[2].keyEquivalent == ",")
        #expect(items[2].keyEquivalentModifierMask == .command)
        #expect(items[2].accessibilityIdentifier() == AXID.MenuBar.settings)
        #expect(items[3] === controller.checkForUpdatesItem)
        #expect(items[3].title == "Check for Updates…")
        #expect(items[3].keyEquivalent.isEmpty)
        #expect(items[3].accessibilityIdentifier() == AXID.MenuBar.checkForUpdates)
        #expect(items[4].isSeparatorItem)
        #expect(items[5] === controller.quitItem)
        #expect(items[5].title == "Quit akapen")
        #expect(items[5].keyEquivalent == "q")
        #expect(items[5].keyEquivalentModifierMask == .command)
        #expect(items[5].accessibilityIdentifier() == AXID.MenuBar.quit)
    }

    @Test
    func choosingCheckForUpdatesCallsTheUpdaterOnce() {
        let controller = makeController(StatusBox())
        let updater = FakeUpdater()
        var otherCalls: [String] = []
        controller.onOpenSettings = {
            otherCalls.append("settings")
        }
        controller.onQuitRequested = {
            otherCalls.append("quit")
        }
        controller.onCheckForUpdates = {
            updater.checkForUpdates()
        }
        #expect(controller.checkForUpdatesItem.isEnabled)
        controller.menu.performActionForItem(at: controller.menu.index(of: controller.checkForUpdatesItem))
        #expect(updater.checkCount == 1)
        // ほかの項目のコールバックは呼ばない。
        #expect(otherCalls.isEmpty)
    }

    @Test
    func choosingItemsCallsCallbacks() {
        let controller = makeController(StatusBox())
        var calls: [String] = []
        controller.onOpenSettings = {
            calls.append("settings")
        }
        controller.onQuitRequested = {
            calls.append("quit")
        }
        controller.menu.performActionForItem(at: controller.menu.index(of: controller.settingsItem))
        #expect(calls == ["settings"])
        controller.menu.performActionForItem(at: controller.menu.index(of: controller.quitItem))
        #expect(calls == ["settings", "quit"])
    }

    @Test
    func itemsWithoutCallbacksAreDisabled() {
        let controller = makeController(StatusBox())
        #expect(!controller.settingsItem.isEnabled)
        #expect(!controller.checkForUpdatesItem.isEnabled)
        #expect(!controller.quitItem.isEnabled)
        controller.onOpenSettings = {}
        controller.onCheckForUpdates = {}
        controller.onQuitRequested = {}
        #expect(controller.settingsItem.isEnabled)
        #expect(controller.checkForUpdatesItem.isEnabled)
        #expect(controller.quitItem.isEnabled)
    }

    @Test
    func countAndLanguageAreReadEachTimeTheMenuOpens() {
        let box = StatusBox()
        let controller = makeController(box)
        #expect(controller.headerView.rootView.annotationCount == 2)
        #expect(controller.headerView.rootView.strings.language == .en)
        box.status = MenuBarStatus(annotationCount: 1, language: .ja)
        #expect(controller.headerView.rootView.annotationCount == 2)
        controller.menuNeedsUpdate(controller.menu)
        #expect(controller.status == box.status)
        #expect(controller.headerView.rootView.annotationCount == 1)
        #expect(controller.headerView.rootView.strings.language == .ja)
        #expect(controller.settingsItem.title == "設定…")
        #expect(controller.checkForUpdatesItem.title == "アップデートを確認…")
        #expect(controller.quitItem.title == "akapen を終了")
        box.status = MenuBarStatus(annotationCount: 0, language: .en)
        controller.menuNeedsUpdate(controller.menu)
        #expect(controller.headerView.rootView.annotationCount == 0)
        #expect(controller.settingsItem.title == "Settings…")
        #expect(controller.checkForUpdatesItem.title == "Check for Updates…")
    }

    @Test
    func headerFitsTheMenuWidth() {
        let controller = makeController(StatusBox())
        #expect(controller.headerView.frame.width == Tokens.Menu.headerWidth)
        #expect(controller.headerView.frame.height == 48)
    }

    @Test
    func menuIsLight() {
        let controller = makeController(StatusBox())
        #expect(controller.menu.appearance?.name == .aqua)
    }

    @Test(arguments: [
        (0, Language.en, "No annotations"),
        (1, Language.en, "1 annotation waiting"),
        (2, Language.en, "2 annotations waiting"),
        (0, Language.ja, "注釈はありません"),
        (1, Language.ja, "リスト内に 1 件あります"),
        (2, Language.ja, "リスト内に 2 件あります"),
    ])
    func headerStatusText(count: Int, language: Language, expected: String) {
        #expect(UIStrings(language: language).menuStatus(count: count) == expected)
    }
}
