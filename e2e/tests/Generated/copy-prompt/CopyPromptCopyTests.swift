// spec: e2e/specs/copy-prompt/copy.md
// spec-sha256: 8d95af3b60cfb6b806ea64ebb5a2a575ba8041672fdc2e54365dc4dcd0e9af5f
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class CopyPromptCopyTests: AkapenUITestCase {
    /// 前もってテスト用のクリップボードに入れておく文章。
    private let previousClipboard = "Text that was on the clipboard before"

    /// 前提の注釈 2 件（1 件目は改行を含まない 1 行の文、2 件目は別の文）。
    private let seededAnnotations = [
        SeedAnnotation("The padding differs between left and right"),
        SeedAnnotation("Change this label to Save\nand make it bold"),
    ]

    /// 前提をそろえる: 英語・定型文は既定のまま、確定済みの注釈が 2 件、ボタン類だけが出ている。クリップボードには別の文章。
    private func launchWithTwoAnnotations() -> AppState {
        launch(.setupDone, annotations: seededAnnotations)
        putOnPasteboard(previousClipboard)
        let state = waitForPhase(.idle)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertEqual(state.settings.language, .en)
        XCTAssertEqual(state.settings.boilerplate(.en), DefaultBoilerplate.english)
        XCTAssertEqual(state.comments, seededAnnotations.map(\.comment))
        XCTAssertFalse(state.comments[0].contains("\n"))
        for path in state.imagePaths {
            XCTAssertTrue(fileExists(path), "前提の画像がない: \(path)")
        }
        return state
    }

    // scenario: コピーすると、定型文と「パス → コメント」が確定した順にクリップボードに入る
    func testCopyPutsBoilerplateAndEntriesInOrder() throws {
        let before = launchWithTwoAnnotations()
        let session = try XCTUnwrap(before.storage.sessionDirectory)
        let sessionPrefix = session.hasSuffix("/") ? session : session + "/"

        // 操作: コピーする。
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: クリップボードに入った文章で、冒頭が英語の既定の定型文になっており、そのあとに空行を挟んで、
        // 1 件目の画像のパス・改行・1 件目のコメント、空行、2 件目の画像のパス・改行・2 件目のコメント、の順に並んでいる。
        let prompt = try XCTUnwrap(copiedPrompt())
        let expectedEntries = before.annotations.map { CopiedPrompt.Entry(path: $0.imagePath, comment: $0.comment) }
        XCTAssertEqual(prompt.boilerplate, DefaultBoilerplate.english)
        // してはいけないこと: 注釈の順番が入れ替わる。
        // してはいけないこと: パスとコメントの組がずれる（1 件目のパスに 2 件目のコメントが付くなど）。
        XCTAssertEqual(prompt.entries, expectedEntries)
        // してはいけないこと: 通し番号や、枠の座標が入る。
        // してはいけないこと: 末尾に余分な改行や空行が付く。
        XCTAssertEqual(prompt.text, CopiedPrompt.expectedText(boilerplate: DefaultBoilerplate.english, entries: expectedEntries))
        XCTAssertFalse(prompt.text.hasSuffix("\n"))

        // 期待される結果: クリップボードに入った文章で、各パスが、画像の置き場のこの回のフォルダにある画像の絶対パスになっている。
        for entry in prompt.entries {
            XCTAssertTrue(entry.path.hasPrefix("/"), "絶対パスでない: \(entry.path)")
            XCTAssertTrue(entry.path.hasPrefix(sessionPrefix), "この回のフォルダの下でない: \(entry.path)")
            XCTAssertTrue(fileExists(entry.path), "パスの先に画像がない: \(entry.path)")
        }

        // してはいけないこと: 前もってクリップボードにあった文章が残る、または混ざる。
        XCTAssertFalse(prompt.text.contains(previousClipboard))
    }

    // scenario: コピーすると注釈が空になり、ボタン類が消える
    func testCopyClearsAnnotationsAndHidesToolbar() throws {
        let before = launchWithTwoAnnotations()
        XCTAssertEqual(before.annotations.count, 2)

        // 操作: コピーする。
        tapCopyPrompt()

        // 期待される結果: ボタン類が消え、コピーしたことと件数が分かる表示が出る。
        let message = displayedText(AXID.Copied.message)
        XCTAssertTrue(message.contains("2"), "コピーした件数が表示にない: \(message)")
        waitForElementToDisappear(AXID.Toolbar.add)

        // 期待される結果: アプリの状態で、コピーを終えた状態になっており、注釈は 0 件、直前にコピーした件数は 2、ボタン類は出ていない。
        let state = waitForCopyFinished()
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertEqual(state.lastCopiedCount, 2)
        XCTAssertFalse(state.isToolbarVisible)

        // してはいけないこと: クリップボードには入ったのに注釈が残り、次の回に前の注釈が混ざる。
        XCTAssertNotNil(copiedPrompt())
        XCTAssertNil(state.draft)
        // してはいけないこと: ボタン類が出たまま残る。
        XCTAssertFalse(isShown(AXID.Toolbar.add))
    }

    // scenario: コピーしても、画像ファイルは消えずに残る
    func testCopyKeepsImageFiles() throws {
        let before = launchWithTwoAnnotations()

        // 操作: コピーする。
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: 保存された画像で、クリップボードに入った文章の各パスに画像ファイルがあり、赤枠の入った画像として開ける。
        // してはいけないこと: 注釈と一緒に画像ファイルまで消え、AI エージェントがパスを開けない。
        let prompt = try XCTUnwrap(copiedPrompt())
        XCTAssertEqual(prompt.entries.map(\.path), before.imagePaths)
        for (entry, annotation) in zip(prompt.entries, before.annotations) {
            XCTAssertTrue(fileExists(entry.path), "画像が消えた: \(entry.path)")
            assertImage(at: entry.path, showsFrame: annotation.rect.cgRect, window: annotation.windowFrame.cgRect)
        }
    }

    // scenario: コピーのあとにホットキーを押すと、注釈が 0 件の新しい回が始まる
    func testHotkeyAfterCopyStartsNewSession() throws {
        let before = launchWithTwoAnnotations()
        XCTAssertEqual(before.annotations.count, 2)
        tapCopyPrompt()

        // コピーしたことの表示が出ている間に、ホットキーを押す。
        waitForElement(AXID.Copied.message)
        let copied = waitForState("コピーを終えた状態になる") { $0.phase == .copied }
        XCTAssertTrue(copied.annotations.isEmpty)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 0 件。
        // してはいけないこと: コピーしたことの表示が消えるまで、ホットキーが効かない。
        let state = waitForPhase(.drawing, timeout: 2)
        XCTAssertTrue(state.annotations.isEmpty)

        // 期待される結果: ボタン類が出て、マウスが枠を描く操作になる。
        XCTAssertTrue(state.isToolbarVisible)
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Draw.surface)

        // してはいけないこと: 前の回の注釈が残っている。
        XCTAssertNil(state.draft)

        // してはいけないこと: 新しい回を始めたあと、コピーしたことの表示が消えるのに合わせて、何も出ていない状態に戻ってしまう。
        // （コピー完了の表示が消える 2.5 秒を超えて待つ）
        let later = assertStateStays("枠を描く状態のまま", for: 3.5) { state in
            state.phase == .drawing && state.isToolbarVisible && state.annotations.isEmpty
        }
        XCTAssertEqual(later.phase, .drawing)
        XCTAssertTrue(isShown(AXID.Draw.surface))
    }

    // scenario: 新しい回でコピーすると、前の回の注釈は入らず、前の回の画像は残っている
    func testCopyInNewSessionExcludesPreviousSession() throws {
        _ = launchWithTwoAnnotations()

        // 前の回をコピーする。
        tapCopyPrompt()
        waitForCopyFinished()
        let firstPrompt = try XCTUnwrap(copiedPrompt())
        XCTAssertEqual(firstPrompt.entries.count, 2)
        var firstContents: [String: Data] = [:]
        for entry in firstPrompt.entries {
            firstContents[entry.path] = try XCTUnwrap(fileContents(entry.path), "前の回の画像がない: \(entry.path)")
        }

        // 操作: ホットキーで新しい回を始め、注釈を 1 件確定してコピーする。
        startDrawing()
        let newComment = "This field should be wider"
        annotate(around: AXID.Sample.thirdField, comment: newComment)
        let annotated = waitForPhase(.idle)
        XCTAssertEqual(annotated.annotations.count, 1)
        let newAnnotation = try XCTUnwrap(annotated.annotations.first)
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: クリップボードに入った文章で、新しい回で確定した注釈のパスとコメントだけが並んでいる。
        let secondPrompt = try XCTUnwrap(copiedPrompt())
        XCTAssertEqual(secondPrompt.entries, [CopiedPrompt.Entry(path: newAnnotation.imagePath, comment: newComment)])

        // してはいけないこと: 前の回の注釈のパスやコメントが混ざる。
        for entry in firstPrompt.entries {
            XCTAssertFalse(secondPrompt.text.contains(entry.path), "前の回のパスが混ざった: \(entry.path)")
            XCTAssertFalse(secondPrompt.text.contains(entry.comment), "前の回のコメントが混ざった: \(entry.comment)")
        }

        // 期待される結果: 保存された画像で、前の回でコピーした文章の各パスに、前の回の画像がそのまま残っている。
        // してはいけないこと: 前の回の画像が、新しい回の画像で上書きされる、または消える。
        XCTAssertFalse(firstContents.keys.contains(newAnnotation.imagePath), "新しい画像が前の回の画像と同じパスに保存された")
        for (path, contents) in firstContents {
            XCTAssertTrue(fileExists(path), "前の回の画像が消えた: \(path)")
            XCTAssertEqual(fileContents(path), contents, "前の回の画像が書き換わった: \(path)")
        }
    }

    // scenario: 注釈が 0 件のときは、コピーされない
    func testCopyWithoutAnnotationsDoesNothing() throws {
        // 前提: 確定済みの注釈が 0 件で、ボタン類だけが出ている。クリップボードには別の文章。
        launch(.setupDone, open: .toolbar)
        putOnPasteboard(previousClipboard)
        let before = waitForState("ボタン類だけが出ている") { $0.phase == .idle && $0.isToolbarVisible }
        XCTAssertTrue(before.annotations.isEmpty)

        // 操作: コピーしようとする。
        tapCopyPrompt()

        // 期待される結果: アプリの状態で、ボタン類だけが出ている状態のままで、直前にコピーした件数も変わらない。
        // してはいけないこと: ボタン類が消え、コピーを終えた状態になる。
        let state = assertStateStays("ボタン類だけが出ている状態のまま", for: 1.5) { state in
            state.phase == .idle && state.isToolbarVisible && state.lastCopiedCount == before.lastCopiedCount
        }
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertTrue(isShown(AXID.Toolbar.add))

        // 期待される結果: クリップボードに入った文章で、前もって入れておいた文章から変わっていない。
        // してはいけないこと: 定型文だけの文章がクリップボードに入る。
        XCTAssertEqual(pasteboardText(), previousClipboard)
    }
}
