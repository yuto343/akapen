import Foundation
import AkapenCore

/// 画面収録の許可がないときは撮影を断る `WindowCapturing`。
///
/// E2E の偽の撮影（`FixtureCapturer`）を、本物の撮影（`ScreenCaptureKitCapturer`。許可がなければ失敗する）と同じく、
/// 許可の有無（`AKAPEN_SEED` の `screenRecording`）に従わせるために包む。OS には触らない。
@MainActor public final class PermissionCheckedCapturer: WindowCapturing {
    /// 許可がないときのエラー。
    public enum CaptureError: Error, Equatable {
        case permissionDenied
    }

    private let base: any WindowCapturing
    private let permission: any ScreenRecordingPermission

    /// 包む撮影と、確かめる許可を渡す。
    public init(base: any WindowCapturing, permission: any ScreenRecordingPermission) {
        self.base = base
        self.permission = permission
    }

    public func windows() async throws -> [CaptureWindow] {
        guard permission.isGranted else {
            throw CaptureError.permissionDenied
        }
        return try await base.windows()
    }

    public func capture(window: CaptureWindow) async throws -> Data {
        guard permission.isGranted else {
            throw CaptureError.permissionDenied
        }
        return try await base.capture(window: window)
    }
}
