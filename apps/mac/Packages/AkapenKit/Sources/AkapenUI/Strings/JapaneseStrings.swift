/// 日本語の文言。英語の文言を訳したもの（`DECISIONS.md` 29）。単数・複数は出し分けない。
struct JapaneseStrings: StringTable {
    func text(_ key: StringKey) -> String {
        switch key {
        case .list:
            "リスト"
        case .copyPrompt:
            "コピー"
        case .clearShortcutKey:
            "⌫"
        case .listShortcutKey:
            "L"
        case .copyPromptShortcutKey:
            "C"
        case .keyCommand:
            "⌘"
        case .keyShift:
            "⇧"
        case .keyReturn:
            "↵"
        case .keyEscape:
            "esc"
        case .hintDone:
            "確定"
        case .hintNewLine:
            "改行"
        case .hintSave:
            "保存"
        case .hintCancel:
            "キャンセル"
        case .clearAll:
            "すべて消す"
        case .clearAllHelp:
            "注釈をすべて消す (⌘⌫)"
        case .clearTitle:
            "注釈をすべて消しますか？"
        case .listHelp:
            "リストを開く・閉じる（⌘L）"
        case .copyPromptHelp:
            "プロンプトをコピー（⌘C）"
        case .quit:
            "終了"
        case .drawHint:
            "ドラッグしてフレームを追加"
        case .commentPlaceholder:
            "コメントを入力…"
        case .listTitle:
            "注釈"
        case .listEmpty:
            "注釈はまだありません"
        case .listEdit:
            "編集"
        case .listDelete:
            "削除"
        case .copiedTitle:
            "コピーしました！"
        case .appName:
            "akapen"
        case .menuSettings:
            "設定…"
        case .menuQuit:
            "akapen を終了"
        case .menuNoAnnotations:
            "注釈はありません"
        case .quitTitle:
            "akapen を終了しますか？"
        case .quitCancel:
            "キャンセル"
        case .settingsTitle:
            "akapen の設定"
        case .settingsLanguage:
            "言語"
        case .languageEnglish:
            "English"
        case .languageJapanese:
            "日本語"
        case .settingsHotkey:
            "ホットキー"
        case .settingsConfirmKey:
            "コメントの確定キー"
        case .confirmKeyEnter:
            "↵ Enter"
        case .confirmKeyCommandEnter:
            "⌘ ↵ Enter"
        case .settingsPromptHeader:
            "プロンプトの定型文"
        case .settingsPromptNote:
            "編集すると、言語設定によって変更されなくなります"
        case .settingsPromptCaption:
            "この下に、注釈ごとに画像のパスとコメントが続きます。"
        case .settingsRetention:
            "画像を残す日数"
        case .recorderPlaceholder:
            "ショートカットを記録"
        case .recorderRecording:
            "キーを押してください…"
        case .recorderUnavailable:
            "このショートカットは使えません"
        case .recorderInUse:
            "このショートカットはほかの欄で使っています"
        case .setupHotkeyTitle:
            "ホットキーを決める"
        case .setupHotkeyBody:
            "akapen を呼び出すと、マウスで枠を描くモードになります。"
        case .setupRecorderHint:
            "クリックして変更します"
        case .setupConflictNote:
            "⌘⇧6 は、Touch Bar のある Mac では macOS の Touch Bar のスクリーンショットにも使われています。ここか、あとで設定から変えられます。"
        case .setupContinue:
            "続ける"
        case .setupPermissionTitle:
            "画面収録を許可する"
        case .setupStepOpenSettings:
            "システム設定 → プライバシーとセキュリティを開く"
        case .setupStepTurnOn:
            "「画面収録」で akapen をオンにする"
        case .setupStepComeBack:
            "ここに戻る"
        case .setupWaiting:
            "待っています…"
        case .setupGranted:
            "許可されました"
        case .setupBack:
            "戻る"
        case .setupOpenSystemSettings:
            "システム設定を開く"
        case .setupDone:
            "完了"
        case .noticeCaptureFailed:
            "画面を撮影できませんでした"
        case .noticeImageSaveFailed:
            "画像を保存できませんでした"
        case .noticePasteboardFailed:
            "クリップボードにコピーできませんでした"
        case .noticeSettingsSaveFailed:
            "設定を保存できませんでした"
        case .menuEdit:
            "編集"
        case .menuUndo:
            "取り消す"
        case .menuRedo:
            "やり直す"
        case .menuCut:
            "カット"
        case .menuCopy:
            "コピー"
        case .menuPaste:
            "ペースト"
        case .menuSelectAll:
            "すべてを選択"
        }
    }

    func setupPermissionBody(path: String) -> String {
        "akapen は画面を撮影するので、画面収録の権限が必要です。\n画像はこの Mac の \(path) に残ります。"
    }

    func plural(_ key: PluralKey, count: Int) -> String {
        switch key {
        case .listItems:
            "\(count) 件"
        case .listRetention:
            "画像は \(count) 日間保存されます"
        case .copiedSummary:
            "\(count) 件 · AI エージェントに貼り付けてください"
        case .menuWaiting:
            "リスト内に \(count) 件あります"
        case .clearMessage:
            "\(count) 件の注釈と画像を消します。\n元に戻せません。"
        case .quitMessage:
            "コピーしていない注釈が \(count) 件あります。\n終了すると破棄されます。"
        case .retentionUnit:
            "日"
        }
    }

    func sizeLabel(width: Int, height: Int) -> String {
        "\(width) × \(height)"
    }

    func annotationMeta(appName: String, time: String) -> String {
        "\(appName) · \(time)"
    }

    func setupStep(current: Int, total: Int) -> String {
        "ステップ \(current) / \(total)"
    }
}
