import AkapenCore
import Foundation
import Testing
import AkapenPlatform

@MainActor
struct SettingsStoreTests {
    private func changedSettings() -> Settings {
        var settings = Settings()
        settings.language = .ja
        settings.hotkey = KeyboardShortcut(keyCode: 12, modifiers: [.command, .shift])
        settings.confirmKey = .commandEnter
        settings.setBoilerplate("書き換えた定型文", for: .ja)
        settings.imageRetentionDays = 3
        settings.setupCompleted = true
        settings.setupAwaitingPermission = true
        return settings
    }

    /// テスト専用のスイートを作り、終わったら消す。
    private func withSuite(_ body: (UserDefaults) throws -> Void) throws {
        let name = "akapen.platform-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer {
            defaults.removePersistentDomain(forName: name)
        }
        try body(defaults)
    }

    @Test
    func userDefaultsRoundTrip() throws {
        try withSuite { defaults in
            let store = UserDefaultsSettingsStore(defaults: defaults)
            #expect(try store.load() == Settings())
            try store.save(changedSettings())
            #expect(try store.load() == changedSettings())
            #expect(try UserDefaultsSettingsStore(defaults: defaults).load() == changedSettings())
            #expect(defaults.data(forKey: UserDefaultsSettingsStore.key) != nil)
        }
    }

    @Test
    func userDefaultsRejectsBrokenContent() throws {
        try withSuite { defaults in
            let store = UserDefaultsSettingsStore(defaults: defaults)
            defaults.set(Data("{not json".utf8), forKey: UserDefaultsSettingsStore.key)
            #expect(throws: SettingsStoreError.self) {
                try store.load()
            }
            defaults.set("text", forKey: UserDefaultsSettingsStore.key)
            #expect(throws: SettingsStoreError.self) {
                try store.load()
            }
            defaults.set(Data(#"{"language":"fr"}"#.utf8), forKey: UserDefaultsSettingsStore.key)
            #expect(throws: SettingsStoreError.self) {
                try store.load()
            }
        }
    }

    @Test
    func fileRoundTrip() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let url = temporary.child("nested/settings.json")
        let store = FileSettingsStore(url: url)
        #expect(try store.load() == Settings())
        try store.save(changedSettings())
        #expect(try store.load() == changedSettings())
        #expect(try FileSettingsStore(url: url).load() == changedSettings())
        try store.save(Settings())
        #expect(try store.load() == Settings())
    }

    @Test
    func fileReadsPartialContentWithDefaults() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let url = temporary.child("settings.json")
        try Data(#"{"language":"ja","setupCompleted":true}"#.utf8).write(to: url)
        var expected = Settings()
        expected.language = .ja
        expected.setupCompleted = true
        #expect(try FileSettingsStore(url: url).load() == expected)
    }

    @Test
    func fileRejectsBrokenContent() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let url = temporary.child("settings.json")
        try Data("{not json".utf8).write(to: url)
        #expect(throws: SettingsStoreError.self) {
            try FileSettingsStore(url: url).load()
        }
    }
}
