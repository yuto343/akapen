import Foundation
import Testing
import AkapenPlatform

@Test
@MainActor
func atomicReplacement() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("state.json")
    let writer = AtomicStateWriter(url: url)
    try writer.write(Data("old".utf8))
    try writer.write(Data("new".utf8))
    #expect(try String(contentsOf: url, encoding: .utf8) == "new")
    #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["state.json"])
}
