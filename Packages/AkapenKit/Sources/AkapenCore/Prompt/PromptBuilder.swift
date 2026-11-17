import Foundation

/// クリップボードに入れるプロンプトを組み立てる。
///
/// 形は `DESIGN.md`「コピーされるプロンプト」のとおり。定型文、空行、そのあとに
/// 「画像のパス（改行）コメント」を空行で区切って注釈の数だけ並べる。
/// 通し番号と座標は入れない。末尾に改行を付けない。
public enum PromptBuilder {
    /// 定型文と注釈からプロンプトを作る。定型文の前後の空白と改行は除く。
    /// 定型文が空なら、定型文とそのあとの空行を省く。
    public static func build(boilerplate: String, annotations: [Annotation]) -> String {
        let entries = annotations.map { annotation in
            annotation.imagePath + "\n" + annotation.comment
        }
        let head = boilerplate.trimmingWhitespaceAndNewlines()
        let blocks = head.isEmpty ? entries : [head] + entries
        return blocks.joined(separator: "\n\n")
    }

    /// 設定の言語に合った定型文（書き換えていればその文面）でプロンプトを作る。
    public static func build(settings: Settings, annotations: [Annotation]) -> String {
        build(boilerplate: settings.boilerplate(for: settings.language), annotations: annotations)
    }
}

extension String {
    /// 前後の空白と改行を除いた文字列。
    func trimmingWhitespaceAndNewlines() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
