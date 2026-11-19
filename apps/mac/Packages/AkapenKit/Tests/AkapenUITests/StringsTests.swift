import Testing
import AkapenCore
@testable import AkapenUI

/// 文言の表。`swift test` でもアプリと同じ文言が出ること、言語を設定で切り替えられること、単数・複数を出し分けること。
@Suite
struct StringsTests {
    let english = UIStrings(language: .en)
    let japanese = UIStrings(language: .ja)

    @Test
    func clearConfirmationStrings() {
        #expect(english[.clearAll] == "Clear all")
        #expect(japanese[.clearAll] == "すべて消す")
        #expect(english[.clearAllHelp] == "Clear all annotations (⌘⌫)")
        #expect(japanese[.clearAllHelp] == "注釈をすべて消す (⌘⌫)")
        #expect(english[.clearTitle] == "Clear all annotations?")
        #expect(japanese[.clearTitle] == "注釈をすべて消しますか？")
        #expect(english.plural(.clearMessage, count: 1) == "1 annotation and its image will be deleted.\nThis can’t be undone.")
        #expect(english.plural(.clearMessage, count: 2) == "2 annotations and their images will be deleted.\nThis can’t be undone.")
        for count in [1, 2] {
            #expect(japanese.plural(.clearMessage, count: count) == "\(count) 件の注釈と画像を消します。\n元に戻せません。")
        }
        #expect(english[.quitCancel] == "Cancel")
        #expect(japanese[.quitCancel] == "キャンセル")
    }

    @Test
    func toolbarShortcutsAreShown() {
        #expect(english.clearShortcutKeys == ["⌘", "⌫"])
        #expect(english.listShortcutKeys == ["⌘", "L"])
        #expect(english.copyPromptShortcutKeys == ["⌘", "C"])
        #expect(english[.listHelp] == "Show or hide the list (⌘L)")
        #expect(english[.copyPromptHelp] == "Copy the prompt (⌘C)")
        #expect(japanese.clearShortcutKeys == ["⌘", "⌫"])
        #expect(japanese.listShortcutKeys == ["⌘", "L"])
        #expect(japanese.copyPromptShortcutKeys == ["⌘", "C"])
        #expect(japanese[.listHelp] == "リストを開く・閉じる（⌘L）")
        #expect(japanese[.copyPromptHelp] == "プロンプトをコピー（⌘C）")
    }

