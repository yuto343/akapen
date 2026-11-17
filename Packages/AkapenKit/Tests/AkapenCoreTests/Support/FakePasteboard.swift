import Foundation
import AkapenCore

/// 書き込まれた内容を覚えておく偽のクリップボード。
@MainActor final class FakePasteboard: PromptPasteboard {
    var writes: [(text: String, imageURLs: [URL])] = []
    var writeError: TestError?

    var lastText: String? {
        writes.last?.text
    }

    func write(text: String, imageURLs: [URL]) throws {
        if let writeError {
            throw writeError
        }
        writes.append((text, imageURLs))
    }
}
