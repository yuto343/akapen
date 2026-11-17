import AppKit
import AkapenCore

/// AppKit の左下原点と Core の共通左上原点の変換境界。
@MainActor public enum ScreenCoordinates {
    /// AppKit の矩形を、Core の左上原点の矩形にする。
    public static func rect(_ rect: NSRect, primaryTop: CGFloat) -> ScreenRect {
        ScreenRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Core の左上原点の矩形を、AppKit の矩形にする。
    public static func nsRect(_ rect: ScreenRect, primaryTop: CGFloat) -> NSRect {
        NSRect(x: rect.x, y: primaryTop - rect.y - rect.height, width: rect.width, height: rect.height)
    }

    /// AppKit の点を、Core の左上原点の点にする。
    public static func point(_ point: NSPoint, primaryTop: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryTop - point.y)
    }
}
