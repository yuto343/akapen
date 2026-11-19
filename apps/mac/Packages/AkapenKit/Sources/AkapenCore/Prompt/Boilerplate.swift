/// プロンプトの冒頭に置く定型文の、言語ごとの既定値。
public enum Boilerplate {
    /// 英語の既定文。`DESIGN.md`「コピーされるプロンプト」の例と同じ。
    public static let english = """
        I annotated the screen. Please address the comments below.
        Open every image and check the area marked with the red frame before you start.
        """

    /// 日本語の既定文。
    public static let japanese = """
        画面に注釈を付けました。以下のコメントに対応してください。
        作業前にすべての画像を開き、赤枠の箇所を確認してください。
        """

    /// 指定した言語の既定文を返す。
    public static func defaultText(for language: Language) -> String {
        switch language {
        case .en:
            english
        case .ja:
            japanese
        }
    }

    /// 全言語の既定文。キーは `Language.rawValue`（`Settings.boilerplates` と同じ形）。
    public static var defaults: [String: String] {
        [
            Language.en.rawValue: english,
            Language.ja.rawValue: japanese,
        ]
    }
}
