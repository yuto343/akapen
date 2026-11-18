import Foundation
import Testing
import AkapenCore

private let rect = ScreenRect(x: 150, y: 100, width: 100, height: 50)
private let window = ScreenRect(x: 100, y: 50, width: 400, height: 300)
private let createdAt = Date(timeIntervalSince1970: 1_794_979_930)

@Test
func draftBeforeCaptureHasNoAnnotation() {
    let draft = DraftAnnotation(rect: rect, createdAt: createdAt)
    #expect(!draft.isCaptured)
    #expect(draft.annotation(comment: "x") == nil)
}

@Test
func capturedDraftBecomesAnnotation() throws {
    let draft = DraftAnnotation(
        rect: rect,
        createdAt: createdAt,
        imagePath: "/cache/01.png",
        sourceAppName: "Sample App",
        windowFrame: window
    )
    #expect(draft.isCaptured)
    let annotation = try #require(draft.annotation(comment: "余白"))
    #expect(annotation == Annotation(
        id: draft.id,
        imagePath: "/cache/01.png",
        comment: "余白",
        rect: rect,
        sourceAppName: "Sample App",
        createdAt: createdAt,
        windowFrame: window
    ))
}

@Test
func draftEncodingKeepsNullKeys() throws {
    let draft = DraftAnnotation(rect: rect, createdAt: createdAt)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let object = try JSONSerialization.jsonObject(with: encoder.encode(draft)) as? [String: Any]
    let json = try #require(object)
    #expect(Set(json.keys) == ["id", "rect", "createdAt", "imagePath", "sourceAppName", "windowFrame"])
    #expect(json["imagePath"] is NSNull)
    #expect(json["sourceAppName"] is NSNull)
    #expect(json["windowFrame"] is NSNull)
    #expect(json["createdAt"] as? String == "2026-11-18T05:32:10Z")
}
