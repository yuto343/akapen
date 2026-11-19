/// 表示装置の識別子と、共通の左上原点によるフレーム。
public struct ScreenDescriptor: Codable, Equatable, Sendable {
    public var id: UInt32
    public var frame: ScreenRect

    /// id は CGDirectDisplayID と対応する。
    public init(id: UInt32, frame: ScreenRect) {
        self.id = id
        self.frame = frame
    }
}
