import Foundation
import AkapenCore

/// 決まったウィンドウの一覧と、単色の画像を返す偽の撮影。
///
/// `hold()` を呼ぶと、次の撮影は `release()` されるまで終わらない（撮影の途中に入力を送るテスト用）。
@MainActor final class FakeCapturer: WindowCapturing {
    var windowList: [CaptureWindow]
    var windowsError: TestError?
    var captureError: TestError?
    /// 設定すると、撮影の結果としてこのデータを返す（壊れた PNG を渡すテスト用）。
    var pngOverride: Data?
    /// 撮影した画像の倍率（px/pt）。
    var pixelsPerPoint = 2.0
    private(set) var windowsCalls = 0
    private(set) var capturedWindows: [CaptureWindow] = []
    private var isHeld = false
    private var heldContinuations: [CheckedContinuation<Void, Never>] = []
    private var captureStartedWaiters: [CheckedContinuation<Void, Never>] = []

    init(windows: [CaptureWindow] = [FakeCapturer.sampleWindow]) {
        windowList = windows
    }

    static let sampleWindow = CaptureWindow(
        id: 7,
        frame: ScreenRect(x: 100, y: 50, width: 400, height: 300),
        appName: "Sample App",
        title: "Sample"
    )

    func windows() async throws -> [CaptureWindow] {
        windowsCalls += 1
        if let windowsError {
            throw windowsError
        }
        return windowList
    }

    func capture(window: CaptureWindow) async throws -> Data {
        capturedWindows.append(window)
        let waiters = captureStartedWaiters
        captureStartedWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
        if isHeld {
            await withCheckedContinuation { continuation in
                heldContinuations.append(continuation)
            }
        }
        if let captureError {
            throw captureError
        }
        if let pngOverride {
            return pngOverride
        }
        return TestImages.solidPNG(
            width: Int(window.frame.width * pixelsPerPoint),
            height: Int(window.frame.height * pixelsPerPoint),
            color: TestImages.blue
        )
    }

    /// 次からの撮影を、`release()` まで止める。
    func hold() {
        isHeld = true
    }

    /// 止めている撮影を進める。
    func release() {
        isHeld = false
        let continuations = heldContinuations
        heldContinuations = []
        for continuation in continuations {
            continuation.resume()
        }
    }

    /// 撮影が始まるまで待つ。すでに始まっていればすぐに戻る。
    func waitUntilCaptureStarts() async {
        if !capturedWindows.isEmpty {
            return
        }
        await withCheckedContinuation { continuation in
            captureStartedWaiters.append(continuation)
        }
    }
}
