import Foundation
import AkapenCore

/// state.json v1 の中身。矩形は共通左上原点のポイント。
/// `{schemaVersion:1, phase, annotations:[{id,imagePath,comment,rect,sourceAppName,createdAt,windowFrame}],
/// settings, lastDrawnRect:{x,y,width,height}|null, isToolbarVisible, lastCopiedCount}`。
/// 日付は ISO 8601 の文字列。Optional の矩形も null として出力する。
public struct SessionSnapshot: Encodable {
    public let schemaVersion = 1
    public let phase: Phase
    public let annotations: [Annotation]
    public let settings: Settings
    public let lastDrawnRect: ScreenRect?
    public let isToolbarVisible: Bool
    public let lastCopiedCount: Int

    @MainActor public init(model: SessionModel) {
        phase = model.phase
        annotations = model.annotations
        settings = model.settings
        lastDrawnRect = model.lastDrawnRect
        isToolbarVisible = model.isToolbarVisible
        lastCopiedCount = model.lastCopiedCount
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case phase
        case annotations
        case settings
        case lastDrawnRect
        case isToolbarVisible
        case lastCopiedCount
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(phase, forKey: .phase)
        try container.encode(annotations, forKey: .annotations)
        try container.encode(settings, forKey: .settings)
        try container.encode(lastDrawnRect, forKey: .lastDrawnRect)
        try container.encode(isToolbarVisible, forKey: .isToolbarVisible)
        try container.encode(lastCopiedCount, forKey: .lastCopiedCount)
    }
}
