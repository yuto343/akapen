// spec: e2e/specs/draw/cancel.md
// spec-sha256: a2e1991864d57ebece090cf4d0504f51693460306c32f8281c600d796414b107
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class DrawCancelTests: AkapenUITestCase {
    // scenario: 注釈が 0 件のときに Esc を押すと、何も残さずにすべて消える
    func testEscapeWithoutAnnotationsHidesEverything() throws {
        // 前提: 注釈は 0 件。ホットキーで枠を描く状態に入る。
        launch(.setupDone)
        startDrawing()
        let submitCountBefore = try XCTUnwrap(sampleSubmitCount())

        // 操作: Esc を押す。
        pressEscape()

        // 期待される結果: アプリの状態で、何も出ていない状態になっており、注釈は 0 件で、書きかけの注釈もない。
        let state = waitForPhase(.hidden)
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertNil(state.draft)

        // 期待される結果: 枠を描く操作が終わり、ボタン類も消えて、下のアプリを普段どおりクリックできる。
        XCTAssertFalse(state.isToolbarVisible)
        waitForElementToDisappear(AXID.Draw.surface)
        waitForElementToDisappear(AXID.Toolbar.list)
        clickSampleSubmit()
        XCTAssertTrue(poll(timeout: 5) { self.sampleSubmitCount() == submitCountBefore + 1 }, "下のアプリのボタンが押せない")

        // 期待される結果: 保存された画像で、この回の画像が 1 枚もない。
        XCTAssertTrue(imageFilesInCurrentSession().isEmpty)
        XCTAssertTrue(imageFiles().isEmpty)

        // してはいけないこと: ボタン類が画面に残る。
        let after = appState()
        XCTAssertFalse(after.isToolbarVisible)
        XCTAssertEqual(after.phase, .hidden)
        XCTAssertFalse(isShown(AXID.Toolbar.list))
        // してはいけないこと: マウスが枠を描く操作のまま残り、下のアプリをクリックできない。（上のクリックで確かめた）
    }

    // scenario: 注釈が残っているときに Esc を押すと、注釈を保ったままボタン類ごと隠れる
    func testEscapeWithAnnotationsHidesAndKeepsThem() throws {
        // 前提: 確定済みの注釈が 2 件ある。ホットキーで枠を描く状態に入る。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.hidden)
        XCTAssertEqual(before.annotations.count, 2)
        startDrawing()
        let submitCountBefore = try XCTUnwrap(sampleSubmitCount())

        // 操作: Esc を押す。
        pressEscape()

        // 期待される結果: アプリの状態で、何も出ていない状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        let state = waitForPhase(.hidden)
        XCTAssertFalse(state.isToolbarVisible)
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertEqual(state.comments, before.comments)
        XCTAssertNil(state.draft)

        // 期待される結果: 枠を描く操作が終わり、ボタン類も消えて、下のアプリを普段どおりクリックできる。
        waitForElementToDisappear(AXID.Draw.surface)
        waitForElementToDisappear(AXID.Toolbar.list)
        clickSampleSubmit()
        XCTAssertTrue(poll(timeout: 5) { self.sampleSubmitCount() == submitCountBefore + 1 }, "下のアプリのボタンが押せない")

        // 期待される結果: 保存された画像で、2 件の注釈の画像が残っている。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }

        // してはいけないこと: 隠れたのと一緒に、注釈や、その画像ファイルが消える。（上で確かめた）
        XCTAssertEqual(appState().annotations, before.annotations)
        // してはいけないこと: マウスが枠を描く操作のまま残り、下のアプリをクリックできない。（上のクリックで確かめた）
    }

    // scenario: 何も出ていないときに Esc を押しても、何も変わらない
    func testEscapeWhileHiddenDoesNothing() throws {
        // 前提: 確定済みの注釈が 2 件あり、akapen は何も出していない。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.hidden)
        XCTAssertFalse(before.isToolbarVisible)

        // 操作: Esc を押す。
        pressEscape()

        // 期待される結果: アプリの状態で、何も出ていない状態のままで、注釈は 2 件のまま。
        let state = assertStateStays("何も出ていない状態のまま", for: 1.5) { state in
            state.phase == .hidden && !state.isToolbarVisible && state.annotations == before.annotations
        }
        XCTAssertEqual(state.annotations.count, 2)

        // 期待される結果: ボタン類は出ないまま。
        XCTAssertFalse(isShown(AXID.Toolbar.list))

        // してはいけないこと: ボタン類が出る、または枠を描く状態になる。（上で確かめた）
        XCTAssertNotEqual(state.phase, .drawing)
        // してはいけないこと: 注釈が消える。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }
    }
}
