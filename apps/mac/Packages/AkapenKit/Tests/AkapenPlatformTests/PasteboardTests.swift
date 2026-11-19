import AppKit
import Foundation
import Testing
import AkapenPlatform

/// 一般のクリップボードには触らず、テストごとに一意な名前のクリップボードを使う。
@MainActor
struct PasteboardTests {
    private func withPasteboard(_ body: (String, NSPasteboard) throws -> Void) throws {
        let name = "akapen.platform-tests.\(UUID().uuidString)"
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(name))
        defer {
            pasteboard.releaseGlobally()
        }
        try body(name, pasteboard)
    }

    @Test
    func writesTextOnly() throws {
        try withPasteboard { name, pasteboard in
            let store = SystemPromptPasteboard(name: name)
            let text = "I annotated the screen.\n\n/tmp/akapen/01.png\nボタンの余白"
            try store.write(text: text, imageURLs: [])
            #expect(pasteboard.string(forType: .string) == text)
            #expect(pasteboard.pasteboardItems?.count == 1)
        }
    }

    @Test
    func writesTextWithImageURLs() throws {
        try withPasteboard { name, pasteboard in
            let store = SystemPromptPasteboard(name: name)
            let urls = [
                URL(filePath: "/tmp/akapen/20261117-1432/01.png"),
                URL(filePath: "/tmp/akapen/20261117-1432/02.png"),
            ]
            try store.write(text: "prompt", imageURLs: urls)
            #expect(pasteboard.string(forType: .string) == "prompt")
            let read = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL]
            #expect(read == urls)
        }
    }

    @Test
    func writeReplacesPreviousContent() throws {
        try withPasteboard { name, pasteboard in
            let store = SystemPromptPasteboard(name: name)
            try store.write(text: "first", imageURLs: [URL(filePath: "/tmp/akapen/01.png")])
            try store.write(text: "second", imageURLs: [])
            #expect(pasteboard.string(forType: .string) == "second")
            #expect(pasteboard.pasteboardItems?.count == 1)
            let read = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL]
            #expect(read?.isEmpty ?? true)
        }
    }
}
