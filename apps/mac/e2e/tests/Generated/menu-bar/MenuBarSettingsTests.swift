// spec: e2e/specs/menu-bar/settings.md
// spec-sha256: 28f8e00c567c494f647ed15b15222fae632e8f5a5011750ae1322f607d8a197a
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class MenuBarSettingsTests: AkapenUITestCase {
    // scenario: メニューバーから設定を開き、変えた値がアプリに入る
    func testOpenSettingsFromMenuBarAndChangeValue() throws {
        // 前提: セットアップ済み、画像を残す日数は既定の 7 日。確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .toolbar)
        let start = waitForPhase(.drawing)
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

    // scenario: 設定を開くとボタン類は隠れるが、注釈は残っていて、ホットキーで続きから描ける
    func testOpeningSettingsHidesToolbarAndKeepsAnnotations() throws {
        // 前提: セットアップ済み、画像を残す日数は既定の 7 日。確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .toolbar)
        let start = waitForPhase(.drawing)
        XCTAssertTrue(start.isToolbarVisible)
        XCTAssertEqual(start.comments, Array(SeedAnnotation.sampleComments.prefix(2)))

        // 操作: メニューバーから設定を開く。
        openSettingsFromMenuBar()

        // 期待される結果: アプリの状態で、設定のウィンドウが出ていて、何も出ていない状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        // してはいけないこと: 設定を開いたことで、注釈が消える。
        let opened = waitForState("設定のウィンドウが開き、何も出ていない状態になる") { state in
            state.windows.settings && state.phase == .hidden
        }
        XCTAssertFalse(opened.isToolbarVisible)
        XCTAssertEqual(opened.annotations, start.annotations)
        XCTAssertEqual(opened.comments, start.comments)

        // 期待される結果: 設定のウィンドウが開き、ボタン類は消える。
        // してはいけないこと: 設定を開いても枠を描く状態のままで、設定のウィンドウの上を akapen の面が覆う。
        waitForElement(AXID.Settings.window)
        waitForElementToDisappear(AXID.Toolbar.list)
        waitForElementToDisappear(AXID.Draw.surface)
        // 設定のウィンドウを操作できる（面に覆われていれば、入力が届かない）。
        enterRetentionDays("10")
        waitForState("画像を残す日数が 10 日になる") { $0.settings.imageRetentionDays == 10 }

        // 期待される結果: アプリの状態で、設定を閉じてホットキーを押すと、注釈は 2 件のまま枠を描く状態になる。
        closeSettings()
        bringSampleToFront()
        pressHotkey()
        let resumed = waitForPhase(.drawing)
        XCTAssertTrue(resumed.isToolbarVisible)
        XCTAssertEqual(resumed.annotations, start.annotations)
        XCTAssertEqual(resumed.storage.sessionID, start.storage.sessionID)
        waitForElement(AXID.Toolbar.list)
    }
}
