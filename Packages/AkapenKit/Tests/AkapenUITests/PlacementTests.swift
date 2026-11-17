import CoreGraphics
import Testing
import AkapenCore
@testable import AkapenUI

/// 置き場所の計算。Paper の App 01〜04 の絵（1280×800、上 28pt がメニューバー）の位置と合うことと、画面の端・負の座標での振る舞い。
@Suite
struct PlacementTests {
    let visible = ScreenRect(x: 0, y: 28, width: 1280, height: 772)
    /// 主画面の左上にある副画面の `visibleFrame`（原点が負の座標）。
    let secondaryVisible = ScreenRect(x: -1440, y: -75, width: 1440, height: 875)

    @Test
    func toolbarIsCenteredSixteenAboveVisibleBottom() {
        let rect = PanelPlacement.bottomCenter(size: CGSize(width: 300, height: 48), visibleFrame: visible)
        #expect(rect == ScreenRect(x: 490, y: 736, width: 300, height: 48))
    }

    @Test
    func toolbarUsesVisibleFrameAboveDock() {
        let withDock = ScreenRect(x: 0, y: 28, width: 1280, height: 702)
        let rect = PanelPlacement.bottomCenter(size: CGSize(width: 300, height: 48), visibleFrame: withDock)
        #expect(rect.y + rect.height == 730 - 16)
    }

    @Test
    func toastMatchesPaper() {
        let rect = PanelPlacement.bottomCenter(size: CGSize(width: 460, height: 68), visibleFrame: visible)
        #expect(rect == ScreenRect(x: 410, y: 716, width: 460, height: 68))
    }

    @Test
    func hintIsCenteredBelowMenuBar() {
        let rect = PanelPlacement.hint(size: CGSize(width: 229, height: 34), visibleFrame: visible)
        #expect(rect == ScreenRect(x: 525.5, y: 44, width: 229, height: 34))
    }

    @Test
    func listSitsTwelveAboveToolbarCentered() {
        let toolbar = ScreenRect(x: 490, y: 736, width: 300, height: 48)
        let rect = PanelPlacement.list(size: CGSize(width: 440, height: 257), toolbar: toolbar, visibleFrame: visible)
        #expect(rect == ScreenRect(x: 420, y: 467, width: 440, height: 257))
    }

    @Test
    func tallListStopsAtVisibleTop() {
        let toolbar = ScreenRect(x: 490, y: 736, width: 300, height: 48)
        let rect = PanelPlacement.list(size: CGSize(width: 440, height: 760), toolbar: toolbar, visibleFrame: visible)
        #expect(rect.y == 28)
    }

    @Test
    func commentMatchesPaper() {
        let frame = ScreenRect(x: 910, y: 468, width: 204, height: 56)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: visible)
        #expect(rect == ScreenRect(x: 814, y: 536, width: 300, height: 76))
    }

    @Test
    func commentGoesAboveWhenBelowDoesNotFit() {
        let frame = ScreenRect(x: 600, y: 700, width: 200, height: 60)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: visible)
        #expect(rect == ScreenRect(x: 500, y: 612, width: 300, height: 76))
    }

    @Test
    func commentGoesInsideWhenNeitherFits() {
        let frame = ScreenRect(x: 100, y: 40, width: 1000, height: 750)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: visible)
        #expect(rect == ScreenRect(x: 800, y: 702, width: 300, height: 76))
    }

    @Test
    func commentShiftsRightNearLeftEdge() {
        let frame = ScreenRect(x: 0, y: 100, width: 120, height: 40)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: visible)
        #expect(rect.x == 8)
        #expect(rect.y == 152)
    }

    @Test
    func commentShiftsLeftNearRightEdge() {
        let frame = ScreenRect(x: 1250, y: 100, width: 60, height: 40)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: visible)
        #expect(rect.x == 1280 - 8 - 300)
    }

    @Test
    func commentOnSecondaryScreenWithNegativeOrigin() {
        let frame = ScreenRect(x: -1400, y: -60, width: 100, height: 50)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: secondaryVisible)
        #expect(rect == ScreenRect(x: -1432, y: 2, width: 300, height: 76))
    }

    @Test
    func commentAboveOnSecondaryScreenBottom() {
        let frame = ScreenRect(x: -600, y: 720, width: 200, height: 60)
        let rect = PanelPlacement.comment(size: CGSize(width: 300, height: 76), frame: frame, visibleFrame: secondaryVisible)
        #expect(rect == ScreenRect(x: -700, y: 632, width: 300, height: 76))
    }

    @Test
    func sizeLabelMatchesPaper() {
        let rect = PanelPlacement.sizeLabel(size: CGSize(width: 69, height: 22), cursor: CGPoint(x: 702, y: 372), visibleFrame: visible)
        #expect(rect == ScreenRect(x: 618, y: 382, width: 69, height: 22))
    }

    @Test
    func sizeLabelFlipsUpNearBottom() {
        let rect = PanelPlacement.sizeLabel(size: CGSize(width: 69, height: 22), cursor: CGPoint(x: 702, y: 790), visibleFrame: visible)
        #expect(rect == ScreenRect(x: 618, y: 758, width: 69, height: 22))
    }

    @Test
    func sizeLabelFlipsRightNearLeftEdge() {
        let rect = PanelPlacement.sizeLabel(size: CGSize(width: 69, height: 22), cursor: CGPoint(x: 40, y: 300), visibleFrame: visible)
        #expect(rect == ScreenRect(x: 55, y: 310, width: 69, height: 22))
    }

    @Test
    func sizeLabelOnSecondaryScreen() {
        let normal = PanelPlacement.sizeLabel(size: CGSize(width: 69, height: 22), cursor: CGPoint(x: -700, y: -20), visibleFrame: secondaryVisible)
        #expect(normal == ScreenRect(x: -784, y: -10, width: 69, height: 22))
        let corner = PanelPlacement.sizeLabel(size: CGSize(width: 69, height: 22), cursor: CGPoint(x: -1420, y: 795), visibleFrame: secondaryVisible)
        #expect(corner == ScreenRect(x: -1405, y: 763, width: 69, height: 22))
    }

    @Test
    func screenUnderPointFallsBackToPrimary() {
        let screens = [FakeScreens.primary, FakeScreens.secondary]
        #expect(ScreenInfo.containing(CGPoint(x: -10, y: 0), in: screens)?.id == FakeScreens.secondary.id)
        #expect(ScreenInfo.containing(CGPoint(x: 10, y: 10), in: screens)?.id == FakeScreens.primary.id)
        #expect(ScreenInfo.containing(CGPoint(x: 5000, y: 5000), in: screens)?.id == FakeScreens.primary.id)
    }
}
