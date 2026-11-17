import AppKit
import AkapenCore

/// AppKit の左下原点と Core の共通左上原点の変換境界。
@MainActor public enum ScreenCoordinates {
    public static func rect(_ rect: NSRect, primaryTop: CGFloat) -> ScreenRect {
        ScreenRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }
}
