import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit
import AkapenCore

/// ScreenCaptureKit でウィンドウを列挙し、1 枚ずつ撮る。
///
/// 座標は Quartz と同じ「画面全体を通した、左上が原点」の pt。
@MainActor public final class ScreenCaptureKitCapturer: WindowCapturing {
    /// 撮影で起きるエラー。
    public enum CaptureError: Error, Equatable {
        /// 画面収録の許可がない。
        case permissionDenied
        /// 撮る時点で、そのウィンドウが画面になかった。
        case windowNotFound(UInt32)
        /// 撮った画像を PNG にできなかった。
        case encodingFailed
    }

    /// 撮影の候補にするウィンドウの最小の幅と高さ（pt）。
    public static let minimumWindowSize: Double = 40

    /// 除くプロセス（akapen 自身）。
    private let excludedProcessID: pid_t

    /// akapen 自身のウィンドウを除いて列挙する。
    public init() {
        excludedProcessID = ProcessInfo.processInfo.processIdentifier
    }

    /// 画面に出ている通常のウィンドウ（レイヤー 0）を、手前から順に返す。
    ///
    /// akapen 自身のもの、どの画面にも重ならないもの、幅か高さが 40pt 未満のものは除く。
    /// `SCShareableContent` は前後の順を保証しないので、`CGWindowListCopyWindowInfo` の並びで整える。
    public func windows() async throws -> [CaptureWindow] {
        let content = try await Self.shareableContent()
        let order = Self.frontToBackOrder()
        let displays = content.displays.map(\.frame)
        var candidates: [(rank: Int, window: CaptureWindow)] = []
        for window in content.windows {
            guard let rank = order[window.windowID],
                  window.windowLayer == 0,
                  window.isOnScreen,
                  window.owningApplication?.processID != excludedProcessID,
                  window.frame.width >= Self.minimumWindowSize,
                  window.frame.height >= Self.minimumWindowSize,
                  displays.contains(where: { $0.intersects(window.frame) }) else {
                continue
            }
            let candidate = CaptureWindow(
                id: window.windowID,
                frame: ScreenRect(
                    x: window.frame.minX,
                    y: window.frame.minY,
                    width: window.frame.width,
                    height: window.frame.height
                ),
                appName: Self.appName(of: window),
                title: window.title
            )
            candidates.append((rank, candidate))
        }
        return candidates.sorted { $0.rank < $1.rank }.map(\.window)
    }

    /// そのウィンドウだけを、ディスプレイの実解像度で撮って PNG を返す。カーソルと影は写さない。
    public func capture(window: CaptureWindow) async throws -> Data {
        let content = try await Self.shareableContent()
        guard let target = content.windows.first(where: { $0.windowID == window.id }), target.isOnScreen else {
            throw CaptureError.windowNotFound(window.id)
        }
        let filter = SCContentFilter(desktopIndependentWindow: target)
        let scale = Double(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((target.frame.width * scale).rounded()))
        configuration.height = max(1, Int((target.frame.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.captureResolution = .best
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw Self.translate(error)
        }
        do {
            return try PNGEncoding.encode(image)
        } catch {
            throw CaptureError.encodingFailed
        }
    }

    private static func shareableContent() async throws -> SCShareableContent {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }
        do {
            return try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        } catch {
            throw translate(error)
        }
    }

    /// 許可がないことを表すエラーは `permissionDenied` にそろえる。それ以外はそのまま返す。
    private static func translate(_ error: any Error) -> any Error {
        if let streamError = error as? SCStreamError, streamError.code == .userDeclined {
            return CaptureError.permissionDenied
        }
        return error
    }

    /// ウィンドウ番号ごとの、手前からの順位（0 が最も手前）。
    private static func frontToBackOrder() -> [CGWindowID: Int] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }
        var order: [CGWindowID: Int] = [:]
        for (rank, info) in list.enumerated() {
            guard let number = info[kCGWindowNumber as String] as? NSNumber else {
                continue
            }
            order[number.uint32Value] = rank
        }
        return order
    }

    /// 持ち主のアプリの表示名。取れなければ空文字。
    private static func appName(of window: SCWindow) -> String {
        guard let application = window.owningApplication else {
            return ""
        }
        if !application.applicationName.isEmpty {
            return application.applicationName
        }
        return NSRunningApplication(processIdentifier: application.processID)?.localizedName ?? ""
    }
}
