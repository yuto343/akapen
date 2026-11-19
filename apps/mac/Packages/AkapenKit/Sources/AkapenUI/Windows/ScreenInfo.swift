import AppKit
import AkapenCore

/// 画面 1 枚の位置。座標は画面全体を通した左上原点（`ScreenRect` と同じ）。
public struct ScreenInfo: Equatable, Sendable {
    /// `CGDirectDisplayID` に当たる識別子。
    public var id: UInt32
    /// 画面全体。
    public var frame: ScreenRect
    /// メニューバーと Dock を除いた範囲。
    public var visibleFrame: ScreenRect

    /// 値をそのまま持つ。
    public init(id: UInt32, frame: ScreenRect, visibleFrame: ScreenRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    /// `SessionEvent.dragEnded` に渡す画面の値。
    public var descriptor: ScreenDescriptor {
        ScreenDescriptor(id: id, frame: frame)
    }

    /// 点がある画面。どの画面にもないときは先頭（主画面）。
    static func containing(_ point: CGPoint, in screens: [ScreenInfo]) -> ScreenInfo? {
        screens.first { $0.frame.containsPoint(point) } ?? screens.first
    }
}

/// 画面の一覧とカーソルの位置。テストでは決まった値を返す偽物に差し替える。
@MainActor protocol ScreenProviding {
    /// いまつながっている画面。先頭が主画面。
    var screens: [ScreenInfo] { get }

    /// カーソルの位置（画面全体を通した左上原点）。
    var mouseLocation: CGPoint { get }

    /// 主画面の上端（AppKit の座標）。左下原点と左上原点の変換に使う。
    var primaryTop: CGFloat { get }
}

/// 実際の画面（`NSScreen`）。
@MainActor struct SystemScreens: ScreenProviding {
    var screens: [ScreenInfo] {
        let top = primaryTop
        return NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return ScreenInfo(
                id: number?.uint32Value ?? 0,
                frame: ScreenCoordinates.rect(screen.frame, primaryTop: top),
                visibleFrame: ScreenCoordinates.rect(screen.visibleFrame, primaryTop: top)
            )
        }
    }

    var mouseLocation: CGPoint {
        ScreenCoordinates.point(NSEvent.mouseLocation, primaryTop: primaryTop)
    }

    var primaryTop: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }
}
