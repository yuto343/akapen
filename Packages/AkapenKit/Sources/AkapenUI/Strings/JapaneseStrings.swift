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
        }
    }

    func sizeLabel(width: Int, height: Int) -> String {
        "\(width) × \(height)"
    }

    func annotationMeta(appName: String, time: String) -> String {
        "\(appName) · \(time)"
    }
}
