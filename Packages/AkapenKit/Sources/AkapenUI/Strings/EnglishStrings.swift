/// 英語の文言。Paper の資料の文言のとおり。
struct EnglishStrings: StringTable {
    func text(_ key: StringKey) -> String {
        switch key {
        case .add:
            "Add"
        case .list:
            "List"
        case .copyPrompt:
            "Copy prompt"
        case .quit:
            "Quit"
        case .drawHint:
            "Drag to frame"
        case .drawCancel:
            "esc to cancel"
        case .commentPlaceholder:
            "Add a comment…"
        case .commentHintEnter:
            "↵ Done · ⇧↵ New line"
        case .commentHintCommandEnter:
            "⌘↵ Done · ↵ New line"
        case .commentCancel:
            "esc"
        case .listTitle:
            "Annotations"
        case .listEmpty:
            "No annotations yet"
        case .listEditHintEnter:
            "↵ Save · esc Cancel"
        case .listEditHintCommandEnter:
            "⌘↵ Save · esc Cancel"
        case .listEdit:
            "Edit"
        case .listDelete:
            "Delete"
        case .copiedTitle:
            "Prompt copied"
        case .copiedShortcut:
            "⌘ V"
        }
    }

    /// 英語の複数形の決まり（CLDR）: 1 だけが単数。0 は複数。
    func plural(_ key: PluralKey, count: Int) -> String {
        let one = count == 1
        switch key {
        case .listItems:
            return one ? "1 ITEM" : "\(count) ITEMS"
        case .listRetention:
            return one ? "Images are kept for 1 day" : "Images are kept for \(count) days"
        case .copiedSummary:
            return one ? "1 annotation · paste it into your AI agent" : "\(count) annotations · paste it into your AI agent"
        }
    }

    func sizeLabel(width: Int, height: Int) -> String {
        "\(width) × \(height)"
    }

    func annotationMeta(appName: String, time: String) -> String {
        "\(appName) · \(time)"
    }
}
