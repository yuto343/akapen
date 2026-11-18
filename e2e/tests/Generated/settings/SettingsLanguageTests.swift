// spec: e2e/specs/settings/language.md
// spec-sha256: 1a1727a74310fc657a025819d782a904979dee505d80d20fbe8cc569c7eb3074
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class SettingsLanguageTests: AkapenUITestCase {
    // scenario: 日本語に切り替えると、表示とプロンプトの定型文が日本語になる
    func testSwitchToJapanese() throws {
        // 前提: セットアップ済み、言語は英語（既定）。定型文はどの言語も書き換えていない。確定済みの注釈が 1 件あり、akapen は何も出していない。
        launch(.setupDone, annotations: SeedAnnotation.samples(1))
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.language, .en)
        let annotation = try XCTUnwrap(start.annotations.first)

        // 操作: 設定で日本語に切り替える。
        openSettingsFromMenuBar()
        XCTAssertFalse(containsJapanese(displayedText(AXID.Settings.language)))
        chooseLanguage(.ja)

        // 期待される結果: アプリの状態で、設定の言語が日本語になっている。
        // してはいけないこと: 定型文だけが日本語になり、アプリの状態の言語は英語のまま。
        let switched = waitForState("言語が日本語になる") { $0.settings.language == .ja }
        XCTAssertEqual(switched.settings.language, .ja)

        // 期待される結果: 設定やボタン類の表示が日本語に変わる。
        XCTAssertTrue(
            poll(timeout: 5) { self.containsJapanese(self.displayedText(AXID.Settings.language)) },
            "設定の表示が日本語にならない: \(displayedText(AXID.Settings.language))"
        )

        // してはいけないこと: 注釈のコメントまで訳されたり、書き換わったりする。
        XCTAssertEqual(switched.comments, start.comments)
        closeSettings()

        // 操作: ホットキーでボタン類を出す。
        bringSampleToFront()
        pressHotkey()
        waitForPhase(.drawing)

        // 期待される結果: 設定やボタン類の表示が日本語に変わる。（ボタン類）
        XCTAssertTrue(
            poll(timeout: 5) { self.containsJapanese(self.displayedText(AXID.Toolbar.copyPrompt)) },
            "ボタン類の表示が日本語にならない: \(displayedText(AXID.Toolbar.copyPrompt))"
        )

        // 操作: プロンプトをコピーする。
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: クリップボードに入った文章で、冒頭が日本語の既定の定型文になっており、そのあとの「パス → コメント」の並びは変わらない。
        // してはいけないこと: 表示だけが日本語になり、プロンプトの定型文は英語のまま。
        // してはいけないこと: 注釈のコメントまで訳されたり、書き換わったりする。
        let expectedEntries = [CopiedPrompt.Entry(path: annotation.imagePath, comment: annotation.comment)]
        let prompt = try XCTUnwrap(copiedPrompt(), "クリップボードが空")
        XCTAssertEqual(prompt.boilerplate, DefaultBoilerplate.japanese)
        XCTAssertEqual(prompt.entries, expectedEntries)
        XCTAssertEqual(prompt.text, CopiedPrompt.expectedText(boilerplate: DefaultBoilerplate.japanese, entries: expectedEntries))
        XCTAssertFalse(prompt.text.contains(DefaultBoilerplate.english), "英語の定型文が入っている")
    }

    // scenario: 英語に戻すと、英語の既定の定型文に戻る
    func testSwitchBackToEnglish() throws {
        // 前提: セットアップ済み、言語は日本語。定型文はどの言語も書き換えていない。確定済みの注釈が 1 件あり、akapen は何も出していない。
        launch(.setupDone, settings: LaunchSettings(language: .ja), annotations: SeedAnnotation.samples(1))
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.language, .ja)
        let annotation = try XCTUnwrap(start.annotations.first)

        // 操作: 設定で英語に戻す。
        openSettingsFromMenuBar()
        XCTAssertTrue(containsJapanese(displayedText(AXID.Settings.language)))
        chooseLanguage(.en)

        // 期待される結果: アプリの状態で、設定の言語が英語になっている。
        let switched = waitForState("言語が英語になる") { $0.settings.language == .en }
        XCTAssertEqual(switched.settings.language, .en)

        // 期待される結果: 設定やボタン類の表示が英語に変わる。
        XCTAssertTrue(
            poll(timeout: 5) { !self.containsJapanese(self.displayedText(AXID.Settings.language)) },
            "設定の表示が英語にならない: \(displayedText(AXID.Settings.language))"
        )
        closeSettings()

        // 操作: ホットキーでボタン類を出す。
        bringSampleToFront()
        pressHotkey()
        waitForPhase(.drawing)

        // 期待される結果: 設定やボタン類の表示が英語に変わる。（ボタン類）
        XCTAssertTrue(
            poll(timeout: 5) { !self.containsJapanese(self.displayedText(AXID.Toolbar.copyPrompt)) },
            "ボタン類の表示が英語にならない: \(displayedText(AXID.Toolbar.copyPrompt))"
        )

        // 操作: プロンプトをコピーする。
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: クリップボードに入った文章で、冒頭が英語の既定の定型文になっている。
        // してはいけないこと: 英語に戻したのに、日本語の定型文が残る。
        let expectedEntries = [CopiedPrompt.Entry(path: annotation.imagePath, comment: annotation.comment)]
        let prompt = try XCTUnwrap(copiedPrompt(), "クリップボードが空")
        XCTAssertEqual(prompt.boilerplate, DefaultBoilerplate.english)
        XCTAssertEqual(prompt.entries, expectedEntries)
        XCTAssertFalse(prompt.text.contains(DefaultBoilerplate.japanese), "日本語の定型文が残っている")
    }
}
