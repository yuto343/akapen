import Foundation
import Testing
import AkapenApp
import AkapenCore
@Test @MainActor func writesEveryTransitionOnlyInE2E() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let normal = try AppEnvironment.make(LaunchConfiguration(environment: ["AKAPEN_STATE_DIR": dir.path]))
    normal.model.send(.hotkeyPressed)
    #expect(!FileManager.default.fileExists(atPath: dir.path))
    let environment = try AppEnvironment.make(LaunchConfiguration(environment: ["AKAPEN_E2E":"1", "AKAPEN_STATE_DIR":dir.path]))
    environment.model.send(.hotkeyPressed)
    let data = try Data(contentsOf: dir.appendingPathComponent("state.json"))
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["phase"] as? String == "drawing")
    #expect(json["lastDrawnRect"] is NSNull)
    let settings = try #require(json["settings"] as? [String: Any])
    let hotkey = try #require(settings["hotkey"] as? [String: Any])
    #expect(hotkey["modifiers"] as? Int == 1)
    #expect(environment.stateWriteError == nil)
}
@Test func parsesConfiguration() {
    let c = LaunchConfiguration(environment: ["AKAPEN_CAPTURE":"live", "AKAPEN_PASTEBOARD":"test", "AKAPEN_SEED":"{}", "AKAPEN_NOW":"2026-11-18T00:00:00Z"])
    #expect(c.capture == .live); #expect(c.pasteboardName == "test"); #expect(c.seedJSON == "{}"); #expect(c.now != nil)
    #expect(!c.isE2E)
}
