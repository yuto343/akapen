import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit
import AkapenCore

/// ScreenCaptureKit でウィンドウを列挙し、ディスプレイの範囲を、画面に見えているとおりに撮る。
///
/// 座標は Quartz と同じ「画面全体を通した、左上が原点」の pt。
@MainActor public final class ScreenCaptureKitCapturer: WindowCapturing {
    /// 撮影で起きるエラー。
    public enum CaptureError: Error, Equatable {
        /// 画面収録の許可がない。
        case permissionDenied
        /// 撮る時点で、そのディスプレイがつながっていなかった。
        case displayNotFound(UInt32)
        /// 撮る範囲の大きさが 0。
        case emptyRegion
    }

    /// 撮る範囲を決めるウィンドウの最小の幅と高さ（pt）。
    public static let minimumWindowSize: Double = 40

    /// 除くプロセス（akapen 自身）。
    private let excludedProcessID: pid_t

    /// 直前の `windows()` で取ったディスプレイ。`capture(region:on:)` は、ここから撮る（`SCShareableContent` を取り直さない）。
    private var listedDisplays: [CGDirectDisplayID: SCDisplay] = [:]

    /// 撮影から外す akapen 自身のアプリ。一度見つけたら使い回す。
    private var ownApplication: SCRunningApplication?

    /// akapen 自身のウィンドウを除いて列挙し、akapen 自身を写さずに撮る。
    public init() {
        excludedProcessID = ProcessInfo.processInfo.processIdentifier
    }

    /// 画面に出ている通常のウィンドウ（レイヤー 0）を、手前から順に返す。
    ///
    /// akapen 自身のもの、どの画面にも重ならないもの、幅か高さが 40pt 未満のものは除く。
    /// `SCShareableContent` は前後の順を保証しないので、`CGWindowListCopyWindowInfo` の並びで整える。
    /// あわせて、続く撮影に使うディスプレイと akapen 自身のアプリを覚えておく。
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
        remember(content)
        if ownApplication == nil {
            // akapen が画面にウィンドウを出していないと、上の一覧には載らない。撮影を待たせないよう、ここで探しておく。
            ownApplication = try? await Self.findApplication(processID: excludedProcessID)
        }
        return candidates.sorted { $0.rank < $1.rank }.map(\.window)
    }

    /// ディスプレイの中の範囲を、画面に見えているとおりに 1 枚撮る。
    ///
    /// ディスプレイ全体から akapen 自身のアプリだけを外した絞り込みで、範囲を `sourceRect` に指定して 1 回撮る。
    /// 大きさはディスプレイの実解像度（Retina なら範囲の 2 倍）。カーソルは写さない。
    /// ほかのウィンドウの影と、デスクトップの壁紙は、画面に見えているとおりに写る。
    public func capture(region: ScreenRect, on display: ScreenDescriptor) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }
        let target = try await shareableDisplay(id: display.id)
        if ownApplication == nil {
            ownApplication = try? await Self.findApplication(processID: excludedProcessID)
        }
        let filter = SCContentFilter(
            display: target,
            excludingApplications: ownApplication.map { [$0] } ?? [],
            exceptingWindows: []
        )
        let scale = Double(filter.pointPixelScale)
        // `sourceRect` は、そのディスプレイの左上を原点にした pt。
        let source = CGRect(
            x: region.x - target.frame.minX,
            y: region.y - target.frame.minY,
            width: region.width,
            height: region.height
        ).intersection(CGRect(origin: .zero, size: target.frame.size))
        guard !source.isNull, source.width > 0, source.height > 0 else {
            throw CaptureError.emptyRegion
        }
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = source
        configuration.width = max(1, Int((source.width * scale).rounded()))
        configuration.height = max(1, Int((source.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw Self.translate(error)
        }
    }

    /// 取った画面の情報から、ディスプレイと akapen 自身のアプリを覚える。
    private func remember(_ content: SCShareableContent) {
        var displays: [CGDirectDisplayID: SCDisplay] = [:]
        for display in content.displays {
            displays[display.displayID] = display
        }
        listedDisplays = displays
        if let own = content.applications.first(where: { $0.processID == excludedProcessID }) {
            ownApplication = own
        }
    }

    /// 撮るディスプレイの `SCDisplay`。直前の一覧にあればそれを使い、なければ一覧を取り直して探す。
    private func shareableDisplay(id: UInt32) async throws -> SCDisplay {
        if let listed = listedDisplays[id] {
            return listed
        }
        let content = try await Self.shareableContent()
        remember(content)
        guard let found = listedDisplays[id] else {
            throw CaptureError.displayNotFound(id)
        }
        return found
    }

    /// 画面にウィンドウを出していないアプリも含めた一覧から、そのプロセスのアプリを探す（100ms ほど）。
    private static func findApplication(processID: pid_t) async throws -> SCRunningApplication? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        return content.applications.first { $0.processID == processID }
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
