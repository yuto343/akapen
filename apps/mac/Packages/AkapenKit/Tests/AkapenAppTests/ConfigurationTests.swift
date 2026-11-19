import Foundation
import Testing
import AkapenApp
import AkapenCore
import AkapenPlatform

/// 環境変数ごとに選ばれる実装。本番の組み立ては実際の UserDefaults に触るので、ここでは `choose` の値だけを見る。
@MainActor
@Suite
struct ConfigurationTests {
    private let directory = URL(filePath: "/tmp/akapen-config-test", directoryHint: .isDirectory)

    private var e2e: [String: String] {
        [
            "AKAPEN_E2E": "1",
            "AKAPEN_STATE_DIR": directory.path(percentEncoded: false),
            "AKAPEN_PASTEBOARD": "akapen-config-test",
        ]
    }

    @Test
    func productionUsesRealImplementations() throws {
        let choice = try AppEnvironment.choose(LaunchConfiguration(environment: [:]))
        #expect(choice.settings == .userDefaults)
        #expect(choice.imagesDirectory == FileImageStore.defaultRoot())
        #expect(choice.imagesDirectory.path(percentEncoded: false).hasSuffix("/Library/Caches/akapen/"))
        #expect(choice.pasteboard == .general)
        #expect(choice.capture == .screenCaptureKit)
        #expect(choice.clock == .system)
        #expect(choice.loginItem == .system)
        #expect(choice.stateFile == nil)
        #expect(choice.startupErrorFile == nil)
    }

    @Test
    func productionIgnoresTestVariables() throws {
        let configuration = LaunchConfiguration(environment: [
            "AKAPEN_STATE_DIR": "/tmp/x",
            "AKAPEN_PASTEBOARD": "x",
            "AKAPEN_CAPTURE": "nonsense",
            "AKAPEN_SEED": "{",
            "AKAPEN_NOW": "yesterday",
        ])
        #expect(!configuration.isE2E)
        #expect(configuration.problems.isEmpty)
        #expect(configuration.seedJSON == nil)
        #expect(configuration.now == nil)
        let choice = try AppEnvironment.choose(configuration)
        #expect(choice.settings == .userDefaults)
        #expect(choice.pasteboard == .general)
        #expect(choice.stateFile == nil)
        #expect(LaunchConfiguration(environment: ["AKAPEN_E2E": "0"]).isE2E == false)
    }

    @Test
    func e2eKeepsEverythingInStateDirectory() throws {
        var variables = e2e
        variables["AKAPEN_NOW"] = "2026-11-18T05:32:10Z"
        let choice = try AppEnvironment.choose(LaunchConfiguration(environment: variables))
        #expect(choice.settings == .file(directory.appending(path: "settings.json")))
        #expect(choice.imagesDirectory == directory.appending(path: "images", directoryHint: .isDirectory))
        #expect(choice.pasteboard == .named("akapen-config-test"))
        #expect(choice.capture == .fixture)
        #expect(choice.clock == .fixed(Date(timeIntervalSince1970: 1_794_979_930)))
        #expect(choice.loginItem == .noop)
        #expect(choice.stateFile == directory.appending(path: "state.json"))
        #expect(choice.startupErrorFile == directory.appending(path: "startup-error.txt"))
        // ユーザーの設定・キャッシュ・一般のクリップボード・ログイン項目を選ぶ経路がない。
        #expect(choice.settings != .userDefaults)
        #expect(choice.imagesDirectory != FileImageStore.defaultRoot())
        #expect(choice.pasteboard != .general)
        #expect(choice.loginItem != .system)
    }

    @Test
    func e2eClockAndCapture() throws {
        #expect(try AppEnvironment.choose(LaunchConfiguration(environment: e2e)).clock == .system)
        var live = e2e
        live["AKAPEN_CAPTURE"] = "live"
        #expect(try AppEnvironment.choose(LaunchConfiguration(environment: live)).capture == .screenCaptureKit)
        var fixture = e2e
        fixture["AKAPEN_CAPTURE"] = "fixture"
        #expect(try AppEnvironment.choose(LaunchConfiguration(environment: fixture)).capture == .fixture)
        var fractional = e2e
        fractional["AKAPEN_NOW"] = "2026-11-18T05:32:10.500Z"
        #expect(LaunchConfiguration(environment: fractional).now == Date(timeIntervalSince1970: 1_794_979_930.5))
    }

