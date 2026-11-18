// spec: e2e/specs/comment/confirm.md
// spec-sha256: f0885e4f919e648a79ca53ff1cbbce6eaaa02abd853e8e45c874183a1961693b
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class CommentConfirmTests: AkapenUITestCase {
    // scenario: コメントを書いて確定すると注釈になり、画面上の枠と入力欄は消える
    func testConfirmedCommentBecomesAnnotation() throws {
        // 前提: 確定キーは既定。確定済みの注釈が 1 件あり、枠を描き終えてコメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter), annotations: SeedAnnotation.samples(1))
        let before = waitForPhase(.idle)
        XCTAssertEqual(before.annotations.count, 1)
        startCommenting(around: AXID.Sample.thirdField)
        let commenting = waitForPhase(.commenting)
        let draft = try XCTUnwrap(commenting.draft)
        let comment = "Make the label bold"

        // 操作: コメントを書いて確定する。
        typeComment(comment)
        confirmComment(.enter)

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態になっており、注釈が 1 件増え、
        // そのコメントが書いたとおりの文で、画像のパスが撮った画像を指している。
        let state = waitForPhase(.idle)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations.count, before.annotations.count + 1)
        let added = try XCTUnwrap(state.annotations.last)
        XCTAssertEqual(added.comment, comment)
        XCTAssertEqual(added.imagePath, draft.imagePath)
        XCTAssertNil(state.draft)

        // 期待される結果: 入力欄と画面上の赤枠が消え、ボタン類だけが出ている。
        waitForElementToDisappear(AXID.Comment.field)
        waitForElementToDisappear(AXID.Draw.frame)
        XCTAssertTrue(isShown(AXID.Toolbar.add))
        XCTAssertFalse(isShown(AXID.Draw.surface))

        // 期待される結果: 保存された画像で、その画像がこの回のフォルダに残っている。
        XCTAssertTrue(imageFilesInCurrentSession().contains(draft.imagePath))

        // してはいけないこと: 入力欄は消えたのに、注釈が増えていない。（上で確かめた）
        // してはいけないこと: 確定したあとも、赤枠が画面に残り続ける。（上で確かめた）
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
        let state = waitForPhase(.idle)
        XCTAssertEqual(state.comments, ["The padding differs\nbetween left and right"])

        // してはいけないこと: 改行が消えて 1 行につながる。
        XCTAssertTrue(state.comments.first?.contains("\n") ?? false)
    }

    // scenario: コメントを確定したあと、下のアプリを普段どおり操作できる
    func testUnderlyingAppWorksAfterConfirm() throws {
        // 前提: 注釈は 0 件で、コメントの入力欄が出ている。コメントを書いて確定する。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting()
        typeComment("Change this label to Save")
        confirmComment(.enter)
        let confirmed = waitForPhase(.idle)
        XCTAssertEqual(confirmed.annotations.count, 1)
        waitForElementToDisappear(AXID.Comment.field)
        let submitCountBefore = try XCTUnwrap(sampleSubmitCount())

        // 操作: 撮影対象のアプリのボタンを押す。
        clickSampleSubmit()

        // 期待される結果: 撮影対象のアプリのボタンを押すと、押した回数の表示が増える。
        XCTAssertTrue(poll(timeout: 5) { self.sampleSubmitCount() == submitCountBefore + 1 }, "下のアプリのボタンが押せない")

        // 操作: 撮影対象のアプリの入力欄に文字を打つ。
        typeInSample("hello", into: AXID.Sample.firstField)

        // 期待される結果: 撮影対象のアプリの入力欄に文字を打つと、その欄に入る。
        XCTAssertTrue(poll(timeout: 5) { self.sampleText(AXID.Sample.firstField) == "hello" }, "下のアプリの入力欄に文字が入らない")

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態のままで、注釈の件数とコメントは変わらない。
        let state = appState()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations, confirmed.annotations)

        // してはいけないこと: akapen の見えない面がクリックを横取りし、撮影対象のアプリのボタンが押せない。（上で確かめた）
        // してはいけないこと: 打った文字が akapen のどこかに入り、注釈のコメントが変わる。
        XCTAssertEqual(state.comments, ["Change this label to Save"])
        XCTAssertNil(state.draft)
    }

    // scenario: 中身のないコメントでは確定されない
    func testEmptyCommentIsNotConfirmed() throws {
        // 前提: 確定キーは既定。注釈は 0 件で、コメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting()
        let commenting = waitForPhase(.commenting)
        let draft = try XCTUnwrap(commenting.draft)

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

    // scenario: コメントを書いている途中で次の枠を始めようとしても、書きかけが失われない
    func testStartingNextFrameKeepsDraft() throws {
        // 前提: 注釈は 0 件で、コメントの入力欄が出ている。途中まで書いてある。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        startCommenting()
        let commenting = waitForPhase(.commenting)
        let draft = try XCTUnwrap(commenting.draft)
        let partial = "Half written comment"
        typeComment(partial)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: アプリの状態で、コメントを書いている状態のままで、書きかけの注釈の画像のパスも変わらない。
        // してはいけないこと: 枠を描く状態に移り、書きかけのコメントと撮った画像が失われる。
        // してはいけないこと: 書きかけのコメントのまま、注釈として確定される。
        assertStateStays("ホットキーを押してもコメントを書いている状態のまま", for: 1) { state in
            state.phase == .commenting && state.annotations.isEmpty && state.draft?.imagePath == draft.imagePath
        }
        // 期待される結果: 入力欄が出たままで、書きかけの文がそのまま残っている。
        XCTAssertTrue(isShown(AXID.Comment.field))
        XCTAssertEqual(commentText(), partial)

        // 操作: ボタン類から次の枠を始めようとする。
        tapAdd()

        // 期待される結果: アプリの状態で、コメントを書いている状態のままで、書きかけの注釈の画像のパスも変わらない。
        let state = assertStateStays("ボタン類から始めようとしてもコメントを書いている状態のまま", for: 1) { state in
            state.phase == .commenting && state.annotations.isEmpty && state.draft?.imagePath == draft.imagePath
        }
        XCTAssertEqual(state.draft?.imagePath, draft.imagePath)
        // 期待される結果: 入力欄が出たままで、書きかけの文がそのまま残っている。
        XCTAssertTrue(isShown(AXID.Comment.field))
        XCTAssertEqual(commentText(), partial)

        // 期待される結果: 保存された画像で、撮った画像が残っている。
        XCTAssertTrue(fileExists(draft.imagePath))
        XCTAssertEqual(imageFilesInCurrentSession(), [draft.imagePath])
    }
}
