// spec: e2e/specs/list/review.md
// spec-sha256: cb7c81f0fa4cad8e28b4132f80e965900c6f4e41a4b8f70d93d7835a2bb46ad8
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class ListReviewTests: AkapenUITestCase {
    // scenario: 一覧を開くと、すべての注釈を確定した順に見返せる
    func testOpeningListShowsAnnotationsInOrder() throws {
        // 前提: 確定済みの注釈が 2 件あり（コメントはそれぞれ別の文）、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.idle)
        XCTAssertEqual(before.annotations.count, 2)
        XCTAssertNotEqual(before.comments[0], before.comments[1])

        // 操作: 一覧を開く。
        openList()

        // 期待される結果: アプリの状態で、一覧を開いている状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        let state = waitForPhase(.listOpen)
        XCTAssertEqual(state.annotations, before.annotations)

        // 期待される結果: 2 件の注釈が、確定した順に、画像の縮小とコメントつきで並ぶ。
        // してはいけないこと: 一覧に出ている件数と、アプリの状態の注釈の件数が違う。
        XCTAssertEqual(listRowCount(), state.annotations.count)
        // してはいけないこと: 一覧の並びが、確定した順と違う。
        for (index, annotation) in state.annotations.enumerated() {
            XCTAssertEqual(listComment(index), annotation.comment, "\(index) 行目のコメントが違う")
            XCTAssertEqual(listThumbnailPath(index), annotation.imagePath, "\(index) 行目の画像の縮小が違う")
        }

        // してはいけないこと: 開いただけで、注釈の順番やコメントが変わる。
        XCTAssertEqual(appState().annotations, before.annotations)
    }

    // scenario: 一覧を閉じると、注釈を保ったままボタン類だけの状態に戻る
    func testClosingListReturnsToToolbar() throws {
        // 前提: 確定済みの注釈が 2 件あり、一覧を開いている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .list)
        let before = waitForPhase(.listOpen)
        XCTAssertEqual(before.annotations.count, 2)
        waitForElement(AXID.List.panel)

        // 操作: 一覧を閉じる。
        tapList()

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態になっており、注釈は 2 件のまま。
        let state = waitForPhase(.idle)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations, before.annotations)

        // 期待される結果: 一覧が消え、ボタン類は出たまま。
        // してはいけないこと: 一覧と一緒にボタン類まで消える。
        waitForElementToDisappear(AXID.List.panel)
        XCTAssertTrue(isShown(AXID.Toolbar.add))

        // 期待される結果: 保存された画像で、2 件の注釈の画像が残っている。
        // してはいけないこと: 開いて閉じただけで、注釈や画像ファイルが消える。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }
    }
}
