// spec: e2e/specs/menu-bar/quit.md
// spec-sha256: 9bc82c13dba033b7d36121215fe0946507befe0957f359d6eeae67e0d4e91a22
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class MenuBarQuitTests: AkapenUITestCase {
    // scenario: 注釈がないときは、確認なしで終了する
    func testQuitWithoutAnnotationsQuitsImmediately() throws {
        // 前提: セットアップ済み。注釈は 0 件で、何も出ていない。
        launch(.setupDone)
        let start = waitForPhase(.hidden)
        XCTAssertTrue(start.annotations.isEmpty)
        XCTAssertNil(start.draft)

        // 操作: メニューバーから終了を選ぶ。
        chooseQuitFromMenuBar()

        // 期待される結果: 確認を出さずに akapen が終了し、メニューバーのアイコンが消える。
        // 期待される結果: アプリの状態で、akapen のプロセスが終了している。
        // （メニューバーのアイコンは akapen のプロセスが持つので、プロセスが終了すれば消える。）
        // してはいけないこと: 注釈がないのに確認が出る。
        // してはいけないこと: 終了を選んでも、プロセスが動き続ける。
        waitForAppToQuit()
        XCTAssertFalse(isAppRunning)
        XCTAssertFalse(appState().windows.quitConfirm, "終了する前に、終了の確認が出ていた")
    }

    // scenario: 注釈が残っているときに終了しようとすると確認が出て、取りやめると注釈を保ったまま動き続ける
    func testCancelQuitKeepsAnnotations() throws {
        // 前提: セットアップ済み。確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let start = waitForPhase(.idle)
        XCTAssertTrue(start.isToolbarVisible)
        XCTAssertEqual(start.annotations.count, 2)

        // 操作: メニューバーから終了を選ぶ。
        chooseQuitFromMenuBar()

        // 期待される結果: まだコピーしていない注釈があることと、その件数が分かる確認が出る。
        // してはいけないこと: 確認を出さずに終了する。
        let confirming = waitForState("終了の確認が出る") { $0.windows.quitConfirm }
        XCTAssertTrue(isAppRunning)
        waitForElement(AXID.QuitConfirm.panel)
        XCTAssertTrue(quitConfirmMessage().contains("2"), "確認に注釈の件数（2）が出ていない: \(quitConfirmMessage())")
        XCTAssertEqual(confirming.annotations, start.annotations)

        // 操作: 確認で取りやめる。
        answerQuitConfirm(quit: false)

        // 期待される結果: 取りやめると確認が消え、ボタン類は出たまま。
        let cancelled = waitForState("終了の確認が消える") { !$0.windows.quitConfirm }
        waitForElementToDisappear(AXID.QuitConfirm.panel)
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Toolbar.copyPrompt)

        // 期待される結果: アプリの状態で、akapen のプロセスは動いていて、ボタン類だけが出ている状態のままで、注釈は 2 件（コメントも変わらない）。
        // してはいけないこと: 取りやめたのに終了する。
        // してはいけないこと: 取りやめたのに、注釈が消える。
        XCTAssertTrue(isAppRunning)
        XCTAssertEqual(cancelled.phase, .idle)
        XCTAssertTrue(cancelled.isToolbarVisible)
        XCTAssertEqual(cancelled.annotations.count, 2)
        XCTAssertEqual(cancelled.comments, start.comments)
        XCTAssertEqual(cancelled.imagePaths, start.imagePaths)
        let settled = assertStateStays("取りやめたあとも、ボタン類だけが出ている状態で注釈が 2 件のまま") { state in
            state.phase == .idle && state.isToolbarVisible && state.comments == start.comments && !state.windows.quitConfirm
        }
        XCTAssertEqual(settled.annotations, start.annotations)
        XCTAssertTrue(isAppRunning)
    }

    // scenario: 注釈が残っているときに確認で終了を選ぶと、終了する
    func testConfirmQuitQuits() throws {
        // 前提: セットアップ済み。確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let start = waitForPhase(.idle)
        XCTAssertEqual(start.annotations.count, 2)

        // 操作: メニューバーから終了を選ぶ。
        chooseQuitFromMenuBar()

        // 期待される結果: 確認が出る。
        // してはいけないこと: 確認が出ている間に、答える前に終了してしまう。
        waitForState("終了の確認が出る") { $0.windows.quitConfirm }
        waitForElement(AXID.QuitConfirm.confirm)
        let waiting = assertStateStays("答えるまでは確認が出たまま") { $0.windows.quitConfirm }
        XCTAssertTrue(isAppRunning, "確認に答える前に終了した")
        XCTAssertEqual(waiting.annotations, start.annotations)

        // 操作: 確認で終了を選ぶ。
        answerQuitConfirm(quit: true)

        // 期待される結果: 終了を選ぶと akapen が終了し、メニューバーのアイコンが消える。
        // 期待される結果: アプリの状態で、akapen のプロセスが終了している。
        // （メニューバーのアイコンは akapen のプロセスが持つので、プロセスが終了すれば消える。）
        // してはいけないこと: 確認で終了を選んでも、プロセスが動き続ける。
        waitForAppToQuit()
        XCTAssertFalse(isAppRunning)
    }
}
