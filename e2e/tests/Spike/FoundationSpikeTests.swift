import XCTest
import AkapenAXID
final class FoundationSpikeTests: AkapenUITestCase {
    func testHotkeyDragPanelAndUnderlyingClick() throws { // 1 行編集後の反復時間を測定。
        let button = sample.buttons[AXID.Sample.button]
        let frame = button.frame
        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: -30, dy: -30))
        start.hover()
        startDrawing(); waitForPhase("drawing")
        // SampleTarget のフレームを基準にし、イベントの宛先は描画面にする。
        // 下のアプリの座標 API は XCTest がそのアプリを再アクティブ化する。
        let surface = app.descendants(matching: .any)[AXID.Draw.surface].firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        let origin = surface.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let dragStart = origin.withOffset(CGVector(dx: frame.minX - 30 - surface.frame.minX, dy: frame.minY - 30 - surface.frame.minY))
        dragStart.press(forDuration: 0.1, thenDragTo: dragStart.withOffset(CGVector(dx: 180, dy: 110)))
        waitForPhase("idle")
        let rect = try XCTUnwrap(try appState()["lastDrawnRect"] as? [String: Double])
        XCTAssertEqual(try XCTUnwrap(rect["x"]), frame.minX - 30, accuracy: 4)
        XCTAssertEqual(try XCTUnwrap(rect["y"]), frame.minY - 30, accuracy: 4)
        XCTAssertEqual(try XCTUnwrap(rect["width"]), 180, accuracy: 4)
        XCTAssertEqual(try XCTUnwrap(rect["height"]), 110, accuracy: 4)
        button.click()
        XCTAssertEqual(sample.staticTexts[AXID.Sample.count].value as? String, "1")
        app.buttons[AXID.Toolbar.add].click(); waitForPhase("drawing")
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        waitForPhase("hidden")
    }
}