    @Test
    func englishMatchesPaper() {
        #expect(english[.list] == "List")
        #expect(english[.copyPrompt] == "Copy")
        #expect(english[.drawHint] == "Drag to frame")
        #expect(english.cancelHint.keys == ["esc"])
        #expect(english.cancelHint.label == "Cancel")
        #expect(english[.commentPlaceholder] == "Add a comment…")
        #expect(english[.listTitle] == "Annotations")
        #expect(english[.listEmpty] == "No annotations yet")
        #expect(english[.copiedTitle] == "Copied!")
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
        #expect(UIStrings(language: .en)[.copyPrompt] == "Copy")
        #expect(UIStrings(language: .ja)[.copyPrompt] == "コピー")
        #expect(japanese[.listTitle] == "注釈")
        #expect(japanese[.drawHint] == "ドラッグしてフレームを追加")
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
        #expect(english.commentHints(for: .enter) == [
            KeyHint(keys: ["↵"], label: "Done"),
            KeyHint(keys: ["⇧", "↵"], label: "New line"),
        ])
        #expect(english.commentHints(for: .commandEnter) == [
            KeyHint(keys: ["⌘", "↵"], label: "Done"),
            KeyHint(keys: ["↵"], label: "New line"),
        ])
        #expect(english.cancelHint == KeyHint(keys: ["esc"], label: "Cancel"))
        #expect(english.listEditHints(for: .enter).map(\.spoken) == ["↵ Save", "esc Cancel"])
        #expect(english.listEditHints(for: .commandEnter).map(\.spoken) == ["⌘↵ Save", "esc Cancel"])
        #expect(japanese.commentHints(for: .enter).map(\.spoken) == ["↵ 確定", "⇧↵ 改行"])
        #expect(japanese.commentHints(for: .commandEnter).map(\.spoken) == ["⌘↵ 確定", "↵ 改行"])
        #expect(japanese.cancelHint.spoken == "esc キャンセル")
    }

    @Test
    func menuAndQuitConfirmMatchPaper() {
        #expect(english[.appName] == "akapen")
        #expect(english[.menuSettings] == "Settings…")
        #expect(english[.menuCheckForUpdates] == "Check for Updates…")
        #expect(english[.menuQuit] == "Quit akapen")
        #expect(english[.menuNoAnnotations] == "No annotations")
        #expect(english[.quitTitle] == "Quit akapen?")
        #expect(english[.quit] == "Quit")
        #expect(english[.quitCancel] == "Cancel")
        #expect(japanese[.appName] == "akapen")
        #expect(japanese[.menuSettings] == "設定…")
        #expect(japanese[.menuCheckForUpdates] == "アップデートを確認…")
        #expect(japanese[.menuQuit] == "akapen を終了")
        #expect(japanese[.menuNoAnnotations] == "注釈はありません")
        #expect(japanese[.quitTitle] == "akapen を終了しますか？")
        #expect(japanese[.quit] == "終了")
        #expect(japanese[.quitCancel] == "キャンセル")
    }

    @Test
    func menuAndQuitConfirmPlurals() {
        #expect(english.menuStatus(count: 0) == "No annotations")
        #expect(english.menuStatus(count: 1) == "1 annotation waiting")
        #expect(english.menuStatus(count: 2) == "2 annotations waiting")
        #expect(japanese.menuStatus(count: 0) == "注釈はありません")
        #expect(japanese.menuStatus(count: 2) == "リスト内に 2 件あります")
        #expect(english.plural(.quitMessage, count: 1) == "1 annotation hasn’t been copied yet.\nIt will be discarded.")
        #expect(english.plural(.quitMessage, count: 2) == "2 annotations haven’t been copied yet.\nThey will be discarded.")
        #expect(japanese.plural(.quitMessage, count: 1) == "コピーしていない注釈が 1 件あります。\n終了すると破棄されます。")
        #expect(japanese.plural(.quitMessage, count: 2) == "コピーしていない注釈が 2 件あります。\n終了すると破棄されます。")
    }

    @Test
    func settingsMatchPaper() {
        #expect(english[.settingsTitle] == "akapen Settings")
        #expect(english[.settingsLanguage] == "Language")
        #expect(english[.languageEnglish] == "English")
        #expect(english[.languageJapanese] == "日本語")
        #expect(english[.settingsHotkey] == "Hotkey")
        #expect(english[.settingsConfirmKey] == "Confirm comment with")
        #expect(english[.confirmKeyEnter] == "↵ Enter")
        #expect(english[.confirmKeyCommandEnter] == "⌘ ↵ Enter")
        #expect(english[.settingsPromptHeader] == "Prompt header")
        #expect(english[.settingsPromptNote] == "Once edited, it won’t change with the language")
        #expect(english[.settingsPromptCaption] == "Each annotation is added below as an image path followed by its comment.")
        #expect(english[.settingsRetention] == "Keep images for")
        #expect(english[.recorderPlaceholder] == "Record shortcut")
        #expect(english[.recorderRecording] == "Type shortcut…")
        #expect(english[.recorderUnavailable] == "This shortcut is unavailable")
        #expect(english[.recorderInUse] == "This shortcut is already in use")
        #expect(english.plural(.retentionUnit, count: 1) == "day")
        #expect(english.plural(.retentionUnit, count: 7) == "days")
    }

    @Test
    func settingsInJapanese() {
        #expect(japanese[.settingsTitle] == "akapen の設定")
        #expect(japanese[.settingsLanguage] == "言語")
        #expect(japanese[.languageEnglish] == "English")
        #expect(japanese[.languageJapanese] == "日本語")
        #expect(japanese[.settingsHotkey] == "ホットキー")
        #expect(japanese[.settingsConfirmKey] == "コメントの確定キー")
        #expect(japanese[.confirmKeyEnter] == "↵ Enter")
        #expect(japanese[.confirmKeyCommandEnter] == "⌘ ↵ Enter")
        #expect(japanese[.settingsPromptHeader] == "プロンプトの定型文")
        #expect(japanese[.settingsPromptNote] == "編集すると、言語設定によって変更されなくなります")
        #expect(japanese[.settingsPromptCaption] == "この下に、注釈ごとに画像のパスとコメントが続きます。")
        #expect(japanese[.settingsRetention] == "画像を残す日数")
        #expect(japanese[.recorderPlaceholder] == "ショートカットを記録")
        #expect(japanese[.recorderRecording] == "キーを押してください…")
        #expect(japanese[.recorderUnavailable] == "このショートカットは使えません")
        #expect(japanese[.recorderInUse] == "このショートカットはほかの欄で使っています")
        #expect(japanese.plural(.retentionUnit, count: 1) == "日")
        #expect(japanese.plural(.retentionUnit, count: 7) == "日")
    }

    @Test
    func setupMatchesPaper() {
        #expect(english.setupStep(current: 1, total: 2) == "STEP 1 OF 2")
        #expect(english.setupStep(current: 2, total: 2) == "STEP 2 OF 2")
        #expect(english[.setupHotkeyTitle] == "Choose your hotkey")
        #expect(english[.setupHotkeyBody] == "Press it anywhere to show the buttons and start drawing a frame. Press it again for the next frame.")
        #expect(english[.setupRecorderHint] == "Click and press a new combination to change")
        #expect(english[.setupConflictNote] == "⌘⇧6 is also used by macOS to save a screenshot of the Touch Bar (on Macs with a Touch Bar). You can change it here or later in Settings.")
        #expect(english[.setupContinue] == "Continue")
        #expect(english[.setupPermissionTitle] == "Allow Screen Recording")
        #expect(english.setupPermissionBody(path: "~/Library/Caches/akapen") == "akapen captures the screen around each frame. Images stay on this Mac in ~/Library/Caches/akapen.")
        #expect(english[.setupStepOpenSettings] == "Open System Settings → Privacy & Security")
        #expect(english[.setupStepTurnOn] == "Turn on akapen under Screen Recording")
        #expect(english[.setupStepComeBack] == "Come back here")
        #expect(english[.setupWaiting] == "Waiting…")
        #expect(english[.setupGranted] == "Granted")
        #expect(english[.setupBack] == "Back")
        #expect(english[.setupOpenSystemSettings] == "Open System Settings")
        #expect(english[.setupDone] == "Done")
    }

    @Test
    func setupInJapanese() {
        #expect(japanese.setupStep(current: 1, total: 2) == "ステップ 1 / 2")
        #expect(japanese[.setupHotkeyTitle] == "ホットキーを決める")
        #expect(japanese[.setupHotkeyBody] == "akapen を呼び出すと、マウスで枠を描くモードになります。")
        #expect(japanese[.setupRecorderHint] == "クリックして変更します")
        #expect(japanese[.setupConflictNote] == "⌘⇧6 は、Touch Bar のある Mac では macOS の Touch Bar のスクリーンショットにも使われています。ここか、あとで設定から変えられます。")
        #expect(japanese[.setupContinue] == "続ける")
        #expect(japanese[.setupPermissionTitle] == "画面収録を許可する")
        #expect(japanese.setupPermissionBody(path: "~/Library/Caches/akapen") == "akapen は画面を撮影するので、画面収録の権限が必要です。\n画像はこの Mac の ~/Library/Caches/akapen に残ります。")
        #expect(japanese[.setupStepOpenSettings] == "システム設定 → プライバシーとセキュリティを開く")
        #expect(japanese[.setupStepTurnOn] == "「画面収録」で akapen をオンにする")
        #expect(japanese[.setupStepComeBack] == "ここに戻る")
        #expect(japanese[.setupWaiting] == "待っています…")
        #expect(japanese[.setupGranted] == "許可されました")
        #expect(japanese[.setupBack] == "戻る")
        #expect(japanese[.setupOpenSystemSettings] == "システム設定を開く")
        #expect(japanese[.setupDone] == "完了")
    }

    @Test
    func lookupByStringKey() {
        #expect(UIStrings.text("quit") == "Quit")
        #expect(UIStrings.text("quit", language: .ja) == "終了")
        #expect(UIStrings.text("unknown.key") == "unknown.key")
    }
}
