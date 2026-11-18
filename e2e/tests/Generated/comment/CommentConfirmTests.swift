// spec: e2e/specs/comment/confirm.md
// spec-sha256: c89ee17acdc5403153be86e3c2288ff5608173aef1931f7fe8de8aadb6a75257
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class CommentConfirmTests: AkapenUITestCase {
    // scenario: コメントを書いて確定すると注釈になり、画面上の枠と入力欄が消えて、すぐ次の枠を描ける
    func testConfirmedCommentBecomesAnnotationAndDrawingResumes() throws {
        // 前提: 確定キーは既定。確定済みの注釈が 1 件あり、枠を描き終えてコメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter), annotations: SeedAnnotation.samples(1))
        let before = waitForPhase(.hidden)
        XCTAssertEqual(before.annotations.count, 1)
        startCommenting(around: AXID.Sample.thirdField)
        let commenting = waitForCapturedDraft()
        let draft = try XCTUnwrap(commenting.capturedDraft)
        let comment = "Make the label bold"

        // 操作: コメントを書いて確定する。
        typeComment(comment)
        confirmComment(.enter)

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈が 1 件増え、
        // そのコメントが書いたとおりの文で、画像のパスが撮った画像を指している。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations.count, before.annotations.count + 1)
        let added = try XCTUnwrap(state.annotations.last)
        XCTAssertEqual(added.comment, comment)
        XCTAssertEqual(added.imagePath, draft.imagePath)
        XCTAssertNil(state.draft)

        // 期待される結果: 入力欄と画面上の赤枠が消え、ボタン類は出たままで、マウスが枠を描く操作になっている。
        waitForElementToDisappear(AXID.Comment.field)
        waitForElementToDisappear(AXID.Draw.frame)
        XCTAssertTrue(isShown(AXID.Toolbar.list))
        XCTAssertTrue(isShown(AXID.Draw.surface))

        // 期待される結果: 保存された画像で、その画像がこの回のフォルダに残っている。
        XCTAssertTrue(imageFilesInCurrentSession().contains(draft.imagePath))

        // してはいけないこと: 入力欄は消えたのに、注釈が増えていない。（上で確かめた）
        // してはいけないこと: 確定したあとも、赤枠が画面に残り続ける。（上で確かめた）
        // してはいけないこと: 確定したあと、枠を描けない状態になり、次の枠を始めるのにホットキーを押し直す必要がある。
        // （ホットキーを押さずに次の枠を描くと、コメントを書いている状態になる）
        drawFrame(around: AXID.Sample.firstField)
        let next = waitForPhase(.commenting)
        XCTAssertNotNil(next.draft)
        // してはいけないこと: 書いていない文や、前の注釈のコメントが入る。
        XCTAssertNotEqual(added.comment, before.annotations[0].comment)
        // してはいけないこと: 前からある注釈が、新しい注釈で上書きされる。
        XCTAssertEqual(state.annotations.first, before.annotations.first)
        XCTAssertTrue(fileExists(before.annotations[0].imagePath))
    }

    // scenario: 改行を含むコメントが、改行ごと注釈になる
    func testMultilineCommentKeepsNewline() throws {
        // 前提: 確定キーは既定（Enter で確定、Shift+Enter で改行）。注釈は 0 件で、コメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting()

        // 操作: 1 行目を書き、改行して 2 行目を書き、確定する。
        typeComment("The padding differs")
        newLineInComment(.enter)

        // してはいけないこと: 改行を入れようとした時点で確定され、途中までの文で注釈になる。
        assertStateStays("改行してもコメントを書いている状態のまま", for: 0.5) { state in
            state.phase == .commenting && state.annotations.isEmpty
        }

        typeComment("between left and right")
        confirmComment(.enter)

        // 期待される結果: アプリの状態で、注釈のコメントに改行が入っており、改行の前と後の文がどちらも残っている。
        let state = waitForPhase(.drawing)
        XCTAssertEqual(state.comments, ["The padding differs\nbetween left and right"])

        // してはいけないこと: 改行が消えて 1 行につながる。
        XCTAssertTrue(state.comments.first?.contains("\n") ?? false)
    }

    // scenario: 確定したあと、続けて次の枠を描いてコメントを入れられる
    func testNextFrameCanBeAnnotatedRightAfterConfirm() throws {
        // 前提: 注釈は 0 件で、コメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting(around: AXID.Sample.button)
        let firstDraft = try XCTUnwrap(waitForCapturedDraft().capturedDraft)

        // 操作: 1 つ目のコメントを書いて確定する。
        typeComment("First comment")
        confirmComment(.enter)
        let afterFirst = waitForPhase(.drawing)
        XCTAssertEqual(afterFirst.comments, ["First comment"])

        // 操作: ホットキーを押し直さずに、次の枠を描く。
        drawFrame(around: AXID.Sample.firstField)

        // 期待される結果: ホットキーを押し直さずに次の枠を描くと、コメントの入力欄が出る。
        // してはいけないこと: 1 つ目を確定したあと、次の枠が描けない。
        let commenting = waitForCapturedDraft()
        let secondDraft = try XCTUnwrap(commenting.capturedDraft)
        waitForElement(AXID.Comment.field)

        // 操作: 2 つ目のコメントを書いて確定する。
        typeComment("Second comment")
        confirmComment(.enter)

        // 期待される結果: アプリの状態で、2 つ目のコメントを確定すると、注釈が確定した順に 2 件増えて、
        // それぞれ書いたとおりのコメントになっており、枠を描く状態に戻っている。
        let state = waitForPhase(.drawing)
        XCTAssertEqual(state.comments, ["First comment", "Second comment"])
        XCTAssertEqual(state.imagePaths, [firstDraft.imagePath, secondDraft.imagePath])

        // 期待される結果: 保存された画像で、この回のフォルダに、増えた 2 件それぞれの画像がある。
        XCTAssertEqual(Set(imageFilesInCurrentSession()), Set(state.imagePaths))
        // してはいけないこと: 2 つ目の注釈が、1 つ目の注釈や画像を上書きする。
        XCTAssertNotEqual(firstDraft.imagePath, secondDraft.imagePath)
        XCTAssertTrue(fileExists(firstDraft.imagePath))
        XCTAssertTrue(fileExists(secondDraft.imagePath))
    }

    // scenario: 中身のないコメントでは確定されない
    func testEmptyCommentIsNotConfirmed() throws {
        // 前提: 確定キーは既定。注釈は 0 件で、コメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting()
        let commenting = waitForCapturedDraft()
        let draft = try XCTUnwrap(commenting.capturedDraft)

        // 操作: 何も書かずに確定キーを押す。
        confirmComment(.enter)

        // 期待される結果: アプリの状態で、コメントを書いている状態のままで、注釈は増えていない。
        // してはいけないこと: 空のコメントの注釈ができる。
        assertStateStays("空のままではコメントを書いている状態のまま", for: 1) { state in
            state.phase == .commenting && state.annotations.isEmpty && state.draft?.imagePath == draft.imagePath
        }

        // 操作: 空白と改行だけを書いて確定キーを押す。
        typeComment("   ")
        newLineInComment(.enter)
        typeComment("  ")
        confirmComment(.enter)

        // してはいけないこと: 空白と改行だけのコメントの注釈ができる。
        let state = assertStateStays("空白と改行だけではコメントを書いている状態のまま", for: 1) { state in
            state.phase == .commenting && state.annotations.isEmpty && state.draft?.imagePath == draft.imagePath
        }
        XCTAssertTrue(state.annotations.isEmpty)

        // 期待される結果: 保存された画像で、撮った画像は消えずに残っている。
        // してはいけないこと: 確定できなかった拍子に、撮った画像が捨てられる。
        XCTAssertTrue(fileExists(draft.imagePath))
        XCTAssertEqual(imageFilesInCurrentSession(), [draft.imagePath])

        // 期待される結果: 入力欄が出たままで、続けて書ける。
        XCTAssertTrue(isShown(AXID.Comment.field))
        typeComment("Now with text")
        XCTAssertTrue(commentText().hasSuffix("Now with text"), "入力欄に続けて書けない: \(commentText())")
    }

    // scenario: コメントを書いている途中でホットキーを押しても、書きかけが失われない
    func testHotkeyWhileCommentingKeepsDraft() throws {
        // 前提: 注釈は 0 件で、コメントの入力欄が出ている。途中まで書いてある。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting()
        let commenting = waitForCapturedDraft()
        let draft = try XCTUnwrap(commenting.capturedDraft)
        let partial = "Half written comment"
        typeComment(partial)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: アプリの状態で、コメントを書いている状態のままで、書きかけの注釈の画像のパスも変わらない。
        // してはいけないこと: ボタン類ごと隠れて、書きかけのコメントと撮った画像が失われる。
        // してはいけないこと: 書きかけのコメントのまま、注釈として確定される。
        let state = assertStateStays("ホットキーを押してもコメントを書いている状態のまま", for: 1) { state in
            state.phase == .commenting && state.isToolbarVisible && state.annotations.isEmpty && state.draft?.imagePath == draft.imagePath
        }
        XCTAssertEqual(state.draft?.imagePath, draft.imagePath)

        // 期待される結果: ホットキーを押しても、入力欄が出たままで、書きかけの文がそのまま残っている。
        XCTAssertTrue(isShown(AXID.Comment.field))
        XCTAssertEqual(commentText(), partial)

        // 期待される結果: 保存された画像で、撮った画像が残っている。
        XCTAssertTrue(fileExists(draft.imagePath))
        XCTAssertEqual(imageFilesInCurrentSession(), [draft.imagePath])
    }
}
