import Foundation
import Testing
import AkapenApp
import AkapenCore
import AkapenPlatform

/// `AKAPEN_SEED` の解釈（一部だけの指定、注釈つきの開始、壊れた内容）。
@MainActor
@Suite
struct SeedTests {
    // MARK: - 設定

    @Test
    func partialSettingsKeepOtherValues() async throws {
        let seed = try LaunchSeed.parse(#"{"settings": {"language": "ja", "setupCompleted": true}}"#)
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        let settings = app.model.settings
        #expect(settings.language == .ja)
        #expect(settings.setupCompleted)
        #expect(settings.hotkey == KeyboardShortcut())
        #expect(settings.confirmKey == .enter)
        #expect(settings.imageRetentionDays == 7)
        #expect(settings.boilerplate(for: .en) == Boilerplate.english)
        // 保存もされている（起動し直しても同じ値）。
        #expect(try FileSettingsStore(url: app.directory.appending(path: "settings.json")).load() == settings)
    }

    @Test
    func seedSettingsAreLaidOverStoredSettings() async throws {
        var stored = Settings()
        stored.confirmKey = .commandEnter
        stored.setupCompleted = true
        let seed = try LaunchSeed.parse(#"{"settings": {"boilerplates": {"en": "Look at these."}, "imageRetentionDays": 3}}"#)
        let app = try await TestApp.make(seed: seed) { directory in
            try FileSettingsStore(url: directory.appending(path: "settings.json")).save(stored)
        }
        defer { app.cleanUp() }
        let settings = app.model.settings
        #expect(settings.confirmKey == .commandEnter)
        #expect(settings.setupCompleted)
        #expect(settings.imageRetentionDays == 3)
        #expect(settings.boilerplate(for: .en) == "Look at these.")
        #expect(settings.boilerplate(for: .ja) == Boilerplate.japanese)
    }

    @Test
    func removedToolbarShortcutIsRejected() {
        // ボタン類の表示切り替えのショートカットはなくなった。書いた seed は書き間違いと同じく起動エラーにする。
        #expect(throws: LaunchSeed.ParseError.self) {
            try LaunchSeed.parse(#"{"settings": {"toolbarShortcut": null}}"#)
        }
    }

    @Test
    func oldSettingsFileWithToolbarShortcutStillLoads() async throws {
        let app = try await TestApp.make(seed: LaunchSeed()) { directory in
            let json = #"{"language":"ja","toolbarShortcut":{"keyCode":11,"modifiers":3},"setupCompleted":true}"#
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(json.utf8).write(to: directory.appending(path: "settings.json"))
        }
        defer { app.cleanUp() }
        #expect(app.model.settings.language == .ja)
        #expect(app.model.settings.setupCompleted)
    }

    @Test(arguments: [(0, 1), (366, 365), (-3, 1), (30, 30)])
    func seedRetentionDaysAreClamped(days: Int, expected: Int) async throws {
        let seed = try LaunchSeed.parse(#"{"settings": {"imageRetentionDays": \#(days)}}"#)
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        #expect(app.model.settings.imageRetentionDays == expected)
    }

    @Test
    func seedRoundTripsThroughJSON() throws {
        var patch = LaunchSeed.SettingsPatch()
        patch.language = .ja
        patch.boilerplates = ["en": "Hello"]
        let seed = LaunchSeed(
            settings: patch,
            screenRecording: .denied,
            windows: [LaunchSeed.Window(frame: ScreenRect(x: 1, y: 2, width: 300, height: 200), appName: "App")],
            annotations: [LaunchSeed.Annotation(comment: "c", rect: ScreenRect(x: 10, y: 10, width: 20, height: 20))],
            open: .list
        )
        #expect(try LaunchSeed.parse(seed.json()) == seed)
    }

    // MARK: - 許可とウィンドウ

    @Test
    func deniedScreenRecordingMakesCaptureFail() async throws {
        let seed = try LaunchSeed.parse(#"{"settings": {"setupCompleted": true}, "screenRecording": "denied"}"#)
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        #expect(!app.environment.permission.isGranted)
        await app.send(.hotkeyPressed)
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: TestApp.screen))
        #expect(app.model.phase == .drawing)
        #expect(app.model.lastFailure == .captureFailed)
        #expect(app.imageFiles().isEmpty)
    }

    @Test
    func windowsDefaultToSampleTarget() throws {
        let windows = LaunchSeed().fixtureWindows
        #expect(windows.count == 1)
        #expect(windows.first?.frame == TestApp.window)
        #expect(windows.first?.appName == "Sample App")
    }

    // MARK: - 注釈

    @Test
    func annotationsAreMadeThroughCapture() async throws {
        let seed = TestApp.setupDone(annotations: [
            LaunchSeed.Annotation(comment: "一つ目", rect: TestApp.firstRect),
            LaunchSeed.Annotation(comment: "二つ目\n二行目", rect: TestApp.secondRect),
        ])
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        // 作り終えたら隠す。注釈は残っている。
        #expect(app.model.phase == .hidden)
        #expect(!app.model.isToolbarVisible)
        #expect(app.model.draft == nil)
        #expect(app.model.annotations.map(\.comment) == ["一つ目", "二つ目\n二行目"])
        #expect(app.model.annotations.map(\.sourceAppName) == ["Sample App", "Sample App"])
        #expect(app.model.annotations.map(\.rect) == [TestApp.firstRect, TestApp.secondRect])
        let session = try #require(app.sessionDirectory)
        #expect(app.model.annotations.map(\.imagePath) == [
            session.appending(path: "01.png").path(percentEncoded: false),
            session.appending(path: "02.png").path(percentEncoded: false),
        ])
        for annotation in app.model.annotations {
            let image = try #require(SavedImage(url: URL(filePath: annotation.imagePath)))
            let expected = image.expectedRedFrame(drawn: annotation.rect, window: TestApp.window)
            #expect(rectsMatch(image.redFrameInWindow(TestApp.window), expected, tolerance: 1.5))
        }
        // 次の枠は、seed の画像を上書きしない番号で保存する。
        await app.annotate("三つ目", rect: TestApp.firstRect)
        #expect(app.model.annotations.last?.imagePath == session.appending(path: "03.png").path(percentEncoded: false))
    }

