// spec: e2e/specs/toolbar/shortcuts.md
// spec-sha256: da6974ac1c190bc744bf7781fdb97bc5e0fe22f877878040c1e40d327fd391b4
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class ToolbarShortcutsTests: AkapenUITestCase {
    /// 前もってクリップボードに入れておく文章。
    private let previousClipboard = "Something copied earlier"

    /// 前提をそろえる: 英語・定型文は既定のまま、確定済みの注釈が 2 件。クリップボードには別の文章。
    private func launchWithTwoAnnotations(open: OpenView) -> AppState {
        launch(.setupDone, annotations: SeedAnnotation.samples(2), open: open)
        putOnPasteboard(previousClipboard)
        let state = waitForPhase(open == .list ? .listOpen : .drawing)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.annotations.count, 2)
        XCTAssertEqual(state.settings.boilerplate(.en), DefaultBoilerplate.english)
        for path in state.imagePaths {
            XCTAssertTrue(fileExists(path), "前提の画像がない: \(path)")
        }
        return state
    }

    // scenario: ボタン類が出ているときに ⌘C を押すと、プロンプトがコピーされる
    func testCommandCCopiesWhileDrawing() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。クリップボードには別の文章。
        let before = launchWithTwoAnnotations(open: .toolbar)
        waitForElement(AXID.Draw.surface)

        // 操作: ⌘C を押す。
        pressToolbarShortcut(.copyPrompt)

        // 期待される結果: ボタン類が消え、コピーしたことと件数が分かる表示が出る。
        // （コピー完了の表示は一定時間で消えるので、押した直後に読む）
        let messageText = displayedText(AXID.Copied.message)
        XCTAssertTrue(messageText.contains("2"), "コピーした件数が出ていない: \(messageText)")
        waitForElementToDisappear(AXID.Toolbar.list)

        // 期待される結果: アプリの状態で、コピーを終えた状態になっており、注釈は 0 件、直前にコピーした件数は 2。
        // してはいけないこと: クリップボードには入ったのに、注釈が残る。
        let state = waitForCopyFinished()
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertEqual(state.lastCopiedCount, 2)
        XCTAssertFalse(state.isToolbarVisible)

        // 期待される結果: クリップボードに入った文章で、冒頭が英語の既定の定型文になっており、そのあとに 2 件の注釈の「パス → コメント」が確定した順に並んでいる。
        // してはいけないこと: 前もってクリップボードにあった文章が残る。
        let expectedEntries = before.annotations.map { CopiedPrompt.Entry(path: $0.imagePath, comment: $0.comment) }
        let prompt = try XCTUnwrap(copiedPrompt(), "クリップボードが空")
        XCTAssertEqual(prompt.boilerplate, DefaultBoilerplate.english)
        XCTAssertEqual(prompt.entries, expectedEntries)
        XCTAssertEqual(prompt.text, CopiedPrompt.expectedText(boilerplate: DefaultBoilerplate.english, entries: expectedEntries))
        XCTAssertFalse(prompt.text.contains(previousClipboard))
    }

    // scenario: ⌘L で一覧が開き、もう一度押すと閉じて枠を描く状態に戻る
    func testCommandLTogglesList() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類が出ている（枠を描く状態）。
        let before = launchWithTwoAnnotations(open: .toolbar)
        waitForElement(AXID.Draw.surface)

        // 操作: ⌘L を押す。
        pressToolbarShortcut(.list)

        // 期待される結果: アプリの状態で、1 回目のあとは一覧を開いている状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        let opened = waitForPhase(.listOpen)
        XCTAssertEqual(opened.annotations, before.annotations)
        // 期待される結果: 1 回目で一覧が出て、ボタン類は出たまま。
        // してはいけないこと: 一覧と一緒にボタン類まで消える。
        waitForElement(AXID.List.panel)
        XCTAssertTrue(opened.isToolbarVisible)
        XCTAssertTrue(isShown(AXID.Toolbar.list))

        // 操作: もう一度 ⌘L を押す。
        pressToolbarShortcut(.list)

        // 期待される結果: アプリの状態で、2 回目のあとは枠を描く状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        // してはいけないこと: 開いて閉じただけで、注釈が消える。
        let closed = waitForPhase(.drawing)
        XCTAssertEqual(closed.annotations, before.annotations)
        XCTAssertEqual(closed.comments, before.comments)
        // 期待される結果: 2 回目で一覧が消える。ボタン類は出たまま。
        waitForElementToDisappear(AXID.List.panel)
        XCTAssertTrue(closed.isToolbarVisible)
        XCTAssertTrue(isShown(AXID.Toolbar.list))
    }

    // scenario: 一覧を開いているときに ⌘C を押すと、プロンプトがコピーされる
    func testCommandCCopiesWhileListIsOpen() throws {
        // 前提: 確定済みの注釈が 2 件あり、一覧を開いている。クリップボードには別の文章。
        let before = launchWithTwoAnnotations(open: .list)
        waitForElement(AXID.List.panel)

        // 操作: ⌘C を押す。
        pressToolbarShortcut(.copyPrompt)

        // 期待される結果: アプリの状態で、コピーを終えた状態になっており、注釈は 0 件、直前にコピーした件数は 2。
        // してはいけないこと: 一覧を開いているときだけ、⌘C が効かない。
        let state = waitForCopyFinished()
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertEqual(state.lastCopiedCount, 2)

        // 期待される結果: 一覧とボタン類が消える。
        waitForElementToDisappear(AXID.List.panel)
        waitForElementToDisappear(AXID.Toolbar.list)

        // 期待される結果: クリップボードに入った文章で、2 件の注釈の「パス → コメント」が確定した順に並んでいる。
        let expectedEntries = before.annotations.map { CopiedPrompt.Entry(path: $0.imagePath, comment: $0.comment) }
        let prompt = try XCTUnwrap(copiedPrompt(), "クリップボードが空")
        XCTAssertEqual(prompt.entries, expectedEntries)
    }

    // scenario: コメントを書いているときの ⌘C と ⌘L は、コピーも一覧の開閉もしない
    func testShortcutsAreIgnoredWhileCommenting() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類が出ている。枠を描き終え、コメントの入力欄が出ている。クリップボードには別の文章。
        let before = launchWithTwoAnnotations(open: .toolbar)
        startCommenting(around: AXID.Sample.thirdField)
        let commenting = waitForCapturedDraft()
        let draft = try XCTUnwrap(commenting.capturedDraft)
        typeComment("Not finished yet")

        // 操作: ⌘C と ⌘L を押す。
        pressToolbarShortcut(.copyPrompt)
        pressToolbarShortcut(.list)

        // 期待される結果: アプリの状態で、コメントを書いている状態のままで、注釈は 2 件のまま。
        // してはいけないこと: 書きかけのコメントを残したまま、プロンプトがコピーされる。
        // してはいけないこと: 書きかけのコメントを残したまま、一覧が開く。
        let state = assertStateStays("コメントを書いている状態のまま", for: 1.5) { state in
            state.phase == .commenting && state.annotations == before.annotations && state.draft?.imagePath == draft.imagePath
        }
        XCTAssertEqual(state.lastCopiedCount, 0)

        // 期待される結果: 入力欄が出たままで、一覧は出ない。
        XCTAssertTrue(isShown(AXID.Comment.field))
        XCTAssertFalse(isShown(AXID.List.panel))

        // 期待される結果: クリップボードに入った文章で、前もって入れておいた文章から変わっていない。
        XCTAssertEqual(pasteboardText(), previousClipboard)
    }
}
