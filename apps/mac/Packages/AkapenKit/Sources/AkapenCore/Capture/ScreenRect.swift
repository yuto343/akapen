/// 全ディスプレイ共通の左上原点（主画面の左上 = 0,0）、単位はポイント。
/// 左・上に配置された画面では負数を許す。ピクセル倍率は含めない。
public struct ScreenRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    /// 幅と高さは非負の矩形を渡す。
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
