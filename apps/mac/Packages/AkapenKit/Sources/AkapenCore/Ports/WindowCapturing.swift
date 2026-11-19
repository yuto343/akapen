import CoreGraphics
import Foundation

/// ウィンドウの列挙と、画面の範囲の撮影。OS エラーは throws で呼び出し側へ返す。
@MainActor public protocol WindowCapturing {
    /// 自分のオーバーレイを除く、画面に出ているウィンドウを、手前にあるものから順に列挙する。撮る範囲を決めるのに使う。
    ///
    /// 実装は、ここで取った画面の情報（ディスプレイなど）を覚えておき、続く `capture(region:on:)` で使ってよい（取り直さない）。
    func windows() async throws -> [CaptureWindow]

    /// ディスプレイの中の範囲を、画面に見えているとおりに 1 枚撮った画像を返す。
    ///
    /// - Parameters:
    ///   - region: 撮る範囲（画面全体の座標、pt）。`display` の中にある前提。
    ///   - display: 撮るディスプレイ。
    ///
    /// akapen 自身のウィンドウとカーソルは写さない。デスクトップの壁紙は写す。
    /// 画像の大きさは「範囲の大きさ × ディスプレイの倍率」（px）。
    /// PNG への書き出しと赤枠の描き込みは呼び出し側の責務。
    func capture(region: ScreenRect, on display: ScreenDescriptor) async throws -> CGImage
}
