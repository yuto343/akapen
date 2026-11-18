import Foundation
import Testing
import AkapenApp
import AkapenCore

/// `state.json`（v3）の中身。spec の「アプリの状態で、〜」が確かめる項目が、各状態で入っていること。
@MainActor
@Suite
struct StateFileTests {
    @Test
    func writtenOnlyAfterStartAndOnEveryChange() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone(annotations: [
            LaunchSeed.Annotation(comment: "seed", rect: TestApp.firstRect),
        ]))
        defer { app.cleanUp() }
        // 前提づくり（seed の注釈）の途中は書き出さない。書き出しが始まった時点で起動が済んでいる。
        #expect(!app.hasStateFile)
        app.environment.startWritingState()
        var state = try app.stateJSON()
        #expect(state["schemaVersion"] as? Int == 3)
        #expect(state["phase"] as? String == "hidden")
        #expect((state["annotations"] as? [Any])?.count == 1)
        await app.send(.hotkeyPressed)
        state = try app.stateJSON()
        #expect(state["phase"] as? String == "drawing")
        #expect(app.environment.stateWriteError == nil)
    }

    @Test
    func hiddenStateAtLaunch() async throws {
        let app = try await TestApp.make()
        defer { app.cleanUp() }
        app.environment.startWritingState()
        let state = try app.stateJSON()
        #expect(state["phase"] as? String == "hidden")
        #expect(state["isToolbarVisible"] as? Bool == false)
        #expect((state["annotations"] as? [Any])?.isEmpty == true)
        #expect(state["draft"] is NSNull)
        #expect(state["lastDrawnRect"] is NSNull)
        #expect(state["lastCopiedCount"] as? Int == 0)
        #expect(state["lastFailure"] is NSNull)
        let settings = try #require(state["settings"] as? [String: Any])
        #expect(settings["language"] as? String == "en")
        #expect(settings["confirmKey"] as? String == "enter")
        #expect(settings["imageRetentionDays"] as? Int == 7)
        #expect(settings["setupCompleted"] as? Bool == false)
        #expect(settings.keys.contains("toolbarShortcut") == false)
        let hotkey = try #require(settings["hotkey"] as? [String: Any])
        #expect(hotkey["keyCode"] as? Int == 22)
        #expect(hotkey["modifiers"] as? Int == 3)
        let boilerplates = try #require(settings["boilerplates"] as? [String: String])
        #expect(boilerplates == ["en": Boilerplate.english, "ja": Boilerplate.japanese])
        let storage = try #require(state["storage"] as? [String: Any])
        #expect(storage["imagesDirectory"] as? String == app.imagesDirectory.path(percentEncoded: false))
        #expect(storage["sessionID"] is NSNull)
        #expect(storage["sessionDirectory"] is NSNull)
        let windows = try #require(state["windows"] as? [String: Any])
        #expect(windows["settings"] as? Bool == false)
        #expect(windows["setup"] as? Bool == false)
        #expect(windows["setupPage"] is NSNull)
        #expect(windows["quitConfirm"] as? Bool == false)
        let hotkeys = try #require(state["hotkeys"] as? [String: Any])
        #expect(hotkeys["draw"] is NSNull)
        #expect(hotkeys.keys.contains("toolbar") == false)
        #expect(hotkeys["suspended"] as? Bool == false)
        #expect((hotkeys["failed"] as? [Any])?.isEmpty == true)
    }

    @Test
    func drawingAndCommentingState() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        app.environment.startWritingState()
        await app.send(.hotkeyPressed)
        var state = try app.stateJSON()
        #expect(state["phase"] as? String == "drawing")
        #expect(state["isToolbarVisible"] as? Bool == true)
        let storage = try #require(state["storage"] as? [String: Any])
        let session = try #require(app.sessionDirectory)
        #expect(storage["sessionID"] as? String == sessionID(for: TestApp.now))
        #expect(storage["sessionDirectory"] as? String == session.path(percentEncoded: false))
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        state = try app.stateJSON()
        #expect(state["phase"] as? String == "commenting")
        let draft = try #require(state["draft"] as? [String: Any])
        #expect(draft["imagePath"] as? String == session.appending(path: "01.png").path(percentEncoded: false))
        #expect(draft["comment"] as? String == "")
        #expect(draft["sourceAppName"] as? String == "Sample App")
        #expect(draft["createdAt"] as? String == TestApp.nowText)
        let windowFrame = try #require(draft["windowFrame"] as? [String: Double])
        #expect(windowFrame == ["x": 140, "y": 64, "width": 1000, "height": 660])
        let rect = try #require(state["lastDrawnRect"] as? [String: Double])
        #expect(rect == ["x": TestApp.firstRect.x, "y": TestApp.firstRect.y, "width": TestApp.firstRect.width, "height": TestApp.firstRect.height])
        #expect((state["annotations"] as? [Any])?.isEmpty == true)
    }

    @Test
    func drawingListHiddenAndCopiedState() async throws {
        let app = try await TestApp.make(seed: TestApp.setupDone())
        defer { app.cleanUp() }
        app.environment.startWritingState()
        await app.annotate("一つ目", rect: TestApp.firstRect)
        await app.annotate("二つ目", rect: TestApp.secondRect)
        var state = try app.stateJSON()
        #expect(state["phase"] as? String == "drawing")
        #expect(state["draft"] is NSNull)
        let annotations = try #require(state["annotations"] as? [[String: Any]])
        #expect(annotations.compactMap { $0["comment"] as? String } == ["一つ目", "二つ目"])
        #expect(annotations.compactMap { $0["imagePath"] as? String } == app.model.annotations.map(\.imagePath))
        #expect(annotations.compactMap { $0["id"] as? String } == app.model.annotations.map(\.id.uuidString))
        await app.send(.listToggled)
        state = try app.stateJSON()
        #expect(state["phase"] as? String == "listOpen")
        await app.send(.hotkeyPressed)
        state = try app.stateJSON()
        #expect(state["phase"] as? String == "hidden")
        #expect(state["isToolbarVisible"] as? Bool == false)
        #expect((state["annotations"] as? [Any])?.count == 2)
        await app.send(.hotkeyPressed)
        await app.send(.copyPromptTapped)
        state = try app.stateJSON()
        #expect(state["phase"] as? String == "copied")
        #expect(state["lastCopiedCount"] as? Int == 2)
        #expect(state["isToolbarVisible"] as? Bool == false)
        #expect((state["annotations"] as? [Any])?.isEmpty == true)
    }

    @Test
    func failureAndSettingsState() async throws {
        let app = try await TestApp.make(seed: LaunchSeed(settings: TestApp.setupDone().settings, windows: []))
        defer { app.cleanUp() }
        app.environment.startWritingState()
        await app.send(.hotkeyPressed)
        await app.send(.dragEnded(rect: TestApp.firstRect, screen: ScreenDescriptor(id: 1, frame: TestApp.window)))
        var state = try app.stateJSON()
        #expect(state["phase"] as? String == "drawing")
        #expect(state["lastFailure"] as? String == "noWindowUnderFrame")
        var settings = app.model.settings
        settings.language = .ja
        settings.confirmKey = .commandEnter
        settings.setBoilerplate("書き換えた", for: .ja)
        await app.send(.settingsChanged(settings))
        state = try app.stateJSON()
        let values = try #require(state["settings"] as? [String: Any])
        #expect(values["language"] as? String == "ja")
        #expect(values["confirmKey"] as? String == "commandEnter")
        #expect(values["boilerplates"] as? [String: String] == ["en": Boilerplate.english, "ja": "書き換えた"])
        // 次の入力が成功したら、失敗は消える。
        await app.send(.escapePressed)
        state = try app.stateJSON()
        #expect(state["lastFailure"] is NSNull)
        #expect(state["phase"] as? String == "hidden")
    }

    @Test
    func windowStatusComesFromScreens() async throws {
        let app = try await TestApp.make()
        defer { app.cleanUp() }
        app.environment.windowStatus = {
            SessionSnapshot.Windows(settings: true, setup: true, setupPage: .permission, quitConfirm: true)
        }
        app.environment.startWritingState()
        let windows = try #require(try app.stateJSON()["windows"] as? [String: Any])
        #expect(windows["settings"] as? Bool == true)
        #expect(windows["setup"] as? Bool == true)
        #expect(windows["setupPage"] as? String == "permission")
        #expect(windows["quitConfirm"] as? Bool == true)
    }
}
