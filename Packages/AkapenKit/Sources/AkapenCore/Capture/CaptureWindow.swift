/// 撮影候補。frame は全画面共通の左上原点、ポイント単位。
public struct CaptureWindow: Sendable, Equatable {
    public let id: UInt32
    public let frame: ScreenRect
    /// そのウィンドウを持つアプリの表示名。
    public let appName: String
    /// ウィンドウのタイトル。取れないときは nil。
    public let title: String?

    /// OS のウィンドウ ID と、ポイント単位の矩形から候補を作る。
    public init(id: UInt32, frame: ScreenRect, appName: String, title: String? = nil) {
        self.id = id
        self.frame = frame
        self.appName = appName
        self.title = title
    }
}
