// spec: e2e/specs/draw/toggle.md
// spec-sha256: 39b82a5fd171ff9d512cc26b7b4371e633c9ca70829455ab1995759a76749456
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class DrawToggleTests: AkapenUITestCase {
    // scenario: 枠を描く状態でホットキーを押すと、ボタン類が消えて下のアプリを普段どおり操作できる
    func testHotkeyWhileDrawingHides() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .toolbar)
        let before = waitForPhase(.drawing)
        XCTAssertTrue(before.isToolbarVisible)
        XCTAssertEqual(before.annotations.count, 2)
        waitForElement(AXID.Draw.surface)
        let submitCountBefore = try XCTUnwrap(sampleSubmitCount())

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: アプリの状態で、何も出ていない状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        let state = waitForPhase(.hidden)
        XCTAssertFalse(state.isToolbarVisible)
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertEqual(state.comments, before.comments)

        // 期待される結果: ボタン類が消え、マウスが普段どおりの操作に戻り、撮影対象のアプリのボタンを押すと、押した回数の表示が増える。
        waitForElementToDisappear(AXID.Toolbar.list)
        waitForElementToDisappear(AXID.Draw.surface)
        clickSampleSubmit()
        // してはいけないこと: ボタン類は消えたのに、akapen の見えない面がクリックを横取りし、撮影対象のアプリのボタンが押せない。
        XCTAssertTrue(poll(timeout: 5) { self.sampleSubmitCount() == submitCountBefore + 1 }, "下のアプリのボタンが押せない")

        // 期待される結果: 保存された画像で、2 件の注釈の画像が残っている。
        // してはいけないこと: 隠しただけで、注釈や画像ファイルが消える。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }
        XCTAssertEqual(appState().annotations, before.annotations)
    }

    // scenario: ボタン類が出ているあいだは、下のアプリをクリックしても操作されない
    func testClicksDoNotReachTheAppBelowWhileToolbarIsShown() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .toolbar)
        let before = waitForPhase(.drawing)
        waitForElement(AXID.Draw.surface)
        let submitCountBefore = try XCTUnwrap(sampleSubmitCount())

        // 操作: 撮影対象のアプリのボタンの上をクリックする。
        clickSampleSubmit()

        // 期待される結果: アプリの状態で、枠を描く状態のままで、注釈は 2 件のまま。
        // してはいけないこと: クリックしただけで、注釈や書きかけの注釈ができる。
        let state = assertStateStays("枠を描く状態のまま", for: 1.5) { state in
            state.phase == .drawing && state.annotations == before.annotations && state.draft == nil
        }
        XCTAssertEqual(state.annotations.count, 2)

        // 期待される結果: 撮影対象のアプリのボタンの上をクリックしても、押した回数の表示は増えない。
        // してはいけないこと: クリックが下のアプリに届き、撮影対象のアプリのボタンが押される。
        XCTAssertEqual(sampleSubmitCount(), submitCountBefore)
    }

    // scenario: 隠したあとにホットキーで出し直すと、注釈が残っていて、同じ回のまま次の枠を足せる
    func testShowingAgainContinuesTheSession() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。ホットキーで一度隠す。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .toolbar)
        let before = waitForPhase(.drawing)
        let sessionDirectory = try XCTUnwrap(before.storage.sessionDirectory)
        let imagesBefore = try before.imagePaths.map { try XCTUnwrap(fileContents($0)) }
        pressHotkey()
        waitForPhase(.hidden)

        // 操作: ホットキーで出し直す。
        pressHotkey()

        // 期待される結果: ボタン類が出て、マウスが枠を描く操作になる。
        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 2 件のまま、この回のフォルダも変わらない。
        let shown = waitForPhase(.drawing)
        XCTAssertTrue(shown.isToolbarVisible)
        waitForElement(AXID.Toolbar.list)
        waitForElement(AXID.Draw.surface)
        XCTAssertEqual(shown.annotations, before.annotations)
        // してはいけないこと: 出し直したときに新しい回が始まり、それまでの注釈が消える。
        XCTAssertEqual(shown.storage.sessionDirectory, sessionDirectory)

        // 操作: 続けて枠を描いてコメントを確定する。
        annotate(around: AXID.Sample.firstField, comment: "三つ目の注釈")

        // 期待される結果: アプリの状態で、続けて枠を描いてコメントを確定すると、注釈が 3 件になり、3 件目が最後に並ぶ。
        let after = appState()
        XCTAssertEqual(after.annotations.count, 3)
        XCTAssertEqual(after.comments, before.comments + ["三つ目の注釈"])
        XCTAssertEqual(Array(after.imagePaths.prefix(2)), before.imagePaths)

        // 期待される結果: 保存された画像で、この回のフォルダに 3 件分の画像があり、前からある 2 件の画像は書き換わっていない。
        let third = try XCTUnwrap(after.imagePaths.last)
        XCTAssertTrue(third.hasPrefix(sessionDirectory), "3 件目の画像がこの回のフォルダにない: \(third)")
        XCTAssertEqual(Set(imageFilesInCurrentSession()), Set(after.imagePaths))
        XCTAssertEqual(imageFilesInCurrentSession().count, 3)
        // してはいけないこと: 3 件目の画像が、前からある注釈の画像を上書きする。
        XCTAssertFalse(before.imagePaths.contains(third))
        for (path, data) in zip(before.imagePaths, imagesBefore) {
            XCTAssertEqual(fileContents(path), data, "前からある注釈の画像が書き換わった: \(path)")
        }
    }

    // scenario: 一覧を開いているときにホットキーを押すと、一覧ごと隠れて注釈は残る
    func testHotkeyWhileListIsOpenHides() throws {
        // 前提: 確定済みの注釈が 2 件あり、一覧を開いている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .list)
        let before = waitForPhase(.listOpen)
        waitForElement(AXID.List.panel)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: アプリの状態で、何も出ていない状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        let state = waitForPhase(.hidden)
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertEqual(state.comments, before.comments)

        // 期待される結果: 一覧とボタン類が消える。
        // してはいけないこと: 一覧だけが閉じて、ボタン類が残る。
        XCTAssertFalse(state.isToolbarVisible)
        waitForElementToDisappear(AXID.List.panel)
        waitForElementToDisappear(AXID.Toolbar.list)
        // してはいけないこと: 一覧ごと隠したことで、注釈が消える。（上で確かめた）
    }
}
