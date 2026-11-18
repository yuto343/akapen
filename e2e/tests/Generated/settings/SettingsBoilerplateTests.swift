// spec: e2e/specs/settings/boilerplate.md
// spec-sha256: b44a8c33f50b413691476634a539fb8ee6f86d472a72b9e27bc48b8502d58465
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class SettingsBoilerplateTests: AkapenUITestCase {
    /// 書き換える定型文。
    private let customBoilerplate = "Fix each item below. Keep the changes small."

    // scenario: 定型文を書き換えると、コピーしたプロンプトの冒頭がその文になる
    func testEditedBoilerplateLeadsCopiedPrompt() throws {
        // 前提: セットアップ済み、言語は英語（既定）。どの言語の定型文も書き換えていない。確定済みの注釈が 1 件あり、akapen は何も出していない。
        launch(.setupDone, annotations: SeedAnnotation.samples(1))
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.language, .en)
        XCTAssertEqual(start.settings.boilerplate(.en), DefaultBoilerplate.english)
        XCTAssertEqual(start.settings.boilerplate(.ja), DefaultBoilerplate.japanese)
        let annotation = try XCTUnwrap(start.annotations.first)
        let expectedEntries = [CopiedPrompt.Entry(path: annotation.imagePath, comment: annotation.comment)]

        // 操作: 設定を開き、定型文を書き換えて閉じる。
        openSettingsFromMenuBar()
        replaceBoilerplate(with: customBoilerplate)

        // 期待される結果: アプリの状態で、英語の定型文が書き換えた文になっており、日本語の定型文は既定のまま。
        let edited = waitForState("英語の定型文が書き換わる") { $0.settings.boilerplate(.en) == self.customBoilerplate }
        XCTAssertEqual(edited.settings.boilerplate(.en), customBoilerplate)
        XCTAssertEqual(edited.settings.boilerplate(.ja), DefaultBoilerplate.japanese)
        closeSettings()

        // 操作: ホットキーでボタン類を出し、プロンプトをコピーする。
        bringSampleToFront()
        pressHotkey()
        waitForPhase(.drawing)
        tapCopyPrompt()
        let copied = waitForCopyFinished()
        XCTAssertEqual(copied.lastCopiedCount, 1)

        // 期待される結果: クリップボードに入った文章で、冒頭が書き換えた定型文になっており、そのあとに空行を挟んで、注釈の「パス → コメント」が書き換える前と同じ形で並んでいる。
        // してはいけないこと: 書き換える前の既定の定型文が入る。
        // してはいけないこと: 書き換えた定型文と既定の定型文が、両方入る。
        // してはいけないこと: 定型文を書き換えたことで、「パス → コメント」の並びや区切りが変わる。
        let prompt = try XCTUnwrap(copiedPrompt(), "クリップボードが空")
        XCTAssertEqual(prompt.boilerplate, customBoilerplate)
        XCTAssertEqual(prompt.entries, expectedEntries)
        XCTAssertEqual(prompt.text, CopiedPrompt.expectedText(boilerplate: customBoilerplate, entries: expectedEntries))
        XCTAssertTrue(prompt.text.hasPrefix(customBoilerplate + "\n\n"))
        XCTAssertFalse(prompt.text.contains(DefaultBoilerplate.english), "既定の英語の定型文が入っている")
        XCTAssertFalse(prompt.text.contains(DefaultBoilerplate.japanese), "既定の日本語の定型文が入っている")
    }

    // scenario: 書き換えた定型文は、言語を切り替えても言語ごとに保たれる
    func testEditedBoilerplateIsKeptPerLanguage() throws {
        // 前提: セットアップ済み、言語は英語（既定）。英語の定型文だけを書き換えてある。確定済みの注釈が 1 件あり、akapen は何も出していない。
        launch(
            .setupDone,
            settings: LaunchSettings(boilerplates: [.en: customBoilerplate]),
            annotations: SeedAnnotation.samples(1)
        )
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.language, .en)
        XCTAssertEqual(start.settings.boilerplate(.en), customBoilerplate)
        XCTAssertEqual(start.settings.boilerplate(.ja), DefaultBoilerplate.japanese)
        let annotation = try XCTUnwrap(start.annotations.first)
        let expectedEntries = [CopiedPrompt.Entry(path: annotation.imagePath, comment: annotation.comment)]

        // 操作: 設定で日本語に切り替える。
        openSettingsFromMenuBar()
        chooseLanguage(.ja)

        // 期待される結果: アプリの状態で、日本語に切り替えたあとも、英語の定型文は書き換えた文のままで、日本語の定型文は既定のまま。
        // してはいけないこと: 英語の定型文を書き換えた内容が、日本語の定型文にも入る。
        let japanese = waitForState("言語が日本語になる") { $0.settings.language == .ja }
        XCTAssertEqual(japanese.settings.boilerplate(.en), customBoilerplate)
        XCTAssertEqual(japanese.settings.boilerplate(.ja), DefaultBoilerplate.japanese)
        closeSettings()

        // 操作: ホットキーでボタン類を出し、プロンプトをコピーする。
        bringSampleToFront()
        pressHotkey()
        waitForPhase(.drawing)
        tapCopyPrompt()
        waitForCopyFinished()

        // 期待される結果: クリップボードに入った文章で、日本語に切り替えたあとにコピーすると、冒頭が日本語の既定の定型文になっている。
        // してはいけないこと: 日本語に切り替えたのに、書き換えた英語の定型文が入る。
        let prompt = try XCTUnwrap(copiedPrompt(), "クリップボードが空")
        XCTAssertEqual(prompt.boilerplate, DefaultBoilerplate.japanese)
        XCTAssertEqual(prompt.entries, expectedEntries)
        XCTAssertEqual(prompt.text, CopiedPrompt.expectedText(boilerplate: DefaultBoilerplate.japanese, entries: expectedEntries))
        XCTAssertFalse(prompt.text.contains(customBoilerplate), "書き換えた英語の定型文が入っている")

        // 操作: 設定で英語に戻す。
        openSettingsFromMenuBar()
        chooseLanguage(.en)

        // 期待される結果: アプリの状態で、英語に戻したあとも、英語の定型文は書き換えた文のままで、日本語の定型文は既定のまま。
        // してはいけないこと: 言語を往復しただけで、書き換えた英語の定型文が既定に戻る。
        // してはいけないこと: 英語の定型文を書き換えた内容が、日本語の定型文にも入る。
        let english = waitForState("言語が英語に戻る") { $0.settings.language == .en }
        XCTAssertEqual(english.settings.boilerplate(.en), customBoilerplate)
        XCTAssertEqual(english.settings.boilerplate(.ja), DefaultBoilerplate.japanese)
        XCTAssertEqual(element(AXID.Settings.boilerplate).value as? String, customBoilerplate)
    }
}
