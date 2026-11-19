import CoreGraphics
import Foundation
import AkapenCore

/// 決まったウィンドウの一覧と、単色の画像を返す偽の撮影。
///
/// `hold()` を呼ぶと、次の撮影は `release()` されるまで終わらない（撮影の途中に入力を送るテスト用）。
/// `holdListing()` を呼ぶと、次の一覧の取得は `releaseListing()` されるまで終わらない。
@MainActor final class FakeCapturer: WindowCapturing {
    var windowList: [CaptureWindow]
    var windowsError: TestError?
    var captureError: TestError?
    /// 撮影した画像の倍率（px/pt）。
    var pixelsPerPoint = 2.0
    private(set) var windowsCalls = 0
    /// 撮った範囲と、そのディスプレイ（撮った順）。
    private(set) var capturedRegions: [(region: ScreenRect, display: ScreenDescriptor)] = []
    private var isHeld = false
    private var heldContinuations: [CheckedContinuation<Void, Never>] = []
    private var captureStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var isListingHeld = false
    private var heldListingContinuations: [CheckedContinuation<Void, Never>] = []

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
        // 呼ばれた時点の設定で答える（取得の途中で一覧を変えても、返すのは呼ばれた時点のもの）。
        let list = windowList
        let error = windowsError
        if isListingHeld {
            await withCheckedContinuation { continuation in
                heldListingContinuations.append(continuation)
            }
        }
        if let error {
            throw error
        }
        return list
    }

    func capture(region: ScreenRect, on display: ScreenDescriptor) async throws -> CGImage {
        capturedRegions.append((region, display))
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
        return TestImages.solidImage(
            width: Int(region.width * pixelsPerPoint),
            height: Int(region.height * pixelsPerPoint),
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

    /// 次からの一覧の取得を、`releaseListing()` まで止める。
    func holdListing() {
        isListingHeld = true
    }

    /// 止めている一覧の取得を進める。
    func releaseListing() {
        isListingHeld = false
        let continuations = heldListingContinuations
        heldListingContinuations = []
        for continuation in continuations {
            continuation.resume()
        }
    }

    /// 撮影が始まるまで待つ。すでに始まっていればすぐに戻る。
    func waitUntilCaptureStarts() async {
        if !capturedRegions.isEmpty {
            return
        }
        await withCheckedContinuation { continuation in
            captureStartedWaiters.append(continuation)
        }
    }
}
