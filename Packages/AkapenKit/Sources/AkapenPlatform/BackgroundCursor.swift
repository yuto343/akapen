import CoreFoundation
import Darwin

/// アクティブでないアプリ（akapen）のカーソルの変更を、効くようにする。
///
/// akapen はメニューバーに常駐するアプリで、パネルはアクティブ化しない（撮影対象のウィンドウのタイトルバーの見た目を変えないため）。
/// macOS は、アクティブでないアプリの `NSCursor.set()` とカーソル矩形を無視する。そのままでは、枠を描く面を出しても、
/// マウスを動かして追跡領域が動きを受けるまで十字のカーソルにならない（出した直後に十字にならないことがある不具合の原因）。
///
/// ウィンドウサーバーへの接続に `SetsCursorInBackground` を立てると、アクティブでないままカーソルを変えられる。
/// 公開されていない関数（`CGSSetConnectionProperty`）を、名前で探して呼ぶ。見つからなければ何もしない
/// （そのときも、マウスを動かせば追跡領域が十字にする）。
public enum BackgroundCursor {
    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    /// 許可を取る。効いたら true。何度呼んでもよい。
    @discardableResult
    public static func enable() -> Bool {
        guard let handle = dlopen(nil, RTLD_NOW) else {
            return false
        }
        defer {
            dlclose(handle)
        }
        guard let connectionSymbol = dlsym(handle, "_CGSDefaultConnection"),
              let setSymbol = dlsym(handle, "CGSSetConnectionProperty") else {
            return false
        }
        let connection = unsafeBitCast(connectionSymbol, to: DefaultConnection.self)()
        let setProperty = unsafeBitCast(setSymbol, to: SetConnectionProperty.self)
        let status = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        return status == 0
    }
}