    @Test
    func annotationOutsideWindowsCapturesAroundFrame() async throws {
        // ウィンドウと重ならない枠でも、枠のまわりを撮って注釈になる（起動エラーにしない）。
        let rect = ScreenRect(x: 5000, y: 5000, width: 40, height: 40)
        let app = try await TestApp.make(seed: TestApp.setupDone(annotations: [
            LaunchSeed.Annotation(comment: "外", rect: rect),
        ]))
        defer { app.cleanUp() }
        let annotation = try #require(app.model.annotations.first)
        #expect(annotation.comment == "外")
        #expect(annotation.windowFrame == ScreenRect(x: 4800, y: 4800, width: 440, height: 440))
        #expect(annotation.sourceAppName == "")
    }

    @Test
    func annotationWithEmptyCommentFails() async throws {
        let seed = TestApp.setupDone(annotations: [
            LaunchSeed.Annotation(comment: "ok", rect: TestApp.firstRect),
            LaunchSeed.Annotation(comment: " \n ", rect: TestApp.secondRect),
        ])
        await #expect(throws: AppEnvironment.StartupError.seedAnnotationFailed(1, "コメントが空")) {
            let app = try await TestApp.make(seed: seed)
            app.cleanUp()
        }
    }

    @Test
    func tinyAnnotationFails() async throws {
        let seed = TestApp.setupDone(annotations: [
            LaunchSeed.Annotation(comment: "小さい", rect: ScreenRect(x: 500, y: 300, width: 2, height: 2)),
        ])
        await #expect(throws: AppEnvironment.StartupError.seedAnnotationFailed(0, "枠が小さすぎる")) {
            let app = try await TestApp.make(seed: seed)
            app.cleanUp()
        }
    }

    // MARK: - 起動後に出しておくもの

    @Test
    func openToolbarWithoutAnnotations() async throws {
        let seed = try LaunchSeed.parse(#"{"settings": {"setupCompleted": true}, "open": "toolbar"}"#)
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        #expect(app.model.phase == .drawing)
        #expect(app.model.isToolbarVisible)
        #expect(app.model.annotations.isEmpty)
    }

    @Test
    func openListWithAnnotations() async throws {
        var seed = TestApp.setupDone(annotations: [
            LaunchSeed.Annotation(comment: "一つ目", rect: TestApp.firstRect),
            LaunchSeed.Annotation(comment: "二つ目", rect: TestApp.secondRect),
        ])
        seed.open = .list
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        #expect(app.model.phase == .listOpen)
        #expect(app.model.isToolbarVisible)
        #expect(app.model.annotations.map(\.comment) == ["一つ目", "二つ目"])
    }

    @Test
    func openListWithoutAnnotations() async throws {
        var seed = TestApp.setupDone()
        seed.open = .list
        let app = try await TestApp.make(seed: seed)
        defer { app.cleanUp() }
        #expect(app.model.phase == .listOpen)
        #expect(app.model.annotations.isEmpty)
    }

    // MARK: - 壊れた内容

    @Test(arguments: [
        "{",
        "[]",
        #"{"setings": {}}"#,
        #"{"settings": {"langauge": "ja"}}"#,
        #"{"settings": {"language": "fr"}}"#,
        #"{"settings": {"confirmKey": "space"}}"#,
        #"{"settings": {"imageRetentionDays": "7"}}"#,
        #"{"settings": {"boilerplates": {"de": "Hallo"}}}"#,
        #"{"screenRecording": "maybe"}"#,
        #"{"windows": [{"frame": {"x": 0, "y": 0, "width": 10, "height": 10}}]}"#,
        #"{"annotations": [{"comment": "c"}]}"#,
        #"{"annotations": [{"comment": "c", "rect": {"x": 0, "y": 0, "width": 10, "height": 10}, "window": 0}]}"#,
        #"{"open": "settings"}"#,
    ])
    func brokenSeedIsRejected(json: String) {
        #expect(throws: LaunchSeed.ParseError.self) {
            try LaunchSeed.parse(json)
        }
    }

    @Test
    func brokenSeedStopsStartup() async throws {
        let directory = TestApp.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var variables = TestApp.variables(directory: directory, pasteboardName: "akapen-test-" + UUID().uuidString)
        variables["AKAPEN_SEED"] = #"{"settings": {"langauge": "ja"}}"#
        do {
            _ = try await AppEnvironment.make(LaunchConfiguration(environment: variables))
            Issue.record("起動エラーにならなかった")
        } catch let AppEnvironment.StartupError.invalidSeed(reason) {
            #expect(reason.contains("langauge"))
        }
        // 設定は書き換えていない。
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "settings.json").path(percentEncoded: false)))
    }
}
