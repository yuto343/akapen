// spec: e2e/specs/menu-bar/settings.md
// spec-sha256: ddfbb2f3cb282b9dedf757735c59521e8411408d15b2e4752c74fc8e8da621a9
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class MenuBarSettingsTests: AkapenUITestCase {
    // scenario: メニューバーから設定を開き、変えた値がアプリに入る
    func testOpenSettingsFromMenuBarAndChangeValue() throws {
        // 前提: セットアップ済み、画像を残す日数は既定の 7 日。確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let start = waitForPhase(.idle)
        XCTAssertEqual(start.settings.imageRetentionDays, 7)
        XCTAssertFalse(start.windows.settings)

        // 操作: メニューバーから設定を開く。
        openSettingsFromMenuBar()

        // 期待される結果: 設定のウィンドウが開く。
        // してはいけないこと: メニューバーから選んでも、設定のウィンドウが開かない。
        waitForElement(AXID.Settings.window)
        waitForState("設定のウィンドウが開く") { $0.windows.settings }

        // 操作: 設定のウィンドウで、画像を残す日数を 14 日に変える。
        enterRetentionDays("14")

        // 期待される結果: アプリの状態で、設定のウィンドウで変えた値（画像を残す日数など）が新しい値になっている。
        // してはいけないこと: 設定のウィンドウでは変わって見えるのに、アプリの状態の値が元のまま。
        let changed = waitForState("画像を残す日数が 14 日になる") { $0.settings.imageRetentionDays == 14 }
        XCTAssertEqual(changed.settings.imageRetentionDays, 14)
        XCTAssertEqual(element(AXID.Settings.imageRetentionDays).value as? String, "14")
    }

    // scenario: 設定を開いても、注釈とボタン類はそのまま
    func testOpeningSettingsKeepsAnnotationsAndToolbar() throws {
        // 前提: セットアップ済み、画像を残す日数は既定の 7 日。確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let start = waitForPhase(.idle)
        XCTAssertTrue(start.isToolbarVisible)
        XCTAssertEqual(start.comments, Array(SeedAnnotation.sampleComments.prefix(2)))

        // 操作: メニューバーから設定を開く。
        openSettingsFromMenuBar()
        waitForState("設定のウィンドウが開く") { $0.windows.settings }

        // 期待される結果: 設定のウィンドウが開いている間も、ボタン類は出たまま。
        // してはいけないこと: 設定を開いたことで、ボタン類が消える、または枠を描く状態になる。
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Toolbar.list)
        waitForElement(AXID.Toolbar.copyPrompt)
        XCTAssertFalse(isShown(AXID.Draw.surface), "設定を開いたら、枠を描く面が出た")

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態のままで、注釈は 2 件（順番とコメントも変わらない）。
        // してはいけないこと: 設定を開いたことで、注釈が消える。
        let opened = assertStateStays("設定を開いている間も、ボタン類だけが出ていて注釈が 2 件のまま") { state in
            state.windows.settings && state.phase == .idle && state.isToolbarVisible && state.comments == start.comments
        }
        XCTAssertEqual(opened.phase, .idle)
        XCTAssertTrue(opened.isToolbarVisible)
        XCTAssertEqual(opened.annotations.count, 2)
        XCTAssertEqual(opened.comments, start.comments)
        XCTAssertEqual(opened.imagePaths, start.imagePaths)
        XCTAssertEqual(opened.storage.sessionID, start.storage.sessionID)
        XCTAssertTrue(isShown(AXID.Settings.window))
    }
}
