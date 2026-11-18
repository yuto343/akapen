import Foundation
import Testing
import AkapenApp
import AkapenCore

/// 本物の組み立て（E2E の設定）で、一連の流れと分岐を通す。画面は操作せず、`SessionModel` に入力を順に送る。
@MainActor
@Suite
struct FlowTests {
    // MARK: - 一連の流れ

    @Test
    func hotkeyFrameCommentAnotherAndCopy() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        app.putOnPasteboard("前から入っていた文章")
        await app.send(.hotkeyPressed)
        #expect(app.model.phase == .drawing)
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        #expect(app.model.phase == .commenting)
        await app.send(.commentConfirmed(text: "ボタンの余白が左右で違う"))
        // 確定するとすぐ次の枠を描ける。
        #expect(app.model.phase == .drawing)
        await app.send(.dragEnded(rect: TestApp.secondRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        await app.send(.commentConfirmed(text: "ここの文言を「保存する」に\n2 行目も直す"))
        #expect(app.model.annotations.count == 2)
        let session = try #require(app.sessionDirectory)
        #expect(session.lastPathComponent == sessionID(for: TestApp.now))
        let first = session.appending(path: "01.png").path(percentEncoded: false)
        let second = session.appending(path: "02.png").path(percentEncoded: false)
        await app.send(.copyPromptTapped)
        #expect(app.model.phase == .copied)
        let expected = """
            I annotated the screen. Please address the comments below.
            Open every image and check the area marked with the red frame before you start.

            \(first)
            ボタンの余白が左右で違う

            \(second)
            ここの文言を「保存する」に
            2 行目も直す
            """
        #expect(app.pasteboardText() == expected)
        #expect(app.model.annotations.isEmpty)
        #expect(app.model.lastCopiedCount == 2)
        for (path, rect) in [(first, TestApp.firstRect), (second, TestApp.secondRect)] {
            let image = try #require(SavedImage(url: URL(filePath: path)))
            // 偽の撮影はウィンドウの 2 倍の画素。長辺の上限（1568px）に合わせて縮んでいる。
            #expect(image.pixelWidth == FrameRenderer.defaultMaxLongEdge)
            #expect(abs(Double(image.pixelHeight) / Double(image.pixelWidth) - TestApp.window.height / TestApp.window.width) < 0.002)
            let expectedFrame = image.expectedRedFrame(drawn: rect, window: TestApp.window)
            #expect(rectsMatch(image.redFrameInWindow(TestApp.window), expectedFrame, tolerance: 1.5))
        }
    }

    // MARK: - 分岐

    @Test
    func cancellingCommentLeavesNoImage() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.send(.hotkeyPressed)
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        let draft = try #require(app.model.draft)
        #expect(FileManager.default.fileExists(atPath: draft.imagePath))
        await app.send(.commentCancelled)
        #expect(app.model.phase == .drawing)
        #expect(app.model.draft == nil)
        #expect(app.model.annotations.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: draft.imagePath))
        #expect(app.imageFiles().isEmpty)
    }

    @Test
    func cancellingCommentKeepsEarlierAnnotations() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("残す", rect: TestApp.firstRect)
        await app.send(.dragEnded(rect: TestApp.secondRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        let draft = try #require(app.model.draft)
        await app.send(.commentCancelled)
        #expect(app.model.phase == .drawing)
        #expect(app.model.isToolbarVisible)
        #expect(app.model.annotations.map(\.comment) == ["残す"])
        #expect(!FileManager.default.fileExists(atPath: draft.imagePath))
        #expect(app.imageFiles().map(\.path) == app.model.annotations.map { URL(filePath: $0.imagePath).standardizedFileURL.path })
    }

    @Test
    func escapeWithNoAnnotationsLeavesNothing() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.send(.hotkeyPressed)
        await app.send(.escapePressed)
        #expect(app.model.phase == .hidden)
        #expect(!app.model.isToolbarVisible)
        #expect(app.model.annotations.isEmpty)
        #expect(app.imageFiles().isEmpty)
    }

