// spec: e2e/specs/settings/toolbar-shortcut.md
// spec-sha256: 18942a3c2f3b2170334f7a11859a82fff10fc1f2599039a6b7bfe78bdb816562
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class SettingsToolbarShortcutTests: AkapenUITestCase {
    /// ボタン類の表示を切り替えるキーに割り当てる組み合わせ（⌃⌥J）。
    private let toggleKey = Shortcut(key: "j", modifiers: [.control, .option])

    // scenario: キーを割り当てると、そのキーでボタン類を隠したり出したりでき、注釈は保たれる
    func testAssignedKeyTogglesToolbarAndKeepsAnnotations() throws {
        // 前提: セットアップ済み。ボタン類の表示を切り替えるキーは割り当てなし（既定）。確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let start = waitForPhase(.idle)
        XCTAssertTrue(start.isToolbarVisible)
        XCTAssertEqual(start.annotations.count, 2)

        // 期待される結果: アプリの状態で、設定のボタン類の表示を切り替えるキーが、割り当てる前は無く、
        // してはいけないこと: 既定のときから、何かのキーが割り当てられている。
        XCTAssertNil(start.settings.toolbarShortcut, "既定で割り当てがある")
        XCTAssertNil(start.hotkeys.toolbar, "既定でキーが登録されている")

        // 操作: 設定でキーを割り当てて、設定のウィンドウを閉じる。
        openSettingsFromMenuBar()
        recordShortcut(toggleKey, in: AXID.Settings.toolbarShortcut)

        // 期待される結果: 割り当てたあとはその組み合わせになっている。
        let assigned = waitForState("ボタン類の表示を切り替えるキーが割り当てられる") { $0.settings.toolbarShortcut == self.toggleKey }
        XCTAssertEqual(assigned.settings.toolbarShortcut, toggleKey)
        waitForState("キーが登録される") { $0.hotkeys.toolbar == self.toggleKey }
        closeSettings()
        bringSampleToFront()

        // 操作: 割り当てたキーを 1 回押す。
        pressHotkey(toggleKey)

        // 期待される結果: 1 回押すとボタン類が消え、
        // 期待される結果: アプリの状態で、1 回目のあとはボタン類が出ておらず、注釈は 2 件のまま（コメントも変わらない）。
        // してはいけないこと: 隠したときに注釈が消え、コピーしたのと同じことになる。
        let hidden = waitForState("ボタン類が隠れる") { !$0.isToolbarVisible }
        waitForElementToDisappear(AXID.Toolbar.add)
        XCTAssertEqual(hidden.annotations.count, 2)
        XCTAssertEqual(hidden.comments, start.comments)
        XCTAssertEqual(hidden.imagePaths, start.imagePaths)
        XCTAssertEqual(hidden.lastCopiedCount, 0)
        XCTAssertNotEqual(hidden.phase, .copied)

        // 操作: もう 1 回押す。
        pressHotkey(toggleKey)

        // 期待される結果: もう 1 回押すと出る。
        // 期待される結果: アプリの状態で、2 回目のあとは出ており、注釈は 2 件のまま（コメントも変わらない）。
        // してはいけないこと: 隠したあとに出し直すと、新しい回になって注釈が 0 件になっている。
        let shown = waitForState("ボタン類がまた出る") { $0.isToolbarVisible }
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Toolbar.copyPrompt)
        XCTAssertEqual(shown.phase, .idle)
        XCTAssertEqual(shown.annotations.count, 2)
        XCTAssertEqual(shown.comments, start.comments)
        XCTAssertEqual(shown.imagePaths, start.imagePaths)
        XCTAssertEqual(shown.storage.sessionID, start.storage.sessionID)
    }

    // scenario: 何も出ていないときに割り当てたキーを押すと、ボタン類だけが出て、枠は描かない
    func testAssignedKeyShowsToolbarOnlyWhenNothingIsShown() throws {
        // 前提: セットアップ済み。ボタン類の表示を切り替えるキーは割り当て済み。注釈は 0 件で、何も出ていない。
        launch(.setupDone, settings: LaunchSettings(toolbarShortcut: .some(toggleKey)))
        let start = waitForPhase(.hidden)
        XCTAssertFalse(start.isToolbarVisible)
        XCTAssertEqual(start.settings.toolbarShortcut, toggleKey)
        XCTAssertEqual(start.hotkeys.toolbar, toggleKey)

        // 操作: 割り当てたキーを押す。
        pressHotkey(toggleKey)

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態になっており、注釈は 0 件。
        // してはいけないこと: 枠を描く状態になる。
        // してはいけないこと: ボタン類が出ないまま、何も出ていない状態が続く。
        let shown = waitForState("ボタン類だけが出る") { $0.phase == .idle && $0.isToolbarVisible }
        XCTAssertTrue(shown.annotations.isEmpty)
        XCTAssertNil(shown.draft)
        waitForElement(AXID.Toolbar.add)
        let stayed = assertStateStays("枠を描く状態にならない") { $0.phase == .idle && $0.isToolbarVisible }
        XCTAssertTrue(stayed.annotations.isEmpty)
        XCTAssertFalse(isShown(AXID.Draw.surface), "枠を描く面が出ている")

        // 期待される結果: ボタン類が出るが、マウスは枠を描く操作にならず、下のアプリを普段どおりクリックできる。
        let before = try XCTUnwrap(sampleSubmitCount())
        clickSampleSubmit()
        XCTAssertTrue(
            poll(timeout: 5) { self.sampleSubmitCount() == before + 1 },
            "下のアプリの Submit を押せない（回数が \(String(describing: sampleSubmitCount()))）"
        )
        let afterClick = appState()
        XCTAssertEqual(afterClick.phase, .idle)
        XCTAssertTrue(afterClick.isToolbarVisible)
        XCTAssertTrue(afterClick.annotations.isEmpty)
        XCTAssertNil(afterClick.draft)
    }

    // scenario: 割り当てを外すと、そのキーを押しても何も起きない
    func testUnassignedKeyDoesNothing() throws {
        // 前提: セットアップ済み。ボタン類の表示を切り替えるキーは割り当て済み。確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(
            .setupDone,
            settings: LaunchSettings(toolbarShortcut: .some(toggleKey)),
            annotations: SeedAnnotation.samples(2)
        )
        let start = waitForPhase(.idle)
        XCTAssertTrue(start.isToolbarVisible)
        XCTAssertEqual(start.settings.toolbarShortcut, toggleKey)

        // 操作: 設定で割り当てを外して、設定のウィンドウを閉じる。
        openSettingsFromMenuBar()
        clearShortcut(in: AXID.Settings.toolbarShortcut)

        // 期待される結果: アプリの状態で、設定のボタン類の表示を切り替えるキーが割り当てなしになっており、
        let cleared = waitForState("割り当てが外れる") { $0.settings.toolbarShortcut == nil && $0.hotkeys.toolbar == nil }
        XCTAssertNil(cleared.settings.toolbarShortcut)
        closeSettings()
        bringSampleToFront()

        // 操作: 外したキーを押す。
        pressHotkey(toggleKey)

        // 期待される結果: 外したキーを押してもボタン類の出入りが変わらない。
        // してはいけないこと: 設定の表示では外れたのに、外したキーでボタン類が消える。
        let stayed = assertStateStays("外したキーではボタン類が消えない", for: 2) { $0.isToolbarVisible && $0.phase == .idle }
        XCTAssertTrue(stayed.isToolbarVisible)
        XCTAssertEqual(stayed.comments, start.comments)
        XCTAssertNil(stayed.settings.toolbarShortcut)
        waitForElement(AXID.Toolbar.add)
    }
}
