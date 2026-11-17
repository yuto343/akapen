import Foundation

/// プロンプトと任意の画像ファイルをコピーする。
@MainActor public protocol PromptPasteboard {
    /// テキストと添付画像 URL を同じコピー操作で置き換える。画像不要なら空配列。
    func write(text: String, imageURLs: [URL]) throws
}
