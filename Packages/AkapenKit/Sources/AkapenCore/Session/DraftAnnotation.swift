import Foundation

/// 書きかけの注釈。枠を描き終えた時点で作り、撮影と保存が終わると画像のパス・アプリ名・撮った範囲が入る。
///
/// コメントは持たない（確定すると `Annotation` になって一覧に入る）。
public struct DraftAnnotation: Identifiable, Equatable, Sendable, Encodable {
    public var id: UUID
    /// 描いた枠。ScreenRect と同じ全画面共通の座標。
    public var rect: ScreenRect
    /// 枠を描き終えた時刻（撮影を始めた時刻）。
    public var createdAt: Date
    /// 保存した画像の絶対パス。撮影と保存が終わるまで nil。
    public var imagePath: String?
    /// 枠内に見えていたウィンドウのアプリ名（`Annotation.sourceAppName` と同じ）。撮影と保存が終わるまで nil。
    public var sourceAppName: String?
    /// 撮った範囲（`Annotation.windowFrame` と同じ）。撮影と保存が終わるまで nil。
    public var windowFrame: ScreenRect?

    /// 撮影と保存が終わっていない書きかけを作る。
    public init(
        id: UUID = UUID(),
        rect: ScreenRect,
        createdAt: Date,
        imagePath: String? = nil,
        sourceAppName: String? = nil,
        windowFrame: ScreenRect? = nil
    ) {
        self.id = id
        self.rect = rect
        self.createdAt = createdAt
        self.imagePath = imagePath
        self.sourceAppName = sourceAppName
        self.windowFrame = windowFrame
    }

    /// 撮影と保存が終わっているか（画像のパスがあるか）。
    public var isCaptured: Bool {
        imagePath != nil
    }

    /// コメントを付けた、確定済みの注釈。撮影と保存が終わっていなければ nil。
    public func annotation(comment: String) -> Annotation? {
        guard let imagePath, let sourceAppName, let windowFrame else {
            return nil
        }
        return Annotation(
            id: id,
            imagePath: imagePath,
            comment: comment,
            rect: rect,
            sourceAppName: sourceAppName,
            createdAt: createdAt,
            windowFrame: windowFrame
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rect
        case createdAt
        case imagePath
        case sourceAppName
        case windowFrame
    }

    /// 値がないものも `null` として書く（キーを省かない。`state.json` の決まり）。
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(rect, forKey: .rect)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(sourceAppName, forKey: .sourceAppName)
        try container.encode(windowFrame, forKey: .windowFrame)
    }
}
