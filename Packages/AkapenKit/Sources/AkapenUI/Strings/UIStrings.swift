import AkapenCore

/// 引数のない文言のキー。値は `EnglishStrings` と `JapaneseStrings` の表にある。
public enum StringKey: String, CaseIterable, Sendable {
    /// 「+」ボタンの読み上げ用の名前。
    case add
    /// 「List」ボタン。
    case list
    /// 「Copy prompt」ボタン。
    case copyPrompt
    /// メニューバーの終了。
    case quit
    /// 案内の表示の `Drag to frame`。
    case drawHint
    /// 案内の表示の `esc to cancel`。
    case drawCancel
    /// コメント入力のプレースホルダー。
    case commentPlaceholder
    /// コメント入力の下の案内（`Enter` で確定の設定）。
    case commentHintEnter
    /// コメント入力の下の案内（`⌘Enter` で確定の設定）。
    case commentHintCommandEnter
    /// コメント入力の下の `esc`。
    case commentCancel
    /// 一覧の見出し。
    case listTitle
    /// 一覧が 0 件のときの表示。
    case listEmpty
    /// 一覧の編集中の行の下の案内（`Enter` で確定の設定）。
    case listEditHintEnter
    /// 一覧の編集中の行の下の案内（`⌘Enter` で確定の設定）。
    case listEditHintCommandEnter
    /// 一覧の鉛筆のボタンの読み上げ用の名前。
    case listEdit
    /// 一覧のゴミ箱のボタンの読み上げ用の名前。
    case listDelete
    /// コピー完了の表示の 1 行目。
    case copiedTitle
    /// コピー完了の表示のキー表示。
    case copiedShortcut
}

/// 件数で単数・複数を出し分ける文言のキー（`DECISIONS.md` 21）。日本語は出し分けない。
public enum PluralKey: String, CaseIterable, Sendable {
    /// 一覧の見出しの件数（`2 ITEMS`）。
    case listItems
    /// 一覧のフッター（`Images are kept for 7 days`）。数は設定の日数。
    case listRetention
    /// コピー完了の表示の 2 行目（`2 annotations · paste it into your AI agent`）。
    case copiedSummary
}

/// 1 つの言語の文言の表。
protocol StringTable: Sendable {
    func text(_ key: StringKey) -> String

    func plural(_ key: PluralKey, count: Int) -> String

    func sizeLabel(width: Int, height: Int) -> String

    func annotationMeta(appName: String, time: String) -> String
}

/// 表示の文言。言語はシステムの言語ではなく、アプリの設定（`Settings.language`）で選ぶ。
///
/// 文言そのものは `EnglishStrings.swift` と `JapaneseStrings.swift` の表に置く。
/// 文字列カタログを使わないのは、`swift test` と `xcodebuild` で結果を同じにするため（カタログは `swift test` ではコンパイルされない）。
public struct UIStrings: Sendable {
    public let language: Language

    /// 指定した言語の文言を引く。
    public init(language: Language) {
        self.language = language
    }

    private var table: any StringTable {
        switch language {
        case .en:
            EnglishStrings()
        case .ja:
            JapaneseStrings()
        }
    }

    /// 引数のない文言。
    public subscript(_ key: StringKey) -> String {
        table.text(key)
    }

    /// 件数で単数・複数を出し分ける文言。
    public func plural(_ key: PluralKey, count: Int) -> String {
        table.plural(key, count: count)
    }

    /// 大きさの表示（`332 × 88`）。
    public func sizeLabel(width: Int, height: Int) -> String {
        table.sizeLabel(width: width, height: height)
    }

    /// 一覧の行のメタ情報（`Sample App · 14:32`）。
    public func annotationMeta(appName: String, time: String) -> String {
        table.annotationMeta(appName: appName, time: time)
    }

    /// コメント入力の下の案内。確定キーの設定で文言が変わる（`DECISIONS.md` 22）。
    public func commentHint(for confirmKey: ConfirmKey) -> String {
        switch confirmKey {
        case .enter:
            self[.commentHintEnter]
        case .commandEnter:
            self[.commentHintCommandEnter]
        }
    }

    /// 一覧の編集中の行の下の案内。確定キーの設定で文言が変わる。
    public func listEditHint(for confirmKey: ConfirmKey) -> String {
        switch confirmKey {
        case .enter:
            self[.listEditHintEnter]
        case .commandEnter:
            self[.listEditHintCommandEnter]
        }
    }

    /// キーを文字列で指定して引く。キーが表にないときは、キーをそのまま返す。
    public static func text(_ key: String, language: Language = .en) -> String {
        guard let known = StringKey(rawValue: key) else {
            return key
        }
        return UIStrings(language: language)[known]
    }
}
