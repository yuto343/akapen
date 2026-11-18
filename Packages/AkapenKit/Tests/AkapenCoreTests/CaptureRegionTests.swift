import Testing
@testable import AkapenCore

private func window(_ id: UInt32, _ x: Double, _ y: Double, _ width: Double, _ height: Double, app: String? = nil) -> CaptureWindow {
    CaptureWindow(id: id, frame: ScreenRect(x: x, y: y, width: width, height: height), appName: app ?? "App \(id)")
}

private let mainScreen = ScreenDescriptor(id: 1, frame: ScreenRect(x: 0, y: 0, width: 1440, height: 900))

private func resolve(_ frame: ScreenRect, _ windows: [CaptureWindow], screen: ScreenDescriptor = mainScreen) -> CaptureRegion {
    CaptureRegion.resolve(frame: frame, screen: screen, windows: windows)
}

/// 枠内に見えているウィンドウ全体を、まとめて囲む範囲を撮る。
@Suite
struct CaptureRegionWindowTests {
    @Test
    func frameInsideOneWindowCapturesThatWindow() {
        let editor = window(1, 100, 80, 800, 600)
        let region = resolve(ScreenRect(x: 300, y: 200, width: 120, height: 60), [editor])
        #expect(region.rect == editor.frame)
        #expect(region.windows == [editor])
    }

    @Test
    func frameAcrossTwoWindowsCapturesBoth() {
        // 左右に並んだ 2 つのウィンドウの境目をまたぐ枠。両方を囲む矩形を撮る。
        let left = window(1, 0, 100, 600, 500)
        let right = window(2, 600, 50, 700, 700)
        let region = resolve(ScreenRect(x: 500, y: 300, width: 200, height: 100), [left, right])
        #expect(region.rect == ScreenRect(x: 0, y: 50, width: 1300, height: 700))
        #expect(Set(region.windows.map(\.id)) == [1, 2])
    }

    @Test
    func frontDialogInsideFrameIsIncludedWithBackWindow() {
        // 奥のエディタの上に手前の小さいダイアログ。枠は両方にかかる。
        let dialog = window(1, 300, 300, 200, 150)
        let editor = window(2, 0, 0, 1000, 800)
        let region = resolve(ScreenRect(x: 250, y: 250, width: 200, height: 200), [dialog, editor])
        #expect(region.rect == editor.frame)
        // 見えている面積は、ダイアログ 150×150 = 22500、エディタ 40000 - 22500 = 17500。
        #expect(region.windows.map(\.id) == [1, 2])
    }

    @Test
    func barelyTouchedWindowIsLeftOut() {
        // 枠（100×100 = 10000）の右下 20×20 = 400（4%）だけが手前の小窓にかかる。小窓は範囲に入らない。
        let small = window(1, 380, 380, 300, 300)
        let editor = window(2, 0, 0, 400, 400)
        let region = resolve(ScreenRect(x: 300, y: 300, width: 100, height: 100), [small, editor])
        #expect(region.rect == editor.frame)
        #expect(region.windows.map(\.id) == [2])
    }

    @Test
    func exactlyFivePercentIsIncluded() {
        // 枠の 5% ちょうど（100×100 のうち 5×100 = 500）は入る。
        let side = window(1, 0, 0, 105, 400)
        let editor = window(2, 100, 0, 600, 400)
        let region = resolve(ScreenRect(x: 100, y: 100, width: 100, height: 100), [side, editor])
        #expect(region.rect == ScreenRect(x: 0, y: 0, width: 700, height: 400))
        #expect(region.windows.map(\.id) == [2, 1])
    }

    @Test
    func windowHiddenBehindFrontWindowIsLeftOut() {
        // 枠は手前のウィンドウの内側だけにある。奥のウィンドウは枠と重なるが、見えている部分がないので入らない。
        let front = window(1, 100, 100, 400, 300)
        let back = window(2, 0, 0, 1200, 800)
        let region = resolve(ScreenRect(x: 150, y: 150, width: 100, height: 100), [front, back])
        #expect(region.rect == front.frame)
        #expect(region.windows.map(\.id) == [1])
    }

    @Test
    func orderDecidesWhichWindowIsVisible() {
        // 同じ 2 つのウィンドウでも、並び（手前から）で見えているものが変わる。
        let a = window(1, 0, 0, 300, 300)
        let b = window(2, 0, 0, 600, 600)
        let frame = ScreenRect(x: 100, y: 100, width: 100, height: 100)
        #expect(resolve(frame, [a, b]).rect == a.frame)
        #expect(resolve(frame, [b, a]).rect == b.frame)
    }

    @Test
    func windowOutsideFrameIsLeftOut() {
        let editor = window(1, 0, 0, 600, 600)
        let far = window(2, 900, 0, 400, 400)
        let region = resolve(ScreenRect(x: 100, y: 100, width: 100, height: 100), [editor, far])
        #expect(region.rect == editor.frame)
    }
}

/// 見えているウィンドウがなければ、枠のまわりに余白を足して撮る。
@Suite
struct CaptureRegionWithoutWindowTests {
    @Test
    func noWindowsAddsMarginAroundFrame() {
        let region = resolve(ScreenRect(x: 500, y: 300, width: 100, height: 80), [])
        #expect(region.rect == ScreenRect(x: 300, y: 100, width: 500, height: 480))
        #expect(region.windows.isEmpty)
        #expect(region.sourceAppName == "")
    }

