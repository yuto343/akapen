import Foundation

/// 保存済みの注釈。rect は ScreenRect と同じ全画面共通の座標。
public struct Annotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var imagePath: String
    public var comment: String
    public var rect: ScreenRect
    /// 撮影したウィンドウのアプリ名。
    public var sourceAppName: String
    /// 撮影した時刻。
    public var createdAt: Date
    /// 撮影した時点の、そのウィンドウの矩形。画像のどこに赤枠があるかを割り出すのに使う。
    public var windowFrame: ScreenRect

    /// imagePath は画像ファイルの絶対パス。
    public init(
        id: UUID = UUID(),
        imagePath: String,
        comment: String,
        rect: ScreenRect,
        sourceAppName: String,
        createdAt: Date,
        windowFrame: ScreenRect
    ) {
        self.id = id
        self.imagePath = imagePath
        self.comment = comment
        self.rect = rect
        self.sourceAppName = sourceAppName
        self.createdAt = createdAt
        self.windowFrame = windowFrame
    }
}
