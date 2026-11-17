import Testing
import AkapenCore

private func window(_ id: UInt32, _ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CaptureWindow {
    CaptureWindow(id: id, frame: ScreenRect(x: x, y: y, width: width, height: height), appName: "App \(id)")
}

@Test
func picksWindowWithLargestOverlap() {
    let windows = [
        window(1, 0, 0, 100, 100),
        window(2, 100, 0, 300, 300),
    ]
    // 枠は 1 に 20×50、2 に 60×50 かかる。
    let frame = ScreenRect(x: 80, y: 10, width: 80, height: 50)
    #expect(WindowPicker.pick(frame: frame, from: windows)?.id == 2)
}

@Test
func picksFrontmostWhenOverlapIsEqual() {
    let windows = [
        window(3, 0, 0, 100, 100),
        window(4, 100, 0, 100, 100),
    ]
    let frame = ScreenRect(x: 90, y: 10, width: 20, height: 20)
    #expect(WindowPicker.pick(frame: frame, from: windows)?.id == 3)
    #expect(WindowPicker.pick(frame: frame, from: windows.reversed())?.id == 4)
}

@Test
func picksBackWindowWhenItOverlapsMore() {
    // 手前の小さなウィンドウより、奥の大きなウィンドウとの重なりが大きい。
    let windows = [
        window(5, 0, 0, 10, 10),
        window(6, 0, 0, 500, 500),
    ]
    let frame = ScreenRect(x: 0, y: 0, width: 100, height: 100)
    #expect(WindowPicker.pick(frame: frame, from: windows)?.id == 6)
}

@Test
func ignoresWindowsWithoutOverlap() {
    let windows = [
        window(7, 0, 0, 100, 100),
        // 辺で接するだけのものも重なりなし。
        window(8, 200, 0, 100, 100),
    ]
    let frame = ScreenRect(x: 100, y: 0, width: 100, height: 50)
    #expect(WindowPicker.pick(frame: frame, from: windows) == nil)
    #expect(WindowPicker.pick(frame: frame, from: []) == nil)
}

@Test
func worksWithNegativeCoordinates() {
    // 主画面の左にある画面のウィンドウ。
    let windows = [
        window(9, -800, 100, 600, 400),
        window(10, 0, 0, 800, 600),
    ]
    let frame = ScreenRect(x: -300, y: 200, width: 200, height: 100)
    #expect(WindowPicker.pick(frame: frame, from: windows)?.id == 9)
}
