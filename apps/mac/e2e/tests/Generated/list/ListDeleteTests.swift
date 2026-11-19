// spec: e2e/specs/list/delete.md
// spec-sha256: 672f08ffa9a076a60f1994cb7c5e70284cff98685322b81260d917cb0fb3c8cd
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class ListDeleteTests: AkapenUITestCase {
    // scenario: 注釈を消すと、一覧からも画像の置き場からも消える
    func testDeletingRemovesAnnotationAndImage() throws {
        // 前提: 確定済みの注釈が 2 件あり（コメントはそれぞれ別の文。どちらの画像も置き場にある）、一覧を開いている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .list)
        let before = waitForPhase(.listOpen)
        XCTAssertEqual(before.annotations.count, 2)
        let deleted = before.annotations[0]
        let kept = before.annotations[1]
        XCTAssertTrue(fileExists(deleted.imagePath))
        XCTAssertTrue(fileExists(kept.imagePath))

        // 操作: 1 件目の注釈を消す。
        deleteAnnotation(0)

        // 期待される結果: アプリの状態で、注釈が 1 件になっており、残っているのは消さなかった方（コメントと画像のパスも変わらない）。
        // してはいけないこと: 一覧からは消えたのに、アプリの状態には 2 件残っている。
        let state = waitForState("注釈が 1 件になる") { $0.annotations.count == 1 }
        XCTAssertEqual(state.annotations, [kept])

        // 期待される結果: 一覧からその注釈が消え、もう 1 件だけが残る。
        XCTAssertTrue(poll(timeout: 5) { self.listRowCount() == 1 }, "一覧の行が 1 件にならない")
        XCTAssertEqual(listComment(0), kept.comment)

        // 期待される結果: 保存された画像で、消した注釈の画像ファイルが無くなり、残った注釈の画像はある。
        // してはいけないこと: 一覧からは消えたのに、画像ファイルが残る。
        XCTAssertFalse(fileExists(deleted.imagePath))
        // してはいけないこと: 消さなかった方の注釈や、その画像ファイルが消える。
        XCTAssertTrue(fileExists(kept.imagePath))
    }

    // scenario: 消したあとにコピーすると、残った注釈だけがプロンプトに入る
    func testCopyAfterDeleteContainsOnlyRemaining() throws {
        // 前提: 確定済みの注釈が 2 件あり、一覧を開いている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .list)
        let before = waitForPhase(.listOpen)
        XCTAssertEqual(before.annotations.count, 2)
        let deleted = before.annotations[0]
        let kept = before.annotations[1]

        // 操作: 1 件目の注釈を消し、コピーする。
        deleteAnnotation(0)
        waitForState("注釈が 1 件になる") { $0.annotations.count == 1 }
        tapCopyPrompt()
        let copied = waitForCopyFinished()
        XCTAssertEqual(copied.lastCopiedCount, 1)

        // 期待される結果: クリップボードに入った文章で、定型文のあとに、残った注釈のパスとコメントの組だけが並んでいる。
        let prompt = try XCTUnwrap(copiedPrompt())
        XCTAssertEqual(prompt.boilerplate, copied.settings.boilerplate(copied.settings.language))
        XCTAssertEqual(prompt.entries, [CopiedPrompt.Entry(path: kept.imagePath, comment: kept.comment)])

        // してはいけないこと: 消した注釈のパスやコメントが、プロンプトに入る。
        XCTAssertFalse(prompt.text.contains(deleted.imagePath))
        XCTAssertFalse(prompt.text.contains(deleted.comment))
        // してはいけないこと: 消した注釈の分の空行が残る。
        XCTAssertEqual(prompt.text, CopiedPrompt.expectedText(boilerplate: prompt.boilerplate, entries: prompt.entries))
        XCTAssertFalse(prompt.text.contains("\n\n\n"))
    }
}