    @Test
    func editAndDeleteInList() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("一つ目", rect: TestApp.firstRect)
        await app.annotate("二つ目", rect: TestApp.secondRect)
        let first = app.model.annotations[0]
        let second = app.model.annotations[1]
        await app.send(.listToggled)
        #expect(app.model.phase == .listOpen)
        await app.send(.annotationEdited(id: first.id, text: "一つ目を直した"))
        // 空のコメントには直せない。
        await app.send(.annotationEdited(id: second.id, text: "  \n "))
        #expect(app.model.annotations.map(\.comment) == ["一つ目を直した", "二つ目"])
        #expect(app.model.annotations.map(\.imagePath) == [first.imagePath, second.imagePath])
        await app.send(.annotationDeleted(id: first.id))
        #expect(app.model.annotations.map(\.id) == [second.id])
        #expect(!FileManager.default.fileExists(atPath: first.imagePath))
        #expect(FileManager.default.fileExists(atPath: second.imagePath))
    }

    @Test
    func copyAfterDeleteHasOnlyRemainingAnnotation() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("消す", rect: TestApp.firstRect)
        await app.annotate("残す", rect: TestApp.secondRect)
        let removed = app.model.annotations[0]
        let kept = app.model.annotations[1]
        await app.send(.listToggled)
        await app.send(.annotationDeleted(id: removed.id))
        await app.send(.copyPromptTapped)
        #expect(app.pasteboardText() == Boilerplate.english + "\n\n" + kept.imagePath + "\n残す")
        #expect(app.model.lastCopiedCount == 1)
    }

    @Test
    func nextSessionAfterCopyKeepsPreviousImages() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("前の回", rect: TestApp.firstRect)
        let previous = app.model.annotations[0]
        let previousData = try Data(contentsOf: URL(filePath: previous.imagePath))
        await app.send(.copyPromptTapped)
        let previousPrompt = app.pasteboardText()
        // コピー完了の表示が消える前にホットキーを押すと、注釈が 0 件の新しい回になる。
        await app.send(.hotkeyPressed)
        #expect(app.model.phase == .drawing)
        #expect(app.model.annotations.isEmpty)
        await app.send(.dragEnded(rect: TestApp.secondRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        await app.send(.commentConfirmed(text: "新しい回"))
        let current = app.model.annotations[0]
        // 時刻を固定しているので回のフォルダは同じ。番号を続けて、前の回の画像を上書きしない（DECISIONS.md A2）。
        #expect(current.imagePath != previous.imagePath)
        #expect(try Data(contentsOf: URL(filePath: previous.imagePath)) == previousData)
        await app.send(.copyPromptTapped)
        #expect(app.pasteboardText() == Boilerplate.english + "\n\n" + current.imagePath + "\n新しい回")
        #expect(previousPrompt?.contains(previous.imagePath) == true)
        #expect(app.pasteboardText()?.contains(previous.imagePath) == false)
    }

    @Test
    func hotkeyToggleKeepsAnnotationsAndSession() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("一つ目", rect: TestApp.firstRect)
        let session = try #require(app.sessionDirectory)
        // ホットキーはトグル。隠しても注釈は残る。
        await app.send(.hotkeyPressed)
        #expect(app.model.phase == .hidden)
        #expect(!app.model.isToolbarVisible)
        #expect(app.model.annotations.map(\.comment) == ["一つ目"])
        // 出し直すと同じ回を続け、画像の番号も続ける。
        await app.send(.hotkeyPressed)
        #expect(app.model.phase == .drawing)
        #expect(app.sessionDirectory == session)
        await app.annotate("二つ目", rect: TestApp.secondRect)
        #expect(app.model.annotations.map(\.comment) == ["一つ目", "二つ目"])
        #expect(app.model.annotations.map { URL(filePath: $0.imagePath).lastPathComponent } == ["01.png", "02.png"])
        // 一覧を開いていてもホットキーで隠す。
        await app.send(.listToggled)
        await app.send(.hotkeyPressed)
        #expect(app.model.phase == .hidden)
        await app.send(.hotkeyPressed)
        await app.send(.copyPromptTapped)
        #expect(app.pasteboardText()?.contains("01.png") == true)
        #expect(app.pasteboardText()?.contains("02.png") == true)
    }

    @Test
    func dismissForSettingsKeepsAnnotations() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("一つ目", rect: TestApp.firstRect)
        await app.send(.dragEnded(rect: TestApp.secondRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        let draft = try #require(app.model.draft)
        await app.send(.dismissRequested)
        #expect(app.model.phase == .hidden)
        #expect(app.model.annotations.map(\.comment) == ["一つ目"])
        #expect(!FileManager.default.fileExists(atPath: draft.imagePath))
    }

    @Test
    func languageAndBoilerplateChangeThePrompt() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        await app.annotate("コメント", rect: TestApp.firstRect)
        let path = app.model.annotations[0].imagePath
        var settings = app.model.settings
        settings.language = .ja
        await app.send(.settingsChanged(settings))
        await app.send(.copyPromptTapped)
        #expect(app.pasteboardText() == Boilerplate.japanese + "\n\n" + path + "\nコメント")
        await app.send(.hotkeyPressed)
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        await app.send(.commentConfirmed(text: "二回目"))
        let secondPath = app.model.annotations[0].imagePath
        settings = app.model.settings
        settings.language = .en
        settings.setBoilerplate("Fix these, please.", for: .en)
        await app.send(.settingsChanged(settings))
        await app.send(.copyPromptTapped)
        #expect(app.pasteboardText() == "Fix these, please.\n\n" + secondPath + "\n二回目")
        // 日本語の定型文は既定のまま。
        #expect(app.model.settings.boilerplate(for: .ja) == Boilerplate.japanese)
        // 定型文を空にすると、「パス → コメント」の並びだけになる（DECISIONS.md A7）。
        await app.annotate("三回目", rect: TestApp.firstRect)
        let thirdPath = app.model.annotations[0].imagePath
        settings = app.model.settings
        settings.setBoilerplate("", for: .en)
        await app.send(.settingsChanged(settings))
        await app.send(.copyPromptTapped)
        #expect(app.pasteboardText() == thirdPath + "\n三回目")
    }

    @Test
    func startupCleanupRemovesSessionsOlderThanRetention() async throws {
        let old = sessionID(for: TestApp.now.addingTimeInterval(-5 * 86_400))
        let recent = sessionID(for: TestApp.now.addingTimeInterval(-1 * 86_400))
        let seed = TestApp.setupDone({
            var patch = LaunchSeed.SettingsPatch()
            patch.imageRetentionDays = 3
            return patch
        }())
        let app = try await TestApp.make(seed: seed) { directory in
            for id in [old, recent] {
                let folder = directory.appending(path: "images/\(id)", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data("png".utf8).write(to: folder.appending(path: "01.png"))
            }
        }
        defer { app.cleanUp() }
        let folders = try FileManager.default.contentsOfDirectory(atPath: app.imagesDirectory.path(percentEncoded: false))
        #expect(folders == [recent])
        #expect(app.model.settings.imageRetentionDays == 3)
        #expect(app.environment.startupCleanupError == nil)
    }

    @Test
    func startupCleanupUsesDefaultSevenDays() async throws {
        let five = sessionID(for: TestApp.now.addingTimeInterval(-5 * 86_400))
        let eight = sessionID(for: TestApp.now.addingTimeInterval(-8 * 86_400))
        let app = try await TestApp.make(seed: TestApp.setupDone()) { directory in
            for id in [five, eight] {
                let folder = directory.appending(path: "images/\(id)", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
        }
        defer { app.cleanUp() }
        let folders = try FileManager.default.contentsOfDirectory(atPath: app.imagesDirectory.path(percentEncoded: false))
        #expect(folders == [five])
    }

    @Test
    func emptyCopyDoesNotTouchPasteboard() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        app.putOnPasteboard("前の文章")
        await app.send(.hotkeyPressed)
        await app.send(.copyPromptTapped)
        #expect(app.model.phase == .drawing)
        #expect(app.model.lastCopiedCount == 0)
        #expect(app.pasteboardText() == "前の文章")
    }

    @Test
    func frameWithoutWindowStaysDrawing() async throws {
        let app = try await TestApp.make(seed: LaunchSeed(settings: TestApp.setupDone().settings, windows: []))
        defer { app.cleanUp() }
        await app.send(.hotkeyPressed)
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        #expect(app.model.phase == .drawing)
        #expect(app.model.lastFailure == .noWindowUnderFrame)
        #expect(app.imageFiles().isEmpty)
    }
}
