// spec: e2e/specs/comment/cancel.md
// spec-sha256: b9df2aa0ac959708ba505044f722aee5c7fe6a5eb9e879c956ad4b40193d8ac2
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class CommentCancelTests: AkapenUITestCase {
    // scenario: 注釈が 0 件のときに取り消すと、撮った画像は残らず、枠を描く状態に戻る
    func testCancelWithoutAnnotationsDiscardsImageAndKeepsDrawing() throws {
        // 前提: 注釈は 0 件で、枠を描き終えてコメントの入力欄が出ている。
        launch(.setupDone)
        startCommenting()
        let commenting = waitForPhase(.commenting)
        let draft = try XCTUnwrap(commenting.draft)
        XCTAssertTrue(fileExists(draft.imagePath))

        // 操作: コメントの入力を取り消す（Esc）。
        pressEscape()

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 0 件で、書きかけの注釈もない。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertNil(state.draft)

        // 期待される結果: 入力欄と画面上の赤枠が消え、ボタン類は出たままで、マウスが枠を描く操作になっている。
        XCTAssertTrue(state.isToolbarVisible)
        waitForElementToDisappear(AXID.Comment.field)
        waitForElementToDisappear(AXID.Draw.frame)
        XCTAssertTrue(isShown(AXID.Toolbar.list))
        XCTAssertTrue(isShown(AXID.Draw.surface))

        // 期待される結果: 保存された画像で、撮った画像のファイルが消えている。
        XCTAssertFalse(fileExists(draft.imagePath))

        // してはいけないこと: 画像ファイルだけが置き場に残る。
        XCTAssertTrue(imageFiles().isEmpty)
        // してはいけないこと: コメントが空の注釈ができる。（注釈 0 件で確かめた）
        // してはいけないこと: ボタン類ごと隠れて、描き直すのにホットキーを押し直す必要がある。
        // （ホットキーを押さずに枠を描くと、コメントを書いている状態になる）
        XCTAssertNotEqual(state.phase, .hidden)
        drawFrame(around: AXID.Sample.firstField)
        XCTAssertNotNil(waitForPhase(.commenting).draft)
    }

    // scenario: 注釈が残っているときに取り消すと、それまでの注釈を保ったまま、枠を描く状態に戻る
    func testCancelWithAnnotationsKeepsThem() throws {
        // 前提: 確定済みの注釈が 1 件あり、枠を描き終えてコメントの入力欄が出ている。途中まで書いてある。
        launch(.setupDone, annotations: SeedAnnotation.samples(1))
        let before = waitForPhase(.hidden)
        XCTAssertEqual(before.annotations.count, 1)
        startCommenting(around: AXID.Sample.thirdField)
        let commenting = waitForPhase(.commenting)
        let draft = try XCTUnwrap(commenting.draft)
        typeComment("This frame is in the wrong place")

        // 操作: コメントの入力を取り消す（Esc）。
        pressEscape()

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 1 件のまま（コメントも変わらない）。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertNil(state.draft)

        // 期待される結果: 入力欄と画面上の赤枠が消え、ボタン類は出たままで、マウスが枠を描く操作になっている。
        waitForElementToDisappear(AXID.Comment.field)
        waitForElementToDisappear(AXID.Draw.frame)
        XCTAssertTrue(isShown(AXID.Toolbar.list))
        XCTAssertTrue(isShown(AXID.Draw.surface))

        // 期待される結果: 保存された画像で、取り消した枠の画像は消え、それまでの注釈の画像は残っている。
        XCTAssertFalse(fileExists(draft.imagePath))
        XCTAssertTrue(fileExists(before.annotations[0].imagePath))

        // してはいけないこと: それまでの注釈の画像まで消える。（上で確かめた）
        XCTAssertEqual(imageFiles(), [before.annotations[0].imagePath])
        // してはいけないこと: 書きかけのコメントが注釈として残る。
        XCTAssertFalse(state.comments.contains("This frame is in the wrong place"))
        // してはいけないこと: ボタン類まで消えて、残っている注釈が見えなくなる。（上で確かめた）
    }
}
