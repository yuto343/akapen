import AppKit
import AkapenCore

/// `NSPasteboard` にプロンプトを書き込む。
///
/// 名前を渡すと、その名前のクリップボードを使う（E2E で手元のコピー内容を壊さないため）。
@MainActor public final class SystemPromptPasteboard: PromptPasteboard {
    /// 書き込みに失敗したときのエラー。
    public enum WriteError: Error, Equatable {
        /// `NSPasteboard.writeObjects` が失敗した。
        case rejected
    }

    private let pasteboard: NSPasteboard

    /// `name` が nil なら一般のクリップボード、名前があればその名前のクリップボードを使う。
    public init(name: String? = nil) {
        if let name {
            pasteboard = NSPasteboard(name: NSPasteboard.Name(name))
        } else {
            pasteboard = NSPasteboard.general
        }
    }

    /// 中身を置き換える。1 つ目の項目に文章、続く項目に画像ファイルの URL を入れる。
    public func write(text: String, imageURLs: [URL]) throws {
        var items: [any NSPasteboardWriting] = [text as NSString]
        for url in imageURLs {
            items.append(url as NSURL)
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(items) else {
            throw WriteError.rejected
        }
    }
}