    @Test
    func onlyBarelyTouchedWindowsAddsMarginAroundFrame() {
        // かすっただけ（5% 未満）のウィンドウしかなければ、ウィンドウがないのと同じ。
        let edge = window(1, 0, 0, 302, 1000)
        let region = resolve(ScreenRect(x: 300, y: 300, width: 100, height: 100), [edge])
        #expect(region.rect == ScreenRect(x: 100, y: 100, width: 500, height: 500))
        #expect(region.windows.isEmpty)
    }

    @Test
    func fractionalFrameIsRoundedOutwardToWholePoints() {
        let region = resolve(ScreenRect(x: 500.4, y: 300.6, width: 100.2, height: 80.1), [])
        #expect(region.rect == ScreenRect(x: 300, y: 100, width: 501, height: 481))
    }
}

/// 範囲は、枠を描いたディスプレイの中に切り詰める。
@Suite
struct CaptureRegionScreenTests {
    @Test
    func marginIsClippedAtScreenEdge() {
        // 画面の左上の角に描いた枠。余白は画面の外にはみ出さない。
        let region = resolve(ScreenRect(x: 20, y: 30, width: 100, height: 50), [])
        #expect(region.rect == ScreenRect(x: 0, y: 0, width: 320, height: 280))
        // 右下の角。
        let corner = resolve(ScreenRect(x: 1380, y: 860, width: 50, height: 30), [])
        #expect(corner.rect == ScreenRect(x: 1180, y: 660, width: 260, height: 240))
    }

    @Test
    func windowExtendingOffScreenIsClipped() {
        // 画面の右にはみ出したウィンドウ（隣のディスプレイにまたがる）は、この画面の中だけを撮る。
        let wide = window(1, 1000, 100, 1200, 600)
        let region = resolve(ScreenRect(x: 1100, y: 200, width: 100, height: 100), [wide])
        #expect(region.rect == ScreenRect(x: 1000, y: 100, width: 440, height: 600))
        #expect(region.windows.map(\.id) == [1])
    }

    @Test
    func screenWithNegativeCoordinates() {
        // 主画面の左上に置いた画面（座標が負）。
        let left = ScreenDescriptor(id: 2, frame: ScreenRect(x: -1920, y: -300, width: 1920, height: 1080))
        let terminal = window(1, -1500, -200, 800, 500)
        let inside = resolve(ScreenRect(x: -1400, y: -100, width: 200, height: 100), [terminal], screen: left)
        #expect(inside.rect == terminal.frame)
        // ウィンドウのない所。余白は画面の上端（y: -300）と左端（x: -1920）で止まる。
        let empty = resolve(ScreenRect(x: -1900, y: -280, width: 100, height: 60), [terminal], screen: left)
        #expect(empty.rect == ScreenRect(x: -1920, y: -300, width: 320, height: 280))
        #expect(empty.windows.isEmpty)
    }

    @Test
    func windowsOnOtherScreenDoNotWidenRegion() {
        // 枠の一部が隣の画面に出ていても、範囲はこの画面の中だけ。
        let right = ScreenDescriptor(id: 3, frame: ScreenRect(x: 1440, y: 0, width: 1280, height: 800))
        let main = window(1, 800, 100, 640, 600)
        let other = window(2, 1440, 0, 1280, 800)
        let region = resolve(ScreenRect(x: 1400, y: 200, width: 100, height: 100), [main, other], screen: mainScreen)
        #expect(region.rect == ScreenRect(x: 800, y: 0, width: 640, height: 800))
        let onRight = resolve(ScreenRect(x: 1400, y: 200, width: 100, height: 100), [main, other], screen: right)
        #expect(onRight.rect == ScreenRect(x: 1440, y: 0, width: 1280, height: 800))
    }

    @Test
    func frameEntirelyOffScreenFallsBackToWholeScreen() {
        let region = resolve(ScreenRect(x: 3000, y: 3000, width: 50, height: 50), [])
        #expect(region.rect == mainScreen.frame)
    }
}

/// 一覧に出すアプリ名。
@Suite
struct CaptureRegionAppNameTests {
    @Test
    func appNamesAreOrderedByVisibleAreaWithoutDuplicates() {
        // 枠 200×100。Notion が 120×100、T3 Code が 60×100、もう 1 枚の Notion が 20×100 見えている。
        let notion = window(1, 0, 0, 120, 400, app: "Notion")
        let t3 = window(2, 120, 0, 60, 400, app: "T3 Code")
        let notionOther = window(3, 180, 0, 400, 400, app: "Notion")
        let region = resolve(ScreenRect(x: 0, y: 100, width: 200, height: 100), [t3, notionOther, notion])
        #expect(region.windows.map(\.id) == [1, 2, 3])
        #expect(region.sourceAppName == "Notion, T3 Code")
    }

    @Test
    func sameVisibleAreaKeepsFrontWindowFirst() {
        let a = window(1, 0, 0, 100, 400, app: "Front")
        let b = window(2, 100, 0, 100, 400, app: "Back")
        let region = resolve(ScreenRect(x: 50, y: 100, width: 100, height: 100), [a, b])
        #expect(region.sourceAppName == "Front, Back")
    }

    @Test
    func emptyAppNamesAreSkipped() {
        let unnamed = window(1, 0, 0, 150, 400, app: "")
        let named = window(2, 150, 0, 400, 400, app: "Finder")
        let region = resolve(ScreenRect(x: 100, y: 100, width: 100, height: 100), [unnamed, named])
        #expect(region.windows.count == 2)
        #expect(region.sourceAppName == "Finder")
    }
}
