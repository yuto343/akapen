// spec: e2e/specs/draw/capture.md
// spec-sha256: 626e100e092c01d2f50f506278a9c9bc5c9c1185760f845e6491a48380f18a77
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class DrawCaptureTests: AkapenUITestCase {
    // scenario: 枠を描いて離すと、枠のあるウィンドウが赤枠入りの画像として残る
    func testFrameCapturesWindow() throws {
        // 前提: 注釈は 0 件で、ホットキーで枠を描く状態に入ったところから始める。
        launch(.setupDone)
        let submitCountBefore = sampleSubmitCount()
        startDrawing()

        // 操作: 撮影対象のアプリの Submit を囲む枠を描いて離す。
        let drawn = drawFrame(around: AXID.Sample.button)

        // 期待される結果: アプリの状態で、コメントを書いている状態になっており、
        // 書きかけの注釈の画像のパスが、この回のフォルダの画像を指している。
        let state = waitForPhase(.commenting)
        let draft = try XCTUnwrap(state.draft)
        let session = try XCTUnwrap(state.storage.sessionDirectory)
        XCTAssertTrue(draft.imagePath.hasPrefix(session.hasSuffix("/") ? session : session + "/"), "画像のパスがこの回のフォルダの下にない")

        // 期待される結果: 描いた枠が画面に残ったまま、その近くにコメントの入力欄が出る。
        let frameElement = waitForElement(AXID.Draw.frame)
        let field = waitForElement(AXID.Comment.field)
        XCTAssertTrue(frameElement.frame.intersects(drawn), "画面上の枠が、描いた位置にない")
        XCTAssertTrue(field.frame.intersects(drawn.insetBy(dx: -120, dy: -120)), "コメントの入力欄が、描いた枠の近くにない")

        // 期待される結果: アプリの状態で、最後に描いた枠の位置と大きさが、ドラッグした範囲と数 pt の誤差で一致している。
        assertRect(state.lastDrawnRect?.cgRect, matches: drawn)

        // 期待される結果: 保存された画像で、この回のフォルダに画像が 1 枚だけでき、縦横の比が撮影対象のウィンドウと同じで、
        // ウィンドウの中で描いた枠に当たる位置に赤枠が入っている。
        XCTAssertEqual(imageFilesInCurrentSession(), [draft.imagePath])
        assertImage(at: draft.imagePath, showsFrame: drawn)

        // してはいけないこと: 画像が画面全体や、枠の中だけを切り抜いたものになっている。（縦横の比と赤枠の位置で確かめた）
        // してはいけないこと: 赤枠が入っていない、または描いた位置からずれている。（assertImage で確かめた）
        // してはいけないこと: 1 つの枠で画像が 2 枚以上できる。
        XCTAssertEqual(imageFiles(), [draft.imagePath])
        // してはいけないこと: 枠を描いたドラッグが下のアプリに届き、撮影対象のアプリのボタンが押されたことになっている。
        XCTAssertEqual(sampleSubmitCount(), submitCountBefore)
        // してはいけないこと: コメントを確定する前に、注釈の件数が増えている。
        XCTAssertTrue(state.annotations.isEmpty)
    }

    // scenario: ほとんど動かさずに離しても、撮影されない
    func testTinyDragDoesNotCapture() throws {
        // 前提: 注釈は 0 件で、ホットキーで枠を描く状態に入ったところから始める。
        launch(.setupDone)
        startDrawing()

        // 操作: ほとんど動かさずにドラッグして離す。
        let tiny = dragBarely(on: AXID.Sample.form)

        // ドラッグが akapen に届いたこと（最後に描いた枠が、ほぼ大きさのない枠になったこと）を待つ。
        let reached = waitForState("ほとんど動かさない枠が届く") { $0.lastDrawnRect != nil }
        let reachedRect = try XCTUnwrap(reached.lastDrawnRect?.cgRect)
        XCTAssertLessThan(reachedRect.width, 4)
        XCTAssertLessThan(reachedRect.height, 4)
        XCTAssertEqual(reachedRect.minX, tiny.minX, accuracy: 4)
        XCTAssertEqual(reachedRect.minY, tiny.minY, accuracy: 4)

        // 期待される結果: アプリの状態で、枠を描く状態のままで、書きかけの注釈はなく、注釈は 0 件。
        let state = assertStateStays("枠を描く状態のまま", for: 1.5) { state in
            state.phase == .drawing && state.draft == nil && state.annotations.isEmpty
        }
        XCTAssertNil(state.draft)

        // 期待される結果: マウスは枠を描く操作のままで、コメントの入力欄は出ない。
        XCTAssertTrue(isShown(AXID.Draw.surface))
        XCTAssertFalse(isShown(AXID.Comment.field))

        // 期待される結果: 保存された画像で、この回のフォルダに画像が 1 枚もない。
        XCTAssertTrue(imageFilesInCurrentSession().isEmpty)

        // してはいけないこと: 幅や高さがほぼ 0 の枠で画像が保存される。
        XCTAssertTrue(imageFiles().isEmpty)
        // してはいけないこと: コメントの入力欄が出る。（上で確かめた）
        // してはいけないこと: 枠を描く状態から抜けてしまい、もう一度描くのにホットキーが要る。
        // ホットキーを押さずに、そのまま次の枠を描けることを確かめる。
        let drawn = drawFrame(around: AXID.Sample.button)
        let commenting = waitForPhase(.commenting)
        assertRect(commenting.lastDrawnRect?.cgRect, matches: drawn)
    }
}
