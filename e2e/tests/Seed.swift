import XCTest
import AkapenAXID

final class Seed: AkapenUITestCase {
    func testShowToolbar() throws {
        startDrawing()
        waitForPhase("drawing")
        XCTAssertTrue(app.buttons[AXID.Toolbar.copyPrompt].exists)
    }
}
