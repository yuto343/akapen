import Foundation
import Testing
import AkapenCore

@MainActor private final class Store: SettingsStore {
    func load() throws -> Settings {
        Settings()
    }

    func save(_ settings: Settings) throws {}
}

@Test
@MainActor
func drawingAndEscape() async throws {
    let model = try SessionModel(settingsStore: Store())
    await model.send(.hotkeyPressed).value
    #expect(model.phase == .drawing)
    await model.send(.escapePressed).value
    #expect(model.phase == .hidden)
    model.send(.addTapped)
    let rect = ScreenRect(x: -30, y: 20, width: 50, height: 70)
    model.send(.dragEnded(rect: rect, screen: ScreenDescriptor(id: 1, frame: rect)))
    #expect(model.phase == .idle)
    #expect(model.lastDrawnRect == rect)
    model.send(.escapePressed)
    #expect(model.phase == .idle)
}

@Test
@MainActor
func contractDefaults() throws {
    let model = try SessionModel(settingsStore: Store())
    #expect(!model.isToolbarVisible)
    #expect(model.lastCopiedCount == 0)
    #expect(model.lastFailure == nil)
    #expect(!model.settings.setupCompleted)
    model.send(.hotkeyPressed)
    #expect(model.isToolbarVisible)
}

@Test
func settingsDecodeWithoutSetupCompleted() throws {
    let json = Data(#"{"language":"ja","imageRetentionDays":3}"#.utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: json)
    #expect(settings.language == .ja)
    #expect(settings.imageRetentionDays == 3)
    #expect(!settings.setupCompleted)
}
