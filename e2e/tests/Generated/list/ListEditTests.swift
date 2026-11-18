// spec: e2e/specs/list/edit.md
// spec-sha256: ebaca1d240a7a6cb86c0ec3a18f47160e453648c038eb921e01d484151bead81
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class ListEditTests: AkapenUITestCase {
    // scenario: コメントを直すと、その注釈のコメントだけが変わり、コピーしたプロンプトにも入る
    func testEditedCommentIsSavedAndCopied() throws {
        // 前提: 確定キーは既定（Enter で確定）。確定済みの注釈が 2 件あり（コメントはそれぞれ別の文）、一覧を開いている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter), annotations: SeedAnnotation.samples(2), open: .list)
        let before = waitForPhase(.listOpen)
        XCTAssertEqual(before.annotations.count, 2)
        let oldComment = before.annotations[0].comment
        let newComment = "Use the same padding on both sides"

        // 操作: 1 件目のコメントを直して確定する。
        editAnnotation(0, to: newComment, confirmKey: .enter)

        // 期待される結果: アプリの状態で、直した注釈のコメントが新しい文になっており、もう 1 件のコメントと、
        // 両方の画像のパスと、注釈の順番は変わらない。
        // してはいけないこと: 一覧の表示だけが変わり、アプリの状態のコメントは元のまま。
        let state = waitForState("1 件目のコメントが直る") { $0.annotations.first?.comment == newComment }
        // してはいけないこと: 直した注釈が、新しい注釈として 1 件増える。
        XCTAssertEqual(state.annotations.count, 2)
        XCTAssertEqual(state.annotations.map(\.id), before.annotations.map(\.id))
        XCTAssertEqual(state.imagePaths, before.imagePaths)
        // してはいけないこと: 別の注釈のコメントが変わる。
        XCTAssertEqual(state.annotations[1], before.annotations[1])

        // 期待される結果: 一覧のその注釈に、直したあとのコメントが出る。
        XCTAssertTrue(poll(timeout: 5) { self.listComment(0) == newComment }, "一覧のコメントが直らない: \(listComment(0))")
        XCTAssertEqual(listComment(1), before.annotations[1].comment)

        // 操作: コピーする。
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: クリップボードに入った文章で、直した注釈のパスの次の行に、直したあとのコメントが入っている。
        let prompt = try XCTUnwrap(copiedPrompt())
        XCTAssertEqual(prompt.entries, [
            CopiedPrompt.Entry(path: before.annotations[0].imagePath, comment: newComment),
            CopiedPrompt.Entry(path: before.annotations[1].imagePath, comment: before.annotations[1].comment),
        ])
        // してはいけないこと: コピーしたプロンプトに、直す前のコメントが入る。
        XCTAssertFalse(prompt.text.contains(oldComment))
    }

    // scenario: コメントを空にして確定しようとしても、元のコメントが残る
    func testEmptyEditKeepsOriginalComment() throws {
        // 前提: 確定キーは既定（Enter で確定）。確定済みの注釈が 2 件あり、一覧を開いている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter), annotations: SeedAnnotation.samples(2), open: .list)
        let before = waitForPhase(.listOpen)
        XCTAssertEqual(before.annotations.count, 2)

        // 操作: 1 件目のコメントを空にして確定しようとする。
        editAnnotation(0, to: "", confirmKey: .enter)

        // 期待される結果: アプリの状態で、その注釈のコメントは元の文のままで、注釈は 2 件のまま。
        // してはいけないこと: コメントが空の注釈になる。
        // してはいけないこと: 空にしたことで、注釈が消える。
        let state = assertStateStays("注釈が元のまま", for: 1.5) { state in
            state.annotations == before.annotations
        }
        XCTAssertEqual(state.annotations.count, 2)
        XCTAssertEqual(state.annotations[0].comment, before.annotations[0].comment)
        XCTAssertFalse(state.comments.contains(""))
    }
}
