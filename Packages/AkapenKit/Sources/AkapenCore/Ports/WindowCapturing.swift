import Foundation

/// ウィンドウ列挙と PNG 撮影。OS エラーは throws で呼び出し側へ返す。
@MainActor public protocol WindowCapturing {
    /// 自分のオーバーレイを除く撮影可能な候補を、手前にあるウィンドウから順に列挙する。
    func windows() async throws -> [CaptureWindow]

    /// 指定ウィンドウ全体の PNG を返す。赤枠の描き込みは呼び出し側の責務。
    func capture(window: CaptureWindow) async throws -> Data
}
