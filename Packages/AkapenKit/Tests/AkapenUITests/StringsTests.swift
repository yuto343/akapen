import Testing
import AkapenCore
@testable import AkapenUI

/// 文言の表。`swift test` でもアプリと同じ文言が出ること、言語を設定で切り替えられること、単数・複数を出し分けること。
@Suite
struct StringsTests {
    let english = UIStrings(language: .en)
    let japanese = UIStrings(language: .ja)

    @Test
    func englishMatchesPaper() {
        #expect(english[.list] == "List")
        #expect(english[.copyPrompt] == "Copy prompt")
        #expect(english[.drawHint] == "Drag to frame")
        #expect(english[.drawCancel] == "esc to cancel")
        #expect(english[.commentPlaceholder] == "Add a comment…")
        #expect(english[.listTitle] == "Annotations")
        #expect(english[.listEmpty] == "No annotations yet")
        #expect(english[.copiedTitle] == "Prompt copied")
        #expect(english[.copiedShortcut] == "⌘ V")
        #expect(english.sizeLabel(width: 332, height: 88) == "332 × 88")
        #expect(english.annotationMeta(appName: "Sample App", time: "14:32") == "Sample App · 14:32")
    }

    @Test
    func everyKeyHasTextInBothLanguages() {
        for key in StringKey.allCases {
            #expect(!english[key].isEmpty, "\(key)")
            #expect(!japanese[key].isEmpty, "\(key)")
        }
        for key in PluralKey.allCases {
            for count in [0, 1, 2] {
                #expect(!english.plural(key, count: count).isEmpty)
                #expect(!japanese.plural(key, count: count).isEmpty)
            }
        }
    }

    @Test
    func languageComesFromSettingsNotSystem() {
        #expect(UIStrings(language: .en)[.copyPrompt] == "Copy prompt")
        #expect(UIStrings(language: .ja)[.copyPrompt] == "プロンプトをコピー")
        #expect(japanese[.listTitle] == "注釈")
        #expect(japanese[.drawHint] == "ドラッグして枠を描く")
    }

    @Test
    func englishSingularAndPlural() {
        #expect(english.plural(.listItems, count: 0) == "0 ITEMS")
        #expect(english.plural(.listItems, count: 1) == "1 ITEM")
        #expect(english.plural(.listItems, count: 2) == "2 ITEMS")
        #expect(english.plural(.listRetention, count: 1) == "Images are kept for 1 day")
        #expect(english.plural(.listRetention, count: 7) == "Images are kept for 7 days")
        #expect(english.plural(.copiedSummary, count: 1) == "1 annotation · paste it into your AI agent")
        #expect(english.plural(.copiedSummary, count: 2) == "2 annotations · paste it into your AI agent")
    }

    @Test
    func japaneseDoesNotChangeWithCount() {
        #expect(japanese.plural(.listItems, count: 1) == "1 件")
        #expect(japanese.plural(.listItems, count: 2) == "2 件")
        #expect(japanese.plural(.listRetention, count: 1) == "画像は 1 日間保存されます")
        #expect(japanese.plural(.listRetention, count: 7) == "画像は 7 日間保存されます")
        #expect(japanese.plural(.copiedSummary, count: 1) == "1 件 · AI エージェントに貼り付けてください")
    }

    @Test
    func hintFollowsConfirmKey() {
        #expect(english.commentHint(for: .enter) == "↵ Done · ⇧↵ New line")
        #expect(english.commentHint(for: .commandEnter) == "⌘↵ Done · ↵ New line")
        #expect(english.listEditHint(for: .enter) == "↵ Save · esc Cancel")
        #expect(english.listEditHint(for: .commandEnter) == "⌘↵ Save · esc Cancel")
        #expect(japanese.commentHint(for: .enter) == "↵ 確定 · ⇧↵ 改行")
        #expect(japanese.commentHint(for: .commandEnter) == "⌘↵ 確定 · ↵ 改行")
    }

    @Test
    func lookupByStringKey() {
        #expect(UIStrings.text("quit") == "Quit")
        #expect(UIStrings.text("quit", language: .ja) == "終了")
        #expect(UIStrings.text("unknown.key") == "unknown.key")
    }
}
