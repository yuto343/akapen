import AppKit
import CoreGraphics
import AkapenCore

/// 実際の画面収録の許可。`CGPreflightScreenCaptureAccess` と `CGRequestScreenCaptureAccess` を包む。
@MainActor public final class SystemScreenRecordingPermission: ScreenRecordingPermission {
    /// システム設定の「画面収録とシステムオーディオ録音」を開く URL。新しい形から順に試す。
    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
    ]

    public init() {}

    public var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func openSystemSettings() {
        for text in Self.settingsURLs {
            guard let url = URL(string: text) else {
                continue
            }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
