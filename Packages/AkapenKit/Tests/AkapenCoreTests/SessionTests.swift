import Testing
import AkapenCore
@MainActor private final class Store: SettingsStore {
    func load() throws -> Settings { Settings() }
    func save(_ settings: Settings) throws {}
}
@Test @MainActor func drawingAndEscape() throws {
    let model = try SessionModel(settingsStore: Store())
    model.send(.hotkeyPressed); #expect(model.phase == .drawing)
    model.send(.escapePressed); #expect(model.phase == .hidden)
    model.send(.addTapped)
    let rect = ScreenRect(x: -30, y: 20, width: 50, height: 70)
    model.send(.dragEnded(rect: rect, screen: ScreenDescriptor(id: 1, frame: rect)))
    #expect(model.phase == .idle); #expect(model.lastDrawnRect == rect)
    model.send(.escapePressed); #expect(model.phase == .idle)
}
