import AppKit
import Testing
import AkapenCore
import AkapenUI

@MainActor private final class Store: SettingsStore {
    func load() throws -> Settings {
        Settings()
    }

    func save(_ settings: Settings) throws {}
}

@Test
@MainActor
func panelsFollowState() throws {
    _ = NSApplication.shared
    let model = try SessionModel(settingsStore: Store())
    let windows = SessionWindows(model: model)
    defer { windows.hide() }
    windows.render()
    #expect(!windows.toolbar.isVisible)
    #expect(!windows.drawing.isVisible)
    model.send(.hotkeyPressed)
    windows.render()
    #expect(windows.toolbar.isVisible)
    #expect(windows.drawing.isVisible)
    #expect(windows.toolbar.styleMask.contains(.nonactivatingPanel))
    let rect = ScreenRect(x: 10, y: 20, width: 30, height: 40)
    model.send(.dragEnded(rect: rect, screen: ScreenDescriptor(id: 1, frame: rect)))
    windows.render()
    #expect(windows.toolbar.isVisible)
    #expect(!windows.drawing.isVisible)
}

@Test
@MainActor
func coordinateConversion() {
    let converted = ScreenCoordinates.rect(NSRect(x: -100, y: 50, width: 20, height: 40), primaryTop: 900)
    #expect(converted == ScreenRect(x: -100, y: 810, width: 20, height: 40))
}
