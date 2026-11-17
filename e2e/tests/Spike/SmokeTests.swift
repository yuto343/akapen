import XCTest
import AkapenAXID

/// 組み立て（app-wiring）の確認。実物のアプリで代表的な流れを通し、`Support` のヘルパーだけで書けることを確かめる。
/// `e2e/specs` から生成したテストが揃ったら、生成したテストに置き換えて消す。
final class SmokeTests: AkapenUITestCase {
    /// ホットキー → 枠 → コメント → 一覧で確認 → コピー。クリップボードの文章と、画像の赤枠の位置を確かめる。
    func testAnnotateReviewAndCopy() throws {
        launch(.setupDone)
        putOnPasteboard("Text that was on the clipboard before")
        let comment = "The padding differs between left and right"

        startDrawing()
        let drawn = drawFrame(around: AXID.Sample.button)
        let commenting = waitForPhase(.commenting)
        let draft = try XCTUnwrap(commenting.draft)
        let session = try XCTUnwrap(commenting.storage.sessionDirectory)
        XCTAssertTrue(draft.imagePath.hasPrefix(session))
        assertRect(commenting.lastDrawnRect?.cgRect, matches: drawn)
        XCTAssertEqual(imageFilesInCurrentSession(), [draft.imagePath])
        waitForElement(AXID.Draw.frame)

        typeComment(comment)
        confirmComment()
        let idle = waitForPhase(.idle)
        XCTAssertTrue(idle.isToolbarVisible)
        XCTAssertEqual(idle.comments, [comment])
        XCTAssertEqual(idle.imagePaths, [draft.imagePath])
        XCTAssertNil(idle.draft)
        waitForElementToDisappear(AXID.Comment.field)

        tapList()
        waitForPhase(.listOpen)
        XCTAssertEqual(listRowCount(), 1)
        XCTAssertEqual(listComment(0), comment)
        XCTAssertEqual(listThumbnailPath(0), draft.imagePath)
        XCTAssertEqual(listRetentionDays(), 7)
        pressEscape()
        waitForPhase(.idle)

        tapCopyPrompt()
        let copied = waitForCopyFinished()
        XCTAssertEqual(copied.lastCopiedCount, 1)
        let prompt = try XCTUnwrap(copiedPrompt())
        XCTAssertEqual(prompt.boilerplate, DefaultBoilerplate.english)
        XCTAssertEqual(prompt.entries, [CopiedPrompt.Entry(path: draft.imagePath, comment: comment)])
        XCTAssertEqual(
            prompt.text,
            CopiedPrompt.expectedText(boilerplate: DefaultBoilerplate.english, entries: prompt.entries)
        )
        XCTAssertEqual(idle.settings.boilerplate(.en), DefaultBoilerplate.english)
        XCTAssertEqual(idle.settings.boilerplate(.ja), DefaultBoilerplate.japanese)
        assertImage(at: draft.imagePath, showsFrame: drawn)
    }

    /// 注釈つきで起動し、メニューバーから設定を開いて日数とホットキーを変える。注釈が残っているときの終了は確認が出て、
    /// 取りやめると動き続け、終了を選ぶと終了する。
    func testMenuSettingsAndQuit() throws {
        launch(.setupDone, annotations: SeedAnnotation.samples(1))
        let start = waitForPhase(.idle)
        XCTAssertTrue(start.isToolbarVisible)
        XCTAssertEqual(start.comments, [SeedAnnotation.sampleComments[0]])
        XCTAssertEqual(start.annotations.first?.sourceAppName, AkapenUITestCase.sampleAppName)
        let annotation = try XCTUnwrap(start.annotations.first)
        assertImage(at: annotation.imagePath, showsFrame: annotation.rect.cgRect)
        openList()
        XCTAssertEqual(listComment(0), annotation.comment)
        pressEscape()
        waitForPhase(.idle)

        openSettingsFromMenuBar()
        waitForState("設定のウィンドウが開く") { $0.windows.settings }
        enterRetentionDays("400")
        waitForState("日数が丸まって入る") { $0.settings.imageRetentionDays == 365 }
        let newHotkey = Shortcut(key: "k", modifiers: [.control, .option])
        recordShortcut(newHotkey, in: AXID.Settings.hotkey)
        waitForState("ホットキーが変わる") { $0.settings.hotkey == newHotkey && $0.hotkeys.draw == newHotkey }
        closeSettings()

        chooseQuitFromMenuBar()
        waitForState("終了の確認が出る") { $0.windows.quitConfirm }
        XCTAssertTrue(quitConfirmMessage().contains("1"))
        answerQuitConfirm(quit: false)
        let cancelled = waitForState("終了の確認が消える") { !$0.windows.quitConfirm }
        XCTAssertTrue(isAppRunning)
        XCTAssertEqual(cancelled.phase, .idle)
        XCTAssertEqual(cancelled.comments, [annotation.comment])

        chooseQuitFromMenuBar()
        waitForState("終了の確認がもう一度出る") { $0.windows.quitConfirm }
        answerQuitConfirm(quit: true)
        waitForAppToQuit()
        XCTAssertTrue(fileExists(annotation.imagePath))
    }

    /// 初めての起動でセットアップが出る。
    func testFirstRunShowsSetup() throws {
        launch(.firstRun)
        waitForElement(AXID.Setup.window)
        let state = waitForState("セットアップのウィンドウが出る") { $0.windows.setup }
        XCTAssertFalse(state.settings.setupCompleted)
        XCTAssertEqual(state.windows.setupPage, .hotkey)
        XCTAssertEqual(state.settings.hotkey, .commandSemicolon)
        XCTAssertEqual(state.hotkeys.draw, .commandSemicolon)
    }
}