    @Test(arguments: [
        ("AKAPEN_STATE_DIR", nil, LaunchConfiguration.Problem.missingStateDirectory),
        ("AKAPEN_STATE_DIR", "", LaunchConfiguration.Problem.missingStateDirectory),
        ("AKAPEN_STATE_DIR", "relative/dir", LaunchConfiguration.Problem.relativeStateDirectory("relative/dir")),
        ("AKAPEN_PASTEBOARD", nil, LaunchConfiguration.Problem.missingPasteboardName),
        ("AKAPEN_PASTEBOARD", "", LaunchConfiguration.Problem.missingPasteboardName),
        ("AKAPEN_CAPTURE", "camera", LaunchConfiguration.Problem.invalidCapture("camera")),
        ("AKAPEN_NOW", "yesterday", LaunchConfiguration.Problem.invalidNow("yesterday")),
        ("AKAPEN_E2E", "true", LaunchConfiguration.Problem.invalidE2EFlag("true")),
    ] as [(String, String?, LaunchConfiguration.Problem)])
    func e2eWithMissingOrInvalidVariableFails(name: String, value: String?, problem: LaunchConfiguration.Problem) throws {
        var variables = e2e
        variables[name] = value
        let configuration = LaunchConfiguration(environment: variables)
        // 読めない値があっても、本番の依存には落とさない。
        #expect(configuration.isE2E)
        #expect(configuration.problems == [problem])
        #expect(throws: AppEnvironment.StartupError.invalidConfiguration([problem])) {
            try AppEnvironment.choose(configuration)
        }
    }

    @Test
    func e2eBuildsTestImplementations() async throws {
        let app = try await TestApp.make()
        defer { app.cleanUp() }
        let environment = app.environment
        #expect(environment.settingsStore is FileSettingsStore)
        #expect((environment.images as? FileImageStore)?.root == app.imagesDirectory)
        #expect(environment.pasteboard is SystemPromptPasteboard)
        #expect(environment.capturer is PermissionCheckedCapturer)
        #expect((environment.clock as? FixedClock)?.now == TestApp.now)
        #expect(environment.permission is FixedScreenRecordingPermission)
        #expect(environment.permission.isGranted)
        #expect(environment.loginItem is NoopLoginItem)
        #expect(environment.choice.pasteboard == .named(app.pasteboardName))
    }

    @Test
    func startupFailureIsWrittenForE2E() throws {
        let directory = TestApp.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = LaunchConfiguration(environment: [
            "AKAPEN_E2E": "1",
            "AKAPEN_STATE_DIR": directory.path(percentEncoded: false),
        ])
        do {
            _ = try AppEnvironment.choose(configuration)
            Issue.record("起動エラーにならなかった")
        } catch {
            AppEnvironment.reportStartupFailure(error, configuration: configuration)
        }
        let text = try String(contentsOf: directory.appending(path: "startup-error.txt"), encoding: .utf8)
        #expect(text.contains("missingPasteboardName"))
    }

    @Test
    func quitConfirmationCountsDraft() {
        #expect(QuitPolicy.pendingCount(annotationCount: 0, hasDraft: false) == 0)
        #expect(QuitPolicy.pendingCount(annotationCount: 0, hasDraft: true) == 1)
        #expect(QuitPolicy.pendingCount(annotationCount: 2, hasDraft: false) == 2)
        #expect(QuitPolicy.pendingCount(annotationCount: 2, hasDraft: true) == 3)
    }

    @Test
    func quitConfirmationCountsFromModel() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        #expect(QuitPolicy.pendingCount(app.model) == 0)
        await app.annotate("一つ目", rect: TestApp.firstRect)
        #expect(QuitPolicy.pendingCount(app.model) == 1)
        // 隠しても注釈は残るので、件数は変わらない。
        await app.send(.hotkeyPressed)
        #expect(app.model.phase == .hidden)
        #expect(QuitPolicy.pendingCount(app.model) == 1)
        await app.send(.hotkeyPressed)
        await app.send(.dragEnded(rect: TestApp.secondRect, screen: TestApp.screen))
        #expect(QuitPolicy.pendingCount(app.model) == 2)
    }
}
