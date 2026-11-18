import Foundation

/// 保存済みの注釈。rect は ScreenRect と同じ全画面共通の座標。
public struct Annotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var imagePath: String
    public var comment: String
    public var rect: ScreenRect
    /// 枠内に見えていたウィンドウのアプリ名。見えている面積の大きい順に `, ` でつなぐ。ウィンドウがなければ空文字。
    public var sourceAppName: String
    /// 撮影した時刻。
    public var createdAt: Date
    /// 撮った範囲（画像全体に当たる矩形。画面全体の座標）。画像のどこに赤枠があるかを割り出すのに使う。
    ///
    /// 名前は、ウィンドウ 1 つを撮っていたころのまま（state.json や E2E のキーと揃えるため）。
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
