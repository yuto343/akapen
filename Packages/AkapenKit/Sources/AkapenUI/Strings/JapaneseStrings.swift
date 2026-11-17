/// 日本語の文言。英語の文言を訳したもの（`DECISIONS.md` 29）。単数・複数は出し分けない。
struct JapaneseStrings: StringTable {
    func text(_ key: StringKey) -> String {
        switch key {
        case .add:
            "追加"
        case .list:
            "一覧"
        case .copyPrompt:
            "プロンプトをコピー"
        case .quit:
            "終了"
        case .drawHint:
            "ドラッグして枠を描く"
        case .drawCancel:
            "esc でキャンセル"
        case .commentPlaceholder:
            "コメントを入力…"
        case .commentHintEnter:
            "↵ 確定 · ⇧↵ 改行"
        case .commentHintCommandEnter:
            "⌘↵ 確定 · ↵ 改行"
        case .commentCancel:
            "esc"
        case .listTitle:
            "注釈"
        case .listEmpty:
            "注釈はまだありません"
        case .listEditHintEnter:
            "↵ 保存 · esc キャンセル"
        case .listEditHintCommandEnter:
            "⌘↵ 保存 · esc キャンセル"
        case .listEdit:
            "編集"
        case .listDelete:
            "削除"
        case .copiedTitle:
            "プロンプトをコピーしました"
        case .copiedShortcut:
            "⌘ V"
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
        case .settingsToolbarShortcut:
            "ボタン類の表示・非表示"
        case .settingsToolbarShortcutCaption:
            "割り当ては任意"
        case .settingsConfirmKey:
            "コメントの確定キー"
        case .confirmKeyEnter:
            "↵ Enter"
        case .confirmKeyCommandEnter:
            "⌘ ↵ Enter"
        case .settingsPromptHeader:
            "プロンプトの定型文"
        case .settingsPromptNote:
            "日本語版を編集します"
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
            "どこで押しても、ボタン類が出て枠を描き始めます。\nもう一度押すと、次の枠を描きます。"
        case .setupRecorderHint:
            "クリックして、新しい組み合わせを押すと変わります"
        case .setupConflictNote:
            "⌘; は macOS のテキスト入力欄（スペルミスの箇所へ移動）、VS Code、Photoshop でも使われています。ここか、あとで設定から変えられます。"
        case .setupContinue:
            "続ける"
        case .setupPermissionTitle:
            "画面収録を許可する"
        case .setupPermissionBody:
            "akapen は枠の下のウィンドウを撮影します。画像はこの Mac の\n~/Library/Caches/akapen に残ります。"
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
        }
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
            "\(count) 件の注釈がコピー待ち"
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
