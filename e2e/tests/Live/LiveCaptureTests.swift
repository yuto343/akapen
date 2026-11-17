import XCTest
import AkapenAXID

/// 実際の画面収録（ScreenCaptureKit）で SampleTarget を撮る確認。`make e2e-live` で走らせる（手元だけ）。
///
/// akapen に画面収録の許可が要る。許可がなければ撮影に失敗し、akapen はセットアップの 2 ページ目（許可の案内）を開く。
/// そのときは、失敗の理由（`lastFailure`）を出して落ちる。
final class LiveCaptureTests: AkapenUITestCase {
    /// SampleTarget のウィンドウ全体が写り、描いた枠の位置に赤枠が入る。
    func testCaptureSampleWindow() throws {
        XCTAssertEqual(ProcessInfo.processInfo.environment["AKAPEN_CAPTURE"], "live", "make e2e-live で走らせる")
        launch(.setupDone)
        startDrawing()
        let drawn = drawFrame(around: AXID.Sample.button)
        let state = waitForState("撮影が終わる（コメントを書く状態になるか、失敗する）", timeout: 15) { state in
            state.phase == .commenting || state.lastFailure != nil || state.windows.setup
        }
        XCTAssertFalse(
            state.windows.setup,
            "撮影に失敗し、セットアップの \(state.windows.setupPage?.rawValue ?? "?") ページが開いた（akapen に画面収録の許可がない）"
        )
        XCTAssertNil(state.lastFailure, "撮影に失敗した: \(state.lastFailure ?? "")")
        XCTAssertEqual(state.phase, .commenting)
        let draft = try XCTUnwrap(state.draft)
        XCTAssertEqual(draft.windowFrame.cgRect, sampleElement(AXID.Sample.window).frame)
        let image = try XCTUnwrap(savedImage(at: draft.imagePath))
        // 実際の画面の倍率（Retina なら 2 倍）で撮ったうえで、長辺の上限（1568px）に収まるように縮む。
        XCTAssertLessThanOrEqual(max(image.pixelWidth, image.pixelHeight), 1568)
        assertImage(at: draft.imagePath, showsFrame: drawn, window: draft.windowFrame.cgRect)
        pressEscape()
        waitForPhase(.hidden)
    }
}
