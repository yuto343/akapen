import Foundation

/// 撮影候補。frame は全画面共通の左上原点、ポイント単位。
public struct CaptureWindow: Sendable, Equatable {
    public let id: UInt32
    public let frame: ScreenRect
    /// OS のウィンドウ ID と、ポイント単位の矩形から候補を作る。
    public init(id: UInt32, frame: ScreenRect) { self.id = id; self.frame = frame }
}
/// ウィンドウ列挙と PNG 撮影。OS エラーは throws で呼び出し側へ返す。
@MainActor public protocol WindowCapturing {
    /// 自分のオーバーレイを除く撮影可能な候補を列挙する。
    func windows() async throws -> [CaptureWindow]
    /// 指定ウィンドウ全体の PNG を返す。赤枠の描き込みは呼び出し側の責務。
    func capture(window: CaptureWindow) async throws -> Data
}
/// プロンプトと任意の画像ファイルをコピーする。
@MainActor public protocol PromptPasteboard {
    /// テキストと添付画像 URL を同じコピー操作で置き換える。画像不要なら空配列。
    func write(text: String, imageURLs: [URL]) throws
}
/// 設定の読み書き。未保存なら既定値を返す。
@MainActor public protocol SettingsStore {
    /// 未保存なら Settings()。壊れた保存内容や I/O エラーは throws。
    func load() throws -> Settings
    /// 設定全体を置き換える。
    func save(_ settings: Settings) throws
}
/// PNG の保存と削除。before より古い回の画像を掃除する。
@MainActor public protocol ImageStore {
    /// 同じ回の index 番目（1 始まり）に保存し、絶対 URL を返す。
    func save(png: Data, sessionID: String, index: Int) throws -> URL
    /// 未確定注釈などの画像を削除する。
    func remove(at url: URL) throws
    /// 指定日時より古い回のフォルダを削除する。
    func removeSessions(before date: Date) throws
}
/// グローバル入力の登録。再登録は以前の登録を置き換え、失敗は throws。
@MainActor public protocol HotkeyRegistering {
    /// 既存登録を解除して登録する。handler はメインアクターで呼ぶ。
    func register(_ shortcut: KeyboardShortcut, handler: @escaping @MainActor () -> Void) throws
    /// 登録とハンドラーを解放する。未登録時も安全に呼べる。
    func unregister()
}
/// 画面収録の事前確認と OS の許可要求。
@MainActor public protocol ScreenRecordingPermission {
    var isGranted: Bool { get }
    /// OS の許可要求を行い、現時点の許可状態を返す。
    func request() -> Bool
}
/// ログイン起動の照会と切り替え。
@MainActor public protocol LoginItem {
    var isEnabled: Bool { get }
    /// ログイン時の起動設定を変更する。OS の失敗は throws。
    func setEnabled(_ enabled: Bool) throws
}
/// 時刻と待機。テストでは固定時刻と制御可能な待機を差す。
@MainActor public protocol Clock {
    var now: Date { get }
    /// キャンセル可能な待機。固定時計の実装ではテスト側が進行を制御する。
    func sleep(for duration: Duration) async throws
}
/// 状態などの診断データの原子的な保存。実ファイル操作は Platform が担う。
@MainActor public protocol StateWriting {
    /// 読者から途中の内容が見えないように全体を原子的に置き換える。
    func write(_ data: Data) throws
}
