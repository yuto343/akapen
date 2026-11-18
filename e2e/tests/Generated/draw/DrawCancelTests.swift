// spec: e2e/specs/draw/cancel.md
// spec-sha256: 9cd8ac3f987172cba1bce845d41bca0fe924929b7ac3fb138894b85dc30ab43d
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
        waitForElementToDisappear(AXID.Toolbar.add)
        clickSampleSubmit()
        XCTAssertTrue(poll(timeout: 5) { self.sampleSubmitCount() == submitCountBefore + 1 }, "下のアプリのボタンが押せない")

        // 期待される結果: 保存された画像で、この回の画像が 1 枚もない。
        XCTAssertTrue(imageFilesInCurrentSession().isEmpty)
        XCTAssertTrue(imageFiles().isEmpty)

        // してはいけないこと: ボタン類だけが画面に残る。
        let after = appState()
        XCTAssertFalse(after.isToolbarVisible)
        XCTAssertEqual(after.phase, .hidden)
        XCTAssertFalse(isShown(AXID.Toolbar.add))
        // してはいけないこと: マウスが枠を描く操作のまま残り、下のアプリをクリックできない。（上のクリックで確かめた）
    }

    // scenario: 注釈が残っているときに Esc を押すと、注釈を保ったままボタン類だけの状態に戻る
    func testEscapeWithAnnotationsReturnsToToolbar() throws {
        // 前提: 確定済みの注釈が 2 件ある。ホットキーで枠を描く状態に入る。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.idle)
        XCTAssertEqual(before.annotations.count, 2)
        startDrawing()

        // 操作: Esc を押す。
        pressEscape()

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        let state = waitForPhase(.idle)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertNil(state.draft)

        // 期待される結果: 枠を描く操作が終わり、ボタン類は出たまま。
        waitForElementToDisappear(AXID.Draw.surface)
        XCTAssertTrue(isShown(AXID.Toolbar.add))

        // 期待される結果: 保存された画像で、2 件の注釈の画像が残っている。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }

        // してはいけないこと: ボタン類まで消えて、注釈が残っているのに見えなくなる。（isToolbarVisible とボタンの要素で確かめた）
        // してはいけないこと: 注釈や、その画像ファイルが消える。（上で確かめた）
    }

    // scenario: ボタン類だけが出ているときに Esc を押しても、何も変わらない
    func testEscapeOnToolbarOnlyDoesNothing() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.idle)
        XCTAssertTrue(before.isToolbarVisible)

        // 操作: Esc を押す。
        pressEscape()

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態のままで、注釈は 2 件のまま。
        let state = assertStateStays("ボタン類だけが出ている状態のまま", for: 1.5) { state in
            state.phase == .idle && state.isToolbarVisible && state.annotations == before.annotations
        }
        XCTAssertEqual(state.annotations.count, 2)

        // 期待される結果: ボタン類は出たまま。
        XCTAssertTrue(isShown(AXID.Toolbar.add))

        // してはいけないこと: ボタン類が消える。（上で確かめた）
        // してはいけないこと: 注釈が消える、または何も出ていない状態（新しい回の前）に戻る。
        XCTAssertNotEqual(state.phase, .hidden)
        XCTAssertEqual(state.storage.sessionDirectory, before.storage.sessionDirectory)
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }
    }
}
